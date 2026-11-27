#!/bin/sh
# 设备侧【只读】导出：把「你关掉/删掉、且验证服务仍正常」的状态带回来。
# 绝不打包 ART / caldata / MAC / host key / shadow / 首启 stamp。
# 刷 factory.bin 只写 kernel + rootfs 两个 UBI 卷；ART 是独立 MTD 分区
# （本仓 3000Q-VS010-固件/VS010-smem_0-ART.bin，1MB），每台机器刷完
# 由官方闭栈自动读自己那一份，无需也不能固化进固件。
set -eu
PATH=/usr/sbin:/usr/bin:/sbin:/bin; export PATH
OUT=${VS010_CAPTURE_DIR:-/tmp}
mkdir -p "$OUT"
WH="$OUT/prune-real.txt"
OPI="$OUT/installed.txt"
TAR="$OUT/rootfs-capture.tar.gz"

echo '── VS010 实机状态导出（只读，不改系统）──'
echo "  ART 分区：不打包、不读取、不写入 → 目标机刷完自动读自己的 ART"

# ① overlay 里的 whiteout 删除标记 = 「你真正删了什么」
if [ -d /overlay/upper ]; then
  find /overlay/upper \( -name '.wh.*' -o -type c \) 2>/dev/null \
    | sed 's|^/overlay/upper/||; s|/\.wh\.|/|' \
    | grep -v '^$' | LC_ALL=C sort -u > "$WH" || : > "$WH"
else
  : > "$WH"
fi
# ② opkg 已装清单（交叉核对，别把 uhttpd / libuci 依赖带走）
opkg list-installed 2>/dev/null | LC_ALL=C sort > "$OPI" || : > "$OPI"
echo "  删除标记 $(wc -l < "$WH") 条 / 已装包 $(wc -l < "$OPI") 条"
echo '  ⚠ 回灌前先 opkg whatdepends <包名>；删完静置 12 分钟 + wifi-check 确认不重启'

if [ "${1:-}" != '--tar' ]; then
  echo "  输出：$WH  $OPI"
  echo '  （加 --tar 才打包 merged rootfs 参考视图；构建只用清单回灌，不用整树替换）'
  exit 0
fi

# ③ 可选：merged rootfs 参考视图。硬排除机器唯一数据与 ART。
#    这只是「给你/给我看差异」的参考，build-from-capture 默认不拿它当注入层。
EX='./proc ./sys ./dev ./tmp ./overlay ./rom ./mnt ./var/run ./run ./root/.ssh'
EX="$EX ./etc/shadow ./etc/shadow- ./etc/dropbear/*_host_key*"
EX="$EX ./etc/config/network ./etc/config/wireless ./etc/config/system"
EX="$EX ./etc/vs010/*.stamp ./etc/.vs010-* ./etc/firmware_mode"
EX="$EX ./etc/hostname ./etc/hosts ./etc/resolv.conf"
EX="$EX ./lib/firmware/*ART* ./lib/firmware/*art* ./lib/firmware/*caldata*"
EX="$EX ./lib/firmware/*smem_0* ./mtd* ./dev/mtd*"
set -- $EX
TAREX=''
for e in "$@"; do TAREX="$TAREX --exclude=$e"; done
# shellcheck disable=SC2086
tar czf "$TAR" -C / $TAREX \
  --exclude='*.wh.*' --exclude='./overlay/upper' . 2>/dev/null || true

# ④ 产物净化断言：文件名里不许出现 ART / MAC / host key / shadow
LIST=$(tar tzf "$TAR" 2>/dev/null | grep -iE 'ART|caldata|smem_0|host_key|/etc/shadow|\.wh\.' || true)
if [ -n "$LIST" ]; then
  echo '::error:: 参考包混入了机器唯一数据，已删除该包：' >&2
  printf '%s\n' "$LIST" | head -10 >&2
  rm -f "$TAR"; exit 1
fi
echo "  参考包：$TAR  $(wc -c < "$TAR") B（不含 ART/MAC/密钥，仅供比对）"
echo "  输出：$WH  $OPI  $TAR"
echo '  回灌：sh tools/build-from-capture.sh --capture=/tmp/prune-real.txt --device=all --mode=all'
