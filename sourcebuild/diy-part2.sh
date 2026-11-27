#!/bin/sh
# DIY part 2：.config 与 files/ 已就位之后执行（在 openwrt/ 下）。
set -eu
echo "[diy-p2] 源码编译线配置核对"

# 🔴 安全网：files 大法里绝不放官方无线/驱动/配置目录（由编译期包提供）
for k in lib/firmware lib/modules etc/uci-defaults etc/board.d etc/config/network etc/config/wireless; do
  [ ! -e "files/$k" ] || { echo "::error::files/ 含禁止路径 $k"; exit 1; }
done

# 记录当前配置要点（日志简洁）
grep -E '^CONFIG_TARGET_PROFILE|^CONFIG_LINUX_5_4|^CONFIG_PACKAGE_(kmod-ath11k|luci-theme-argon|luci-app-ttyd|ttyd|ethtool|swconfig)=' .config \
  | sed 's/^/[cfg] /' || true
echo "[cfg] Argon 版本由 Replace Argon theme step 固定为 v2.4.3（Lua 兼容）"
echo "[cfg] 常驻守护：仅 vs010-tick（NTP/Snooping/WDS/机器狗分频）"
echo "[cfg] 内存：关 autoreboot / firewall 菜单 / bootstrap / odhcpd-ipv6only / dnsmasq 冗余特性"

# ── r25 验收标准（以后每版都按此自检，见 STANDARDS.md）────────────────
for k in CONFIG_PACKAGE_dropbear=y CONFIG_PACKAGE_ttyd=y CONFIG_PACKAGE_luci-app-ttyd=y \
         CONFIG_PACKAGE_ethtool=y CONFIG_PACKAGE_swconfig=y \
         CONFIG_PACKAGE_kmod-ath11k=y CONFIG_PACKAGE_kmod-qca-nss-dp=y; do
  grep -Fxq "$k" .config || { echo "::error::[STANDARDS] 缺必备项 $k（SSH/串口/TTYD/速率/无线）"; exit 1; }
done
grep -Fxq '# CONFIG_PACKAGE_autocore-arm is not set' .config \
  || { echo "::error::[STANDARDS] autocore-arm 未关，内存不达标"; exit 1; }
echo "[STANDARDS] OK  SSH(dropbear) + 串口(ttyMSM0) + TTYD + 速率 + 无线 + 低内存"

echo "[diy-p2] ✅ 完成"
