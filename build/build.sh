#!/bin/sh
# 两机型共用入口：组装 files/ + files.<机型>/ -> 以官方固件为底座叠加 -> 出固件
# 用法: sh build/build.sh --device=cucc_vs010|cmcc_rax3000q [--mode=wds|ap]
set -eu
cd "$(dirname "$0")/.."
D=${1#--device=}
MODE=wds
for a in "$@"; do case "$a" in --mode=*) MODE=${a#--mode=} ;; esac; done
case "$MODE" in wds|ap) ;; *) echo "::error::未知模式 $MODE"; exit 1 ;; esac
FW=3000Q-VS010-固件
case "$D" in
  cucc_vs010)
    SRC="$FW/Nwrt-QSDK12.2-2024-04-16-ipq50xx-ipq50xx_32-cucc_vs010-squashfs-nand-factory.bin"
    LAYER=files.vs010; TAG=cucc_vs010 ;;
  cmcc_rax3000q)
    SRC="$FW/Nwrt-QSDK12.2-2024-04-16-ipq50xx-ipq50xx_32-cmcc_rax3000qy-squashfs-nand-factory.bin"
    LAYER=files.rax3000q; TAG=cmcc_rax3000qy ;;
  *) echo "::error::未知机型 $D"; exit 1 ;;
esac
[ -s "$SRC" ] || { echo "::error::缺官方底座 $SRC"; exit 1; }
for t in unsquashfs mksquashfs python3; do command -v $t >/dev/null || { echo "::error::缺 $t"; exit 1; }; done

T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
( cd files && tar cf - . ) | ( cd "$T" && tar xf - )
( cd "$LAYER" && tar cf - . ) | ( cd "$T" && tar xf - )
# 机型层的说明文档只给仓库看，不进固件 rootfs
find "$T" -type f \( -name '*.md' -o -name 'README*' \) -delete
mkdir -p "$T/etc" "$T/etc/rc.d"
# ★ 注入的 init.d 脚本必须自带 rc.d 自启链接，否则刷完根本不会运行
#   （squashfs 只读，/etc/init.d/xxx enable 在构建期做不到）
for pair in '18:vs010-luci-fix' '94:vs010-wds-pair' '95:vs010-dhcp-guard' '96:vs010-ntp' \
            '97:vs010-watchdog' '99:vs010-mode'; do
  N=${pair%%:*}; S=${pair##*:}
  ln -s "../init.d/$S" "$T/etc/rc.d/S${N}${S}"
done
# 构建期写入默认模式（运行期仍可 vs010-mode set ap|wds 切换）
printf '%s\n' "$MODE" > "$T/etc/vs010/mode"
printf 'Nwrt-QSDK12.2-5.4-%s-%s-%s\n' "$(date +%Y%m%d)" "$TAG" "$MODE" > "$T/etc/firmware_build"
# ★ 设备侧导出工具必须随固件刷进去，否则用户刷完找不到脚本
mkdir -p "$T/usr/sbin"
cp tools/rootfs-capture.sh "$T/usr/sbin/vs010-capture"
chmod 755 "$T/usr/sbin/vs010-capture"

# 🔴 安全网：注入树绝不许碰官方配置 / 驱动 / BDF / 分区
for k in etc/config lib/firmware lib/modules etc/rc.local etc/uci-defaults \
         etc/config/network etc/config/wireless; do
  [ ! -e "$T/$k" ] || { echo "::error::注入树含禁止路径 $k"; exit 1; }
done
echo "[build] $D / $MODE : 注入 $(find "$T" -type f | wc -l) 个新增文件，底座 $(basename "$SRC")"

OUT="Nwrt-QSDK12.2-5.4-$(date +%Y%m%d)-ipq50xx-arm-$TAG-$MODE-squashfs-nand-factory.bin"
VS010_PRUNE_LIST=build/prune.list VS010_PRUNE_KEEP=build/prune.keep \
  python3 build/fused.py "$SRC" "$T" "$OUT"
sha256sum "$OUT" | tee "$OUT.sha256"
echo "[build] OK  $OUT"
