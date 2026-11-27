#!/bin/sh
# PC 侧：把实机导出的「删除清单」回灌构建，重出可刷多台的优化固件。
# 只回灌【清单】，不做整树替换 → kernel FIT / BDF / 闭源驱动仍是官方原卷，
# ART 不进固件，每台机器刷完自动读自己的 ART 分区。
set -eu
cd "$(dirname "$0")/.."
CAP=''; INS=''; DEV=cucc_vs010; MODE=wds; DRY=0
for a in "$@"; do case "$a" in
  --capture=*)   CAP=${a#--capture=} ;;
  --installed=*) INS=${a#--installed=} ;;
  --device=*)    DEV=${a#--device=}  ;;
  --mode=*)      MODE=${a#--mode=}   ;;
  --dryrun)      DRY=1 ;;
  *) echo "::error::未知参数 $a"; exit 1 ;;
esac; done
# 第 12 次：设备无 whiteout 时直接用 opkg list-installed 作双机型共用基线
if [ -n "$INS" ]; then
  [ "$DRY" = 1 ] && exec sh tools/apply-installed-baseline.sh --dryrun \
                 || exec sh tools/apply-installed-baseline.sh --device="$DEV" --mode="$MODE"
fi
[ -n "$CAP" ] && [ -r "$CAP" ] || { echo '::error::缺 --capture=<prune-real.txt> 或 --installed=<list>'; exit 1; }

echo '── VS010 清单回灌 ──'
echo '  ART 分区不进固件：factory.bin 只有 layout/kernel/rootfs 三个 UBI 卷，'
echo '  ART 是独立 MTD（smem_0），刷机不覆盖，每台机器自读自己的校准数据。'

# ① 硬护栏：清单绝不允许碰无线栈 / 主题 / SSH / 网络配置 / 驱动
BAD=$(grep -v '^#' "$CAP" | grep -v '^[[:space:]]*$' \
  | grep -E '^\.\./|^/|lib/firmware|lib/modules|bdwlan|qca_ol|umac|wifi_3_0|ipq_cnss2|ART|caldata|smem_0|etc/inittab|etc/board\.d|etc/config/(luci|uhttpd|argon|network|wireless|dhcp)|usr/bin/ttyd|usr/sbin/(dropbear|ethtool|iw|wlanconfig)|www/cgi-bin/luci|dispatcher|themes/argon|controller/terminal' || true)
if [ -n "$BAD" ]; then
  echo '::error:: 清单含禁止路径（会破坏无线/主题/SSH），拒绝回灌：' >&2
  printf '%s\n' "$BAD" | head -12 >&2
  exit 1
fi

# ② 幂等追加：先删上一轮回灌块，再写新块（重复运行不累积）
P=build/prune.list
if grep -q '^# ── FROM CAPTURE' "$P" 2>/dev/null; then
  awk '/^# ── FROM CAPTURE/{exit} {print}' "$P" > "$P.tmp" && mv -f "$P.tmp" "$P"
fi
{
  printf '# ── FROM CAPTURE：实机验证「删完服务仍正常」后导出，勿手改 ──\n'
  grep -v '^#' "$CAP" | grep -v '^[[:space:]]*$' | LC_ALL=C sort -u
} >> "$P"
N=$(grep -c '^# ── FROM CAPTURE' "$P")
echo "  回灌条目 $(grep -v '^#' "$CAP" | grep -cv '^[[:space:]]*$') 条；prune.list 现 $(grep -cv '^#\|^[[:space:]]*$' "$P") 条"

# ③ 自检 + 出固件
sh verify.sh
[ "$DRY" = 1 ] && { echo '  --dryrun：只回灌与自检，未构建'; exit 0; }
case "$DEV" in all) DEVS='cucc_vs010 cmcc_rax3000q' ;; cucc_vs010|cmcc_rax3000q) DEVS=$DEV ;; *) echo '::error::机型错'; exit 1;; esac
case "$MODE" in all) MODES='wds ap' ;; wds|ap) MODES=$MODE ;; *) echo '::error::模式错'; exit 1;; esac
for d in $DEVS; do for m in $MODES; do
  echo "  → build $d / $m"
  sh build/build.sh --device="$d" --mode="$m"
done; done
echo '  ✅ 完成。产物名带 5.4；按机型严格对应刷，别勾「保留配置」。'
