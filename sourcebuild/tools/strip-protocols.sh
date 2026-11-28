#!/bin/sh
# r29.4 编译期物理删除 IPv6 / PPP 拨号协议包；r29.7 起 dnsmasq-full 保留
#（AP 界面可选 DHCP 服务端，默认 ignore=1 + init disable，不占运行内存）。
# 由 diy-part2.sh 在 openwrt/ 源码树根调用；用 sh 执行，不依赖执行位。
set -eu
MUST="ppp ppp-mod-pppoe kmod-ppp kmod-pppoe kmod-pppox kmod-pptp luci-proto-ppp kmod-qca-nss-drv-pppoe ipv6helper luci-proto-ipv6 odhcp6c 6in4 rpcd-mod-rrdns"
BEST="firewall ip6tables ip6tables-mod-nat libip6tc kmod-ip6tables kmod-ipt-nat6 kmod-nf-conntrack6 kmod-nf-ipt6 kmod-nf-nat6 kmod-nf-reject6 block-mount luci-app-filetransfer luci-i18n-filetransfer-zh-cn"
NOISE="luci-app-passwall_INCLUDE_ luci-app-ssr-plus_INCLUDE_ luci-app-vssr_INCLUDE_ luci-app-rclone_INCLUDE_ luci-app-diskman_INCLUDE_"
python3 - "$MUST" "$BEST" "$NOISE" <<'PYSTRIP'
import sys,pathlib,re
must,best,noise=sys.argv[1].split(),sys.argv[2].split(),sys.argv[3].split()
alln=set(must+best)
p=pathlib.Path('.config'); L=p.read_text().splitlines(); out=[]; n=0
for l in L:
    m=re.match(r'^(CONFIG_(?:PACKAGE|DEFAULT)_)([\w.\-]+)=y$',l)
    if m and m.group(2) in alln:
        out.append(f'# {m.group(1)}{m.group(2)} is not set'); n+=1; continue
    if m and any(m.group(2).startswith(x) for x in noise):
        out.append(f'# {m.group(1)}{m.group(2)} is not set'); n+=1; continue
    out.append(l)
p.write_text('\n'.join(out)+'\n')
print(f'[strip] .config 关闭 {n} 行（PPP / IPv6 / 反向DNS / 冗余 / 空壳选项）')
# target 默认包集合才是 CONFIG_DEFAULT_* 的真正来源，必须一并摘掉，
# 否则 make defconfig 会把 CONFIG_PACKAGE_ppp 重新拉回 =y。
removed=0
for f in pathlib.Path('target/linux').rglob('*'):
    if not f.is_file(): continue
    try: s=f.read_text()
    except (UnicodeDecodeError,OSError): continue
    if 'DEFAULT_PACKAGES' not in s: continue
    def fix(line):
        global removed
        if 'DEFAULT_PACKAGES' not in line: return line
        def rep(m):
            global removed
            tok=m.group(0)
            if tok.lstrip('+') in alln: removed+=1; return ''
            return tok
        return re.sub(r'\+?[A-Za-z0-9_.\-]+',rep,line)
    ns='\n'.join(fix(x) for x in s.splitlines())+'\n'
    if ns!=s: f.write_text(ns)
print(f'[strip] target/linux DEFAULT_PACKAGES 摘掉 {removed} 个 token')
PYSTRIP
echo "[strip] ✅ 内核 CONFIG_IPV6 / NSS / bridge / netfilter 符号保留（QSDK 编译依赖）；由 sysctl 关死 v6"

# ── r29.5：源码树 uci-defaults 追加「删 WAN 逻辑接口」──
# 只动 UCI，绝不碰 board.d 的 switch/GMAC 寄存器（改错网口全灭）。
# board.d/02_network 由 boot 先执行，99- 前缀保证在其后跑；运行期 scrub() 每次开机再兜底。
UD=package/base-files/files/etc/uci-defaults
if [ -d "$UD" ]; then
  cat > "$UD/99-vs010-no-wan" <<'EOFUCIDEFAULT'
#!/bin/sh
# r29.5 编译期：board.d 生成 LAN/WAN 之后，删掉 WAN 逻辑接口。
# 只动 UCI，不动 switch/GMAC 寄存器；物理 WAN 口仍桥进 LAN。
# 运行期 /etc/init.d/vs010-mode scrub() 每次开机再兜底一次。
[ -f /etc/config/network ] || exit 0
uci -q delete network.wan
uci -q delete network.wan6
uci -q delete dhcp.wan6
uci -q set network.globals.ula_prefix=''
uci -q set network.lan.ipv6='0'
uci -q commit network
uci -q commit dhcp
exit 0
EOFUCIDEFAULT
  chmod 755 "$UD/99-vs010-no-wan" 2>/dev/null || true
  echo "[strip-wan] ✅ 已追加 99-vs010-no-wan（编译期删 WAN/WAN6）"
else
  echo "::notice::[strip-wan] 未找到 $UD，跳过（运行期 scrub() 仍每次开机删 WAN）"
fi
