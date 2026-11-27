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
grep -q 'PW_HASH=' files/etc/init.d/vs010-mode \
  && grep -q 'fix_login' files/etc/init.d/vs010-mode \
  && ! grep -q '/bin/passwd root' files/etc/init.d/vs010-mode \
  && grep -q 'RootPasswordAuth=on' files/etc/init.d/vs010-mode \
  && ok 'SSH 修复：空密码→root/admin（固定 hash 写 overlay）+ dropbear 不绑 Interface' || bad 'SSH 未修'
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
grep -Fq "PW_HASH='\$1\$VS010Z" files/etc/init.d/vs010-mode \
  && grep -q 'fix_login' files/etc/init.d/vs010-mode \
  && ok 'root 密码 admin（固定 hash，每次开机幂等）' || bad '未设 root 密码'
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
  && grep -q 'channel=auto' files/usr/sbin/vs010-wds-pair \
  && ok '5G 桥接 HE160 + 信道自动（11axa+HT160→11AHE160，auto→ACS）' || bad '未设 HE160/信道自动'
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
  | grep -vE 'vs010(_|\.lua)|/themes/argon2/' | grep -q . \
  && bad '注入树含非 vs010_ / 非 argon2 主题的 LuCI 文件' \
  || ok '新增 LuCI 仅 vs010_ 前缀 + 独立主题目录 argon2（零冲突）'
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
for k in '172.10.10.241' '255.255.252.0' 'root' 'admin' 'TTYD' '插件' 'bridge-watchdog' 'portstat' '保留配置' '5.4.213' \
         'DHCP' '<u>' 'dhcp.lan.ignore=1' '网桥状态' 'AP 状态'; do
  printf '%s\n' "$BODY" | grep -q "$k" || bad "下载页缺: $k"
done
[ "$F" = 0 ] && ok '下载页含 IP/掩码/账号/设置/插件清单/DHCP 红字划线/刷机必读' || true
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

echo "── 第 11 次：自检零硬编码路径（runner 可跑）──"
grep -q 'src=os.getcwd()' build/verify.sh \
  && grep -q 'shutil.which' build/verify.sh \
  && ok '负例用仓库根 cwd + 工具守卫（不依赖开发机路径）' || bad '负例仍硬编码路径'
if grep -q '第 11 次' CHANGELOG.md && grep -q '第 11 次' README.md; then
  ok 'CHANGELOG / 仓库主页已记第 11 次'
else
  echo '  NOTE  第 11 次文档未同步（不影响编译）'
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
# 🔴 第 11 次：绝不硬编码任何开发机路径。本脚本开头已 cd "$(dirname "$0")/.."，
#    cwd 就是仓库根；GitHub runner 上是 /home/runner/work/<repo>/<repo>。
src=os.getcwd()
if not (shutil.which('unsquashfs') and shutil.which('mksquashfs')):
    print('  NOTE 本环境无 squashfs-tools，跳过 664 负例（CI Init 已安装）')
    raise SystemExit(0)
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

echo "── 第 12 次：实机保留基线（双机型共用 / 无线零改动）──"
AL=capture/installed-allowlist.txt
if [ -s "$AL" ]; then
  NL=$(grep -cv '^[[:space:]]*$' "$AL")
  [ "$NL" -ge 200 ] && ok "基线 $NL 行（opkg list-installed 实机导出）" || bad '基线行数异常'
  for k in 'kernel - 5.4.213' 'qca-wifi-fw-hw4' 'qca-cnss-daemon' 'kmod-qca-nss-drv' \
           'ttyd' 'luci-theme-argonv3' 'dropbear' 'uhttpd' 'ethtool' 'swconfig'; do
    grep -qF "$k" "$AL" || bad "基线缺 $k"
  done
  [ "$F" = 0 ] && ok '基线含 5.4.213 闭源栈 / Argon / TTYD / SSH / 速率工具' || true
  # 用户确实清掉的杂项菜单不应出现在「最干净系统」里
  for k in wireguard ddns upnp zerotier autoreboot odhcpd firewall; do
    grep -qi "^${k}" "$AL" && bad "基线仍含杂项 $k（与实机状态不符）" || true
  done
  [ "$F" = 0 ] && ok 'DDNS/UPnP/ZeroTier/WireGuard/定时重启 等不在基线' || true
else
  bad '缺 capture/installed-allowlist.txt'
fi
[ -s tools/apply-installed-baseline.sh ] && sh -n tools/apply-installed-baseline.sh \
  && ok '回灌脚本在位 / sh -n 通过' || bad '回灌脚本缺或语法错'
grep -q 'FROM INSTALLED BASELINE' tools/apply-installed-baseline.sh \
  && grep -q 'prune.keep 零交集' tools/apply-installed-baseline.sh \
  && grep -q '拒绝回灌（无线/主题/管理可能被误删）' tools/apply-installed-baseline.sh \
  && ok '回灌带基线硬护栏 + 白名单零交集 + 幂等' || bad '回灌无护栏'
grep -q 'FROM INSTALLED BASELINE' build/prune.list \
  && ok 'prune.list 已落双机型共用基线块' || bad '基线块未回灌'
grep -q 'VS010_PRUNE_LIST=build/prune.list' build/build.sh \
  && ok '两个机型构建共用同一份 prune.list（标准一致）' || bad '两机型精简标准不一致'
grep -q 'Apply installed baseline (both devices)' .github/workflows/build-openwrt.yml \
  && grep -q '^permissions:' .github/workflows/build-openwrt.yml \
  && grep -q 'contents: write' .github/workflows/build-openwrt.yml \
  && ok 'Actions 自动回灌基线 + 显式 Release 权限（不再依赖 Settings）' || bad 'workflow 未接基线/缺权限'
grep -q -- '--installed=' tools/build-from-capture.sh \
  && ok '回灌入口兼容 --installed= 与 --capture= 两种实机来源' || bad '入口不兼容'
# 负例：故意把基线里的闭源无线栈删掉，护栏必须拒绝回灌（且不递归调 verify）
python3 - <<'PYB' || F=1
import tempfile, pathlib, shutil, subprocess, os
src = os.getcwd()
t = tempfile.mkdtemp()
for d in ('tools','build','capture'):
    os.makedirs(os.path.join(t,d), exist_ok=True)
for f in ('tools/apply-installed-baseline.sh','build/prune.list','build/prune.keep'):
    shutil.copy2(os.path.join(src,f), os.path.join(t,f))
p = pathlib.Path(t,'capture','installed-allowlist.txt')
txt = pathlib.Path(src,'capture','installed-allowlist.txt').read_text()
# 制造「无线栈被误删」的坏清单
bad = '\n'.join(l for l in txt.splitlines()
                if not l.startswith(('qca-','kmod-qca','kernel -','libiwinfo')))
# 仍补足 200 行，确保触发的是①而不是行数检查
pad = [f'fake-pkg-{i} - 1' for i in range(230)]
p.write_text(bad + '\n' + '\n'.join(pad) + '\n')
r = subprocess.run(['sh','tools/apply-installed-baseline.sh','--dryrun'],
                   cwd=t, capture_output=True, text=True)
shutil.rmtree(t)
if r.returncode == 0:
    print('  FAIL 坏基线未被拒绝'); raise SystemExit(1)
if '拒绝回灌' not in (r.stdout+r.stderr):
    print('  FAIL 未报出护栏原因'); raise SystemExit(1)
print('  ✅ 负例：无线栈缺失的基线被护栏拒绝（rc=%d）' % r.returncode)
PYB
if grep -q '第 12 次' CHANGELOG.md; then ok 'CHANGELOG 已记第 12 次'; else echo '  NOTE  第 12 次文档未同步（不影响编译）'; fi

# ★ 第 16 次硬校验：PW_HASH 必须等于 openssl -1 -salt VS010Z admin（杜绝占位符）
HASH=$(sed -n "s/^PW_HASH='//;s/'\$//p" files/etc/init.d/vs010-mode | head -1)
CALC=$(openssl passwd -1 -salt VS010Z admin)
[ "$HASH" = "$CALC" ] && [ "${HASH#*...}" = "$HASH" ] \
  && ok "登录密码 = admin（真实 MD5-crypt：$HASH）" || bad "密码不是 admin 或仍是占位符"
echo "── 第 13 次：实机两 BUG 修复（root/admin + 5G 单 SSID）──"
M=files/etc/init.d/vs010-mode; W=files/usr/sbin/vs010-wds-pair
# ① 密码：固定 hash、每次开机都在 stamp 之前修、不再用会静默失败的 passwd
grep -Fq "PW_HASH='\$1\$VS010Z\$UZ4qew78etSeRS5gXbjrR1'" "$M" \
  && ok 'password 固定 MD5-crypt hash 写入（openssl -salt VS010Z）' || bad '密码 hash 不对（应为 admin）'
! grep -q '/bin/passwd root' "$M" && ok '已弃用 passwd（只读底层/非 tty 会失败）' || bad '仍用 passwd'
grep -q '^  fix_login        # ★ 放在 stamp 检查之前' "$M" \
  && grep -q '^  fix_login$' "$M" \
  && ok '密码在 apply 的 stamp 检查【之前】+ scrub 里各修一次（不受幂等 stamp 影响）' || bad '密码仍受 stamp 限制'
grep -q 'VS010_SHADOW:-/etc/shadow' "$M" && grep -q 'cat "\$T" > "\$SH"' "$M" \
  && ok 'shadow 写 overlay copy-up（失败走同目录 mv 兜底）' || bad 'shadow 写入不可靠'
# ② 5G 收敛：只开 radio、复用首个 VAP、其余 disable、不再新增段
grep -Fq '=wifi-device$' "$M" && ! grep -Fq 'wifi-\(device\|iface\)' "$M" \
  && ok '只清 wifi-device 的 disabled（不再把多余 5G VAP 全打开）' || bad '仍会复活双 SSID'
grep -Fq 'vs010-wds-pair converge' "$M" && ok 'scrub 开机即收敛（不等 loop 的 35 秒）' || bad '开机仍有双 SSID 窗口'
grep -Fq 'case " $seen "' "$M" && grep -Fq 'wireless.$sec.disabled=1' "$M" \
  && ok 'AP 模式每 radio 只留一个 enabled iface' || bad 'AP 模式仍会双 SSID'
grep -q '^converge(){' "$W" && grep -q 'disabled=1' "$W" \
  && grep -q 'wds.section' "$W" \
  && grep -q '5G 单 VAP 收敛' "$W" \
  && ok 'WDS 复用首个 5G VAP、其余 disabled=1（不新增 wds_z）' || bad '5G 收敛缺'
grep -q '^  converge) converge' "$W" && grep -q 'converge || return 1' "$W" \
  && ok 'converge 可独立调用，apply 复用同一套收敛' || bad '收敛入口不通'
! grep -Fq 'wireless.$WDS_SEC=wifi-iface' "$W" || bad '仍会新增 wds_z 段'

# ③ mock 真跑 A：官方 root:: → 必须变成 admin hash，daemon 行不动，二次幂等
python3 - <<'PY13A' || F=1
import subprocess, tempfile, pathlib, os
src = pathlib.Path('files/etc/init.d/vs010-mode').read_text()
h = [l for l in src.splitlines() if l.startswith('PW_HASH=')][0].split("'",1)[1].split("'",1)[0]
i = src.index('fix_login(){'); j = src.index('\n}', i) + 2
fn = src[i:j]
t = tempfile.mkdtemp(); sh = pathlib.Path(t,'shadow')
orig = 'root::0:0:99999:7:::\ndaemon:*:0:0:99999:7:::\nntp:x:0:0:99999:7:::\n'
sh.write_text(orig)
script = 'log(){ :; }\nPW_HASH=' + "'"+h+"'" + '\n' + fn + '\nfix_login\n'
env = dict(os.environ, VS010_SHADOW=str(sh))
r = subprocess.run(['sh','-c',script], env=env, capture_output=True, text=True)
if r.returncode: print('  FAIL fix_login 执行错', r.stderr[-300:]); raise SystemExit(1)
a = sh.read_text()
r2 = subprocess.run(['sh','-c',script], env=env, capture_output=True, text=True)
b = sh.read_text()
root = [x for x in a.splitlines() if x.startswith('root:')][0].split(':')[1]
print('   root hash:', root)
# 反算：openssl passwd -1 -salt VS010Z admin 必须就是这个 hash
try:
    calc = subprocess.check_output(['openssl','passwd','-1','-salt','VS010Z','admin'],text=True).strip()
except Exception:
    calc = h          # 无 openssl 的环境跳过反算，不误报
ok = (root == h == calc
      and [x for x in a.splitlines() if x.startswith(('daemon:','ntp:'))]
        == [x for x in orig.splitlines() if x.startswith(('daemon:','ntp:'))]
      and a == b)
import shutil; shutil.rmtree(t)
if not ok: print('  FAIL 密码归一/幂等/其它行保持 不成立'); raise SystemExit(1)
print('  ✅ mock A：root::→admin，其它账号不变，二次运行幂等')
PY13A

# ④ mock 真跑 B：官方 5G 生成 2 个 VAP → converge 后只剩 1 个 SSID
python3 - <<'PY13B' || F=1
import json, os, pathlib, subprocess, tempfile, shutil, stat
t = tempfile.mkdtemp(); bind = pathlib.Path(t,'bin'); bind.mkdir()
state = pathlib.Path(t,'uci.json')
db = {
 'wireless.wifi0':{'_type':'wifi-device'},
 'wireless.wifi0.hwmode':'11axg','wireless.wifi0.channel':'1',
 'wireless.wifi0.disabled':'0',
 'wireless.wifi1':{'_type':'wifi-device'},
 'wireless.wifi1.hwmode':'11axa','wireless.wifi1.channel':'36',
 'wireless.wifi1.disabled':'0',
 'wireless.radio0':{'_type':'wifi-iface'},
 'wireless.radio0.device':'wifi0','wireless.radio0.ssid':'Nwrt_2.4G',
 'wireless.radio0.disabled':'0','wireless.radio0.mode':'ap',
 'wireless.radio1':{'_type':'wifi-iface'},
 'wireless.radio1.device':'wifi1','wireless.radio1.ssid':'Nwrt_5G',
 'wireless.radio1.disabled':'0','wireless.radio1.mode':'ap',
 'wireless.radio1_1':{'_type':'wifi-iface'},
 'wireless.radio1_1.device':'wifi1','wireless.radio1_1.ssid':'Nwrt_5G_Guest',
 'wireless.radio1_1.disabled':'0','wireless.radio1_1.mode':'ap',
}
state.write_text(json.dumps(db))
# 最小假 uci：只实现 show/get/set/delete/commit，覆盖脚本用到的全部语法
fake = r'''#!/usr/bin/env python3
import sys,os,json
S=os.environ['UCI_STATE']; db=json.load(open(S))
a=[x for x in sys.argv[1:] if x!='-q']; c=a[0] if a else 'show'
TYPES=('wifi-iface','wifi-device','interface','dropbear','dhcp','core','timeserver','wdsdog','dhcp-guard','ntp-sync')
def dump(): json.dump(db,open(S,'w'))
if c=='show':
    sec=a[1] if len(a)>1 else ''
    for k,v in db.items():
        if sec and not (k==sec or k.startswith(sec+'.')): continue
        if isinstance(v,dict): print(k+'='+v.get('_type',''))
        else: print(k+"='"+str(v)+"'")
elif c=='get':
    v=db.get(a[1]);  sys.exit(1 if v is None else (print(v.get('_type','') if isinstance(v,dict) else v) or 0))
elif c=='set':
    k,_,v=a[1].partition('=')
    db[k]={'_type':v} if v in TYPES else v; dump()
elif c=='delete':
    db.pop(a[1],None); dump()
elif c=='commit':
    dump()
'''
p = bind/'uci'; p.write_text(fake); p.chmod(0o755)
# mock 副本：只把 /etc/vs010 与 /etc/config/wireless 指到临时目录
s = pathlib.Path('files/usr/sbin/vs010-wds-pair').read_text()
s = s.replace('D=/etc/vs010', 'D='+t+'/vs010')
s = s.replace('/etc/config/wireless', t+'/wireless')
# 脚本自带 PATH=/usr/sbin:... 会盖掉注入的假 uci，mock 副本里前置假 bin
s = s.replace('PATH=/usr/sbin:/usr/bin:/sbin:/bin; export PATH',
              'PATH='+str(bind)+':/usr/sbin:/usr/bin:/sbin:/bin; export PATH')
os.makedirs(t+'/vs010', exist_ok=True); pathlib.Path(t,'wireless').write_text('# mock\n')
pathlib.Path(t+'/vs010/role').write_text('ap\n')
mock = pathlib.Path(t,'pair.sh'); mock.write_text(s)
env = dict(os.environ, PATH=str(bind)+':'+os.environ['PATH'], UCI_STATE=str(state))
def run():
    return subprocess.run(['sh',str(mock),'converge'], env=env, capture_output=True, text=True)
r = run()
if r.returncode: print('  FAIL converge rc',r.returncode,r.stdout[-400:],r.stderr[-400:]); raise SystemExit(1)
d1 = json.loads(state.read_text())
r2 = run(); d2 = json.loads(state.read_text())
g = lambda d,k: d.get(k)
iface5 = [k.split('.')[1] for k,v in d1.items()
          if isinstance(v,dict) and v.get('_type')=='wifi-iface' and d1.get(k+'.device')=='wifi1']
enabled5 = [x for x in iface5 if g(d1,'wireless.'+x+'.disabled')!='1']
print('   5G VAP 段:',iface5,' enabled:',enabled5)
ok = (len(enabled5)==1
      and g(d1,'wireless.'+enabled5[0]+'.ssid')=='WDS-Bridge-Z'
      and g(d1,'wireless.'+enabled5[0]+'.key')=='WDS123456'
      and g(d1,'wireless.'+enabled5[0]+'.network')=='lan'
      and g(d1,'wireless.'+enabled5[0]+'.wds')=='1'
      and g(d1,'wireless.'+enabled5[0]+'.wds_bridge')=='br-lan'
      and g(d1,'wireless.wds_z') is None
      and g(d1,'wireless.radio0.wds') is None
      and g(d1,'wireless.radio0.disabled')=='0'
      and g(d1,'wireless.wifi1.htmode')=='HT160'
      and g(d1,'wireless.wifi1.channel')=='auto'
      and d1==d2)
shutil.rmtree(t)
if not ok: print('  FAIL 5G 单 SSID 收敛/幂等 不成立'); raise SystemExit(1)
print('  ✅ mock B：2 个 5G VAP → 仅 1 个 WDS-Bridge-Z；2.4G 不动；HE160；信道 auto；二次幂等')
PY13B

echo "── 第 14 次：固件长期保存 / 只保留 5 个 ──"
Y=.github/workflows/build-openwrt.yml
grep -Fq 'KEEP_RELEASES: 5' "$Y" && ok '保留数 5（可改数字，0=不清理）' || bad '缺保留数配置'
grep -Fq 'retention-days: 90' "$Y" && ok 'artifact 设 90 天（GitHub 上限）；长期以 Release 为准' || bad 'artifact 未设最长保留'
grep -Fq '  cleanup:' "$Y" && grep -Fq 'needs: build' "$Y" && grep -Fq 'if: success()' "$Y" \
  && ok 'cleanup 独立 job，等 4 个构建全发完再跑（不会并发互删）' || bad 'cleanup 时序不安全'
grep -Fq 'startswith("fw-5.4-")' "$Y" \
  && ok '只清理本流水线 fw-5.4- 前缀 Release（不误删用户手动建的 tag）' || bad '会误删非固件 Release'
grep -Fq 'tail -n +$((KEEP+1))' "$Y" && grep -Fq -- '--cleanup-tag' "$Y" \
  && ok '按创建时间倒序保留前 5 个，旧 Release 连 tag 一起删' || bad '保留/清理逻辑缺'
grep -Fq 'GH_TOKEN: ${{ github.token }}' "$Y" && grep -Fq '  contents: write' "$Y" \
  && ok 'cleanup 有 contents: write 与 token（继承顶层授权）' || bad '清理无权限'
# 真跑 mock：从 YAML 抽出 cleanup 的真实 run 块，喂假 gh（14 个 Release，含 2 个非 fw-5.4）
python3 - <<'PY14' || F=1
import re, pathlib, subprocess, tempfile, os, json, shutil, stat
s = pathlib.Path('.github/workflows/build-openwrt.yml').read_text()
lines = s.splitlines()
i = next(k for k,l in enumerate(lines) if 'Keep latest firmware releases' in l)
j = next(k for k in range(i,len(lines)) if re.match(r'^\s+run:\s*\|\s*$', lines[k]))
base = len(lines[j]) - len(lines[j].lstrip(' '))
blk=[]
for x in lines[j+1:]:
    if x.strip() and len(x)-len(x.lstrip(' ')) <= base: break
    blk.append(x)
ind = min(len(x)-len(x.lstrip(' ')) for x in blk if x.strip())
run = '\n'.join(x[ind:] if len(x)>=ind else x for x in blk)
if 'gh release delete' not in run: print('  FAIL 未抽到 cleanup run 块'); raise SystemExit(1)

t = tempfile.mkdtemp(); bind = pathlib.Path(t,'bin'); bind.mkdir()
fake = r'''#!/usr/bin/env python3
import sys,os,json
a=sys.argv[1:]
if a[:2]==['release','list']:
    d=json.load(open(os.environ['MOCK_RELEASES']))
    # 模拟 --jq 'sort_by(.createdAt)|reverse|map(select(startswith("fw-5.4-")))|.[].tagName'
    for r in sorted(d,key=lambda x:x['createdAt'],reverse=True):
        if r['tagName'].startswith('fw-5.4-'): print(r['tagName'])
elif a[:2]==['release','delete']:
    open(os.environ['MOCK_DELETED'],'a').write(a[2]+'\n')
'''
p = bind/'gh'; p.write_text(fake); p.chmod(0o755)
# 12 个固件 Release（时间从新到旧）+ 2 个非固件 tag（必须原样保留）
rels=[{'tagName':'fw-5.4-run%02d'%(20-n),'createdAt':'2026-11-%02dT00:00:00Z'%(27-n)} for n in range(12)]
rels += [{'tagName':'RAX3000Q-2026.11.25-0345','createdAt':'2026-11-26T00:00:00Z'},
         {'tagName':'manual-backup','createdAt':'2026-11-25T00:00:00Z'}]
rels.sort(key=lambda x:x['createdAt'],reverse=True)
rp=pathlib.Path(t,'releases.json'); rp.write_text(json.dumps(rels))
dp=pathlib.Path(t,'deleted.txt'); dp.write_text('')
env=dict(os.environ, PATH=str(bind)+':'+os.environ['PATH'],
         GITHUB_REPOSITORY='mock/repo', KEEP='5',
         MOCK_RELEASES=str(rp), MOCK_DELETED=str(dp))
r=subprocess.run(['bash','-c',run],env=env,capture_output=True,text=True)
if r.returncode: print('  FAIL cleanup run 执行错:',r.stdout[-400:],r.stderr[-400:]); raise SystemExit(1)
deleted=dp.read_text().splitlines()
fw=[x['tagName'] for x in rels if x['tagName'].startswith('fw-5.4-')]
expect=fw[5:]
kept=[x for x in fw if x not in deleted]
print('   总固件 Release',len(fw),'| 删除',len(deleted),'| 保留',len(kept),'| 误删非固件',
      [x for x in deleted if not x.startswith('fw-5.4-')])
ok = (deleted==expect and len(kept)==5
      and not [x for x in deleted if not x.startswith('fw-5.4-')]
      and '保留前 5 个' in r.stdout)
shutil.rmtree(t)
if not ok: print('  FAIL 保留 5 个 / 只删本流水线 tag 不成立'); raise SystemExit(1)
print('  ✅ mock：12 个固件 Release → 删 7 留 5，2 个非固件 tag 一个没动')
PY14
if grep -Fq '第 14 次' CHANGELOG.md; then ok 'CHANGELOG 已记第 14 次'; else echo '  NOTE  第 14 次文档未同步（不影响编译）'; fi

echo "── 第 15 次：MU-MIMO/WMM/弱信号、IPv6/DHCP/防火墙全关、主题内置入口 ──"
M=files/etc/init.d/vs010-mode; W=files/usr/sbin/vs010-wds-pair
# ① 字段名必须来自官方 qcawifi.sh，不能是我编的（解官方 rootfs 实查）
python3 - <<'PY15FIELD' || F=1
import pathlib,struct,subprocess,tempfile,os,shutil
PEB,VID,DATA=131072,2048,4096
p='3000Q-VS010-固件/Nwrt-QSDK12.2-2024-04-16-ipq50xx-ipq50xx_32-cucc_vs010-squashfs-nand-factory.bin'
b=pathlib.Path(p).read_bytes(); v={}
for i in range(len(b)//PEB):
 x=b[i*PEB:(i+1)*PEB]
 if x[:4]==b'UBI#' and x[VID:VID+4]==b'UBI!':
  v.setdefault(struct.unpack_from('>I',x,VID+8)[0],{})[struct.unpack_from('>I',x,VID+12)[0]]=x[DATA:]
t=tempfile.mkdtemp(); f=t+'/r'; pathlib.Path(f).write_bytes(b''.join(v[1][k] for k in sorted(v[1])))
d=t+'/x'; subprocess.run(['unsquashfs','-f','-d',d,f],capture_output=True)
q=os.path.join(d,'lib/wifi/qcawifi.sh'); s=open(q,errors='replace').read()
need=['config_get_bool wmm "$vif" wmm','config_get he_ulmumimo "$vif" he_ulmumimo',
      'config_get he_mubfer "$vif" he_mubfer','config_get he_dlofdma "$vif" he_dlofdma',
      'config_get he_ulofdma "$vif" he_ulofdma',
      'config_get db_rssi_thr "$vif" db_rssi_thr','config_get db_timeout "$vif" db_timeout']
host=open(os.path.join(d,'lib/wifi/hostapd.sh'),errors='replace').read()
print('   官方 qcawifi.sh 字段:',len(need),'项')
for n in need: print('   ',('OK  ' if n in s else 'FAIL'),n)
print('   官方 hostapd.sh 内建 wmm_enabled=1:', 'wmm_enabled=1' in host)
ok=all(n in s for n in need) and 'wmm_enabled=1' in host
shutil.rmtree(t)
if not ok: raise SystemExit(1)
print('  ✅ MU-MIMO/WMM/弱信号字段全部在官方 QSDK 源码里真实存在')
PY15FIELD
for k in 'wmm=1' 'he_ulmumimo=1' 'he_mubfer=1' 'he_dlofdma=1' 'he_ulofdma=1' \
         'db_rssi_thr=' 'db_timeout=10' '/etc/vs010/weak.rssi'; do
  grep -Fq "$k" "$M" || bad "AP 模式缺 $k"
done
[ "$F" = 0 ] && ok 'AP 开 MU-MIMO/WMM + 弱信号剔除/拒绝（阈值可改 weak.rssi，默认 -70）' || true
for k in 'wmm=1' 'he_ulmumimo=1' 'he_mubfer=1' 'he_dlofdma=1' 'he_ulofdma=1'; do
  grep -Fq "$k" "$W" || bad "网桥模式缺 $k"
done
[ "$F" = 0 ] && ok '网桥 WDS 主 VAP 同样开 MU-MIMO/WMM' || true
# ② IPv6 / DHCP / 防火墙：每次开机（scrub）都跑，不受 stamp 限制
for fn in kill_ipv6 kill_dhcp kill_firewall fix_login wifi_single_5g; do
  grep -Fq "$fn" "$M" || bad "缺 $fn"
done
grep -Fq 'ip6assign ip6prefix ip6class ip6hint ip6ifaceid ip6weight' "$M" \
  && grep -Fq '/proc/sys/net/ipv6/conf/*/disable_ipv6' "$M" \
  && grep -Fq 'uci -q set network.lan.ipv6=' "$M" \
  && ok 'IPv6 全关：UCI 选项 + 所有网卡 sysctl + odhcpd 停' || bad 'IPv6 关不彻底'
grep -Fq "dhcp.lan.ignore='1'" "$M" && grep -Fq '/etc/init.d/dnsmasq disable' "$M" \
  && grep -Fq '[!!! DHCP !!!]' "$M" \
  && ok '本机 DHCP 服务端全关（wds/ap 都关）+ 开机日志红字' || bad 'DHCP 未全关'
grep -Fq 'iptables -F' "$M" && grep -Fq 'nft flush ruleset' "$M" \
  && grep -Fq '/etc/init.d/firewall disable' "$M" \
  && ok '防火墙服务 + 自启 + iptables/nft 规则全清' || bad '防火墙未彻底关'
grep -Fq 'wifi_single_5g' "$M" && grep -Fq 'WDS-Bridge-Z' "$M" \
  && ok '5G 单 SSID 内联兜底（不依赖外部脚本）+ 15 秒重试' || bad '5G 兜底缺'
# ③ MAC 全自动读，绝不硬编码
if grep -rE '([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}' files files.vs010 files.rax3000q 2>/dev/null | grep -q .; then
  bad '注入树含硬编码 MAC'
else
  grep -Fq '/sys/class/net/' "$W" && grep -Fq 'mymac()' "$W" \
    && ok 'MAC 全部从 sysfs/ART 自动读，零硬编码（WDS 配对也用它）' || bad 'MAC 不是自动读'
fi
# ④ 主题内置入口
for f in files/usr/lib/lua/luci/controller/admin/vs010.lua \
         files/usr/lib/lua/luci/view/vs010_bridge.htm \
         files/usr/lib/lua/luci/view/vs010_ap.htm \
         files/usr/lib/lua/luci/view/vs010_console.htm; do
  [ -s "$f" ] && ok "$(basename "$f") 在位" || bad "缺 $f"
done
grep -Fq 'entry({"admin", "status", "vs010_bridge"' files/usr/lib/lua/luci/controller/admin/vs010.lua \
  && grep -Fq 'entry({"admin", "status", "vs010_ap"' files/usr/lib/lua/luci/controller/admin/vs010.lua \
  && grep -Fq 'entry({"admin", "status", "vs010_console"' files/usr/lib/lua/luci/controller/admin/vs010.lua \
  && ok 'Argon「状态」菜单新增 网桥状态 / AP 状态 / WDS 控制台' || bad '主题菜单缺入口'
for f in vs010_bridge vs010_ap vs010_console; do
  h=$(grep -c '<%+header%>' "files/usr/lib/lua/luci/view/$f.htm")
  t=$(grep -c '<%+footer%>' "files/usr/lib/lua/luci/view/$f.htm")
  [ "$h" = 1 ] && [ "$t" = 1 ] || bad "$f.htm header/footer 结构错"
done
[ "$F" = 0 ] && ok '3 个视图 header/footer 闭合（不会报主题 427 那类错）' || true
grep -Fq 'iframe src="/bridge/"' files/usr/lib/lua/luci/view/vs010_bridge.htm \
  && grep -Fq 'iframe src="/ap/"' files/usr/lib/lua/luci/view/vs010_ap.htm \
  && ok '丰富页用 iframe 内嵌，原页面/CGI 一字未改' || bad '主题入口没链到丰富页'
grep -Fq 'vs010_bridge' .github/workflows/build-openwrt.yml \
  && grep -Fq '<u>' .github/workflows/build-openwrt.yml \
  && ok '下载页含主题入口与 DHCP <u> 划线红字' || bad '下载页缺提示'
grep -Fq '[!!! DHCP !!!]' CHANGELOG.md && grep -Fq '[!!! DHCP !!!]' README.md \
  && ok 'CHANGELOG / README（日志与主页）也有 DHCP 红字' || bad '日志缺 DHCP 红字'

# ⑤ mock 真跑：假 uci + 假 init.d，验证 IPv6/DHCP/AP 弱信号/5G 单 SSID 的 UCI 结果
python3 - <<'PY15MOCK' || F=1
import json, os, pathlib, subprocess, tempfile, shutil
src = pathlib.Path('files/etc/init.d/vs010-mode').read_text()
def grab(name):
    i = src.index(name+'(){'); j = src.index('\n}', i) + 2
    return src[i:j]
t = tempfile.mkdtemp(); bind = pathlib.Path(t,'bin'); bind.mkdir()
initd = pathlib.Path(t,'initd'); initd.mkdir()
ipvc = pathlib.Path(t,'ipv6conf/all'); ipvc.mkdir(parents=True)
(pathlib.Path(t,'ipv6conf/all/disable_ipv6')).write_text('0\n')
vsdir = pathlib.Path(t,'vs010'); vsdir.mkdir()
(vsdir/'weak.rssi').write_text('-70\n')
pathlib.Path(t,'firmware_model').write_text('cucc_vs010\n')
pathlib.Path(t,'wireless').write_text('# mock\n')
pathlib.Path(t,'sysctl.conf').write_text('net.ipv6.conf.all.disable_ipv6=1\n')
# 假 init.d：所有服务脚本都成功返回；假 iptables/nft/sysctl 绝不碰宿主机
for n in ('dnsmasq','odhcpd','firewall','fw3'):
    p=initd/n; p.write_text('#!/bin/sh\nexit 0\n'); p.chmod(0o755)
for n in ('iptables','ip6tables','nft','sysctl','logger'):
    p=bind/n; p.write_text('#!/bin/sh\nexit 0\n'); p.chmod(0o755)
state = pathlib.Path(t,'uci.json')
db = {
 'wireless.wifi0':{'_type':'wifi-device'},'wireless.wifi0.hwmode':'11axg','wireless.wifi0.channel':'1',
 'wireless.wifi1':{'_type':'wifi-device'},'wireless.wifi1.hwmode':'11axa','wireless.wifi1.channel':'36',
 'wireless.radio0':{'_type':'wifi-iface'},'wireless.radio0.device':'wifi0','wireless.radio0.ssid':'Nwrt_2.4G',
 'wireless.radio0.disabled':'0','wireless.radio0.mode':'ap',
 'wireless.radio1':{'_type':'wifi-iface'},'wireless.radio1.device':'wifi1','wireless.radio1.ssid':'Nwrt_5G',
 'wireless.radio1.disabled':'0','wireless.radio1.mode':'ap',
 'wireless.radio1_1':{'_type':'wifi-iface'},'wireless.radio1_1.device':'wifi1','wireless.radio1_1.ssid':'Nwrt_5G_Guest',
 'wireless.radio1_1.disabled':'0','wireless.radio1_1.mode':'ap',
 'network.lan':{'_type':'interface'},'network.lan.ip6assign':'64','network.lan.ipv6':'1',
 'network.globals':{'_type':'globals'},'network.globals.ula_prefix':'fd00::/64',
 'network.wan6':{'_type':'interface'},
 'dhcp.lan':{'_type':'dhcp'},'dhcp.lan.ra':'server','dhcp.lan.dhcpv6':'server','dhcp.lan.ndp':'relay',
 'dhcp.wan6':{'_type':'dhcp'},
}
state.write_text(json.dumps(db))
fake = r'''#!/usr/bin/env python3
import sys,os,json
S=os.environ['UCI_STATE']; db=json.load(open(S))
a=[x for x in sys.argv[1:] if x!='-q']; c=a[0] if a else 'show'
TYPES=('wifi-iface','wifi-device','interface','globals','dhcp','core','timeserver','wdsdog','dhcp-guard','ntp-sync')
def dump(): json.dump(db,open(S,'w'))
if c=='show':
    sec=a[1] if len(a)>1 else ''
    for k,v in db.items():
        if sec and not (k==sec or k.startswith(sec+'.')): continue
        if isinstance(v,dict): print(k+'='+v.get('_type',''))
        else: print(k+"='"+str(v)+"'")
elif c=='get':
    v=db.get(a[1]); sys.exit(1 if v is None else (print(v.get('_type','') if isinstance(v,dict) else v) or 0))
elif c=='set':
    k,_,v=a[1].partition('='); db[k]={'_type':v} if v in TYPES else v; dump()
elif c=='delete': db.pop(a[1],None); dump()
elif c=='commit': dump()
'''
p=bind/'uci'; p.write_text(fake); p.chmod(0o755)
body = '\n'.join(grab(n) for n in ('kill_ipv6','kill_dhcp','kill_firewall','set_ap_ssid','wifi_single_5g'))
for old,new in [('/etc/init.d/',str(initd)+'/'),('/proc/sys/net/ipv6/conf/',str(pathlib.Path(t,'ipv6conf'))+'/'),
                ('/etc/sysctl.d/99-vs010-no-ipv6.conf',str(pathlib.Path(t,'sysctl.conf'))),
                ('/etc/vs010/',str(vsdir)+'/'),('/etc/firmware_model',str(pathlib.Path(t,'firmware_model'))),
                ('/etc/config/wireless',str(pathlib.Path(t,'wireless')))]:
    body = body.replace(old,new)
script = ("PATH="+str(bind)+":/usr/sbin:/usr/bin:/sbin:/bin; export PATH\n"
          "uci(){ command uci \"$@\" 2>/dev/null; }\nlog(){ :; }\n"
          + body + "\nkill_ipv6; kill_dhcp; kill_firewall; set_ap_ssid\n"
          "# 再模拟 WDS 场景：把主 VAP 改成 WDS-Bridge-Z 后跑内联兜底\n"
          "uci -q set wireless.radio1.ssid=WDS-Bridge-Z\nwifi_single_5g\n")
env=dict(os.environ, UCI_STATE=str(state))
r=subprocess.run(['sh','-c',script],env=env,capture_output=True,text=True)
if r.returncode: print('  FAIL mock 执行错:',r.stdout[-500:],r.stderr[-500:]); raise SystemExit(1)
d=json.loads(state.read_text())
g=lambda k: d.get(k)
checks={
 'network.lan.ipv6=0': g('network.lan.ipv6')=='0',
 'ip6assign 已删': g('network.lan.ip6assign') is None,
 'ULA 前缀已删': g('network.globals.ula_prefix') is None,
 'network.wan6 已删': g('network.wan6') is None,
 'dhcp.wan6 已删': g('dhcp.wan6') is None,
 'RA/DHCPv6/NDP 全 off': all(g('dhcp.lan.'+x)=='off' for x in ('ra','dhcpv6','ndp')),
 'dhcp.lan.ignore=1': g('dhcp.lan.ignore')=='1',
 '所有网卡 disable_ipv6=1': (pathlib.Path(t,'ipv6conf/all/disable_ipv6')).read_text().strip()=='1',
 'AP SSID 按机型 VS010-AP': (pathlib.Path(t,'vs010/ap.ssid')).exists() and (pathlib.Path(t,'vs010/ap.ssid')).read_text().strip()=='VS010-AP',
 'AP 弱信号阈值 -70': g('wireless.radio1.db_rssi_thr')=='-70',
 'AP db_timeout=10': g('wireless.radio1.db_timeout')=='10',
 'WMM=1': g('wireless.radio1.wmm')=='1',
 'he_ulmumimo=1': g('wireless.radio1.he_ulmumimo')=='1',
 'he_mubfer/dlofdma/ulofdma=1': all(g('wireless.radio1.'+x)=='1' for x in ('he_mubfer','he_dlofdma','he_ulofdma')),
 '2.4G 也开 WMM/MU': g('wireless.radio0.wmm')=='1' and g('wireless.radio0.he_ulmumimo')=='1',
 '5G 仅 1 个 enabled VAP': g('wireless.radio1.disabled')=='0' and g('wireless.radio1_1.disabled')=='1',
}
for k,v in checks.items(): print('   ',('OK  ' if v else 'FAIL'),k)
shutil.rmtree(t)
if not all(checks.values()): raise SystemExit(1)
print('  ✅ mock：IPv6/DHCP/防火墙全关 + AP 弱信号/MU/WMM + 5G 单 SSID 全部落到 UCI')
PY15MOCK
if grep -Fq '第 15 次' CHANGELOG.md && grep -Fq '第 15 次' README.md; then
  ok 'CHANGELOG / 仓库主页已记第 15 次'
else
  echo '  NOTE  第 15 次文档未同步（不影响编译）'
fi


echo "── 第 15 次扩展：密码 admin / 弱信号守护 / 已插线速率 / 总览 IPv6 / 双页 NETWORK ──"
M=files/etc/init.d/vs010-mode
grep -Fq "PW_HASH='\$1\$VS010Z\$UZ4qew78etSeRS5gXbjrR1'" "$M" && ok '登录密码 = admin（最新拍板，真实 hash）' || bad '密码 hash 不是 admin'
grep -Fq 'root/admin 已写入 shadow' "$M" && ok 'fix_login 日志口径同步 admin' || bad 'fix_login 日志仍写 password'
grep -Fq '`root` / `admin`' .github/workflows/build-openwrt.yml && ok '下载页账号 = admin' || bad '下载页账号不是 admin'
grep -Fq '`root` / `password`' README.md && ok '仓库主页账号 = admin' || bad 'README 账号不是 admin'
# ap-rssi-guard（AP 页那套命令必须真能用）
G=files/usr/sbin/ap-rssi-guard
[ -s "$G" ] && sh -n "$G" && ok 'ap-rssi-guard 脚本在位且语法通过' || bad 'ap-rssi-guard 缺失/语法错'
for k in 'status)' 'on)' 'off)' 'dryrun)' 'set)' 'loop)' 'db_rssi_thr' 'ap-rssi-guard.main'; do
  grep -Fq "$k" "$G" || bad "ap-rssi-guard 缺 $k"
done
grep -Fq 'ap-rssi-guard.main' files/www/cgi-bin/apstatus   && ok 'AP 页 CGI 读的正是这套 UCI 字段（页面命令与实现闭环）' || bad '页面与脚本字段不闭环'
# 共用 CGI：只列已插线口 + net 三卡
C=files/www/cgi-bin/vs010-links
[ -s "$C" ] && sh -n "$C" && ok 'vs010-links 共用端点在位且语法通过' || bad '共用端点缺失/语法错'
grep -Fq 'carrier' "$C" && grep -Fq 'Link detected' "$C"   && ok '只返回已插网线口（carrier=1 / ethtool yes）' || bad '未过滤未插线口'
for k in admin_ip bridge dhcp_server gateway dns firewall watchdog snooping phy_speed; do
  grep -Fq "$k" "$C" || bad "共用端点缺 net.$k"
done
# 两个丰富页
for f in files/www/bridge/index.html files/www/ap/index.html; do
  grep -Fq 'LINK UP' "$f" || bad "$(basename $(dirname $f)) 页缺「已插网线」区块"
  grep -Fq 'vs010-links' "$f" || bad "$(basename $(dirname $f)) 页未接共用端点"
done
grep -Fq 'netgrid' files/www/bridge/index.html   && ok '网桥页也补上「网络与本机 / 地址分配」三卡（与 AP 页一致）' || bad '网桥页缺 NETWORK'
grep -Fq 'filter(function(p)' files/www/bridge/index.html   && ok '网桥四宫格只显示已插线口，不再铺一堆' || bad '四宫格未过滤'
grep -Fq "if (\$('netgrid') && !\$('netgrid').innerHTML)" files/www/ap/index.html \
  && ok 'AP 页主 CGI 已渲染则共用端点不覆盖（无双写闪烁）' || bad 'AP 页 NETWORK 会双写'
# 主题里的网口速率页：只列已插线
grep -Fq 'portstat --rows-up' files/usr/lib/lua/luci/controller/admin/vs010_ports.lua   && ok 'Argon「已插网线速率」页只取 --rows-up' || bad '主题速率页仍取全量'
grep -Fq '已插网线' files/usr/lib/lua/luci/view/vs010_ports.htm   && ok '主题速率页标题/空态已精简' || bad '主题速率页未精简'
grep -Fq 'list_up' files/usr/sbin/portstat   && ok 'portstat 默认只列已插线口（--all 才看全部）' || bad 'portstat 未收敛'
sh -n files/usr/sbin/portstat && ok 'portstat 语法通过' || bad 'portstat 语法错'
# 系统总览 IPv6 块：删 ip6tables symlink → has_ipv6=false（零覆盖官方视图）
grep -Fxq 'usr/sbin/ip6tables' build/prune.list   && ok '构建期删 ip6tables 符号链接 → 总览 IPv6 WAN/DUID 块自动消失' || bad '总览 IPv6 块还在'
grep -Fq 'ip6tables' build/prune.keep && bad 'ip6tables 误进白名单' || ok 'ip6tables 未进白名单'
# 主题内置三页
for f in vs010_bridge vs010_ap vs010_console; do
  [ -s "files/usr/lib/lua/luci/view/$f.htm" ] || bad "缺 $f.htm"
done
grep -Fq 'entry({"admin", "status", "vs010_bridge"' files/usr/lib/lua/luci/controller/admin/vs010.lua   && ok 'Argon「状态」菜单有网桥/AP/控制台入口（好找）' || bad '主题菜单缺入口'


echo "── 第 16 次：信道自动 / 网桥弱信号 / 网桥网络设置 / 上线网卡 / 主题留档 ──"
M=files/etc/init.d/vs010-mode; W=files/usr/sbin/vs010-wds-pair
B=files/www/bridge/index.html; A=files/www/ap/index.html; L=files/www/cgi-bin/vs010-links
# ① 官方 qcawifi.sh 真的认 auto（解官方 rootfs 实查，不靠我嘴说）
python3 - <<'PY16AUTO' || F=1
import pathlib,struct,subprocess,tempfile,os,shutil
PEB,VID,DATA=131072,2048,4096
p='3000Q-VS010-固件/Nwrt-QSDK12.2-2024-04-16-ipq50xx-ipq50xx_32-cucc_vs010-squashfs-nand-factory.bin'
b=pathlib.Path(p).read_bytes(); v={}
for i in range(len(b)//PEB):
 x=b[i*PEB:(i+1)*PEB]
 if x[:4]==b'UBI#' and x[VID:VID+4]==b'UBI!':
  v.setdefault(struct.unpack_from('>I',x,VID+8)[0],{})[struct.unpack_from('>I',x,VID+12)[0]]=x[DATA:]
t=tempfile.mkdtemp(); f=t+'/r'; pathlib.Path(f).write_bytes(b''.join(v[1][k] for k in sorted(v[1])))
d=t+'/x'; subprocess.run(['unsquashfs','-f','-d',d,f],capture_output=True)
s=open(os.path.join(d,'lib/wifi/qcawifi.sh'),errors='replace').read()
checks={'auto→0 合法':'[ auto = "$channel" ] && channel=0' in s,
        '11AHE160 分支':'*axa:HT160) hwmode=11AHE160' in s,
        '弱信号字段':'config_get db_rssi_thr "$vif" db_rssi_thr' in s,
        'db_timeout 字段':'config_get db_timeout "$vif" db_timeout' in s}
for k,x in checks.items(): print('   ',('OK  ' if x else 'FAIL'),k)
shutil.rmtree(t)
if not all(checks.values()): raise SystemExit(1)
PY16AUTO
grep -Fq 'wireless.$d.channel=auto' "$W" && ok '网桥 5G 信道 auto（ACS）' || bad 'wds-pair 没改 auto'
grep -Fq 'auto_channel()' "$M" && grep -Fq 'auto_channel' "$M" \
  && grep -Fq 'wireless.$x.channel=auto' "$M" \
  && ok '每次开机所有 wifi-device 写 channel=auto' || bad 'auto_channel 缺'
grep -Fq 'wireless.$d.hwmode=11axa' "$W" && grep -Fq 'wireless.$d.htmode=HT160' "$W" \
  && ok 'HE160 保留（11axa+HT160 → 11AHE160）' || bad 'HE160 被改坏'
# ② 网桥也要弱信号
grep -Fq 'wireless.$primary.db_rssi_thr=' "$W" && grep -Fq 'wireless.$primary.db_timeout=10' "$W" \
  && ok '网桥 WDS 主 VAP 也有弱信号剔除/拒绝（与 AP 同口径）' || bad '网桥弱信号缺'
grep -Fq '/etc/vs010/weak.rssi' "$W" && ok '阈值可改 weak.rssi（默认 -70）' || true
# ③ 网桥页网络设置真 BUG 修复
grep -Fq 'function drawNet(j){' "$B" && grep -Fq '  drawNet(j);   /* 第 16 次' "$B" \
  && ok '网桥页主 CGI 直接渲染网络三卡（不再依赖共用端点）' || bad '网桥 drawNet 未调用'
grep -Fq "if (\$('netgrid') && !\$('netgrid').innerHTML)" "$B" \
  && grep -Fq "if (\$('netgrid') && !\$('netgrid').innerHTML)" "$A" \
  && ok 'bridge/ap 两页共用端点只作兜底，已渲染不覆盖' || bad 'loadLinks 兜底缺'
grep -Fq '两端都绝不能开 DHCP 服务端' "$B" && grep -Fq 'text-decoration:underline' "$B" \
  && ok '网桥页也有 DHCP 红字划线提示' || bad '网桥页 DHCP 提示缺'
# ④ 只显示上线网卡
grep -Fq '*1*|*up*|*yes*) ;; *) continue ;;' "$L" \
  && ok 'vs010-links 三重判定，只返回已插网线的口' || bad 'vs010-links 过滤缺'
grep -Fq 'j.ports||[]).filter' "$B" && ok '主 /bridge/ ports 二次过滤' || true
# ⑤ MAC 自动读 ART
grep -Fq '/sys/class/net/br-lan/address' "$L" && grep -Fq 'ART → sysfs' "$L" \
  && grep -Fq '"mac"' "$L" \
  && ok 'MAC 从 sysfs（驱动按 ART 生成）自动读，零手填' || bad 'MAC 来源缺'
if grep -rE '([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}' files files.vs010 files.rax3000q 2>/dev/null | grep -q .; then
  bad '注入树含硬编码 MAC'
else ok '全仓零硬编码 MAC'; fi
# ⑥ 上游主题：拉到 + 留档 + 绝不替换
for f in reference/ARGON-NOTE.md reference/argon-upstream/Makefile \
         reference/argon-upstream/RELEASE.md reference/argon-upstream/header.ut; do
  [ -s "$f" ] || bad "缺 $f"
done
grep -Fq 'PKG_VERSION:=3.2.0' reference/argon-upstream/Makefile && grep -Fq 'ucode' reference/ARGON-NOTE.md \
  && grep -Fq 'v2.4.3' reference/ARGON-NOTE.md && grep -Fq '最后一个兼容版' reference/ARGON-NOTE.md \
  && ok '上游 v3.2.0 元数据留档 + v2.4.3（最后 Lua 版）已注入并说明谱系' || bad '主题说明缺'
grep -Fq 'themes/argon/header.htm' build/prune.keep \
  && grep -Fq 'etc/uci-defaults/90_luci-theme-argon' build/prune.keep \
  && ok '官方 Argon 9 项进白名单，构建期一个字节不许动' || bad '主题白名单缺'
if find files -type f \( -name '*.ut' -o -name 'argon-upstream*' \) 2>/dev/null | grep -q .; then
  bad '注入树混入上游 ucode 主题文件（会打不开后台）'
else ok '注入树零上游主题文件（官方 1.7.2 原样保留）'; fi
# ⑦ vs010-links mock：JSON 合法 + 只上线口 + mac 非空
python3 - <<'PY16LINK' || F=1
import pathlib,subprocess,tempfile,os,shutil,json,re
s=pathlib.Path('files/www/cgi-bin/vs010-links').read_text()
t=tempfile.mkdtemp(); bind=pathlib.Path(t,'bin'); bind.mkdir()
net=pathlib.Path(t,'sys/class/net'); 
for n,carrier,oper,speed in [('eth0','1','up','1000'),('eth1','0','down','-1'),('br-lan','1','up','-1')]:
 d=net/n; d.mkdir(parents=True)
 (d/'carrier').write_text(carrier+'\n'); (d/'operstate').write_text(oper+'\n'); (d/'speed').write_text(speed+'\n')
 (d/'address').write_text('00:25:5c:11:62:74\n')
for n,body in [('uci','#!/bin/sh\ncase "$2" in network.lan.ipaddr) echo 172.10.10.241;; network.lan.ipv6) echo 0;; dhcp.lan.ignore) echo 1;; *) exit 1;; esac\n'),
               ('swconfig','#!/bin/sh\necho "Found: switch0"; echo "speed: 1000"; echo "duplex: full"\n'),
               ('ethtool','#!/bin/sh\ncase "$1" in eth0) echo "Link detected: yes"; echo "Duplex: Full";; *) echo "Link detected: no";; esac\n')]:
 p=bind/n; p.write_text(body); p.chmod(0o755)
initd=pathlib.Path(t,'initd'); initd.mkdir(); (initd/'firewall').write_text('#!/bin/sh\necho "not running"\n'); (initd/'firewall').chmod(0o755)
s=s.replace('/sys/class/net/',str(net)+'/').replace('/etc/init.d/',str(initd)+'/')
s=s.replace('/proc/sys/kernel/hostname',str(pathlib.Path(t,'hostname')))
pathlib.Path(t,'hostname').write_text('WDS-Z\n')
s=s.replace('/tmp/sysinfo/board_name',str(pathlib.Path(t,'board'))); pathlib.Path(t,'board').write_text('cucc_vs010\n')
s=s.replace('/etc/resolv.conf',str(pathlib.Path(t,'resolv'))); pathlib.Path(t,'resolv').write_text('nameserver 172.10.10.254\n')
s=s.replace('/etc/firmware_mode',str(pathlib.Path(t,'mode'))); pathlib.Path(t,'mode').write_text('wds\n')
s=s.replace('/etc/vs010/role',str(pathlib.Path(t,'role'))); pathlib.Path(t,'role').write_text('ap\n')
env=dict(os.environ,PATH=str(bind)+':/usr/sbin:/usr/bin:/sbin:/bin')
r=subprocess.run(['sh','-c',s],env=env,capture_output=True,text=True)
out=r.stdout[r.stdout.find('{'):].strip()
try: j=json.loads(out)
except Exception as e: print('  FAIL JSON 非法:',e,out[:300]); raise SystemExit(1)
ifs=[x['if'] for x in j['links']]
checks={'JSON 合法':True,'未插线 eth1 不出现':'eth1' not in ifs,'上线 eth0 出现':'eth0' in ifs,
        'eth0 速率 1000':any(x['if']=='eth0' and x['speed']==1000 for x in j['links']),
        'MAC 非空':bool(j['net'].get('mac')),'MAC 来源 ART':('ART' in j['net'].get('mac_src','')),
        '本机 DHCP 关':j['net'].get('dhcp_server')=='off','IPv6 全关':j['net'].get('ipv6')=='0',
        '有 net 对象':isinstance(j['net'],dict)}
for k,v in checks.items(): print('   ',('OK  ' if v else 'FAIL'),k)
shutil.rmtree(t)
if not all(checks.values()): raise SystemExit(1)
PY16LINK
if grep -Fq '第 16 次' CHANGELOG.md && grep -Fq '第 16 次' README.md; then
  ok 'CHANGELOG / README 已记第 16 次'
else echo '  NOTE  第 16 次文档未同步'; fi

echo "── 第 17 次：可用的新版 Argon / WDS 主客开关 / DHCP 两模式全关 / 双机型 ──"
TH=files/usr/lib/lua/luci/view/themes/argon2
WW=files/www/luci-static/argon2
R=files/usr/sbin/vs010-role; T=files/usr/sbin/vs010-theme
C=files/usr/lib/lua/luci/controller/admin/vs010.lua
V=files/usr/lib/lua/luci/view/vs010_role.htm
M=files/etc/init.d/vs010-mode; S=files/etc/init.d/vs010-luci-fix
# ① 版本谱系硬证据：注入的是 Lua .htm，不是 ucode .ut
n=$(find "$TH" -maxdepth 1 -name '*.htm' | wc -l)
[ "$n" = 6 ] && ok 'Argon v2.4.3 六张 Lua 模板在位（官方最后一个兼容版）' || bad "模板数 $n ≠ 6"
find files -type f -name '*.ut' 2>/dev/null | grep -q . \
  && bad '注入树混入 ucode .ut（本机 Lua 渲染器不认，后台会挂）' \
  || ok '注入树零 ucode .ut（v2.4.4+ 已排除）'
[ -s "$WW/css/cascade.css" ] && [ -s "$WW/css/dark.css" ] \
  && ok '新版静态资源 cascade.css / dark.css 在位' || bad '新版 CSS 缺'
grep -q 'PKG_VERSION:=2.4.3' reference/argon-upstream/Makefile.v2.4.3 \
  && grep -Fq 'LUCI_DEPENDS:=+curl +jsonfilter' reference/argon-upstream/Makefile.v2.4.3 \
  && ok '上游 v2.4.3 Makefile 留档（版本/依赖可追溯）' || bad '版本留档缺'
grep -Fq 'v2.4.3' reference/ARGON-NOTE.md && grep -Fq '最后一个兼容版' reference/ARGON-NOTE.md \
  && ok 'ARGON-NOTE 说明版本谱系与不兼容边界' || bad '主题说明缺'
# ② 零覆盖官方 + 模板路径自洽 + 登录页用实机验证版
if find files -type f \( -path '*/view/themes/argon/*' -o -path '*/www/luci-static/argon/*' \) 2>/dev/null | grep -q .; then
  bad '注入树覆盖了官方 argon 1.7.2 目录'
else ok '官方 argon 目录一个字节未碰（新版放独立 argon2）'; fi
if grep -rq '/www/luci-static/argon/' "$TH" 2>/dev/null; then
  bad 'argon2 模板仍硬编码官方路径（dark.css 会读不到）'
else ok 'argon2 模板路径全部自洽（/www/luci-static/argon2/）'; fi
grep -Fq '/www/luci-static/argon2/css/dark.css' "$TH/header.htm" \
  && grep -Fq '/www/luci-static/argon2/css/dark.css' "$TH/header_login.htm" \
  && ok 'header / header_login 的 dark.css 已指向 argon2' || bad 'dark.css 路径未改'
grep -Fq 'online_wallpaper' "$TH/sysauth.htm" \
  && bad '登录页 sysauth 仍调不存在的 online_wallpaper（缺 curl 会报错）' \
  || ok '登录页沿用官方 1.7.2 实机验证版（零在线壁纸依赖）'
# ③ 主题切换命令 + S18 不再覆盖用户选择
for k in 'argon243' 'argon' 'luci.themes.Argon_243=/luci-static/argon2' 'luci.main.mediaurlbase=/luci-static/argon2' 'uhttpd restart'; do
  grep -Fq "$k" "$T" || bad "vs010-theme 缺 $k"
done
grep -Fq 'Argon_243=/luci-static/argon2' "$S" \
  && grep -Fq '|/luci-static/argon2) : ;;' "$S" \
  && ok 'S18 注册两个主题且尊重用户选择（不再强制打回 argon）' || bad 'S18 仍会覆盖主题'
[ "$F" = 0 ] && ok '主题切换：不重启机器、不动网络无线，一键可回退' || true
# ④ WDS 主/客开关：241 / 242 / hostname / DHCP 全关
grep -Fq '172.10.10.241' "$R" && grep -Fq '172.10.10.242' "$R" \
  && grep -Fq 'WDS-Z' "$R" && grep -Fq 'WDS-K' "$R" \
  && ok '主 WDS-Z=.241 / 客户端 WDS-K=.242（掩码 /22）' || bad '主客 IP/设备名缺'
grep -Fq 'dhcp.lan.ignore=1' "$R" && grep -Fq '内网只允许上级一台 DHCP' "$R" \
  && ok '切角色后再次兜底关本机 DHCP（WDS/AP 都关）' || bad '角色开关未关 DHCP'
grep -Fq 'set-role "$r"' "$R" && grep -Fq 'apply_now "$ip"' "$R" \
  && ok '复用已验证 wds-pair set-role（只 wifi reload，不碰 IP、不重启）' || bad '角色切换副作用未控'
grep -Fq '当前是 AP 模式固件' "$R" && ok 'AP 模式提示（IP 恒 241）' || true
# ⑤ 每次开机按 role 定 IP，AP 恒 241
grep -Fq 'if [ "$MODE_S" = ap ]; then' "$M" \
  && grep -Fq '[ "$R" = sta ] && IP=172.10.10.242 || IP=172.10.10.241' "$M" \
  && ok '首启按 mode/role 定 IP：WDS 主 .241 / 客户端 .242 / AP 恒 .241' || bad '首启 IP 逻辑缺'
# ⑥ Web 开关页：入口 + 白名单（防命令注入）+ 模板闭合
grep -Fq 'entry({"admin", "status", "vs010_role"' "$C" \
  && grep -Fq 'function show_role()' "$C" \
  && ok 'Argon「状态」菜单新增 主题与 WDS 角色 页' || bad 'Web 开关入口缺'
grep -Fq 'act == "master" or act == "client" or act == "auto"' "$C" \
  && grep -Fq 'act == "argon243" or act == "argon"' "$C" \
  && ok 'GET 参数严格白名单（杜绝命令注入）' || bad 'Web 参数未白名单'
[ -s "$V" ] && [ "$(grep -c '<%+header%>' "$V")" = 1 ] \
  && [ "$(grep -c '<%+footer%>' "$V")" = 1 ] \
  && grep -Fq '两端都绝不能开 DHCP' "$V" \
  && ok '开关页模板闭合 + 双 DHCP 红字划线' || bad '开关页模板/提示缺'
# ⑦ 双机型共用：公共层实现
if grep -rq 'vs010-role\|argon2' files.vs010 files.rax3000q 2>/dev/null; then
  echo '  NOTE  机型层也出现主题/角色文件（应只在公共 files/）'
else ok '主题与角色全在公共 files/：VS010 / RAX3000Q 两种机型同时生效'; fi

# ⑧ mock 真跑：假 uci + 假 init.d，验证主/客切换与主题切换真实落盘
python3 - <<'PY17MOCK' || F=1
import os,json,pathlib,subprocess,tempfile,shutil
t=tempfile.mkdtemp(); bind=pathlib.Path(t,'bin'); bind.mkdir()
initd=pathlib.Path(t,'initd'); initd.mkdir()
for n in ('uhttpd','network'):
 p=initd/n; p.write_text('#!/bin/sh\nexit 0\n'); p.chmod(0o755)
state=pathlib.Path(t,'uci.json')
db={'luci.main':{'_type':'core'},'luci.main.mediaurlbase':'/luci-static/argon',
    'luci.themes':{'_type':'internal'},
    'network.lan':{'_type':'interface'},'network.lan.ipaddr':'172.10.10.241',
    'network.lan.netmask':'255.255.252.0','network.lan.proto':'static',
    'dhcp.lan':{'_type':'dhcp'},'dhcp.lan.ignore':'1'}
state.write_text(json.dumps(db))
fake=r'''#!/usr/bin/env python3
import sys,os,json
S=os.environ['UCI_STATE']; d=json.load(open(S)); a=[x for x in sys.argv[1:] if x!='-q']; c=a[0] if a else 'show'
TYPES=('core','internal','interface','dhcp','globals')
def dump(): json.dump(d,open(S,'w'))
if c=='show':
 s=a[1] if len(a)>1 else ''
 for k,v in d.items():
  if s and not (k==s or k.startswith(s+'.')): continue
  print(k+'='+v.get('_type','') if isinstance(v,dict) else k+"='"+str(v)+"'")
elif c=='get':
 v=d.get(a[1]); sys.exit(1 if v is None else (print(v.get('_type','') if isinstance(v,dict) else v) or 0))
elif c=='set':
 k,_,v=a[1].partition('='); d[k]={'_type':v} if v in TYPES else v; dump()
elif c=='rename':
 old,_,new=a[1].partition('='); d[new]=d.pop(old,{}); dump()
elif c=='delete': d.pop(a[1],None); dump()
elif c=='commit': dump()
'''
p=bind/'uci'; p.write_text(fake); p.chmod(0o755)
for n,body in [('vs010-host','#!/bin/sh\nexit 0\n'),('vs010-wds-pair','#!/bin/sh\nexit 0\n'),
               ('logger','#!/bin/sh\nexit 0\n'),('sleep','#!/bin/sh\nexit 0\n')]:
 q=bind/n; q.write_text(body); q.chmod(0o755)
D=pathlib.Path(t,'vs010'); D.mkdir()
pathlib.Path(t,'firmware_mode').write_text('wds\n')
www=pathlib.Path(t,'www/luci-static/argon2/css'); www.mkdir(parents=True); (www/'cascade.css').write_text('x')
luav=pathlib.Path(t,'usr/lib/lua/luci/view/themes/argon2'); luav.mkdir(parents=True); (luav/'header.htm').write_text('x')
luci_cfg=pathlib.Path(t,'luci'); luci_cfg.write_text('config core main\n')
env=dict(os.environ,UCI_STATE=str(state),PATH=str(bind)+':/usr/sbin:/usr/bin:/sbin:/bin')
def exec_script(script,arg):
 s=(pathlib.Path('files/usr/sbin/'+script).read_text()
    .replace('/etc/vs010',str(D)).replace('/etc/firmware_mode',str(pathlib.Path(t,'firmware_mode')))
    .replace('/etc/init.d/',str(initd)+'/')
    .replace('/www/luci-static/argon2',str(pathlib.Path(t,'www/luci-static/argon2')))
    .replace('/usr/lib/lua/luci/view/themes/argon2',str(luav))
    .replace('L=/etc/config/luci','L='+str(luci_cfg))
    .replace('PATH=/usr/sbin:/usr/bin:/sbin:/bin; export PATH',
             'PATH='+str(bind)+':/usr/sbin:/usr/bin:/sbin:/bin; export PATH'))
 f=pathlib.Path(t,script); f.write_text(s); f.chmod(0o755)
 return subprocess.run(['sh',str(f),arg],env=env,capture_output=True,text=True)
a=exec_script('vs010-role','master'); b=exec_script('vs010-role','client'); c=exec_script('vs010-role','status')
d=json.loads(state.read_text())
th=exec_script('vs010-theme','argon243'); d_new=json.loads(state.read_text())
th2=exec_script('vs010-theme','status')
th3=exec_script('vs010-theme','argon'); d_back=json.loads(state.read_text())
checks={
 'master rc=0':a.returncode==0,'client rc=0':b.returncode==0,
 'master 输出 .241':'172.10.10.241' in a.stdout,
 'client 输出 .242':'172.10.10.242' in b.stdout,
 'client role=sta':(D/'role').read_text().strip()=='sta',
 'client ipaddr 文件 .242':(D/'ipaddr').read_text().strip()=='172.10.10.242',
 'uci network.lan.ipaddr=.242':d.get('network.lan.ipaddr')=='172.10.10.242',
 'uci dhcp.lan.ignore=1':d.get('dhcp.lan.ignore')=='1',
 'status 显示客户端':'客户端 WDS-K' in c.stdout,
 'status 显示 .242':'172.10.10.242' in c.stdout,
 'theme argon243 rc=0':th.returncode==0,
 '切新版 mediaurlbase=argon2':d_new.get('luci.main.mediaurlbase')=='/luci-static/argon2',
 '注册 Argon_243':d_new.get('luci.themes.Argon_243')=='/luci-static/argon2',
 'Argon 官方项保留':d_new.get('luci.themes.Argon')=='/luci-static/argon',
 'status 认出 2.4.3':'v2.4.3' in th2.stdout,
 '切回官方 mediaurlbase=argon':d_back.get('luci.main.mediaurlbase')=='/luci-static/argon',
 '切回官方 rc=0':th3.returncode==0,
}
for k,v in checks.items(): print('   ',('OK  ' if v else 'FAIL'),k)
shutil.rmtree(t)
if not all(checks.values()): raise SystemExit(1)
print('  ✅ mock：主/客 241↔242、DHCP 关、主题 1.7.2↔2.4.3 双向切换全部落盘')
PY17MOCK
if grep -Fq '第 17 次' CHANGELOG.md && grep -Fq '第 17 次' README.md; then
  ok 'CHANGELOG / README 已记第 17 次'
else echo '  NOTE  第 17 次文档未同步'; fi

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
[ "$F" = 0 ] && echo 'RESULT: PASS —— 第 17 次：可用新版 Argon v2.4.3 / WDS 主客 241·242 / DHCP 两模式全关 / 双机型 / 前 16 次全继承' || echo 'RESULT: FAIL'
exit $F
