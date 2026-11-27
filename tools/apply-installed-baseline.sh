#!/bin/sh
# 第 12 次：把实机「最干净系统」的 opkg list-installed 清单，作为
# VS010 / RAX3000Q 两个机型【共用】的保留基线，回灌构建期精简。
#
# 背景：设备上 find /overlay -name '.wh.*' 为空是正常的 —— 说明当时是
# stop+disable 而非 opkg remove，没有 whiteout 删除标记。此时
# installed-allowlist.txt（还剩哪些包）本身就是最可靠的依据，不必再导。
#
# 只删「基线里没有的杂项包」对应的 UCI 配置 / 自启链接 / LuCI 控制器；
# 物理二进制与内核模块一律不删（不启动就不占内存 CPU，也避免破坏闭源依赖）。
# kernel FIT / BDF / qca_ol·umac·wifi_3_0·ipq_cnss2 / ART 零改动。
#
# 用法:
#   sh tools/apply-installed-baseline.sh --dryrun
#   sh tools/apply-installed-baseline.sh --device=all --mode=all
set -eu
cd "$(dirname "$0")/.."
AL=capture/installed-allowlist.txt
P=build/prune.list
DRY=0; DEV=cucc_vs010; MODE=wds
for a in "$@"; do case "$a" in
  --dryrun) DRY=1 ;;
  --device=*) DEV=${a#--device=} ;;
  --mode=*) MODE=${a#--mode=} ;;
  *) echo "::error::未知参数 $a"; exit 1 ;;
esac; done

echo '── 第 12 次：双机型共用「实机保留基线」回灌 ──'
echo '  ART 不进固件：factory.bin 只有 layout/kernel/rootfs 三个 UBI 卷，'
echo '  ART 是独立 MTD（smem_0），每台机器刷完自动读自己的校准数据。'
[ -r "$AL" ] || { echo "::error::缺 $AL"; exit 1; }

# ① 基线自身硬护栏：必须确实来自这台 5.4.213 好固件，且无线栈/管理入口都在。
N=$(grep -cv '^[[:space:]]*$' "$AL")
[ "$N" -ge 200 ] || { echo "::error::基线只有 $N 行，不像完整 opkg 清单"; exit 1; }
for k in 'kernel - 5.4.213' 'qca-wifi-fw-hw4' 'qca-cnss-daemon' 'qca-hostap' \
         'ttyd' 'luci-theme-argonv3' 'dropbear' 'uhttpd' 'ethtool' 'swconfig' \
         'kmod-qca-nss-drv' 'libiwinfo-lua'; do
  grep -qF "$k" "$AL" || { echo "::error::基线缺关键项 [$k]，拒绝回灌（无线/主题/管理可能被误删）"; exit 1; }
done
echo "  OK 基线 $N 行，5.4.213 闭源栈 / Argon / TTYD / SSH / 速率工具齐全"

# ② 杂项包 → 可精简路径映射。仅当包名【不在基线】时才输出。
#    路径全部避开 prune.keep；不删 init.d 脚本（运行期 vs010-mode 仍会调用）。
cat > /tmp/.vs010-junkmap.$$ <<'MAP'
etc/config/firewall|firewall
etc/config/wireguard|wireguard
etc/config/odhcpd|odhcpd
etc/config/ddns|ddns-scripts
etc/config/upnpd|miniupnpd
etc/config/zerotier|zerotier
etc/config/ddns-go|ddns-go
etc/config/autoreboot|luci-app-autoreboot
etc/config/pppoe|pppoe-server
etc/config/mia|mia
etc/config/lldpd|lldpd
etc/config/ripd|quagga-ripd
etc/config/dhcrelay|dhcrelay
etc/config/macsec|qca-hostap-macsec
etc/config/cnss_diag|cnssdiag
etc/rc.d/S60dnsmasq|dnsmasq
etc/rc.d/S19firewall|firewall
etc/rc.d/S35odhcpd|odhcpd
etc/rc.d/S50autoreboot|luci-app-autoreboot
etc/rc.d/S95ddns|ddns-scripts
etc/rc.d/S99ddns-go|ddns-go
etc/rc.d/S99zerotier|zerotier
etc/rc.d/S94miniupnpd|miniupnpd
etc/rc.d/S50pppoe-server|pppoe-server
etc/rc.d/S60pppoe-relay|pppoe-relay
etc/rc.d/S91dhcrelay4|dhcrelay
etc/rc.d/S30mia|mia
etc/rc.d/S90lldpd|lldpd
etc/rc.d/S90quagga|quagga
etc/rc.d/S80relayd|relayd
etc/rc.d/S12breakpad|breakpad
etc/rc.d/S19cnss_diag|cnssdiag
etc/rc.d/S98diag_socket_app|qca-diag
usr/lib/lua/luci/controller/firewall.lua|firewall
usr/lib/lua/luci/controller/qos.lua|luci-app-qos
usr/lib/lua/luci/controller/samba.lua|luci-app-samba
usr/lib/lua/luci/controller/minidlna.lua|luci-app-minidlna
usr/lib/lua/luci/controller/transmission.lua|luci-app-transmission
usr/lib/lua/luci/controller/openvpn.lua|luci-app-openvpn
usr/lib/lua/luci/controller/adblock.lua|luci-app-adblock
usr/lib/lua/luci/controller/banip.lua|luci-app-banip
usr/lib/lua/luci/controller/ddns.lua|luci-app-ddns
usr/lib/lua/luci/controller/wireguard.lua|luci-app-wireguard
usr/lib/lua/luci/controller/autoreboot.lua|luci-app-autoreboot
usr/lib/lua/luci/controller/ddns-go.lua|ddns-go
usr/lib/lua/luci/controller/filetransfer.lua|luci-app-filetransfer
usr/lib/lua/luci/controller/mia.lua|mia
usr/lib/lua/luci/controller/upnp.lua|luci-app-upnp
usr/lib/lua/luci/controller/zerotier.lua|luci-app-zerotier
MAP

# ③ 生成块：包名在基线里 → 跳过（保留原厂状态）；不在 → 加入精简。
BLOCK=/tmp/.vs010-block.$$
: > "$BLOCK"
KEPT=0; CUT=0
while IFS='|' read -r path pkg; do
  [ -n "$path" ] || continue
  if awk -v p="$pkg" '$1==p{f=1} END{exit !f}' "$AL"; then
    KEPT=$((KEPT+1)); continue
  fi
  printf '%s\n' "$path" >> "$BLOCK"; CUT=$((CUT+1))
done < /tmp/.vs010-junkmap.$$
rm -f /tmp/.vs010-junkmap.$$
sort -u "$BLOCK" -o "$BLOCK"
echo "  基线内保留 $KEPT 项；基线外新增精简 $CUT 条（两机型共用同一份）"

# ④ 二次护栏：生成结果绝不能碰无线 / 主题 / SSH / 内核 / 网络配置 / 官方驱动。
BAD=$(grep -E '^\.\./|^/|lib/firmware|lib/modules|bdwlan|qca_ol|umac|wifi_3_0|ipq_cnss2|ART|caldata|smem_0|etc/inittab|etc/board\.d|etc/config/(luci|uhttpd|argon|network|wireless|dhcp|dropbear|ttyd)|usr/bin/ttyd|usr/sbin/(dropbear|ethtool|iw|wlanconfig)|www/cgi-bin/luci|dispatcher|themes/argon|controller/(terminal|argon-config)|rc.d/S(00|13|16|19dropbear|20|26|50uhttpd|70|98sysntpd|99ttyd)' "$BLOCK" || true)
[ -z "$BAD" ] || { echo '::error::回灌块含禁止路径：'; printf '%s\n' "$BAD" | head -8; rm -f "$BLOCK"; exit 1; }
# 与 prune.keep 求交集：有任何一项命中即停止出包
CROSS=$(grep -v '^#' build/prune.keep | grep -v '^[[:space:]]*$' | grep -Fxf "$BLOCK" || true)
[ -z "$CROSS" ] || { echo '::error::回灌块与白名单冲突：'; printf '%s\n' "$CROSS" | head -8; rm -f "$BLOCK"; exit 1; }
echo '  OK 无线栈 / Argon / SSH / 串口 / TTYD 全部避开（prune.keep 零交集）'

# ⑤ 幂等追加：先删上一轮回灌块，再写新块。
if grep -q '^# ── FROM INSTALLED BASELINE' "$P" 2>/dev/null; then
  awk '/^# ── FROM INSTALLED BASELINE/{exit} {print}' "$P" > "$P.tmp" && mv -f "$P.tmp" "$P"
fi
{
  printf '# ── FROM INSTALLED BASELINE：capture/installed-allowlist.txt（双机型共用，勿手改）──\n'
  cat "$BLOCK"
} >> "$P"
rm -f "$BLOCK"
echo "  prune.list 现 $(grep -cv '^#\|^[[:space:]]*$' "$P") 条"

# ⑥ 自检
sh verify.sh
[ "$DRY" = 1 ] && { echo '  --dryrun：只回灌与自检，未构建'; exit 0; }

case "$DEV" in all) DEVS='cucc_vs010 cmcc_rax3000q' ;; cucc_vs010|cmcc_rax3000q) DEVS=$DEV ;; *) echo '::error::机型错'; exit 1;; esac
case "$MODE" in all) MODES='wds ap' ;; wds|ap) MODES=$MODE ;; *) echo '::error::模式错'; exit 1;; esac
for d in $DEVS; do for m in $MODES; do
  echo "  → build $d / $m"
  sh build/build.sh --device="$d" --mode="$m"
done; done
echo '  ✅ 两机型两模式出包完成；产物名带 5.4，按机型严格对应刷，别勾「保留配置」。'
