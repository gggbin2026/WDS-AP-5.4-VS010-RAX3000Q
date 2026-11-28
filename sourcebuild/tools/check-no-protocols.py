#!/usr/bin/env python3
"""r29.7：make defconfig 之后硬校验（dnsmasq-full 必须保留供 AP 可选 DHCP）。
MUST_OFF 被拉回 / MUST_KEEP 缺失  → ::error:: 拒绝出包（保证没多余协议、且加速与后台不坏）。
BEST_EFFORT / KERNEL_SLIM 被 Kconfig 拉回 → 只给 notice，不阻断编译。
--no-keep 仅用于 verify.sh 的单元测试（最小 .config 正例）。
"""
import sys,pathlib,re
args=[a for a in sys.argv[1:] if not a.startswith('--')]
NO_KEEP='--no-keep' in sys.argv
cfg=pathlib.Path(args[0] if args else '.config')
s=cfg.read_text()

MUST="""ppp ppp-mod-pppoe kmod-ppp kmod-pppoe kmod-pppox kmod-pptp luci-proto-ppp
kmod-qca-nss-drv-pppoe ipv6helper luci-proto-ipv6 odhcp6c 6in4
rpcd-mod-rrdns""".split()
BEST="""firewall ip6tables ip6tables-mod-nat libip6tc kmod-ip6tables kmod-ipt-nat6
kmod-nf-conntrack6 kmod-nf-ipt6 kmod-nf-nat6 kmod-nf-reject6
block-mount luci-app-filetransfer luci-i18n-filetransfer-zh-cn""".split()
# ★ 加速全链路 + LuCI 后台核心 + 管理通道：缺一个都不许出包
KEEP="""kmod-ath11k kmod-mac80211 kmod-cfg80211 MAC80211_NSS_SUPPORT
kmod-qca-nss-dp kmod-qca-nss-drv kmod-qca-nss-ecm-standard
kmod-qca-nss-drv-wifi-meshmgr kmod-qca-ssdk-nohnat qca-nss-fw-ipq50xx-retail
luci luci-base luci-mod-admin-full luci-mod-network luci-mod-status luci-mod-system
uhttpd rpcd rpcd-mod-luci opkg dropbear ttyd luci-app-ttyd
luci-app-turboacc luci-theme-argon ethtool swconfig curl jsonfilter libuci ubus wpad-wolfssl dnsmasq-full""".split()
KSLIM="IP_MROUTE IPV6_MROUTE IPV6_MULTIPLE_TABLES IPV6_SUBTREES IPV6_SEG6_LWTUNNEL NAMESPACES".split()

def on(n): return bool(re.search(rf'^CONFIG_(?:PACKAGE|DEFAULT)_{re.escape(n)}=y$',s,re.M))
rc=0
bad=[n for n in MUST if on(n)]
for n in bad: print(f'::error::[r29.5] {n} 被 defconfig 拉回，多余协议没删干净')
if bad: rc=1
if not NO_KEEP:
    miss=[n for n in KEEP if not on(n)]
    for n in miss: print(f'::error::[r29.5] 缺 {n}：加速链路 / LuCI 后台 / 管理通道会被破坏')
    if miss: rc=1
else:
    miss=[]
back=[n for n in BEST if on(n)]
for n in back: print(f'::notice::[r29.5] {n} 被依赖拉回（运行期仍由 kill_* / scrub 停掉）')
ks=[n for n in KSLIM if re.search(rf'^CONFIG_KERNEL_{n}=y$',s,re.M)]
for n in ks: print(f'::notice::[r29.5] 内核 {n} 被 Kconfig 拉回（不阻断，sysctl 仍关死 v6）')
if rc: sys.exit(1)
print(f'[check] ✅ MUST_OFF {len(MUST)} 全 not set｜MUST_KEEP {len(KEEP)} 全在位'
      f'｜BEST 拉回 {len(back)}｜内核拉回 {len(ks)}')
