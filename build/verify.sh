#!/bin/sh
# 仓库静态自检：结构 / 资产 / 安全网 / 命名 / 语法
cd "$(dirname "$0")/.." || exit 1
F=0
ok(){ echo "  OK  $1"; }
bad(){ echo "  FAIL  $1"; F=1; }

echo "── 双机型共用结构 ──"
for f in .config diy-part1.sh diy-part2.sh build/build.sh build/fused.py \
         files/usr/sbin/wifi-check files/usr/sbin/vs010-mode files/usr/sbin/portstat \
         files/usr/sbin/ntp-sync files/usr/sbin/bridge-watchdog files/usr/sbin/dhcp-guard \
         files/etc/init.d/vs010-mode files/etc/init.d/vs010-ntp \
         files/etc/init.d/vs010-watchdog files/etc/init.d/vs010-dhcp-guard \
         files/www/cgi-bin/vs010 files/www/cgi-bin/bridge files/www/cgi-bin/apstatus \
         files/www/bridge/index.html files/www/ap/index.html \
         files/etc/bridge.conf files/usr/sbin/vs010-host \
         files/etc/init.d/vs010-luci-fix files/usr/sbin/luci-check \
         files/etc/vs010/mode files/etc/vs010/ipaddr files/etc/vs010/netmask \
         build/prune.list build/prune.keep files/etc/sysctl.d/99-vs010-no-ipv6.conf \
         files/etc/init.d/vs010-wds-pair files/usr/sbin/vs010-wds-pair \
         files.vs010/etc/firmware_model files.rax3000q/etc/firmware_model CHANGELOG.md \
         files/usr/lib/lua/luci/controller/admin/vs010_ports.lua \
         files/usr/lib/lua/luci/view/vs010_ports.htm \
         tools/rootfs-capture.sh tools/build-from-capture.sh capture/README.md; do
  [ -s "$f" ] && ok "$f" || bad "缺 $f"
done
for f in "3000Q-VS010-固件/Nwrt-QSDK12.2-2024-04-16-ipq50xx-ipq50xx_32-cucc_vs010-squashfs-nand-factory.bin" \
         "3000Q-VS010-固件/Nwrt-QSDK12.2-2024-04-16-ipq50xx-ipq50xx_32-cmcc_rax3000qy-squashfs-nand-factory.bin"; do
  [ "$(wc -c < "$f")" = 27394048 ] && ok "$(basename "$f") 27394048B" || bad "底座字节异常 $f"
done
[ "$(md5sum "3000Q-VS010-固件/Nwrt-QSDK12.2-2024-04-16-ipq50xx-ipq50xx_32-cucc_vs010-squashfs-nand-factory.bin" | cut -c1-12)" = 1049d78e7e80 ] \
  && ok 'VS010 底座 MD5 一致' || bad 'VS010 底座被换'

echo "── 无线栈保住（不搬 BDF、不覆盖配置）──"
grep -q 'kernel FIT' build/fused.py && ok 'kernel FIT 卷逐 PEB 保留' || bad '缺 kernel 保护'
grep -q '注入树会覆盖官方文件' build/fused.py && ok '注入文件防覆盖断言' || bad '缺防覆盖'
grep -q '禁止路径' build/build.sh && ok '构建期安全网' || bad '缺安全网'
for k in 'etc/config' 'lib/firmware' 'lib/modules'; do
  [ ! -e "files/$k" ] && [ ! -e "files.vs010/$k" ] && [ ! -e "files.rax3000q/$k" ] \
    && ok "共用层不含 $k" || bad "共用层含 $k"
done

echo "── 双模式 / 功能与以前一致 ──"
grep -q "setv network.lan stp 1" files/etc/init.d/vs010-mode && ok 'STP 开（网桥防环）' || bad '缺 STP'
grep -q '172.10.10.241' files/etc/vs010/ipaddr && grep -q '255.255.252.0' files/etc/vs010/netmask \
  && ok 'IP 172.10.10.241 /22 与以前一致' || bad 'IP 不一致'
grep -q 'interval 300' files/etc/init.d/vs010-mode && grep -q 'sleep "\$INTERVAL"' files/usr/sbin/ntp-sync \
  && ok 'NTP 5 分钟循环（失败继续下一轮）' || bad 'NTP 不是循环'
grep -q 'setv wdsdog.main enabled 0' files/etc/init.d/vs010-mode \
  && grep -q '从未成功关联过：只记录，不重启' files/usr/sbin/bridge-watchdog \
  && ok '机器狗插件：出厂停用 + ever_ok 保护' || bad '机器狗会误重启'
grep -q '/etc/init.d/ttyd enable' files/etc/init.d/vs010-mode && ok 'TTYD 官方已装，仅 ensure 启用' || bad 'TTYD 未启用'
grep -q 'dhcp-guard.main mode monitor' files/etc/init.d/vs010-mode && ok 'DHCP/无线 Snooping 监测模式' || bad '缺 Snooping'
grep -q '绝不重建 radio' files/etc/init.d/vs010-mode && grep -q 'disabled=0' files/etc/init.d/vs010-mode \
  && ok '无线配置只清 disabled，不重建 radio/iface' || bad '会动无线'
grep -q '^  set)' files/usr/sbin/vs010-mode && grep -q 'wds|ap' files/usr/sbin/vs010-mode && ok 'AP/网桥运行期可切' || bad '缺模式切换'
grep -q 'portstat --json' files/www/cgi-bin/vs010 && grep -q 'ethtool' files/usr/sbin/portstat \
  && ok '网口速率可视化（ethtool/sysfs 只读）' || bad '缺速率显示'
[ -s files/www/bridge/index.html ] && [ -s files/www/ap/index.html ] && ok '两个可视化页面' || bad '缺页面'

echo "── 精简 / IPv6 / WAN-LAN 桥接 / 防火墙 / SSH / 串口 / 自动配对 ──"
grep -q 'S50autoreboot' build/prune.list && grep -q 'etc/config/autoreboot' build/prune.list \
  && ok '定时重启 autoreboot 已剔除（不自动重启）' || bad 'autoreboot 未清'
grep -q 'S19firewall' build/prune.list && grep -q '/etc/init.d/firewall stop' files/etc/init.d/vs010-mode \
  && ok '防火墙服务停用' || bad '防火墙未关'
grep -q 'qca_ol.ko' build/prune.keep && grep -q 'bdwlan.b10' build/prune.keep \
  && grep -q 'terminal.lua' build/prune.keep && grep -q 'S00load_cnss2' build/prune.keep \
  && ok '精简白名单保住无线/NSS/TTYD/串口' || bad '白名单缺关键项'
grep -q 'VS010_PRUNE_KEEP' build/fused.py && grep -q '精简误删白名单' build/fused.py \
  && ok 'prune 白名单硬断言（误删即停包）' || bad '缺 prune 断言'
grep -q 'net.ipv6.conf.all.disable_ipv6=1' files/etc/sysctl.d/99-vs010-no-ipv6.conf \
  && grep -q 'setv network.lan ipv6 0' files/etc/init.d/vs010-mode \
  && ok 'IPv6 关闭（sysctl + uci + 停 odhcpd）' || bad 'IPv6 未关'
grep -q "setv network.lan ifname 'eth0 eth1'" files/etc/init.d/vs010-mode \
  && grep -q 'uci -q delete network.wan' files/etc/init.d/vs010-mode \
  && ok 'WAN+LAN 全部桥接进 br-lan（无 wan/wan6）' || bad 'WAN 未入桥'
grep -q 'passwd root' files/etc/init.d/vs010-mode && grep -q 'RootPasswordAuth=on' files/etc/init.d/vs010-mode \
  && ok 'SSH 修复：空密码→root/admin + dropbear 不绑 Interface' || bad 'SSH 未修'
grep -q 'ttyMSM0::askfirst' files/etc/init.d/vs010-mode && grep -q 'kill -HUP 1' files/etc/init.d/vs010-mode \
  && ok '串口 getty 保住/兜底（ttyMSM0 115200n8）' || bad '串口未管'
grep -q '绝不重建 radio' files/usr/sbin/vs010-wds-pair \
  && grep -q 'LC_ALL=C sort' files/usr/sbin/vs010-wds-pair \
  && ! grep -q '/sbin/wifi down' files/usr/sbin/vs010-wds-pair \
  && ok '网桥自动配对：MAC 收敛主备（不重建 radio / 不 wifi down）' || bad '自动配对会动无线'
grep -q 'export PATH' files/www/cgi-bin/vs010 && grep -q 'export PATH' files/usr/sbin/bridge-watchdog \
  && ok '脚本 PATH 含 /usr/sbin（官方 iw 在此）' || bad 'PATH 缺 /usr/sbin'
grep -q 'ddns' build/prune.list && grep -q 'zerotier' build/prune.list && grep -q 'upnp' build/prune.list \
  && ok 'DDNS/UPnP/ZeroTier 等杂项剔除' || bad '杂项未剔除'

grep -q 'ln -s "../init.d/' build/build.sh && grep -q 'S99vs010-mode' build/prune.keep \
  && grep -q 'is_symlink' build/fused.py \
  && ok '注入守护带 rc.d 自启链接（刷完必生效）' || bad '缺 rc.d 链接'
echo "── Argon 主题 / NTP 三台 / WDS 主客户端 / 登录 ──"
! grep -q '^etc/config/argon$' build/prune.list \
  && ! grep -q 'controller/argon-config.lua' build/prune.list \
  && grep -q 'etc/config/argon' build/prune.keep \
  && ok 'Argon 主题全套保留（配置/控制器/静态资源）' || bad 'Argon 被误删'
grep -q 'luci.main.mediaurlbase' files/etc/init.d/vs010-mode \
  && grep -q 'luci.main=core' files/etc/init.d/vs010-mode \
  && ok '主题 427 守卫：named main + Argon mediaurlbase' || bad '主题守卫缺失'
grep -q '172.10.10.254' files/etc/init.d/vs010-mode \
  && grep -q '172.100.10.254' files/etc/init.d/vs010-mode \
  && grep -q '192.168.1.254' files/etc/init.d/vs010-mode \
  && grep -q 'enable_server 0' files/etc/init.d/vs010-mode \
  && ok 'NTP 纯内网客户端：三台服务器 / 不对外服务' || bad 'NTP 服务器不全'
grep -q 'interval 300' files/etc/init.d/vs010-mode && ok 'NTP 5 分钟循环' || bad 'NTP 非 5 分钟'
grep -q 'WDS_SSID=WDS-Bridge-Z' files/usr/sbin/vs010-wds-pair \
  && grep -q 'WDS_KEY=WDS123456' files/usr/sbin/vs010-wds-pair \
  && ok 'WDS SSID / 密码正确' || bad 'SSID/密码错'
grep -q 'wds_bridge=br-lan' files/usr/sbin/vs010-wds-pair \
  && grep -q 'mode=wds' files/usr/sbin/vs010-wds-pair \
  && grep -q 'network=lan' files/usr/sbin/vs010-wds-pair \
  && ok 'WDS 主(ap+wds) / 客户端(mode=wds) 纯二层进 br-lan' || bad 'WDS 非纯二层'
grep -q 'set-role master' files/usr/sbin/vs010-wds-pair \
  && grep -q '/sbin/wifi reload' files/usr/sbin/vs010-wds-pair \
  && ! grep -q 'reboot' files/usr/sbin/vs010-wds-pair \
  && ok '可显式切主/客户端；只 reload 不重启' || bad 'WDS 会重启/不可切'
! grep -q '\*11a\*' files/usr/sbin/vs010-wds-pair \
  && grep -q 'channel 优先' files/usr/sbin/vs010-wds-pair \
  && ok 'WDS 只建 5G radio（11axg 不误判）' || bad 'WDS 可能落到 2.4G'
grep -q 'passwd root' files/etc/init.d/vs010-mode && ok 'root 密码 admin' || bad '未设 root 密码'
grep -q '172.10.10.241' files/etc/vs010/ipaddr && grep -q '255.255.252.0' files/etc/vs010/netmask \
  && ok 'IP 172.10.10.241 /22' || bad 'IP 错'

echo "── 旧版丰富页面 / AP SSID / 设备名 / HE160 / WAN 删除 ──"
[ "$(stat -c %s files/www/bridge/index.html 2>/dev/null || echo 0)" -gt 20000 ] \
  && [ "$(stat -c %s files/www/ap/index.html 2>/dev/null || echo 0)" -gt 20000 ] \
  && [ "$(stat -c %s files/www/cgi-bin/bridge 2>/dev/null || echo 0)" -gt 20000 ] \
  && [ "$(stat -c %s files/www/cgi-bin/apstatus 2>/dev/null || echo 0)" -gt 10000 ] \
  && ok '旧版 4 个丰富页面/CGI 已替换（33.9K/32.3K/37.4K/19.6K）' || bad '丰富页面未替换'
# 第 10 次：不要求 git 里存可执行位（网页上传/Windows 会抹成 644），
# 改由 build.sh 在注入前统一 chmod 755 —— 下面另有硬断言核这层兜底。
grep -q 'cgi-bin/bridge' files/www/bridge/index.html \
  && grep -q 'cgi-bin/apstatus' files/www/ap/index.html \
  && [ -s files/www/cgi-bin/bridge ] && [ -s files/www/cgi-bin/apstatus ] \
  && grep -q 'chmod 755' build/build.sh \
  && ok '页面 ↔ CGI 接口对齐（可执行位由 build.sh 强制）' || bad '页面接口断链'
[ -f files/etc/bridge.conf ] && grep -q 'ADMIN_IP=172.10.10.241' files/etc/bridge.conf \
  && ok '旧 CGI 依赖的 /etc/bridge.conf 已补（官方无此文件，零冲突）' || bad '缺 bridge.conf'
grep -q 'VS010-AP' files/etc/init.d/vs010-mode && grep -q 'RAX3000Q-AP' files/etc/init.d/vs010-mode \
  && grep -q 'key=AP123456' files/etc/init.d/vs010-mode \
  && ok 'AP 模式 SSID 按机型区分 / 密码 AP123456' || bad 'AP SSID 不对'
grep -q 'H=WDS-Z' files/usr/sbin/vs010-host && grep -q 'H=WDS-K' files/usr/sbin/vs010-host \
  && grep -q 'H=AP' files/usr/sbin/vs010-host \
  && ok '设备名：WDS 主 WDS-Z / 客户端 WDS-K / AP' || bad '设备名不对'
grep -q 'htmode=HT160' files/usr/sbin/vs010-wds-pair \
  && grep -q 'channel=36' files/usr/sbin/vs010-wds-pair \
  && ok '5G 桥接 HE160（QSDK 11axa+HT160→11AHE160）' || bad '未设 HE160'
grep -q '2.4G 不桥接' files/usr/sbin/vs010-wds-pair \
  && grep -q '"\$dev" = "\$d"' files/usr/sbin/vs010-wds-pair \
  && grep -q 'delete "wireless.\$sec.wds"' files/usr/sbin/vs010-wds-pair \
  && ok '2.4G 不参与 WDS 桥接（清 wds 标记）' || bad '2.4 会被桥接'
grep -q 'scrub(){' files/etc/init.d/vs010-mode && grep -q 'boot(){ scrub; apply; }' files/etc/init.d/vs010-mode \
  && grep -q 'delete network.wan6' files/etc/init.d/vs010-mode \
  && ok 'WAN / WAN6 每次开机都删（不受首启 stamp 限制）' || bad 'WAN 只首启删一次'
grep -q '/etc/firmware_mode' files/etc/init.d/vs010-mode && grep -q '/etc/bridge_role' files/usr/sbin/vs010-wds-pair \
  && ok '旧版丰富页面兼容垫片齐全' || bad '垫片缺失'

echo "── LuCI / Argon 主题不报错（427 那类）──"
# 官方 dispatcher.lua:225 读 luci.config.main.mediaurlbase，core 段必须 named main
grep -q 'START=18' files/etc/init.d/vs010-luci-fix \
  && grep -q "18:vs010-luci-fix" build/build.sh \
  && grep -q 'S18vs010-luci-fix' build/prune.keep \
  && ok '主题修复 START=18 早于 uhttpd(50)，且自带 rc.d 链接' || bad '修复晚于 uhttpd 或缺链接'
grep -q 'rename "luci.\$sect=main"' files/etc/init.d/vs010-luci-fix \
  && grep -q '"\$sect" != main' files/etc/init.d/vs010-luci-fix \
  && grep -q 'rename "luci.\$sect=main"' files/etc/init.d/vs010-mode \
  && ! grep -q 'delete luci.@core\[0\]' files/etc/init.d/vs010-luci-fix \
  && ! grep -q 'delete luci.@core\[0\]' files/etc/init.d/vs010-mode \
  && ok '两处守卫按段名 rename（无 delete @core[0] 自毁风险）' || bad '守卫会误删 main'
grep -q 'luci.main.mediaurlbase' files/etc/init.d/vs010-luci-fix \
  && grep -q '/luci-static/argon' files/etc/init.d/vs010-luci-fix \
  && ok 'mediaurlbase 固定 Argon（dispatcher 取不到 nil）' || bad '主题路径未兜底'
grep -q '/tmp/luci-indexcache' files/etc/init.d/vs010-luci-fix \
  && grep -q '/var/luci-indexcache' files/etc/init.d/vs010-luci-fix \
  && ok '两侧 indexcache 都清（官方只清 /var，dispatcher 用 /tmp）' || bad '缓存路径不全'
grep -q 'redirect_https=0' files/etc/init.d/vs010-luci-fix \
  && grep -q 'delete uhttpd.main.listen_https' files/etc/init.d/vs010-luci-fix \
  && ok '无证书时关 HTTPS 重定向（否则 302 到死 443）' || bad 'LuCI 会被重定向打不开'
grep -q 'lua_prefix' files/etc/init.d/vs010-luci-fix \
  && grep -q 'cgi-bin/luci=/usr/lib/lua/luci/sgi/uhttpd.lua' files/etc/init.d/vs010-luci-fix \
  && ok 'LuCI lua_prefix 兜底（/cgi-bin/luci 可访问）' || bad 'LuCI 入口无兜底'
[ -s files/usr/sbin/luci-check ] && grep -q 'RESULT: PASS' files/usr/sbin/luci-check \
  && grep -q 'chmod 755' build/build.sh \
  && ok 'luci-check 在位（可执行位由 build.sh 强制）' || bad '缺自检工具'
grep -q 'usr/lib/lua/luci/dispatcher.lua' build/prune.keep \
  && grep -q 'etc/config/uhttpd' build/prune.keep \
  && grep -q 'view/themes/argon/header.htm' build/prune.keep \
  && ok 'dispatcher / uhttpd / Argon 模板列入白名单（防误删）' || bad '白名单缺主题关键项'
# 注入树绝不碰官方 LuCI 文件；新增文件只允许 vs010_ 前缀（fused 撞名即停）
OFFICIAL='config/luci$|dispatcher\.lua$|sgi/uhttpd\.lua$|www/cgi-bin/luci$|controller/(argon-config|terminal)\.lua$|themes/argon/header\.htm$'
if find files files.vs010 files.rax3000q -type f 2>/dev/null | grep -E "$OFFICIAL" | grep -q .; then
  bad '注入树会覆盖官方 LuCI 文件'
else
  ok '注入树零覆盖官方 LuCI 文件（新增仅 vs010_ 前缀，撞名即停）'
fi
find files -type f \( -name '*.lua' -o -name '*.htm' \) 2>/dev/null \
  | grep -v 'vs010_ports' | grep -q . \
  && bad '注入树含非 vs010_ 前缀的 LuCI 文件' \
  || ok '新增 LuCI 文件均为 vs010_ports（零冲突）'
# 页面里的 LuCI 链接与官方 lua_prefix 对齐
grep -q 'cgi-bin/luci' files/www/bridge/index.html && grep -q 'cgi-bin/luci' files/www/ap/index.html \
  && ok '两个丰富页面的 LuCI 入口链接有效' || bad '页面 LuCI 链接断'

echo "── 仓库主页详版 / 下载页 IP·设置·插件 ──"
RL=$(wc -l < README.md)
[ "$RL" -ge 150 ] && ok "README.md 详版 $RL 行（仓库主页）" || bad 'README 不是详版'
for k in '172.10.10.241' '255.255.252.0' 'root' 'admin' 'TTYD' '插件' '命令速查' '目录结构' '底座' 'Argon' 'HE160' 'luci-check'; do
  grep -q "$k" README.md || bad "README 缺: $k"
done
[ "$F" = 0 ] && ok 'README 覆盖 IP/账号/插件/命令/目录/主题/无线' || true
# Release body：纯文本精确取出（不依赖 runner 预装 PyYAML）
BODY=$(python3 - <<'PYX'
import re,sys
s=open('.github/workflows/build-openwrt.yml',encoding='utf-8').read()
m=re.search(r'^\s*body:\s*\|\s*\n(.*?)(?=^\s*files:\s*\|)',s,re.M|re.S)
if not m: sys.exit('未找到 Release body')
lines=m.group(1).splitlines()
ind=min((len(x)-len(x.lstrip(' ')) for x in lines if x.strip()),default=0)
print('\n'.join(x[ind:] if len(x)>=ind else x for x in lines).strip())
PYX
) || { echo '  FAIL  Release body 解析失败'; F=1; }
BN=$(printf '%s\n' "$BODY" | wc -l)
[ "$BN" -le 25 ] && ok "下载页简洁（$BN 行，不做复杂长文）" || bad '下载页过长'
for k in '172.10.10.241' '255.255.252.0' 'root' 'admin' 'TTYD' '插件' 'bridge-watchdog' 'portstat' '保留配置' '5.4.213'; do
  printf '%s\n' "$BODY" | grep -q "$k" || bad "下载页缺: $k"
done
[ "$F" = 0 ] && ok '下载页含 IP/掩码/账号/设置/插件清单/刷机必读' || true
printf '%s\n' "$BODY" | grep -q '^| 项 | 值 |' \
  && ok '下载页用一张表承载设置（简洁）' || bad '下载页缺设置表'

echo "── 命名带 5.4 / 两机型两模式 ──"
grep -q 'Nwrt-QSDK12.2-5.4-' build/build.sh && ok '产物名带 5.4' || bad '命名缺 5.4'
grep -q 'cucc_vs010' .github/workflows/build-openwrt.yml && grep -q 'cmcc_rax3000q' .github/workflows/build-openwrt.yml \
  && ok 'workflow 含两机型' || bad 'workflow 缺机型'
grep -q 'wds' .github/workflows/build-openwrt.yml && grep -q 'ap' .github/workflows/build-openwrt.yml \
  && ok 'workflow 含两模式' || bad 'workflow 缺模式'
[ -s .github/workflows/build-source.yml ] && ok 'RAX3000Q 原生编译配置保留' || bad '未保留 3000Q 编译'

echo "── 第 8 次：ART 自读 / 速率 PHY 兜底 / 主题速率页 / 实机回灌 ──"
python3 - <<'PYV' || F=1
import struct, pathlib, glob
# 硬证据：factory.bin 只有 layout / kernel(0) / rootfs(1) 三个卷 →
# ART 是独立 MTD 分区，刷机不覆盖，每台机器自动读自己的 ART。
ok = True
for f in sorted(glob.glob('3000Q-VS010-固件/*factory.bin')):
    b = pathlib.Path(f).read_bytes(); PEB = 131072; v = set()
    for i in range(len(b)//PEB):
        p = b[i*PEB:(i+1)*PEB]
        if p[:4] == b'UBI#' and p[2048:2052] == b'UBI!':
            v.add(struct.unpack_from('>I', p, 2048+8)[0])
    good = v == {0, 1, 2147479551}
    print('  ', 'OK  ' if good else 'FAIL', pathlib.Path(f).name, '卷ID', sorted(v))
    ok = ok and good
if not ok: raise SystemExit(1)
PYV
grep -q 'phy_link_probe' files/usr/sbin/portstat \
  && grep -q 'swconfig' files/usr/sbin/portstat \
  && grep -q -- '--rows' files/usr/sbin/portstat \
  && ok 'portstat 补 PHY 实测兜底（不写死 1000 / 有 --rows）' || bad '速率兜底缺失'
[ -s files/usr/sbin/portstat ] && grep -q 'chmod 755' build/build.sh \
  && ok 'portstat 在位（可执行位由 build.sh 强制）' || bad 'portstat 缺或构建期无 chmod 兜底'
grep -q 'portstat --rows' files/usr/lib/lua/luci/controller/admin/vs010_ports.lua \
  && grep -q '<%+header%>' files/usr/lib/lua/luci/view/vs010_ports.htm \
  && grep -q 'entry({"admin", "status", "vs010_ports"' files/usr/lib/lua/luci/controller/admin/vs010_ports.lua \
  && ok 'Argon 主题内新增「网口速率」菜单（零覆盖官方文件）' || bad '主题速率页缺'
grep -q 'ART 分区' tools/rootfs-capture.sh \
  && grep -q 'smem_0' tools/rootfs-capture.sh \
  && grep -q '\.wh\.' tools/rootfs-capture.sh \
  && ok '设备侧只导出删除清单；ART/MAC/密钥/stamp 硬排除' || bad 'capture 会带机器唯一数据'
grep -q 'lib/firmware' tools/build-from-capture.sh \
  && grep -q 'FROM CAPTURE' tools/build-from-capture.sh \
  && grep -q 'sh verify.sh' tools/build-from-capture.sh \
  && ok '回灌带无线栈硬护栏 + 幂等 + 自检' || bad '回灌无护栏'
# 文档类只提示、不 FAIL：网页上传时文档晚传一步不该卡住编译
if grep -q 'vs010_ports' README.md && grep -q 'ART' README.md \
   && grep -q '第 8 次' CHANGELOG.md; then
  ok 'README / CHANGELOG 已记第 8 次'
else
  echo '  NOTE  第 8 次文档未同步（不影响编译）'
fi

echo "── 第 9 次：实机导出 → 上传仓库 → Actions 自动出固件 ──"
grep -q 'cp tools/rootfs-capture.sh' build/build.sh \
  && grep -q 'vs010-capture' build/build.sh \
  && ok '导出脚本随固件刷入 /usr/sbin/vs010-capture（设备上找得到）' || bad '设备侧缺导出脚本'
grep -q 'Apply captured prune list' .github/workflows/build-openwrt.yml \
  && grep -q 'capture/prune-real.txt' .github/workflows/build-openwrt.yml \
  && grep -q -- '--dryrun' .github/workflows/build-openwrt.yml \
  && ok 'Actions 检测清单→回灌 prune.list→再 Build（闭环）' || bad 'Actions 不读清单'
[ -s capture/README.md ] && grep -q 'vs010-capture' capture/README.md \
  && grep -q 'scp' capture/README.md \
  && ok 'capture/README.md 给出设备导出与取回命令' || bad '缺上传说明'
# 清单若存在，本地 sh verify.sh 也挡一道（与回灌脚本同一护栏）
if [ -f capture/prune-real.txt ]; then
  B=$(grep -v '^#' capture/prune-real.txt | grep -v '^[[:space:]]*$' \
      | grep -E 'lib/firmware|lib/modules|bdwlan|qca_ol|ART|caldata|etc/config/(luci|uhttpd|network|wireless)' || true)
  [ -z "$B" ] && ok '已上传清单不含禁止路径' || bad '清单含无线/主题关键路径'
else
  ok '无实机清单（可选），默认 prune.list 正常'
fi
if grep -q '第 9 次' CHANGELOG.md && grep -q '第 9 次' README.md; then
  ok 'CHANGELOG / 仓库主页已记第 9 次流程'
else
  echo '  NOTE  第 9 次文档未同步（不影响编译）'
fi

echo "── 第 10 次：上传丢权限位不再卡 CI / 不依赖 runner 预装 PyYAML ──"
grep -q 'chmod 755' build/build.sh \
  && grep -q '\-perm -u=x' build/build.sh \
  && grep -q 'NEXEC' build/build.sh \
  && ok 'build.sh 注入前统一 chmod 755（含 rc.d/CGI/init.d/usr/sbin）' || bad '缺权限兜底'
# 只核「真正的导入行」，避免断言自身的字符串被自己匹配到
NYAML=$( { grep '^import ' build/verify.sh; grep '^from ' build/verify.sh; } | grep -c yaml )
[ "$NYAML" = 0 ] \
  && ok 'verify.sh 零 PyYAML 依赖（纯文本解析 workflow）' || bad "仍依赖 yaml（$NYAML 处）"
# 负例：把注入树全设成 644，真跑构建，确认产物里脚本仍是 755
python3 - <<'PYM' || F=1
import shutil,tempfile,os,subprocess,stat,pathlib,glob
src=os.getcwd()
t=tempfile.mkdtemp(); d=os.path.join(t,'repo'); shutil.copytree(src,d,
    ignore=shutil.ignore_patterns('.git','*.bin','*.sha256','3000Q-VS010-固件'))
# 底座固件单独拷回（构建需要）
os.makedirs(d+'/3000Q-VS010-固件',exist_ok=True)
for f in glob.glob(src+'/3000Q-VS010-固件/*factory.bin'):
    dst=d+'/3000Q-VS010-固件/'+os.path.basename(f)
    try: os.link(f,dst)          # 同盘硬链接，省 55MB 拷贝
    except OSError: shutil.copy2(f,dst)
# 🔴 模拟 GitHub 网页上传：所有仓库文件抹成 664
#    （底座 bin 是硬链接，跳过以免误改源；构建只读它，mode 无关）
for root,dirs,files in os.walk(d):
    dirs[:]=[x for x in dirs if x not in ('.git','3000Q-VS010-固件')]
    for f in files: os.chmod(os.path.join(root,f),0o664)
r=subprocess.run(['sh','build/build.sh','--device=cucc_vs010','--mode=wds'],
                 cwd=d,capture_output=True,text=True)
if r.returncode:
    print('  FAIL 664 树下构建失败:',r.stdout[-400:],r.stderr[-400:]); raise SystemExit(1)
out=sorted(glob.glob(d+'/Nwrt-QSDK12.2-5.4-*.bin'))[-1]
# 从 UBI rootfs 卷里读回注入文件的 mode
b=pathlib.Path(out).read_bytes(); PEB=131072; v={}
for i in range(len(b)//PEB):
    p=b[i*PEB:(i+1)*PEB]
    if p[:4]==b'UBI#' and p[2048:2052]==b'UBI!' and __import__('struct').unpack_from('>I',p,2048+8)[0]==1:
        v[__import__('struct').unpack_from('>I',p,2048+12)[0]]=p[4096:]
sq=os.path.join(t,'n.sqfs'); pathlib.Path(sq).write_bytes(b''.join(v[k] for k in sorted(v)))
ext=os.path.join(t,'ext'); subprocess.run(['unsquashfs','-f','-d',ext,sq],capture_output=True)
keys=['usr/sbin/portstat','usr/sbin/luci-check','usr/sbin/vs010-capture',
      'www/cgi-bin/bridge','www/cgi-bin/apstatus','etc/init.d/vs010-mode']
bad=[]
for k in keys:
    p=os.path.join(ext,k)
    m=stat.S_IMODE(os.stat(p).st_mode) if os.path.exists(p) else 0
    print('   ',k,oct(m))
    if not (m & 0o111): bad.append(k)
shutil.rmtree(t)
if bad: print('  FAIL 固件里仍不可执行:',bad); raise SystemExit(1)
print('  ✅ 664 上传树 → 构建成功 → 固件内 6 个关键脚本全部 755')
PYM
if grep -q '第 10 次' CHANGELOG.md && grep -q '第 10 次' README.md; then
  ok 'CHANGELOG / 仓库主页已记第 10 次'
else
  echo '  NOTE  第 10 次文档未同步（不影响编译）'
fi

echo "── 语法 ──"
e=0
for f in $(find . -type f \( -name '*.sh' -o -path 'files/*' -o -path 'files.vs010/*' -o -path 'files.rax3000q/*' \) ! -name '*.md' ! -name '*.html' ! -name '*.lua' ! -name '*.htm' ! -name 'firmware_model'); do
  sh -n "$f" 2>/dev/null || { echo "    syntax: $f"; e=$((e+1)); }
done
[ "$e" = 0 ] && ok "全仓 sh -n 零错误" || bad "$e 个语法错"
if command -v luac >/dev/null 2>&1; then
  luac -p files/usr/lib/lua/luci/controller/admin/vs010_ports.lua 2>/dev/null \
    && ok 'Lua controller luac -p 通过' || bad 'Lua controller 语法错'
else
  grep -q 'module("luci.controller.admin.vs010_ports"' files/usr/lib/lua/luci/controller/admin/vs010_ports.lua \
    && grep -q 'function index()' files/usr/lib/lua/luci/controller/admin/vs010_ports.lua \
    && grep -q 'tpl.render' files/usr/lib/lua/luci/controller/admin/vs010_ports.lua \
    && ok 'Lua controller 结构完整（本环境无 luac，降级检查）' || bad 'Lua controller 结构缺'
fi
H1=$(grep -c '<%+header%>' files/usr/lib/lua/luci/view/vs010_ports.htm)
H2=$(grep -c '<%+footer%>' files/usr/lib/lua/luci/view/vs010_ports.htm)
[ "$H1" = 1 ] && [ "$H2" = 1 ] \
  && grep -q '<% end %>' files/usr/lib/lua/luci/view/vs010_ports.htm \
  && ok 'Argon 视图模板 header/footer/循环闭合' || bad '视图模板结构错'
python3 -c 'import ast;ast.parse(open("build/fused.py",encoding="utf-8").read())' 2>/dev/null \
  && ok 'fused.py 语法' || bad 'fused.py 语法'
python3 - <<'PYEOF' || F=1
import glob,re,subprocess,sys
b=0; total=0
for p in sorted(glob.glob('.github/workflows/*.yml')):
    lines=open(p,encoding='utf-8').read().splitlines(); runs=[]; i=0
    while i < len(lines):
        m=re.match(r'^(\s+)run:\s*\|\s*$',lines[i])
        if not m: i+=1; continue
        base=len(m.group(1)); j=i+1; blk=[]
        while j < len(lines):
            x=lines[j]
            if x.strip() and len(x)-len(x.lstrip(' ')) <= base: break
            blk.append(x); j+=1
        nb=[x for x in blk if x.strip()]
        ind=min((len(x)-len(x.lstrip(' ')) for x in nb),default=0)
        runs.append('\n'.join(x[ind:] if len(x)>=ind else x for x in blk)); i=j
    for r in runs:
        total+=1
        if r.strip() and subprocess.run(['bash','-n'],input=r,text=True,capture_output=True).returncode: b+=1
    print('  OK ',p,'run 块',len(runs))
if total==0: print('  FAIL 未提取到任何 run 块'); sys.exit(1)
if b: print('  FAIL run 块',b); sys.exit(1)
PYEOF

echo
[ "$F" = 0 ] && echo 'RESULT: PASS —— 第 10 次：权限位丢失不再卡 CI / 固件脚本强制 755 / 零 PyYAML 依赖 / 无线栈零改动' || echo 'RESULT: FAIL'
exit $F
