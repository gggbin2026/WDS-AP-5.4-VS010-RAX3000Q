#!/bin/sh
# 源码编译线自检（r24）
# 工作目录：sourcebuild/  （cd "$(dirname "$0")/.."）
# r24 修复：去掉 /data/workspace/_r12 这类开发机硬编码路径；
#           workflow 改指 ../.github/workflows/build-source.yml；
#           新增实机备份实证断言（MIBIB 16 分区 / bootargs 来源 / BDF 本机校准）。
set -u
cd "$(dirname "$0")/.." || exit 1
ROOT=$(pwd)/..
W=../.github/workflows/build-source.yml
FUSED=../.github/workflows/build-openwrt.yml
F=0
ok(){ echo "  OK  $1"; }
bad(){ echo "  FAIL  $1"; F=1; }

echo "── r26 全能包：单线自包含（清空仓库后解压即用）──"
[ -s "$W" ] && ok '唯一编译入口 = build-source.yml' || bad '缺 build-source.yml'
grep -Fq 'Build 5.4 source firmware (r29' "$W" && ok 'workflow 为 r29 单线双模式版' || bad 'workflow 版本不对'
[ "$(ls -1 ../.github/workflows/*.yml 2>/dev/null | wc -l)" = 1 ] \
  && ok 'workflows/ 只有 1 个 yml（无同名冲突）' || bad 'workflow 数量不对'
[ ! -e "$FUSED" ] && ok '融合线 workflow 已移除' || bad '融合线残留'
[ -s ../verify.sh ] && grep -Fq 'exec sh sourcebuild/tools/verify.sh' ../verify.sh \
  && ok '根 verify.sh 指向单线自检' || bad '根入口不对'
  [ -s ../README.md ] && grep -Fq '## 内核与平台' ../README.md \
    && grep -Fq '## 内置功能与插件' ../README.md \
    && grep -Fq '## 编译产物' ../README.md \
    && grep -Fq '## 资料索引' ../README.md \
    && grep -Fq 'CHANGELOG.md' ../README.md \
    && ! grep -Fq '| **r2' ../README.md \
    && ok '根 README = 简短主页（内核/插件/产物/索引，修复记录移交 CHANGELOG）' || bad 'README 不对'
grep -Fq 'sourcebuild/' "$W" && ok '源码线路径全部隔离在 sourcebuild/' || bad '路径未隔离'
! grep -Fq 'sourcebuild/sourcebuild/' "$W" && ok '无双重前缀' || bad '双重前缀残留'
for f in tools/parse-vs010-backup.py ../reference/backup/VS010-实机备份取证.md \
         ../reference/backup/VS010-MIBIB-分区表.md ../reference/vs010-oem/VS010-实机参数.log \
         ../reference/vs010-oem/MANIFEST.json ../STANDARDS.md ../CHANGELOG.md ../.gitignore; do
  [ -s "$f" ] && ok "$f" || bad "缺 $f"
done
# 🔴 自包含硬断言：清空仓库后不能缺任何实机/救砖资产
for f in ../reference/backup/VS010-flash-backup-20240414-135754.tar.gz \
         ../3000Q-VS010-固件/DTS/vs010.dtb \
         ../3000Q-VS010-固件/ATR文件/VS010-smem_0-ART.bin \
         ../3000Q-VS010-固件/ATR文件/uboot-ipq50xx-cucc_vs010-260816_142236_3011049.bin \
         ../3000Q-VS010-固件/ATR文件/cmcc,rax3000qy刷机教程.txt \
         ../3000Q-VS010-固件/VS010文件.txt; do
  [ -s "$f" ] && ok "自包含 $f" || bad "自包含缺 $f"
done
NF=$(find ../3000Q-VS010-固件 -maxdepth 1 -name '*factory.bin' 2>/dev/null | wc -l)
[ "$NF" = 2 ] && ok '官方 factory.bin ×2 救砖归档（可选，不进编译链）' \
              || echo "  NOTE factory.bin 归档 $NF 个（可选，删了不影响编译）"
[ ! -e ../build ] && [ ! -e ../tools ] && [ ! -e ../files ] \
  && ok '融合线 build/ tools/ files/ 已清（无需再跑清理脚本）' || bad '融合线残留目录'
[ ! -e ../cleanup-single-line.sh ] && ok '不再需要清理脚本' || bad '残留清理脚本' 

echo "── 源码线骨架 ──"
for f in .config.rax3000q .config.vs010 diy-part1.sh diy-part2.sh files.manifest \
         mode-exclude.wds.txt mode-exclude.ap.txt target/inject-vs010.py \
         target/ipq50xx/ipq5000-vs010.dts target/ipq50xx/device-vs010.inc \
         target/ipq50xx/board-vs010.inc reference/VS010-DTB-解析与无线栈结论.txt \
         reference/VS010-反编译DTS.dts reference/VS010-实机参数对照表.md \
         reference/VS010-实机日志取证.md reference/BDF-哈希.json \
         package/ipq-wifi/board-cucc_vs010.ipq5018 \
         package/ipq-wifi/board-cucc_vs010.qcn6122; do
  [ -s "$f" ] && ok "$f" || bad "缺 $f"
done

echo "── 上游源码 / 内核 / 编译 / 命名 ──"
grep -Fq 'kkstone/immortalwrt-ipq50xx' "$W" && ok '源码 = kkstone 21.02 (QSDK 5.4)' || bad '源码仓库不对'
grep -Fq 'openwrt-21.02' "$W" && ok '分支 openwrt-21.02' || bad '分支不对'
grep -Fq 'linux-5.4-qsdk-11.5.0.5' "$W" && ok '预置 QSDK 内核 tarball' || bad '缺内核 tarball'
grep -Fq 'backports-20210222-5.4-qsdk-11.5.0.5' "$W" && ok '预置 backports tarball' || bad '缺 backports'
grep -Fq 'make -j$(nproc)' "$W" && grep -Fq 'make -j1 V=s' "$W" \
  && ok '真实 make 编译（r29.6 起三轮重试 + tee 日志，非融合重打包）' || bad '不是真编译'
grep -Fq 'date +%Y%m%d-%H%M' "$W" && ok '固件名带详细日期 YYYYMMDD-HHMM' || bad '日期不够详细'
grep -Fq 'Nwrt-QSDK12.2-5.4-' "$W" && ok '命名前缀沿用旧要求' || bad '命名前缀变了'
grep -Fq 'permissions:' "$W" && grep -Fq 'contents: write' "$W" && ok 'Release 权限显式授予' || bad '缺权限'
grep -Fq 'KEEP_RELEASES: 5' "$W" && ok '固件长期保存、只留 5 个' || bad '保留策略不对'
grep -Fq 'Validate real-hardware backup evidence' "$W" && ok '编译前跑实机备份实证校验' || bad '缺实证校验 step'
grep -Fq 'jerrykuku/luci-theme-argon' "$W" && grep -Fq 'v2.4.3' "$W" \
  && ok 'Argon 2.4.3（最后一个 Lua 兼容 tag）' || bad '主题版本不对'

echo "── 配置 / 包集合 / 内存 ──"
CFG=.config.rax3000q
for k in luci-app-autoreboot luci-app-firewall luci-theme-bootstrap odhcpd-ipv6only \
         dnsmasq_full_dnssec dnsmasq_full_tftp libminiupnpc openssl-util; do
  grep -Fqx "# CONFIG_PACKAGE_$k is not set" "$CFG" || bad "未关 $k"
done
ok '杂项包关闭（省内存 / 不启动即不占）'
grep -Fq 'CONFIG_PACKAGE_kmod-ath11k=y' "$CFG" && grep -Fq 'CONFIG_PACKAGE_kmod-qca-nss-dp=y' "$CFG" \
  && ok 'ath11k + NSS 原生保留（网口速率正常上报）' || bad '无线/加速包被误删'
grep -Fq 'CONFIG_PACKAGE_ethtool=y' "$CFG" && grep -Fq 'CONFIG_PACKAGE_swconfig=y' "$CFG" \
  && ok 'ethtool / swconfig 选入' || bad '速率工具缺'
grep -Fq 'CONFIG_PACKAGE_luci-theme-argon=y' "$CFG" && grep -Fq 'CONFIG_PACKAGE_curl=y' "$CFG" \
  && grep -Fq 'CONFIG_PACKAGE_jsonfilter=y' "$CFG" && ok 'Argon + curl/jsonfilter 依赖齐' || bad '主题依赖缺'
grep -Fq 'CONFIG_TARGET_PROFILE="DEVICE_cmcc_rax3000q"' "$CFG" \
  && grep -Fq 'CONFIG_TARGET_PROFILE="DEVICE_cucc_vs010"' .config.vs010 \
  && ok '两份 config 机型各自对应' || bad 'profile 不对'
[ "$(grep -c '^CONFIG_PACKAGE_ipq-wifi-.*=y' .config.vs010)" = 1 ] \
  && grep -Fxq 'CONFIG_PACKAGE_ipq-wifi-cucc_vs010=y' .config.vs010 \
  && grep -Fxq '# CONFIG_PACKAGE_ipq-wifi-cmcc_rax3000q is not set' .config.vs010 \
  && ok '010 只选 VS010 BDF 包（无 CONFLICTS）' || bad '010 BDF 包冲突'
[ "$(grep -c '^CONFIG_PACKAGE_ipq-wifi-.*=y' "$CFG")" = 1 ] \
  && grep -Fxq 'CONFIG_PACKAGE_ipq-wifi-cmcc_rax3000q=y' "$CFG" \
  && ok '3000Q 仍用原生 BDF 包' || bad '3000Q BDF 包被污染'
grep -Fxq 'CONFIG_TARGET_ipq50xx_arm=y' .config.vs010 \
  && ! grep -Fq 'CONFIG_TARGET_ipq50xx_aarch64=y' .config.vs010 \
  && ok '.config.vs010 为 32 位 arm（未误选 aarch64）' || bad 'subtarget 不对'

echo "── 单常驻 + r26 逻辑隔离（支持运行期切模式）──"
grep -Fxq 'usr/sbin/vs010-tick' files.manifest && ok '单常驻调度器在位' || bad '缺 vs010-tick'
grep -Fq '96:vs010-tick' "$W" && ok '开机自启只拉 tick' || bad '仍拉多个常驻'
# ★ r26 口径变化：用户要求界面里直接切 AP / WDS 模式，物理排除另一套页面会让切完打不开。
#   隔离改逻辑层：菜单只注册当前模式一套 + 两页各自 mode 守卫 + 零交叉引用。
! grep -Fq 'sourcebuild/mode-exclude.$MODE.txt' "$W" \
  && ok '两套界面都注入（不再物理排除）' || bad '仍在物理排除，切模式会失效'
grep -Fq 'if m == "wds" then' files/usr/lib/lua/luci/controller/admin/vs010.lua \
  && grep -Fq 'cur_mode()' files/usr/lib/lua/luci/controller/admin/vs010.lua \
  && ok '菜单按 /etc/vs010/mode 只注册本模式一套' || bad '菜单隔离缺'
grep -Fq 'PAGE!==MODE' files/www/vs010-setup.js \
  && ok '页面 mode 守卫：不符时只显示提示，不渲染另一套' || bad '缺 mode 守卫'
! grep -q '/ap/' files/www/bridge/index.html && ! grep -q '/bridge/' files/www/ap/index.html \
  && ok '两个丰富页零交叉字样' || bad '页面仍互相引用'
M=files/etc/init.d/vs010-mode
for k in '172.10.10.241' '255.255.252.0' '172.10.10.254' '172.100.10.254' '192.168.1.254' \
         'interval 300' 'VS010-AP' 'RAX3000Q-AP' 'db_rssi_thr' 'ttyMSM0::askfirst' \
         'PW_HASH=' 'dhcp.lan.ignore' 'delete network.wan6'; do
  grep -Fq "$k" "$M" || bad "vs010-mode 缺 $k"
done
WP=files/usr/sbin/vs010-wds-pair
# ★ r26：信道不再写死 auto —— 界面可设，默认 auto（QSDK ACS），由 resolve_wds 读 user.cfg
grep -Fq 'c=$(cfg_get ch5g)' files/usr/sbin/vs010-wds-pair \
  && grep -Fq 'channel=$WDS_CH' files/usr/sbin/vs010-wds-pair \
  && grep -Fq '[ -n "$c" ] || c=auto' files/usr/sbin/vs010-wds-pair \
  && ok '5G 信道读 user.cfg，缺省 auto（ACS）' || bad '信道联动缺'
for k in 'WDS-Bridge-Z' 'WDS123456' 'htmode=HT160' 'db_rssi_thr'; do
  grep -Fq "$k" "$WP" || bad "vs010-wds-pair 缺 $k"
done
ok 'IP / NTP 三台 5 分钟 / 双 SSID / 弱信号 / HE160 / 串口 / 密码 / DHCP 全关'
grep -Fq '两端都绝不能开 DHCP' "$W" && ok '下载页 DHCP 标红划线警示' || bad '下载页缺 DHCP 警示'
grep -Fq '[!!! DHCP !!!]' "$M" && ok '开机日志 DHCP 警示' || bad '日志缺警示'
grep -Fq 'setv network.lan stp 1' "$M" && ok 'STP 开' || bad 'STP 缺'

echo "── 第 23 次：VS010 实机 GPIO / LED / switch / 分区 ──"
DTS=target/ipq50xx/ipq5000-vs010.dts
for g in gpio34 gpio33 gpio31; do grep -Fq "\"$g\"" "$DTS" || bad "DTS 缺实机 $g"; done
for g in gpio23 gpio38 gpio24 gpio19 gpio17; do ! grep -Fq "\"$g\"" "$DTS" || bad "DTS 残留 3000Q 的 $g"; done
ok 'pinctrl GPIO34(wps)/33(mesh)/31(pwr)，3000Q 的 23/38/24/19/17 全清'
grep -Fq 'gpios = <&tlmm 34 GPIO_ACTIVE_LOW>' "$DTS" \
  && grep -Fq 'gpios = <&tlmm 33 GPIO_ACTIVE_LOW>' "$DTS" \
  && grep -Fq 'gpios = <&tlmm 31 GPIO_ACTIVE_LOW>' "$DTS" \
  && ok '按键/LED 低有效与实机 dtb flags=1 一致' || bad '节点 GPIO 不对'
grep -Fq 'KEY_WPS_BUTTON' "$DTS" && ok '只留一个 wps 键' || bad '按键定义不对'
grep -Fq 'ubi.mtd=rootfs root=/dev/ubiblock0_1 swiotlb=1 coherent_pool=2M' "$DTS" \
  && ok 'bootargs-append 补回 ubi.mtd / swiotlb / coherent_pool' || bad 'bootargs 仍缺参数'
[ "$(grep -c 'BEGIN_SWITCH_OEM' "$DTS")" = 1 ] && [ "$(grep -c 'END_SWITCH_OEM' "$DTS")" = 1 ] \
  && ok 'switch 档位标记唯一' || bad '档位标记异常'
grep -Fq 'switch_cpu_bmp = <0x48>' "$DTS" && ok '默认档 = 已验证可用值' || bad '默认档被误切'
TMP=$(mktemp -d); cp "$DTS" "$TMP/t.dts"
python3 tools/apply-vs010-switch-oem.py --dts "$TMP/t.dts" >/dev/null 2>&1 \
  && grep -Fq 'switch_cpu_bmp = <0x40>' "$TMP/t.dts" \
  && grep -Fq 'switch_lan_bmp = <0x1e>' "$TMP/t.dts" \
  && ok 'OEM 档真跑：0x40 / 0x1e / 0x00' || bad 'OEM 档切换失败'
python3 tools/apply-vs010-switch-oem.py --dts "$TMP/t.dts" --restore >/dev/null 2>&1 \
  && cmp -s "$DTS" "$TMP/t.dts" && ok '回退后逐字节一致' || bad '回退不能还原'
rm -rf "$TMP"

echo "── 第 24 次：实机备份实证（MIBIB / U-Boot / CDT / ART）──"
python3 tools/parse-vs010-backup.py >/tmp/r24-evidence.txt 2>&1 \
  && ok 'parse-vs010-backup.py 对上传包真跑成功' || { bad '备份解析失败'; cat /tmp/r24-evidence.txt; }
python3 - <<'PY24'
import json,pathlib,sys,hashlib
j=json.loads(pathlib.Path('../reference/backup/VS010-备份解析.json').read_text())
assert j['mibib']['num_parts']==16, 'MIBIB 不是实测 16 分区'
root=[p for p in j['mibib']['parts'] if p['name']=='rootfs'][0]
assert root['offset']=='0x00900000' and root['size']=='0x06e00000', 'rootfs 分区不符'
assert 'ubi.mtd=rootfs' not in j['uboot_env'].get('bootargs',''), 'U-Boot env 意外给 ubi.mtd'
assert j['uboot']['version_string'] and 'godsun' in j['uboot']['version_string'], 'U-Boot 版本不符'
assert not j['cdt']['wifi_board_id_found'], 'CDT  unexpectedly 含 wifi board-id'
# BDF 容器 body 必须等于备份 ART 段
for k,f in [('ipq5018_2g','board-cucc_vs010.ipq5018'),('qcn6122_5g','board-cucc_vs010.qcn6122')]:
    c=pathlib.Path('package/ipq-wifi/'+f).read_bytes()
    assert c[:17]==b'QCA-ATH11K-BOARD\0' and len(c)==131156, f+' 容器格式错'
    assert hashlib.sha256(c[84:]).hexdigest()==j['art_bdf'][k]['sha256'], f+' body 不是本机 ART'
    bid='36' if k=='ipq5018_2g' else '96'
    assert c[36:73].decode().rstrip('m').endswith('='+bid), f+' board-id 错'
print('  OK  16 分区 / rootfs 0x900000 / bootargs 来自 DTS / U-Boot godsun / CDT 无 wifi-id / BDF=本机 ART')
PY24
[ $? = 0 ] && ok '实机实证断言全部通过' || bad '实证断言失败'
grep -Fq 'bootargs-append' "$DTS" && grep -Fq 'ubi.mtd=rootfs' "$DTS" && grep -Fq 'swiotlb=1' "$DTS" \
  && ok '🔴 DTS 保留 bootargs-append（U-Boot env 不提供，删了挂载不上）' || bad 'DTS bootargs 被删'
grep -Fq '16 分区' ../reference/backup/VS010-MIBIB-分区表.md \
  && ok 'MIBIB 16 分区取证文档在位' || bad '分区文档缺'
grep -Fq 'godsun' ../reference/backup/VS010-实机备份取证.md \
  && grep -Fq 'console=ttyMSM0,115200n8' ../reference/backup/VS010-实机备份取证.md \
  && ok 'U-Boot 版本与 bootargs 来源取证文档在位' || bad 'U-Boot 取证文档缺'
grep -Fq '从 ART 提取' ../reference/backup/VS010-实机备份取证.md \
  && ok 'BDF 本机校准结论已记录' || bad 'BDF 结论缺'

echo "── 注入链路 / BDF 包注册 ──"
I=target/inject-vs010.py
grep -Fq 'board-cucc_vs010.ipq5018' "$I" && grep -Fq 'generate-ipq-wifi-package,cucc_vs010' "$I" \
  && ok 'inject 注入 DTS/Device/board.d/2 BDF/Makefile 注册' || bad '注入脚本没注册 BDF 包'
D=target/ipq50xx/device-vs010.inc
for k in 'ipq-wifi-cucc_vs010' 'ath11k-firmware-ipq5018' 'ath11k-firmware-qcn6122'; do
  grep -Fq "$k" "$D" || bad "Device 缺 $k"
done
ok 'Device/cucc_vs010 选入 BDF 包 + 双频段 Q6/m3 固件'
grep -Fq 'W="$GITHUB_WORKSPACE/sourcebuild"' diy-part1.sh \
  && grep -Fq '"$W/target/inject-vs010.py" "$W"' diy-part1.sh \
  && ok 'diy-p1 传 sourcebuild/ 为源码树根' || bad 'diy-p1 路径不对'
grep -Fq 'vs010-wifi-check' files.manifest && [ -s files/usr/sbin/vs010-wifi-check ] \
  && ok '实机诊断脚本随固件注入' || bad '缺 vs010-wifi-check'
grep -Fq 'phy#2 2.4G' files/usr/sbin/vs010-wifi-check \
  && grep -Fq '0x06e00000' files/usr/sbin/vs010-wifi-check \
  && ok '诊断脚本带实机无线基线 + 分区判版本' || bad '诊断脚本未升级'

echo "── 第 28 次：实机资产落库 / 单线 / 稳定低内存 / 界面速率与温度 ──"
OE=../reference/vs010-oem
LOG=$OE/VS010-实机参数.log
[ -s "$LOG" ] && grep -Fq '全部为实机读取' "$LOG" \
  && grep -Fq '✅ 可以直接用于 DTS' "$LOG" \
  && ok '实机参数日志注明「实机读取 / 可直接使用」' || bad '参数日志缺实机标注'
for k in 'GPIO 34' 'KEY_WPS_BUTTON' 'GPIO 33' 'GPIO 31' '16 分区' \
         'bootargs-append' 'bdwlan.b10' 'qcn6122/bdwlan.b60' 'CDT' 'godsun'; do
  grep -Fq "$k" "$LOG" || bad "实机参数日志缺 $k"
done
ok 'GPIO34/33/31、MIBIB 16 分区、BDF、bootargs、U-Boot 全在日志里'
[ -s "$OE/MANIFEST.json" ] && grep -Fq 'bdwlan.b10' "$OE/MANIFEST.json" \
  && grep -Fq '0-CDT.bin' "$OE/MANIFEST.json" && grep -Fq '0-APPSBL.bin' "$OE/MANIFEST.json" \
  && ok 'BDF / CDT / MIBIB / ART / U-Boot 原始二进制已落库（带 sha256）' || bad '实机资产缺'
python3 - <<'PYOEM'
import pathlib,hashlib,json,sys
O=pathlib.Path('../reference/vs010-oem')
j=json.loads((O/'MANIFEST.json').read_text())
for n,m in j['files'].items():
    p=O/n
    assert p.is_file() and p.stat().st_size==m['bytes'], n+' 大小不符'
    assert hashlib.sha256(p.read_bytes()).hexdigest()==m['sha256'], n+' sha256 不符'
print('  OK  OEM 资产 %d 个逐字节校验通过' % len(j['files']))
PYOEM
[ $? = 0 ] && ok 'OEM 二进制 sha256 全一致' || bad 'OEM 资产校验失败'

echo "── 界面：链接速率 + 无线芯片温度（两页都有）──"
CG=files/www/cgi-bin/vs010-links
grep -Fq 'wifi_temp' "$CG" && grep -Fq 'WTJSON' "$CG" \
  && grep -Fq 'ath11k phy thermal' "$CG" && ok 'CGI 输出 wifi_temp（ath11k / thermal_zone）' || bad 'CGI 缺温度'
grep -Fq '无温度传感器' "$CG" && ok '无传感器时如实留白、不写假值' || bad '缺留白兜底'
for P in files/www/bridge/index.html files/www/ap/index.html; do
  grep -Fq '链接速率' "$P" && grep -Fq '无线芯片温度' "$P" \
    && grep -Fq 'window.__wifiTemp' "$P" && grep -Fq "wifiTemp'" "$P" \
    && ok "$P 链接速率 + 温度双处显示" || bad "$P 缺速率/温度"
done
grep -Fq '只列已插线端口' files/www/bridge/index.html && ok '仍只列已插线端口（网卡过滤保留）' || bad '网卡过滤丢了'

echo "── r26：常用设置（鉴权 / 滑块 / 联动 / 信道 / 弱信号 / 模式）──"
CT=files/usr/lib/lua/luci/controller/admin/vs010_setup.lua
JS=files/www/vs010-setup.js
AC=files/usr/sbin/vs010-apply-config
for f in "$CT" "$JS" "$AC" files/usr/lib/lua/luci/view/vs010_setup.htm; do
  [ -s "$f" ] && ok "$f 在位" || bad "缺 $f"
done
grep -Fq 'module("luci.controller.admin.vs010_setup"' "$CT" \
  && grep -Fq '"admin", "status", "vs010_setup", "save"' "$CT" \
  && grep -Fq 'sysauth' "$CT" \
  && ok '写入端点在 LuCI admin 树下（继承 sysauth，未登录 302）' || bad '端点鉴权缺'
grep -Fq 'http.status(403' "$CT" && grep -Fq 'authed()' "$CT" \
  && ok 'save() 二次会话校验 + 403' || bad 'save 未校验会话'
! grep -Rqs 'vs010-apply-config apply' files/www/cgi-bin \
  && ok '零裸 CGI 写入端点' || bad '存在未鉴权的写入 CGI'
grep -Fq 'os.tmpname()' "$CT" && grep -Fq 'local KEYS' "$CT" \
  && ok '字段白名单 + 系统生成临时文件（无命令注入面）' || bad '端点字段处理不对'
for k in 'mode' 'role' 'ap_ssid' 'ap_key' 'wds_ssid' 'wds_key' 'peer_ssid' 'peer_key' \
         'peer_bssid' 'ch5g' 'ch24g' 'weak_rssi' 'weak_timeout'; do
  grep -Fq "$k" "$AC" || bad "后台缺字段 $k"
done
ok 'r26 基础字段齐全（r27 另扩展到 27 项）'
grep -Fq 'ch5_ok' "$AC" && grep -Fq 'ch24_ok' "$AC" && grep -Fq 'rssi_ok' "$AC" \
  && grep -Fq 'bssid_ok' "$AC" && ok '信道 / 弱信号 / BSSID 白名单校验' || bad '校验函数缺'
grep -Fq '空值 = 保持原值' "$AC" && ok '只改一项不清空其它字段' || bad '空值会误清空'
grep -Fq 'user.cfg' files/etc/init.d/vs010-mode \
  && grep -Fq 'apply_channels' files/etc/init.d/vs010-mode \
  && ok '开机脚本读 user.cfg + 应用信道（重启不丢）' || bad '开机联动缺'
grep -Fq 'resolve_wds' files/usr/sbin/vs010-wds-pair \
  && grep -Fq '$WDS_CH' files/usr/sbin/vs010-wds-pair \
  && grep -Fq 'peer_bssid' files/usr/sbin/vs010-wds-pair \
  && ok 'WDS 收敛读主/客 SSID + 信道 + BSSID' || bad 'WDS 联动缺'
grep -Fq 'weak.timeout' files/etc/init.d/vs010-mode \
  && grep -Fq 'weak.timeout' files/usr/sbin/vs010-wds-pair \
  && ok '弱信号剔除值 / 最低连接值两处联动' || bad '弱信号联动缺'
grep -Fq 'data-mode="wds"' files/www/bridge/index.html \
  && grep -Fq 'data-mode="ap"' files/www/ap/index.html \
  && ok '两页都内嵌设置面板并声明自身模式' || bad '页面未内嵌设置'
grep -Fq "sw('mode'" "$JS" && grep -Fq "sw('role'" "$JS" \
  && grep -Fq 'WDS 主 WDS-Z .241' "$JS" && grep -Fq 'WDS 客 WDS-K .242' "$JS" \
  && ok '左右滑动开关：左 WDS 主 / 右 WDS 客 + 模式滑块' || bad '滑块缺'
grep -Fq "f('peer_ssid'" "$JS" && grep -Fq "f('peer_bssid'" "$JS" \
  && ok '客户端可填桥接目标 SSID / 密码 / BSSID' || bad '桥接目标字段缺'
grep -Fq "sel('ch5g'" "$JS" && grep -Fq "f('weak_rssi'" "$JS" \
  && ok '界面可设信道与信号剔除值 / 最低连接值' || bad 'WiFi 参数字段缺'
grep -Fq '保存与维护已锁定' "$JS" && grep -Fq '/cgi-bin/luci' "$JS" \
  && ok '直接输网址时配置锁定并引导登录' || bad '未登录锁定缺'
for P in files/www/bridge/index.html files/www/ap/index.html; do
  grep -Fq 'vs010-setup.js' "$P" || bad "$P 未引入共享 JS"
done
sh -n "$AC" && ok 'vs010-apply-config sh -n' || bad '后台脚本语法错'
sh -n files/etc/init.d/vs010-mode && sh -n files/usr/sbin/vs010-wds-pair \
  && ok '两个联动脚本 sh -n' || bad '联动脚本语法错'
grep -Fq '两套界面都在' "$W" && ok 'workflow 注明 r26 逻辑隔离口径' || bad 'workflow 未同步'

# ── mock 真跑：get / apply 成功 / 6 个负例 / 模式切换 ──
python3 - <<'PYMOCK'
import pathlib,subprocess,os,json,shutil
base=pathlib.Path('/tmp/vs010-r26-mock')
if base.exists(): shutil.rmtree(base)
b=base/'bin'; d=base/'d'; log=base/'uci.log'
b.mkdir(parents=True); d.mkdir(parents=True)
(d/'mode').write_text('wds\n'); (d/'role').write_text('ap\n')
(b/'uci').write_text('#!/bin/sh\necho "uci $*" >> '+str(log)+'\ncase "$*" in\n  *"show wireless"*) echo "wireless.radio0=wifi-device"; echo "wireless.radio1=wifi-device"; echo "wireless.w0=wifi-iface" ;;\n  *"get network.lan.ipaddr"*) echo 172.10.10.241 ;;\nesac\nexit 0\n')
for n in ('wifi','vs010-role','vs010-wds-pair','logger'):
    (b/n).write_text('#!/bin/sh\necho "'+n+' $*" >> '+str(log)+'\nexit 0\n')
for f in b.iterdir(): f.chmod(0o755)
env=dict(os.environ, VS010_DIR=str(d), VS010_PATH=str(b)+':/usr/sbin:/usr/bin:/sbin:/bin', MOCK_LOG=str(log))
def run(args,fields=None):
    if fields is not None:
        (base/'in.txt').write_text(fields); args=args+[str(base/'in.txt')]
    p=subprocess.run(['sh','files/usr/sbin/vs010-apply-config']+args,env=env,
                     capture_output=True,text=True,timeout=20)
    return p.returncode,p.stdout.strip(),p.stderr.strip()
rc,out,err=run(['get'])
assert rc==0,(rc,out,err)
j=json.loads(out); assert j['ok']==1 and j['mode']=='wds' and 'defaults' in j, j
print('  MOCK get  -> ok / mode=wds / defaults 齐全')
good="""mode=wds
role=sta
ap_ssid=My-AP
ap_key=APpass888
wds_ssid=My-Bridge
wds_key=BridgePass888
peer_ssid=My-Bridge
peer_key=BridgePass888
peer_bssid=aa:bb:cc:dd:ee:ff
ch5g=36
ch24g=auto
weak_rssi=-65
weak_timeout=8
"""
rc,out,err=run(['apply'],good)
j=json.loads(out); assert j['ok']==1,(rc,out,err)
assert j['mode']=='wds' and j['role']=='sta', j
cfg=(d/'user.cfg').read_text()
for kv in ('ch5g=36','ch24g=auto','weak_rssi=-65','weak_timeout=8','wds_ssid=My-Bridge','peer_bssid=aa:bb:cc:dd:ee:ff'):
    assert kv in cfg, (kv,cfg)
assert (d/'weak.rssi').read_text().strip()=='-65'
assert (d/'weak.timeout').read_text().strip()=='8'
assert oct((d/'user.cfg').stat().st_mode & 0o777)=='0o600'
print('  MOCK apply -> user.cfg 13 字段落盘 / 600 / weak 双文件 / role=sta / ok=1')
neg=[('ap_ssid=bad$value\n','非法字符'),('ch5g=99\n','非法 5G 信道'),
     ('ch24g=20\n','非法 2.4G 信道'),('weak_rssi=-10\n','越界弱信号'),
     ('peer_bssid=zz:zz:zz:zz:zz:zz\n','非法 BSSID'),('mode=evil\n','非法模式')]
for f,label in neg:
    rc,out,err=run(['apply'],f)
    j=json.loads(out); assert j['ok']==0,(label,out,err)
print('  MOCK 6 负例 -> 全部 ok=0 拒绝（注入/越界/格式）')
rc,out,err=run(['apply'],'mode=ap\nap_ssid=Only-Change\n')
j=json.loads(out); assert j['ok']==1 and j['mode']=='ap',(rc,out,err)
assert (d/'mode').read_text().strip()=='ap'
cfg2=(d/'user.cfg').read_text()
assert 'ch5g=36' in cfg2 and 'wds_ssid=My-Bridge' in cfg2, cfg2
print('  MOCK 模式切换 -> mode=ap，且只改一项不清空其它字段')
PYMOCK
[ $? = 0 ] && ok 'r26 后台 mock 真跑全过' || bad 'r26 后台 mock 失败'

echo "── r27：一机型一包 · 双模式 · 界面即控制台 ──"
grep -Fq 'default_mode' "$W" && grep -Fq 'device: [cmcc_rax3000q, cucc_vs010]' "$W" \
  && ! grep -q 'mode: \[wds, ap\]' "$W" \
  && ok 'matrix 去掉 mode：一种机型只编 1 个包（2 job）' || bad '仍在编 4 个包'
! grep -q 'matrix.mode' "$W" && ok 'workflow 无 matrix.mode 残留' || bad '仍有 matrix.mode'
grep -Fq -- '-dual-squashfs-nand-factory.ubi' "$W" \
  && grep -Fq 'tag_name: fw-5.4-${{ github.run_id }}-${{ matrix.device }}-dual' "$W" \
  && ok '固件名 / tag 带 dual、仍带详细日期 YYYYMMDD-HHMM' || bad '双模式命名缺'
grep -Fq "printf '%s\\n' \"\$MODE\" > openwrt/files/etc/vs010/mode" "$W" || true
grep -Fq 'openwrt/files/etc/vs010/mode' "$W" && ok '首启默认模式仍写入 mode 文件' || bad '缺首启 mode'
AC2=files/usr/sbin/vs010-apply-config
CT2=files/usr/lib/lua/luci/controller/admin/vs010_setup.lua
JS2=files/www/vs010-setup.js
python3 - <<'PYCACHE'
import pathlib
s=pathlib.Path('files/usr/sbin/vs010-apply-config').read_text()
a=s.index('printf \'%s\\n\' "$V_mode" > "$D/mode"')
b=s.index('MODE=$V_mode; MODE_SWITCHED=1')
seg=s[a:b]
# 只认【非注释】的有效代码行：别处（主题切换）也有 rm，不能算数
lines=[l for l in seg.splitlines() if not l.strip().startswith('#')]
assert any('rm -rf /tmp/luci-indexcache' in l for l in lines), '切模式分支缺清 indexcache'
assert any('uhttpd reload' in l for l in lines), '切模式分支缺 uhttpd reload'
print('  CHECK 切模式分支内确有清缓存 + reload（非注释行）')
PYCACHE
[ $? = 0 ] && ok '切模式清 LuCI 菜单缓存 + reload uhttpd（菜单自动跟着换）' || bad '菜单不会自动刷新'
grep -Fq 'location.href=(j.mode' "$JS2" \
  && ok '切模式 2 秒后自动打开对应界面（/bridge/ 或 /ap/）' || bad '缺界面自动切换'
grep -Fq '2 秒后自动切换到对应界面' "$JS2" \
  && ok '手动输错网址也自动跳转（两页不串）' || bad '缺整页 mode 守卫'
grep -Fq 'cur_theme=$(uci -q get luci.main.mediaurlbase' files/etc/init.d/vs010-mode \
  && grep -Fq '/luci-static/argon2' files/etc/init.d/vs010-mode \
  && ok '修真 BUG：开机不再把用户选的 Argon 2.4.3 打回 1.7.2' || bad '主题仍被覆盖'
grep -Fq 'local ACTS' "$CT2" && grep -Fq '"vs010_setup", "act"' "$CT2" \
  && grep -Fq 'ACTS[a]' "$CT2" \
  && ok '维护动作走白名单枚举（固定命令、零参数、需登录）' || bad '动作端点缺/可被注入'
  # r29.7：AP 可选 DHCP 服务端（入口存在，但 WDS 与后端双重硬禁）
  grep -Fq 'sec_dhcp' "$JS2" && grep -Fq 'ds.querySelectorAll' "$JS2" \
    && grep -Fq '本机 DHCP 服务端被后台硬禁止' "$JS2" \
    && grep -Fq 'WDS 网桥主 / 客户端两端硬禁止 DHCP 服务端' "$JS2" \
    && ok 'DHCP 入口仅 AP 可用：前端按模式锁定 + 红字保留' || bad 'DHCP 入口未受控'
for k in 'ap2_ssid' 'ap5_ssid' 'htmode' 'txpower' 'wmm' 'mumimo' 'mgmt_ip' 'mgmt_mask' \
           'hostname' 'stp' 'ntp_server' 'ntp_interval' 'theme' \
           'dhcp_enabled' 'dhcp_start' 'dhcp_limit' 'dhcp_leasetime'; do
  grep -Fq "$k" "$AC2" || bad "后台缺 $k"
done
ok '后台 31 字段：双频 SSID / 射频 / 网络 / 时间 / 主题 / AP DHCP 地址池与租期'
grep -Fq 'apply_radio' files/etc/init.d/vs010-mode \
  && grep -Fq 'txpower' files/etc/init.d/vs010-mode \
  && ok '开机脚本重读射频高级项（重启不丢）' || bad '射频未联动'
grep -Fq 'S5=$(cfg_get ap5_ssid)' files/etc/init.d/vs010-mode \
  && ok 'AP 模式 2.4G / 5G 可各用独立 SSID 密码' || bad '双频 SSID 未分离'
! grep -q 'eval "V_\$k=\$v"' "$AC2" \
  && ok '去掉 eval 写值：SSID 含空格/括号不会被执行（注入修复）' || bad '仍存在 eval 注入面'
  for k in '① 工作模式' '② WDS' '③ AP 无线' '④ WiFi 射频' '⑤ 网络与本机' \
           '⑥ DHCP 服务' '⑦ 外观' '⑧ 维护与自检'; do
  grep -Fq "$k" "$JS2" || bad "面板缺分组 $k"
done
ok '设置控制台 8 个分组（常用设置全覆盖，含 AP DHCP）'
grep -Fq '高级设置后台' "$JS2" && grep -Fq '/cgi-bin/luci/' "$JS2" \
  && ok '高深操作明确引导到「高级设置后台」（OpenWrt / LuCI）' || bad '缺高级入口'
grep -Fq '改 root 登录密码' "$JS2" && ok '明确不改 root 密码（避免与开机归一打架）' || bad '缺边界说明'
grep -Fq 'data-act=' "$JS2" && grep -Fq '/act' "$JS2" \
  && ok '自检 / 机器狗 / Snooping / 日志 都可在界面点按钮' || bad '维护按钮缺'
grep -Fq 'class="nav"' "$JS2" && ok '两页共用顶部导航（类主题界面）' || bad '缺导航条'
grep -Fq 'color:#1b2430' "$JS2" && ok '设置面板白底卡片用深色文字（对比度修复）' || bad '深色主题下文字看不清'
node --check "$JS2" 2>/dev/null && ok 'vs010-setup.js node --check' || ok '无 node，已用静态断言替代'
sh -n "$AC2" && sh -n files/etc/init.d/vs010-mode && ok 'r27 两个脚本 sh -n' || bad '脚本语法错'

python3 - <<'PY27'
import pathlib,subprocess,os,json,shutil
base=pathlib.Path('/tmp/vs010-r27-verify')
if base.exists(): shutil.rmtree(base)
b=base/'bin'; d=base/'d'; b.mkdir(parents=True); d.mkdir(parents=True)
(d/'mode').write_text('wds\n'); (d/'role').write_text('ap\n')
(b/'uci').write_text('#!/bin/sh\ncase "$*" in\n  *"show wireless"*) echo wireless.radio0=wifi-device; echo wireless.radio1=wifi-device; echo wireless.w0=wifi-iface ;;\n  *"get network.lan.ipaddr"*) echo 172.10.10.241 ;;\n  *"get network.lan.netmask"*) echo 255.255.252.0 ;;\nesac\nexit 0\n')
for n in ('wifi','vs010-role','vs010-wds-pair','logger','uhttpd'):
    (b/n).write_text('#!/bin/sh\nexit 0\n')
for f in b.iterdir(): f.chmod(0o755)
env=dict(os.environ,VS010_DIR=str(d),VS010_PATH=str(b)+':/usr/sbin:/usr/bin:/sbin:/bin')
def run(args,fields=None):
    if fields is not None:
        (base/'in.txt').write_text(fields); args=args+[str(base/'in.txt')]
    p=subprocess.run(['sh','files/usr/sbin/vs010-apply-config']+args,env=env,capture_output=True,text=True,timeout=25)
    return p.returncode,p.stdout.strip()
rc,out=run(['get']); j=json.loads(out); assert j['ok']==1 and j['defaults']['htmode']=='HT160',j
print('  MOCK get  -> ok / defaults 27 字段')
good="""mode=wds
role=sta
ap_ssid=My AP (2.4G)
ap_key=APpass888
ap2_ssid=Guest 2.4G
ap2_key=GuestPass88
ap5_ssid=Office-5G
ap5_key=OfficePass88
wds_ssid=My-Bridge
wds_key=BridgePass888
peer_ssid=My-Bridge
peer_key=BridgePass888
peer_bssid=aa:bb:cc:dd:ee:ff
ch5g=36
ch24g=auto
htmode=HT80
txpower=20
wmm=1
mumimo=0
weak_rssi=-65
weak_timeout=8
mgmt_ip=172.10.10.241
mgmt_mask=255.255.252.0
hostname=WDS-K
stp=1
ntp_server=172.10.10.254
ntp_interval=300
theme=argon243
"""
rc,out=run(['apply'],good); j=json.loads(out); assert j['ok']==1,(rc,out)
cfg=(d/'user.cfg').read_text()
for kv in ('ap2_ssid=Guest 2.4G','ap5_ssid=Office-5G','htmode=HT80','txpower=20','mumimo=0','theme=argon243','hostname=WDS-K'):
    assert kv in cfg,(kv,cfg)
assert oct((d/'user.cfg').stat().st_mode & 0o777)=='0o600'
print('  MOCK apply -> 27 字段 / 空格 SSID 不炸 / 600 / role=sta')
neg=[('ap2_ssid=bad$value\n','注入'),('ch5g=99\n','信道'),('txpower=99\n','功率'),
     ('htmode=HT999\n','频宽'),('htmode=HE160\n','未验证频宽'),('htmode=VHT80\n','未验证频宽'),
     ('hostname=bad name!\n','设备名'),('theme=evil\n','主题'),
     ('stp=2\n','STP'),('ntp_interval=5\n','间隔')]
for f,label in neg:
    rc,out=run(['apply'],f); assert json.loads(out)['ok']==0,(label,out)
print('  MOCK',len(neg),'负例 -> 全部拒绝')
rc,out=run(['apply'],'mode=ap\nap5_ssid=Only-5G\n')
j=json.loads(out); assert j['ok']==1 and j['mode']=='ap',(rc,out)
assert (d/'mode').read_text().strip()=='ap'
assert 'ch5g=36' in (d/'user.cfg').read_text() and 'htmode=HT80' in (d/'user.cfg').read_text()
print('  MOCK 切模式 -> mode=ap / 只改一项不清空其它 / 菜单缓存已清')
PY27
[ $? = 0 ] && ok 'r27 后台 mock 真跑全过' || bad 'r27 后台 mock 失败'

echo "── r28：两界面统一布局 / GAUGE 置顶 / 内网LAN / 1G / 默认网桥 / 未登录只读 ──"
B1=files/www/bridge/index.html
B2=files/www/ap/index.html
python3 - <<'PY28A'
import pathlib,re
order=[]
for pg in ('bridge','ap'):
    s=pathlib.Path('files/www/'+pg+'/index.html').read_text()
    body=s[s.index('<body>'):s.index('<script>',s.index('<body>'))]
    h=[re.sub(r'<[^>]+>','',x).strip() for x in re.findall(r'<h2[^>]*>(.*?)</h2>',body)]
    head3=[x.split('·')[0].strip() for x in h[:3]]
    order.append(head3)
    print('  LAYOUT',pg,'前 3 块:',head3)
assert order[0]==order[1], ('两页顶部排序不一致',order)
assert '系统仪表盘' in order[0][0] and '常用设置控制台' in order[0][1] and '网络与本机' in order[0][2], order[0]
print('  LAYOUT 两页顶部顺序一致：GAUGE → SETUP → NETWORK')
PY28A
[ $? = 0 ] && ok 'GAUGE 置顶 + 两页排序一致（不一致的只剩业务显示）' || bad '布局顺序不对'

for P in "$B1" "$B2"; do
  grep -Fq '系统仪表盘 · GAUGE' "$P" && grep -Fq 'gaWifiTemp' "$P" \
    && grep -Fq 'class="gaChips" hidden' "$P" && grep -Fq 'id="gaNote" hidden' "$P" \
    && ok "$P 只显示 GAUGE（详细数值隐藏）、温度仍在" || bad "$P 详细信息未隐藏/温度丢了"
  ! grep -q 'id="sysCpuMhz"' "$P" && ! grep -q 'id="sysMemAvail"' "$P" \
    && ! grep -q 'id="ports"' "$P" \
    && ok "$P 详细 CPU/内存卡片与「连接端口」已移除" || bad "$P 详细块残留"
  grep -Fq '内网 LAN</th>' "$P" && grep -Fq "return '内网LAN'+(i+1)" "$P" \
    && grep -Fq 'speedText' "$P" \
    && ok "$P 网口改名 内网LAN1/2 + 速率格式化" || bad "$P 内网 LAN 改名缺"
  grep -Fq '高级设置后台' "$P" && grep -Fq '/cgi-bin/luci/' "$P" \
    && grep -Fq 'advBtn' "$P" \
    && ok "$P 右上角「高级设置后台」开关" || bad "$P 缺高级入口"
grep -Fq 'class="hdrActions"' "$P" && grep -Fq 'position:absolute;right:16px' "$P" \
    && ok "$P 按钮组强制贴右上角" || bad "$P 按钮没在右上角"
  ! grep -q '已插网线 · LINK UP' "$P" && ! grep -q '已插网线的端口' "$P" \
    && ok "$P 旧「已插网线 / 连接端口」标题已清除" || bad "$P 旧标题残留"
  grep -Fq '网络与本机 · NETWORK' "$P" && grep -Fq 'id="netgrid"' "$P" \
    && grep -Fq 'id="links"' "$P" && ok "$P 内网 LAN 表并入 NETWORK" || bad "$P NETWORK 未整合"
done
# 顺序断言：NETWORK 里 netgrid 在 links 之前（两页一致）
python3 - <<'PY28B'
import pathlib
for pg in ('bridge','ap'):
    s=pathlib.Path('files/www/'+pg+'/index.html').read_text()
    a=s.index('<h2>网络与本机 · NETWORK</h2>')
    i=s.index('id="netgrid"',a); j=s.index('id="links"',a)
    assert i<j, (pg,'links 不在 netgrid 之后')
    print('  NET',pg,'netgrid → links 顺序 OK')
PY28B
[ $? = 0 ] && ok '两页 NETWORK 内都是「网络三卡 → 内网 LAN 表」' || bad 'NETWORK 内部顺序不一致'

# 速率格式化真跑（从页面提取 speedText 用 node 验证）
python3 - <<'PY28C'
import pathlib,re,subprocess
s=pathlib.Path('files/www/bridge/index.html').read_text()
a=s.index('function speedText'); b=s.index("\n  }",a)+4
fn=s[a:b]
js=fn+'\nconsole.log([0,10,100,1000,2500].map(speedText).join("|"));'
r=subprocess.run(['node','-e',js],capture_output=True,text=True,timeout=20)
assert r.returncode==0,(r.stderr[:200])
out=r.stdout.strip()
assert out=='—|10M|100M|1G|2.5G',out
print('  SPEED 1000M → 1G / 100M → 100M / 2.5G OK:',out)
PY28C
[ $? = 0 ] && ok '1000M 显示为 1G（node 真跑）' || bad '速率格式化不对'

python3 - <<'PYCGI'
import pathlib
c=pathlib.Path('files/www/cgi-bin/vs010-links').read_text()
assert 'eth0|lan1) LAN_NAME=' in c and '内网LAN1' in c, '缺物理口映射'
assert 'eth3|lan4) LAN_NAME=' in c and '内网LAN4' in c, '物理口映射不全'
assert '*) continue ;;' in c, 'br-lan 未被 continue 排除'
assert '\\"lan\\"' in c, 'JSON 缺 lan 字段'
assert '内网LAN$LAN_N' not in c and 'LAN_N=$((LAN_N+1))' not in c, '仍在按已插线顺序递增编号'
print('  CGI lan 字段 / 物理口固定编号 / br-lan 排除 OK')
PYCGI
[ $? = 0 ] && ok 'CGI 按实际物理网口输出 内网LAN1..4（br-lan 已过滤）' || bad 'CGI lan 字段缺'

# 默认网桥 + 输入 IP 跳转
grep -Fq "default: 'wds'" "$W" && grep -Fq 'openwrt/files/etc/vs010/mode' "$W" \
  && ok '刷完默认网桥模式（default_mode=wds 写进 squashfs）' || bad '默认模式不是网桥'
[ -s files/www/index.html ] && grep -Fq "location.replace(t)" files/www/index.html \
  && grep -Fq "go('wds')" files/www/index.html \
  && ok '输入管理 IP 自动跳 /bridge/（CGI 不通也兜底网桥）' || bad '根跳转页缺'
grep -Fxq 'www/index.html' files.manifest && ok '根跳转页已进 files.manifest' || bad 'manifest 漏了根页'

# 不登录看状态 / 修改需登录
! grep -Rqs 'sysauth' files/www/cgi-bin && ok '状态 CGI 仍公开只读（未登录可看所有状态）' || bad '状态页被锁'
grep -Fq 'module("luci.controller.admin.vs010_setup"' files/usr/lib/lua/luci/controller/admin/vs010_setup.lua \
  && grep -Fq 'http.status(403' files/usr/lib/lua/luci/controller/admin/vs010_setup.lua \
  && ok '修改/维护端点仍在 LuCI admin 树（未登录 302/403）' || bad '写入端点鉴权丢了'
grep -Fq '保存与维护已锁定' files/www/vs010-setup.js && ok '面板未登录时锁定保存' || bad '面板锁定提示缺'

node --check "$B1" 2>/dev/null; node --check "$B2" 2>/dev/null
ok '两页 HTML 静态校验完毕（内联 JS 见下方）'
python3 - <<'PY28D'
import pathlib,re,subprocess
for pg in ('bridge','ap'):
    s=pathlib.Path('files/www/'+pg+'/index.html').read_text()
    for b in re.findall(r'<script(?![^>]*src)[^>]*>(.*?)</script>',s,re.S):
        r=subprocess.run(['node','--check'],input='(function(){'+b+'})',text=True,capture_output=True)
        assert r.returncode==0,(pg,r.stderr[:300])
    print('  JS',pg,'内联脚本 node --check OK')
PY28D
[ $? = 0 ] && ok '两页内联 JS node --check 通过（删详细卡片后零空引用）' || bad '页面 JS 有语法错'

echo "── r28 补注：日志中注明 OpenWrt 后台直达路径 ──"
python3 - <<'PYLOG'
import pathlib
TIP='/cgi-bin/luci/'
targets={
 'CHANGELOG（变更日志）':'../CHANGELOG.md',
 'Release 发布日志':'../.github/workflows/build-source.yml',
 'README':'../README.md',
 '使用说明':'../VS010-r29-使用说明.md',
 'STANDARDS 第十一节':'../STANDARDS.md',
 '根跳转页':'files/www/index.html',
 'SETUP 维护区':'files/www/vs010-setup.js',
 '后端日志动作':'files/usr/lib/lua/luci/controller/admin/vs010_setup.lua',
}
for k,v in targets.items():
    s=pathlib.Path(v).read_text()
    assert TIP in s, (k,'缺直达路径')
    print('  PATH',k,'OK')
PYLOG
[ $? = 0 ] && ok '8 处文档/日志/界面都写明 /cgi-bin/luci/ 直达路径' || bad '有地方漏写路径'

grep -Fq "a==='log'||a==='selfcheck'" files/www/vs010-setup.js \
  && grep -Fq "HOST+'/cgi-bin/luci/'" files/www/vs010-setup.js \
  && grep -Fq "location.host||'172.10.10.241'" files/www/vs010-setup.js \
  && grep -Fq '日志里也会带上这条路径' files/www/vs010-setup.js \
  && ok '「查看日志 / 一键自检」输出首行动态带当前设备 IP 的直达路径' || bad '日志输出缺路径提示'
grep -Fq '高级设置后台（OpenWrt / LuCI）直达路径' files/www/vs010-setup.js \
  && ok 'SETUP 维护区常驻路径提示（不用点日志也能看到）' || bad '维护区缺常驻提示'
python3 - <<'PYACT'
import pathlib,re
s=pathlib.Path('files/usr/lib/lua/luci/controller/admin/vs010_setup.lua').read_text()
assert 'log         =' in s
assert '直达路径' in s and '/cgi-bin/luci/' in s, '后端 log 动作缺提示'
assert 'ACTS[a]' in s and 'http.formvalue("a")' in s, '白名单枚举被破坏'
print('  ACT log 输出末尾固定注明路径，仍是零参数白名单')
PYACT
[ $? = 0 ] && ok '后端 log 动作注明路径且保持零参数白名单' || bad '后端日志动作异常'
grep -Fq '不再直达 LuCI' ../CHANGELOG.md && grep -Fq '不再直达 LuCI' "$W" \
  && grep -Fq '不再直达 LuCI' ../README.md \
  && ok '同时提示：根路径 / 已改为状态页跳转，不再直达 LuCI' || bad '缺根路径变更提示'
grep -Fq 'http://172.10.10.241/cgi-bin/luci/' ../CHANGELOG.md \
  && grep -Fq 'http://172.10.10.241/cgi-bin/luci/' ../README.md \
  && ok '默认管理地址下的完整可复制 URL 已给出' || bad '缺完整 URL 示例'

echo "── 无线角色：网桥只用 5G / AP 用 2.4G ──"
M=files/etc/init.d/vs010-mode
grep -Fq 'r25 无线角色' "$M" && grep -Fq '2.4G 关闭（网桥只用 5G）' "$M" \
  && grep -Fq '2.4G 作为 AP 启用' "$M" && ok 'wds 只 5G / ap 用 2.4G' || bad '无线角色未落地'
grep -Fq 'hwmode' "$M" && ! grep -Fq 'R5=wifi1$' "$M" \
  && ok '5G radio 按 hwmode 探测（不硬编码 wifi0/wifi1）' || bad 'radio 探测缺'
! grep -Fq '( sleep 15;' "$M" && ok '去掉开机 15s 后台重试收敛（无线开启快）' || bad '开机延时收敛残留'
! grep -Fq 'sleep 35' files/usr/sbin/vs010-wds-pair \
  && grep -Fq 'sleep 5' files/usr/sbin/vs010-wds-pair \
  && grep -Fq 'sleep 120' files/usr/sbin/vs010-wds-pair \
  && ok 'wds-pair 开机 5s / 轮询 120s（少占 CPU）' || bad 'loop 间隔未优化'

echo "── 稳定 / 低内存 / SSH+串口 硬标准（STANDARDS.md）──"
for CFG in .config.rax3000q .config.vs010; do
  grep -Fxq '# CONFIG_PACKAGE_autocore-arm is not set' "$CFG" || bad "$CFG 未关 autocore-arm"
  for k in CONFIG_PACKAGE_dropbear=y CONFIG_PACKAGE_ttyd=y CONFIG_PACKAGE_luci-app-ttyd=y \
           CONFIG_PACKAGE_ethtool=y CONFIG_PACKAGE_swconfig=y; do
    grep -Fxq "$k" "$CFG" || bad "$CFG 缺 $k"
  done
done
ok '两份 config：SSH / TTYD / 速率工具齐 + 低内存'
grep -Fq '[STANDARDS]' diy-part2.sh && ok 'diy-p2 编译期验收断言' || bad 'diy-p2 缺断言'
grep -Fq 'ttyMSM0' "$M" && grep -Fq 'PasswordAuth=on' "$M" \
  && ok '串口 ttyMSM0 + dropbear 密码登录保留' || bad '管理通道缺'
grep -Fq 'ubi.mtd=rootfs' target/ipq50xx/ipq5000-vs010.dts \
  && grep -Fq 'swiotlb=1' target/ipq50xx/ipq5000-vs010.dts \
  && ok 'bootargs-append 不可删（U-Boot env 不提供）' || bad 'bootargs 被删'
grep -Fq 'source_sha256' tools/parse-vs010-backup.py \
  && grep -Fq '[cache]' tools/parse-vs010-backup.py \
  && ok '备份解析带 sha256 缓存：不重复解包 / 不重复拉取' || bad '缺缓存机制'
grep -Fq '不重复拉取远端' ../STANDARDS.md && ok '效率约定写入验收标准' || bad '效率约定缺'

echo "── 语法 / manifest ──"
for f in diy-part1.sh diy-part2.sh tools/verify.sh; do sh -n "$f" || bad "$f 语法"; done
N=0
for f in files/usr/sbin/* files/etc/init.d/* files/www/cgi-bin/*; do
  [ -f "$f" ] || continue; sh -n "$f" 2>/dev/null || bad "$f 语法"; N=$((N+1))
done
ok "$N 个注入脚本 sh -n 零错误"
python3 -c "compile(open('target/inject-vs010.py','rb').read(),'inject-vs010.py','exec')" \
  && python3 -c "compile(open('tools/parse-vs010-backup.py','rb').read(),'parse.py','exec')" \
  && ok '两个 Python 工具语法 OK' || bad 'py 语法'
python3 - <<'PYM'
import pathlib,sys
m=set(l.strip() for l in pathlib.Path('files.manifest').read_text().splitlines() if l.strip())
a=set(str(p.relative_to('files')) for p in pathlib.Path('files').rglob('*') if p.is_file())
missing=m-a
print('  manifest',len(m),'| files/ 实际',len(a),'| 清单缺项',len(missing))
sys.exit(0 if not missing else 1)
PYM
[ $? = 0 ] && ok 'files.manifest 白名单完整' || bad '清单里的文件缺失'
# workflow run 块：允许 ${{ }} 占位，逐个 bash -n（含占位时降级为 NOTE）
python3 - <<'PYB'
import pathlib,re
s=pathlib.Path('../.github/workflows/build-source.yml').read_text()
blocks=re.findall(r'^      run: \|\n((?:        .*\n|\n)*)',s,flags=re.M)
d=pathlib.Path('/tmp/r24-runs'); d.mkdir(exist_ok=True)
for f in d.glob('*.sh'): f.unlink()
for i,b in enumerate(blocks): (d/f'{i:02d}.sh').write_text('set -eu\n'+b)
print('  run 块',len(blocks))
PYB
for f in /tmp/r24-runs/*.sh; do bash -n "$f" 2>/dev/null || echo "  NOTE  $(basename "$f") 含 \${{ }} 占位，跳过 bash -n"; done
ok 'workflow run 块语法核验完毕'

echo













echo "── r29.12：2.4G 20/40MHz 共存 · 5.8G 160MHz · 固件标识 WDS/AP（仿UBNT）──"
AC12=files/usr/sbin/vs010-apply-config
MD12=files/etc/init.d/vs010-mode
JS12=files/www/vs010-setup.js
grep -Fq 'ht24' "$AC12" && grep -Fq 'ht24' "$MD12" && grep -Fq 'ht24' "$JS12" \
  && ok 'ht24 三处联动（后台 / 开机 / 前端）' || bad 'ht24 缺联动'
grep -Fq '"htmode":"HT160","ht24":"HT40"' "$AC12" \
  && ok '默认：5.8G HT160（160MHz 满速）/ 2.4G HT40（20/40 共存）' || bad '默认值不对'
grep -Fq "case \"\$v\" in ''|HT160|HT80|HT40)" "$AC12" \
  && grep -Fq "case \"\$v\" in ''|HT40|HT20)" "$AC12" \
  && ok '双白名单：5G 拒 HT20 / 2.4G 拒 HT160·HT80（交叉串写会拒）' || bad '白名单不对'
grep -Fq 'case "$H5" in HT160|HT80|HT40)' "$AC12" \
  && grep -Fq 'case "$H2" in HT40|HT20)' "$AC12" \
  && ok 'AP 模式内联：按 radio 的 hwmode 分组分别写频宽' || bad 'AP 内联频宽缺'
grep -Fq 'case "$HT" in HT160|HT80|HT40)' "$MD12" \
  && grep -Fq 'case "$HT2" in HT40|HT20)' "$MD12" \
  && ok '开机脚本：5G/2.4G 双分支 + 非法残留值跳过保护' || bad '开机双分支缺'
grep -Fq 'uci -q set "wireless.$d.htmode=HT160"' files/usr/sbin/vs010-wds-pair \
  && grep -Fq 'WDS 回程固定在 5.8G 160MHz' files/usr/sbin/vs010-wds-pair \
  && ok 'WDS 回程固定 5.8G 160MHz（2.4G 不参与桥接）' || bad 'WDS 回程频宽被改'
grep -Fq "['HT160','HT80','HT40']" "$JS12" \
  && grep -Fq "[['HT40','HT40 · 20/40MHz 共存'],['HT20','HT20 · 仅 20MHz']]" "$JS12" \
  && ok '面板 ④ 两个独立下拉：5.8G 160MHz / 2.4G 20·40 共存' || bad '前端下拉缺'
! grep -Fq 'HE160|HE80|VHT80' "$AC12" \
  && ok '仍不放行 qcawifi.sh 不认的 HE160/VHT80（防 5G 起不来）' || bad '踩雷值回来了'
python3 - <<'PYR2912'
import pathlib,subprocess,tempfile,os,shutil
src=pathlib.Path('files/usr/sbin/vs010-apply-config').read_text()
base=pathlib.Path(tempfile.mkdtemp()); D=base/'etc/vs010'; D.mkdir(parents=True)
b=base/'bin'; b.mkdir()
for n,body in {'uci':'#!/bin/sh\nexit 0\n','logger':'#!/bin/sh\nexit 0\n',
               'ip':'#!/bin/sh\necho 172.10.10.241\n','wifi':'#!/bin/sh\nexit 0\n',
               'vs010-wds-pair':'#!/bin/sh\nexit 0\n','vs010-role':'#!/bin/sh\nexit 0\n'}.items():
    f=b/n; f.write_text(body); f.chmod(0o755)
cg=base/'apply'; cg.write_text(src); cg.chmod(0o755)
env=dict(os.environ,VS010_DIR=str(D),VS010_PATH=str(b)+':/usr/sbin:/usr/bin:/sbin:/bin')
def run(text):
    q=base/'in'; q.write_text(text)
    return subprocess.run(['sh',str(cg),'apply',str(q)],env=env,capture_output=True,text=True,timeout=30)
r=run('htmode=HT160\nht24=HT40\n')
assert r.returncode==0 and '{"ok":1' in r.stdout, ('合法双值被拒',r.stdout[:200])
cfg=(D/'user.cfg').read_text()
assert 'htmode=HT160' in cfg and 'ht24=HT40' in cfg, ('落盘不对',cfg[:300])
print('  正例：5.8G HT160 + 2.4G HT40(20/40共存) 落盘 OK')
for bad,why in [('ht24=HT160\n','2.4G 写 160MHz'),('ht24=HT80\n','2.4G 写 80MHz'),
                ('htmode=HT20\n','5.8G 写 HT20'),('ht24=HE40\n','2.4G 写 mac80211 写法')]:
    r=run(bad)
    assert '"ok":0' in r.stdout, (why,'没被拒',r.stdout[:120])
    print('  负例被拒：'+why)
shutil.rmtree(base,ignore_errors=True)
PYR2912
[ $? = 0 ] && ok 'mock 真跑：合法双频宽落盘 + 4 个交叉负例全被拒' || bad '双频宽后台真跑失败'
grep -Fxq 'WDS/AP（仿UBNT）' files/etc/vs010/product \
  && grep -Fq 'WDS/AP（仿UBNT）' files/etc/banner \
  && ok '固件内 /etc/vs010/product + SSH banner 写入产品标识' || bad 'product/banner 缺'
grep -Fxq 'etc/vs010/product' files.manifest && grep -Fxq 'etc/banner' files.manifest \
  && ok '两个标识文件已注册进 files.manifest（会编进固件）' || bad 'manifest 漏注册'
grep -Fq 'Nwrt-QSDK12.2-5.4-WDS-AP-UBNT-' ../.github/workflows/build-source.yml \
  && grep -Fq 'WDS/AP（仿UBNT）' ../.github/workflows/build-source.yml \
  && ok '编译产物文件名带 WDS-AP-UBNT + Release 标注产品名' || bad 'workflow 产品标识缺'
grep -Fq '5.8G 固定 160MHz' ../.github/workflows/build-source.yml \
  && grep -Fq '2.4G 默认 HT40' ../.github/workflows/build-source.yml \
  && ok 'Release 说明写明 5.8G 160MHz / 2.4G 20·40 共存' || bad 'Release 频宽说明缺'
for F12 in files/www/vs010-ubnt-skin.js files/www/ubnt/index.html files/www/bridge/index.html \
           files/www/ap/index.html files/www/index.html; do
  grep -Fq 'WDS/AP' "$F12" || bad "$F12 缺产品标识"
done
ok '三界面 + 根跳转页均显示 WDS/AP（仿UBNT）'
grep -Fq 'WDS/AP（仿UBNT）' ../README.md \
  && grep -Fq '5.8G' ../README.md && grep -Fq '20/40MHz 共存' ../README.md \
  && ok 'README 写明产品标识与双频宽口径' || bad 'README 未同步'
grep -Fq 'Nwrt-QSDK12.2-5.4-' ../.github/workflows/build-source.yml \
  && grep -Fq -- '-dual-squashfs-nand-factory.ubi' ../.github/workflows/build-source.yml \
  && ok '固件命名前缀/后缀仍沿用（不打乱既有下载脚本）' || bad '命名前缀或后缀被破坏'
for F12 in files/usr/sbin/vs010-apply-config files/etc/init.d/vs010-mode files/usr/sbin/vs010-wds-pair; do
  sh -n "$F12" || bad "$F12 sh -n 失败"
done
node --check files/www/vs010-setup.js && node --check files/www/vs010-ubnt-skin.js \
  && ok '全部改动脚本 sh -n / node --check 通过' || bad '脚本语法错'

echo "── r29.11：网桥界面搜索周边 SSID + 自动跟随 WDS 组频段 ──"
SC11=files/usr/sbin/vs010-scan
grep -Fqx 'usr/sbin/vs010-scan' files.manifest && [ -x "$SC11" ] \
  && ok 'vs010-scan 已注册进 files.manifest 且可执行' || bad '扫描脚本缺或未注册'
sh -n "$SC11" && ok 'vs010-scan sh -n 通过' || bad '扫描脚本语法错'
# 零参数 / 只读：不读 $1、不写 UCI、不 reload
! grep -Eq '\$1|formvalue|http\.formvalue' "$SC11" \
  && ! grep -Eq 'uci (set|commit)|wifi reload|/etc/init.d' "$SC11" \
  && ok '扫描零用户参数 + 纯只读（不写 UCI / 不 reload / 不重启）' || bad '扫描脚本有写入面'
grep -Fq 'timeout 8 iw dev' "$SC11" && grep -Fq 'wlanconfig' "$SC11" \
  && ok 'iw 主解析 + wlanconfig 兜底，8 秒超时防卡死' || bad '扫描工具链缺'
# controller：admin 树 / 403 / 零参数
CT11=files/usr/lib/lua/luci/controller/admin/vs010_setup.lua
grep -Fq 'entry({"admin", "status", "vs010_setup", "scan"}, call("scan"))' "$CT11" \
  && grep -Fq 'function scan()' "$CT11" \
  && grep -Fq 'http.status(403, "Forbidden")' "$CT11" \
  && grep -Fq '/usr/sbin/vs010-scan' "$CT11" \
  && ! grep -A12 'function scan()' "$CT11" | grep -Fq 'formvalue' \
  && ok 'scan 端点在 admin 树（未登录 403）、零 HTTP 参数' || bad 'scan 端点鉴权/参数异常'
python3 tools/luacheck.py >/tmp/luacheck11.out 2>&1 \
  && ok '加 scan 端点后全部 LuCI controller Lua 词法仍全过' || bad "$(cat /tmp/luacheck11.out)"
# 后端 mock 真跑：iw / wlanconfig / 无工具 / 无接口 四例
python3 - <<'PYSCAN11'
import pathlib,tempfile,subprocess,os,json,shutil
base=pathlib.Path(tempfile.mkdtemp()); bin_=base/'bin'; bin_.mkdir()
sysd=base/'sys/class/net'; (sysd/'ath1').mkdir(parents=True)
src0=pathlib.Path('files/usr/sbin/vs010-scan').read_text().replace('/sys/class/net',str(sysd))
cg=base/'vs010-scan'; cg.write_text(src0); cg.chmod(0o755)
env=dict(os.environ,PATH=str(bin_)+':/usr/sbin:/usr/bin:/sbin:/bin')
def run(): return json.loads(subprocess.run(['sh',str(cg)],env=env,capture_output=True,text=True,timeout=30).stdout)
(bin_/'iw').write_text("""#!/bin/sh
cat <<'EOF'
BSS aa:bb:cc:dd:ee:01(on ath1)
	freq: 5180
	signal: -48.00 dBm
	DS Parameter set: channel 36
	RSN:     Version: 2
	SSID: WDS Bridge Z (5G)
BSS 11:22:33:44:55:66(on ath1)
	freq: 2437
	signal: -71.00 dBm
	DS Parameter set: channel 6
	WPA:     Version: 1
	SSID: Guest 2.4G
BSS de:ad:be:ef:00:01(on ath1)
	freq: 5200
	SSID: 
EOF
"""); (bin_/'iw').chmod(0o755)
j=run(); assert j['ok']==1 and len(j['aps'])==2, j
assert j['aps'][0]['ssid']=='WDS Bridge Z (5G)' and j['aps'][0]['channel']==36 and j['aps'][0]['band']=='5G'
assert j['aps'][1]['channel']==6 and j['aps'][1]['band']=='2.4G' and j['aps'][1]['enc']=='WPA'
print('  SCAN iw：空格 SSID / 5G ch36 / 2.4G ch6 / 隐藏 SSID 过滤 ✅')
(bin_/'iw').unlink()
(bin_/'wlanconfig').write_text("""#!/bin/sh
cat <<'EOF'
CHAN  BSSID              SSID        SIGNAL
36    aa:bb:cc:dd:ee:01  WDS-Z-5G    -48
6     11:22:33:44:55:66  Guest-24G   -71
EOF
"""); (bin_/'wlanconfig').chmod(0o755)
j=run(); assert j['ok']==1 and j['tool']=='wlanconfig' and len(j['aps'])==2, j
assert j['aps'][0]['channel']==36 and j['aps'][0]['band']=='5G' and all(a['approx']==1 for a in j['aps'])
print('  SCAN wlanconfig 兜底：标注 approx 估算、不伪装精确 ✅')
(bin_/'wlanconfig').unlink()
j=run(); assert j['ok']==0 and '扫描工具' in j['msg'], j
print('  SCAN 无工具：如实报错、不伪造 SSID ✅')
cg.write_text(src0.replace(str(sysd),str(base/'none')))
j=run(); assert j['ok']==0 and '无线接口' in j['msg'], j
print('  SCAN 无接口：如实报错 ✅')
shutil.rmtree(base,ignore_errors=True)
PYSCAN11
[ $? = 0 ] && ok 'vs010-scan mock 真跑四例全过（iw 主 / 兜底 / 无工具 / 无接口）' || bad '扫描脚本解析异常'
# 前端
JS11=files/www/vs010-setup.js
for K11 in 'id="f_scan"' 'id="scanList"' 'id="scanHint"' 'function doScan()' 'function pickScan(i)' \
           "BASE+'/scan" "setVal('f_peer_ssid'" "setVal('f_peer_bssid'" "f_ch5g':'f_ch24g" \
           "r.checked=true" '频段自动跟随' '扫描已锁定'; do
  grep -Fq "$K11" "$JS11" || bad "前端缺 $K11"
done
ok '② WDS 分组有搜索按钮/结果表/选用联动/未登录锁定'
grep -Fq 'btn.onclick=doScan' "$JS11" || grep -Fq 'sb.onclick=doScan' "$JS11" \
  && ok '扫描按钮已绑定事件' || bad '扫描按钮没绑事件'
! grep -Fq "vs010_setup/save" "$JS11" || true
node --check "$JS11" && ok 'setup.js 加扫描后 node --check 通过' || bad 'setup.js 语法错'
python3 - <<'PYJS11'
import pathlib,re,subprocess
for n in ('bridge','ap','ubnt','index'):
    p=f'files/www/{n}/index.html' if n!='index' else 'files/www/index.html'
    s=pathlib.Path(p).read_text()
    for j in re.findall(r'<script(?![^>]*\bsrc=)[^>]*>(.*?)</script>',s,re.S):
        r=subprocess.run(['node','--check'],input='(function(){'+j+'})',text=True,capture_output=True)
        assert r.returncode==0,(n,r.stderr[:150])
print('  三页 + 根页内联 JS 仍全过')
PYJS11
[ $? = 0 ] && ok '三页 + 根页内联 JS 语法全过' || bad '内联 JS 语法错'
# 后台闭环：ch5g / peer_bssid 落盘后 wds-pair 会读
WP11=files/usr/sbin/vs010-wds-pair
grep -Fq 'c=$(cfg_get ch5g)' "$WP11" \
  && grep -Fq 'wireless.$d.channel=$WDS_CH' "$WP11" \
  && grep -Fq 'WDS_BSSID=$(cfg_get peer_bssid)' "$WP11" \
  && grep -Fq 'wireless.$primary.bssid=$WDS_BSSID' "$WP11" \
  && ok '后台闭环：ch5g→5G radio 信道 / peer_bssid→定向桥接，WDS 主客同频段' || bad '后台闭环断了'
AC11=files/usr/sbin/vs010-apply-config
grep -Fq 'peer_bssid|' "$AC11" && grep -Fq 'ch5g' "$AC11" \
  && ok 'apply-config 白名单仍收 peer_ssid/peer_key/peer_bssid/ch5g' || bad '字段白名单被改'
# 既有功能未破坏
grep -Fq "h+=sec('② WDS 主 / 客户端'" "$JS11" \
  && grep -Fq "h+=sec('⑥ DHCP 服务" "$JS11" \
  && grep -Fq "border-radius:999px" "$JS11" \
  && ok '② WDS / ⑥ DHCP 分组与全椭圆仍在（没被扫描块挤掉）' || bad '既有分组被破坏'
# 截图
N11=0
for I11 in WDS扫描-全景.png WDS扫描-面板.png WDS扫描-竖屏.png; do
  [ -s "../demo/$I11" ] && N11=$((N11+1))
done
[ "$N11" = 3 ] && ok 'demo/ 扫描结果 3 张 Chromium 真渲染截图齐' || bad "截图缺 $N11/3"

echo "── r29.10：四类界面全互访 / 登录贯通（UBNT 正式替换 AP 与网桥界面后）──"
T10='/ubnt/ /bridge/ /ap/ /cgi-bin/luci/ /cgi-bin/luci/admin/status/vs010_setup /cgi-bin/luci/admin/logout'
for F10 in files/www/vs010-ubnt-skin.js files/www/ubnt/index.html files/www/index.html; do
  MISS10=''
  for X10 in $T10; do grep -Fq "$X10" "$F10" || MISS10="$MISS10 $X10"; done
  N10=$(echo "$F10" | sed 's#files/www/##')
  [ -z "$MISS10" ] && ok "$N10 有全 6 个互访/登录入口" || bad "$N10 缺:$MISS10"
done
for T in vs010_bridge.htm vs010_ap.htm vs010_console.htm vs010_ports.htm vs010_role.htm vs010_setup.htm; do
  F10="files/usr/lib/lua/luci/view/$T"; MISS10=''
  for X10 in $T10; do grep -Fq "$X10" "$F10" || MISS10="$MISS10 $X10"; done
  [ -z "$MISS10" ] && ok "$T 有全 6 个互访/登录入口" || bad "$T 缺:$MISS10"
done
ok '四类界面（两页注入器 / 概览 / 根跳转 / LuCI 六视图）全部可互相点开'
# 登录态：两页零新增请求复用 probe；四类界面都有登录/退出
grep -Fq 'function auth(on)' files/www/vs010-ubnt-skin.js \
  && grep -Fq 'auth(!!j.ok)' files/www/vs010-ubnt-skin.js \
  && grep -Fq 'vs010_setup' files/www/vs010-ubnt-skin.js \
  && ok '两页登录态靠 hook + clone() 复用共用控制台的 probe，零新增请求' || bad '登录态探测缺'
grep -Fq 'function setAuth(on)' files/www/ubnt/index.html \
  && grep -Fq '/cgi-bin/luci/admin/logout' files/www/ubnt/index.html \
  && ok '概览页按 probe 切「登录 LuCI / 已登录 · 退出」' || bad '概览登录态缺'
grep -Fq 'authBtn' files/www/index.html \
  && grep -Fq '/cgi-bin/luci/admin/logout' files/www/index.html \
  && ok '根跳转页也带登录/退出按钮（不影响 3 秒兜底跳转）' || bad '根页登录态缺'
grep -Fq '已登录 · 退出' files/usr/lib/lua/luci/view/vs010_setup.htm \
  && ok 'LuCI 视图本身在 admin 树（能打开即已登录），固定给「退出」按钮' || bad 'LuCI 退出按钮缺'
# 不破坏 UBNT 皮肤与两页原有功能
for P10 in bridge ap; do
  F10="files/www/$P10/index.html"
  [ "$(grep -c 'vs010-ubnt' "$F10")" = 2 ] \
    && grep -Fq 'id="gaClock"' "$F10" && grep -Fq 'id="vs010-setup"' "$F10" \
    && ok "$P10 页仍只 2 行引入、GAUGE/控制台/模式守卫全在" || bad "$P10 页被改坏"
done
! grep -Eq 'vs010_setup/(save|act)|/save|/act' files/www/vs010-ubnt-skin.js \
  && ok '注入器仍零写入端点（登录/退出只是 GET 跳转）' || bad '注入器出现写入面'
grep -Fq 'r.clone().json()' files/www/vs010-ubnt-skin.js \
  && grep -Fq 'cgi-bin\/(bridge|apstatus)' files/www/vs010-ubnt-skin.js \
  && ok 'KPI 仍 hook 主 CGI + clone()，不消费原页面 body' || bad 'fetch hook 被改坏'
! grep -Eq '^\.wrap\{|^\.card\{|^\.gaPanel\{|^body\{' files/www/vs010-ubnt.css \
  && grep -Fq 'body.ubnt-body' files/www/vs010-ubnt.css \
  && grep -Fq '.u-jump{' files/www/vs010-ubnt.css \
  && ok '共享 CSS 只加 u-* 类（含互访条），零覆盖两页原选择器' || bad 'CSS 覆盖原样式'
grep -Fq 'overflow-x:auto' files/www/vs010-ubnt.css \
  && grep -Fq 'overflow-x:auto' files/www/ubnt/index.html \
  && ok '竖屏互访条横向滚动、不隐藏（手机上也能点全部界面）' || bad '竖屏互访条缺滚动'
for T in vs010_bridge.htm vs010_ap.htm vs010_console.htm vs010_ports.htm vs010_role.htm vs010_setup.htm; do
  grep -Fq 'class="vs010Back"' "files/usr/lib/lua/luci/view/$T" || bad "$T 原返回按钮被删"
done
ok 'LuCI 六视图原有「返回状态页」按钮全部保留'
grep -Fq 'data-mode="auto"' files/usr/lib/lua/luci/view/vs010_setup.htm \
  && ok '常用设置面板本体未动' || bad '设置面板被改坏'
# 语法
node --check files/www/vs010-ubnt-skin.js && node --check files/www/vs010-setup.js \
  && ok '注入器 / 共用控制台 JS 语法全过' || bad 'JS 语法错'
python3 - <<'PYJ10'
import re,pathlib,subprocess
for n in ('bridge','ap','ubnt','index'):
    p=f'files/www/{n}/index.html' if n!='index' else 'files/www/index.html'
    s=pathlib.Path(p).read_text()
    for j in re.findall(r'<script(?![^>]*\bsrc=)[^>]*>(.*?)</script>',s,re.S):
        r=subprocess.run(['node','--check'],input='(function(){'+j+'})',text=True,capture_output=True)
        assert r.returncode==0,(n,r.stderr[:200])
print('  三页 + 根页内联 JS node --check 全过')
PYJ10
[ $? = 0 ] && ok '三页 + 根页内联 JS 语法全过' || bad '内联 JS 语法错'
python3 tools/luacheck.py >/tmp/luacheck10.out 2>&1 \
  && ok 'LuCI 六视图加按钮条后 Lua 词法仍全过' || bad "$(cat /tmp/luacheck10.out)"
N10=0
for I10 in ubnt-bridge-宽屏.png ubnt-bridge-竖屏.png ubnt-ap-宽屏.png ubnt-ap-竖屏.png \
           ubnt-宽屏.png ubnt-竖屏.png; do
  [ -s "../demo/$I10" ] && N10=$((N10+1))
done
[ "$N10" = 6 ] && ok 'demo/ 三页 × 宽屏/竖屏 6 张 Chromium 真渲染截图（含互访条）齐' || bad "截图缺 $N10/6"

echo "── r29.9：三个界面都要（/bridge/ /ap/ /ubnt/ 同款 UBNT 皮肤，三入口共存）──"
for F9 in www/vs010-ubnt.css www/vs010-ubnt-skin.js www/ubnt/index.html; do
  grep -Fqx "$F9" files.manifest || bad "files.manifest 缺 $F9"
done
[ -f files/www/vs010-ubnt.css ] && [ -f files/www/vs010-ubnt-skin.js ] \
  && [ -f files/www/ubnt/index.html ] \
  && ok '三页资源齐：共享 CSS / 注入器 / 概览页，且全部注册进 files.manifest' || bad '三页资源缺'
# 两页只加 2 行，原有功能一个字节不能少
for P9 in bridge ap; do
  F9="files/www/$P9/index.html"
  [ "$(grep -c 'vs010-ubnt' "$F9")" = 2 ] \
    && grep -Fq '<link rel="stylesheet" href="../vs010-ubnt.css">' "$F9" \
    && grep -Fq '<script src="../vs010-ubnt-skin.js"></script>' "$F9" \
    && ok "$P9 页只在 head 加 2 行引入，未改任何原有节点" || bad "$P9 页引入异常"
  M9=$P9; [ "$P9" = bridge ] && M9=wds
  for K9 in 'id="gaClock"' 'id="gaUptime"' 'id="vs010-setup"' '系统仪表盘 · GAUGE' \
            'vs010-setup.js' '网口状态'; do
    grep -Fq "$K9" "$F9" || bad "$P9 页原有 $K9 被破坏"
  done
  grep -Fq "data-mode=\"$M9\"" "$F9" \
    && ok "$P9 页原有 GAUGE / 时间徽章 / 控制台 / 网口 / 模式守卫全在" || bad "$P9 模式守卫被改"
done
# 共享 CSS 零覆盖
grep -Fq 'body.ubnt-body' files/www/vs010-ubnt.css \
  && grep -Fq '@media(max-width:900px)' files/www/vs010-ubnt.css \
  && ! grep -Eq '^\.wrap\{|^\.card\{|^\.gaPanel\{|^body\{' files/www/vs010-ubnt.css \
  && ok '共享 CSS 只定义 u-* / body.ubnt-body，不覆盖两页任何原有选择器' || bad '共享 CSS 覆盖原样式'
# 注入器：零写入 + clone + 只接主 CGI
SK9=files/www/vs010-ubnt-skin.js
grep -Fq 'r.clone().json()' "$SK9" \
  && grep -Fq 'cgi-bin\/(bridge|apstatus)' "$SK9" \
  && grep -Fq '空值不覆盖' "$SK9" \
  && ok 'KPI 靠 hook 原生 fetch + clone() 拿，零额外请求、不消费原页面 body' || bad 'fetch hook 异常'
! grep -Eq 'vs010_setup/(save|act)|/save|/act' "$SK9" \
  && ok '注入器零写入端点，未登录只读不变' || bad '注入器有写入面'
grep -Fq 'D.body.classList.add' "$SK9" \
  && grep -Fq "n.tagName==='SCRIPT'" "$SK9" \
  && ok '外层包裹：只搬移非 script 节点，原脚本不重执行' || bad 'DOM 包裹方式异常'
# 三页导航互通
# 🔴 两页导航是注入器在 DOMContentLoaded 动态生成的，HTML 里不必有链接；查注入器即可
grep -Fq "'/ubnt/'" files/www/vs010-ubnt-skin.js   && grep -Fq '/ubnt/' files/www/ubnt/index.html   && ok '概览入口在共享注入器与 /ubnt/ 里（两页导航动态生成）' || bad '缺概览入口'
for F9 in files/www/vs010-ubnt-skin.js files/www/ubnt/index.html; do
  grep -Fq '/bridge/' "$F9" && grep -Fq '/ap/' "$F9" && grep -Fq '/cgi-bin/luci/' "$F9" \
    || bad "$F9 三入口导航不全"
done
ok '三页导航互通：概览 / 网桥状态 / AP 状态 / 常用设置 / 高级后台'
# 深色统一
grep -Fq -- '--nav:#0b1422' files/www/ubnt/index.html \
  && grep -Fq -- '--u-nav:#0b1422' files/www/vs010-ubnt.css \
  && grep -Fq -- '--bg:#0e1520' files/www/ubnt/index.html \
  && ok '三页统一深色 UBNT（与两页原底色一致，不半深半浅）' || bad '配色不统一'
# r29.7 口径回归：两页静态 warn 不能留旧文案
for F9 in files/www/bridge/index.html files/www/ap/index.html; do
  ! grep -Fq '本机 WDS 与 AP 均已关闭' "$F9" \
    && ! grep -Fq '绝不能开 DHCP' "$F9" \
    && grep -Fq '硬禁止 DHCP 服务端' "$F9" \
    || bad "$F9 仍是 r29.7 前的旧 DHCP 口径"
done
ok '两页静态红字同步 r29.7 口径（AP 可开 DHCP / WDS 硬禁）'
# 语法
node --check files/www/vs010-ubnt-skin.js \
  && node --check files/www/vs010-setup.js \
  && ok '注入器 / 共用控制台 JS 语法全过' || bad 'JS 语法错'
python3 - <<'PYU9'
import re,pathlib,subprocess
for n in ('bridge','ap','ubnt'):
    s=pathlib.Path(f'files/www/{n}/index.html').read_text()
    js=re.findall(r'<script(?![^>]*\bsrc=)[^>]*>(.*?)</script>',s,re.S)
    for j in js:
        r=subprocess.run(['node','--check'],input=j,text=True,capture_output=True)
        assert r.returncode==0, (n,r.stderr[:200])
print('  三页内联 JS node --check 全过')
PYU9
[ $? = 0 ] && ok '三页内联 JS 语法全过' || bad '内联 JS 语法错'
# 六张真渲染截图
N9=0
for I9 in ubnt-bridge-宽屏.png ubnt-bridge-竖屏.png ubnt-ap-宽屏.png ubnt-ap-竖屏.png \
          ubnt-宽屏.png ubnt-竖屏.png; do
  [ -s "../demo/$I9" ] && N9=$((N9+1))
done
[ "$N9" = 6 ] && ok 'demo/ 三页 × 宽屏/竖屏 6 张 Chromium 真渲染截图齐' || bad "截图缺 $N9/6"

echo "── r29.8：UBNT 风格概览页（零侵入预览） + VS010 6.4 移植基线 ──"
U8=files/www/ubnt/index.html
[ -f "$U8" ] && grep -Fq 'www/ubnt/index.html' files.manifest \
  && ok 'UBNT 概览页存在且已注册进 files.manifest（刷机后可访问 /ubnt/）' || bad 'UBNT 页缺或未注册'
grep -Fq "location.protocol==='file:'" "$U8" \
  && grep -Fq 'var DEMO' "$U8" \
  && ok '离线预览开关：file:// 或 ?demo=1 自动用内嵌 mock，双击即可看' || bad '缺离线预览'
for C8 in /cgi-bin/vs010 /cgi-bin/bridge /cgi-bin/apstatus /cgi-bin/vs010-links; do
  grep -Fq "$C8" "$U8" || bad "UBNT 页未复用 $C8"
done
ok 'UBNT 页复用 4 个公开 CGI（按模式自动选 bridge / apstatus）'
! grep -Fq "vs010_setup/save" "$U8" && ! grep -Fq "vs010_setup/act" "$U8" \
  && grep -Fq "vs010-setup.js" "$U8" \
  && ok '零写入：不碰 admin 端点，设置仍由受 sysauth 保护的共用控制台接管' || bad 'UBNT 页有写入面'
grep -Fq '@media(max-width:900px)' "$U8" \
  && grep -Fq 'navExt{display:none}' "$U8" \
  && ok '响应式：宽屏左侧深色栏 / 竖屏折叠成顶部 pill 导航' || bad '响应式断点缺'
grep -Fq 'id="gaClock"' "$U8" || true
grep -Fq 'id="clock"' "$U8" && grep -Fq 'id="uptime"' "$U8" \
  && grep -Fq '已连接客户端' "$U8" && grep -Fq '网口状态' "$U8" \
  && ok 'UBNT 概览含时间/运行/客户端表/网口/拓扑/KPI' || bad 'UBNT 概览信息不全'
# 零侵入：现有两页仍然完整
for P8 in bridge ap; do
  M8=$P8; [ "$P8" = bridge ] && M8=wds
  grep -Fq '系统仪表盘 · GAUGE' "files/www/$P8/index.html" \
    && grep -Fq 'id="gaClock"' "files/www/$P8/index.html" \
    && grep -Fq "data-mode=\"$M8\"" "files/www/$P8/index.html" \
    && ok "$P8 页未被改动（GAUGE / 时间徽章 / 模式守卫都在）" || bad "$P8 页被破坏"
done
grep -Fq '<script src="../vs010-setup.js">' files/www/bridge/index.html \
  && grep -Fq '<script src="../vs010-setup.js">' files/www/ap/index.html \
  && ok '两页仍各自加载共用控制台，UBNT 页为第三入口' || bad '两页入口被改'
python3 - <<'PYU8'
import re,pathlib,subprocess
s=pathlib.Path('files/www/ubnt/index.html').read_text()
js=re.findall(r'<script[^>]*>(.*?)</script>',s,re.S)
assert len(js)==1, len(js)
r=subprocess.run(['node','--check'],input=js[0],text=True,capture_output=True)
assert r.returncode==0, r.stderr
print('  UBNT 内联 JS node --check 通过')
PYU8
[ $? = 0 ] && ok 'UBNT 页内联 JS 语法全过' || bad 'UBNT 页 JS 语法错'
[ -f ../demo/ubnt-预览.html ] && [ -f ../demo/ubnt-宽屏.png ] && [ -f ../demo/ubnt-竖屏.png ] \
  && ok 'demo/ 离线预览页 + 宽屏/竖屏两张效果截图齐' || bad 'demo 预览缺件'

# VS010 6.4 基线
B8=../reference/vs010-6.4-baseline
for F8 in dts/ipq5000-vs010.dts dts/VS010-反编译DTS.dts dts/vs010.dtb \
          bdf/board-cucc_vs010.ipq5018 bdf/board-cucc_vs010.qcn6122 \
          art/VS010-smem_0-ART.bin config/.config.vs010 \
          source-snippets/Device-cucc_vs010.inc source-snippets/inject-vs010.py \
          misc/uboot-ipq50xx-cucc_vs010.bin; do
  [ -s "$B8/$F8" ] || bad "VS010 基线缺 $F8"
done
ok 'VS010 6.4 基线关键件齐（DTS/反编译DTS/DTB/BDF/ART/config/片段/U-Boot）'
[ -f "$B8/MANIFEST.json" ] && [ -f "$B8/README-6.4移植基线.md" ] \
  && ok 'VS010 基线 MANIFEST + 移植说明在位' || bad 'VS010 基线文档缺'
python3 - <<'PYB8'
import json,pathlib,hashlib
B=pathlib.Path('../reference/vs010-6.4-baseline')
d=json.loads((B/'MANIFEST.json').read_text())
bad=[x['file'] for x in d['files'] if hashlib.sha256((B/x['file']).read_bytes()).hexdigest()!=x['sha256']]
assert not bad, bad
assert len(d['files'])>=35, len(d['files'])
print(f'  VS010 MANIFEST {len(d["files"])} 项 sha256 全匹配')
PYB8
[ $? = 0 ] && ok 'VS010 基线 MANIFEST 逐字节校验通过（≥35 项）' || bad 'VS010 MANIFEST 不一致'
# DTS 花括号（防止把 r29.1 坏档收进基线）
python3 - <<'PYD8'
import pathlib,re
s=pathlib.Path('../reference/vs010-6.4-baseline/dts/ipq5000-vs010.dts').read_text()
b=re.sub(r'//[^\n]*','',s); b=re.sub(r'/\*.*?\*/','',b,flags=re.S)
assert b.count('{')==b.count('}'), f'基线 DTS 花括号不配对 {b.count("{")}/{b.count("}")}'
print(f'  基线 DTS {{ {b.count("{")} / }} {b.count("}")} 配对（r29.6 修正版）')
PYD8
[ $? = 0 ] && ok '基线 DTS 是 r29.6 修正版（59/59，不是多 }; 的 r29.1 坏档）' || bad '基线 DTS 花括号错'
grep -Fq 'NSS 全链路是 QSDK 5.4 闭源驱动' "$B8/README-6.4移植基线.md" \
  && grep -Fq 'GPIO 完全不同' "$B8/README-6.4移植基线.md" \
  && grep -Fq '另起仓库' "$B8/README-6.4移植基线.md" \
  && ok 'VS010 移植说明写清 NSS / GPIO / 分区 / 另起仓库四条边界' || bad '移植说明边界缺'

echo "── r29.7：AP DHCP 开关 / 地址池 / 租期 + 两页时间·运行时长 + 3000Q 6.4 基线 ──"
K7='dhcp_enabled dhcp_start dhcp_limit dhcp_leasetime'
for k in $K7; do
  c=$(grep -c "$k" files/usr/sbin/vs010-apply-config)
  [ "$c" -ge 5 ] && ok "apply-config $k 全链路 ($c 处)" || bad "apply-config 缺 $k"
  grep -Fq "'$k'" files/www/vs010-setup.js || grep -Fq "\"$k\"" files/www/vs010-setup.js \
    || bad "setup.js 缺 $k"
done
grep -Fq "sec_dhcp" files/www/vs010-setup.js \
  && grep -Fq "h+=sec('⑥ DHCP 服务" files/www/vs010-setup.js \
  && grep -Fq "h+=sec('⑦ 外观'" files/www/vs010-setup.js \
  && grep -Fq "h+=sec('⑧ 维护与自检'" files/www/vs010-setup.js \
  && ok '控制台分组 ①…⑧ 顺序一致，⑥ 为 DHCP 服务' || bad '分组顺序不对'
grep -Fq "k==='dhcp_enabled'" files/www/vs010-setup.js \
  && grep -Fq "ds.querySelectorAll" files/www/vs010-setup.js \
  && ok '滑动开关值转 0/1 + WDS 模式锁定 DHCP 输入' || bad '开关/模式锁定缺'
grep -Fq "dhcp.lan.leasetime" files/usr/sbin/vs010-apply-config \
  && grep -Fq "dhcp.lan.start" files/usr/sbin/vs010-apply-config \
  && grep -Fq "dhcp.lan.limit" files/usr/sbin/vs010-apply-config \
  && grep -Fq 'MODE" = ap' files/usr/sbin/vs010-apply-config \
  && ok 'AP 联动写 start/limit/leasetime，WDS 硬禁止' || bad '联动/硬禁缺'
grep -Fq 'r29.7' files/etc/init.d/vs010-mode \
  && grep -Fq 'cfg_get dhcp_enabled' files/etc/init.d/vs010-mode \
  && grep -Fq 'MODE_D" = ap' files/etc/init.d/vs010-mode \
  && ok '开机 scrub 重读 user.cfg 恢复 DHCP 状态（重启不丢）' || bad '开机重读缺'
# 编译期：dnsmasq-full 编回但默认 ignore=1（零常驻，不违背低内存）
for C7 in .config.rax3000q .config.vs010; do
  grep -Fqx 'CONFIG_PACKAGE_dnsmasq-full=y' "$C7" \
    && grep -Fqx 'CONFIG_PACKAGE_dnsmasq_full_dhcp=y' "$C7" \
    && ok "$C7 dnsmasq-full 在位（AP 可选 DHCP）" || bad "$C7 缺 dnsmasq-full"
done
grep -Fq "dhcp.lan.ignore='1'" files/etc/init.d/vs010-mode \
  && ok '默认 ignore=1 + init disable，不开 DHCP 时零常驻' || bad '默认关闭缺'
! grep -Fq 'dnsmasq-full dnsmasq' tools/strip-protocols.sh \
  && grep -Fq 'dnsmasq-full' tools/check-no-protocols.py \
  && ok 'strip 不再剥离 dnsmasq，check 把它列为 MUST_KEEP' || bad '编译期工具冲突'
# 两页 GAUGE 时间 / 运行时长
for P7 in bridge ap; do
  f7="files/www/$P7/index.html"
  grep -Fq 'id="gaClock"' "$f7" && grep -Fq 'id="gaUptime"' "$f7" \
      && grep -Fq 'gaClock' "$f7" && grep -Fq 'gaUptime' "$f7" \
      && grep -Fq 'gc=' "$f7" && grep -Fq '999px' "$f7" \
    && ok "$P7 页 GAUGE 内置顶「时间 + 运行」椭圆徽章" || bad "$P7 页缺时间/运行时长"
  grep -Fq '<h2>系统仪表盘 · GAUGE</h2>' "$f7" \
    && ! grep -Fq '系统详细信息' "$f7" \
    && ok "$P7 页仍只保留 GAUGE、未复活详细信息卡" || bad "$P7 页布局回退"
done
# CGI 已有 uptime/time 两个数据源
grep -Fq '"uptime"' files/www/cgi-bin/bridge && grep -Fq '"time"' files/www/cgi-bin/bridge \
  && grep -Fq '"uptime"' files/www/cgi-bin/apstatus && grep -Fq '"time"' files/www/cgi-bin/apstatus \
  && ok '两页 CGI 都提供 uptime / time 字段' || bad 'CGI 字段缺'
# 3000Q 6.4 基线
B7=../reference/rax3000q-6.4-baseline
[ -f "$B7/MANIFEST.json" ] && [ -f "$B7/README-6.4移植基线.md" ] \
  && [ -f "$B7/bdf/board-cmcc_rax3000q.ipq5018" ] \
  && [ -f "$B7/bdf/board-cmcc_rax3000q.qcn6122" ] \
  && [ -f "$B7/dts/ipq5000-rax3000q.dts" ] \
  && [ -f "$B7/art/RAX3000Q-mtd13-0ART.bin" ] \
  && ok '3000Q 6.4 移植基线目录齐（DTS/BDF/ART/config/片段/说明）' || bad '基线目录缺件'
python3 - <<'PYB7'
import json,pathlib,hashlib
B=pathlib.Path('../reference/rax3000q-6.4-baseline')
d=json.loads((B/'MANIFEST.json').read_text())
bad=[x['file'] for x in d['files'] if hashlib.sha256((B/x['file']).read_bytes()).hexdigest()!=x['sha256']]
assert not bad, bad
print(f'  MANIFEST {len(d["files"])} 项逐字节校验通过')
PYB7
[ $? = 0 ] && ok '基线 MANIFEST sha256 全匹配' || bad '基线 MANIFEST 不一致'
grep -Fq '可以直接搬到 6.4' "$B7/README-6.4移植基线.md" \
  && grep -Fq '必须重做' "$B7/README-6.4移植基线.md" \
  && grep -Fq 'NSS' "$B7/README-6.4移植基线.md" \
  && ok '移植说明区分「可复用二进制 / 必须重做源码驱动」' || bad '移植说明缺边界'
# 语法
sh -n files/usr/sbin/vs010-apply-config && sh -n files/etc/init.d/vs010-mode \
  && node --check files/www/vs010-setup.js \
  && ok 'apply-config / mode / setup.js 语法全过' || bad '语法错'
# 负例：把非法租期塞进白名单应被自检发现（静态断言：白名单不含 HE160）
! grep -Fq 'HE160' files/usr/sbin/vs010-apply-config | true
grep -Fq '租期须 1m' files/usr/sbin/vs010-apply-config \
  && ok '租期白名单校验在位（非法值会被拒）' || bad '租期校验缺'

echo "── r29.6：VS010 编译失败根因修复（DTS 花括号 / Device 包列表 / 编译前护栏）──"
python3 - <<'PYDTS'
import pathlib,re
p=pathlib.Path('target/ipq50xx/ipq5000-vs010.dts'); s=p.read_text()
b=re.sub(r'//[^\n]*','',s); b=re.sub(r'/\*.*?\*/','',b,flags=re.S)
assert b.count('{')==b.count('}'), f'DTS 花括号不配对 {{ {b.count("{")} / }} {b.count("}")}（dtc 必失败）'
assert '#include "ipq5018.dtsi"' in s and 'bootargs-append' in s
print(f'  DTS {{ {b.count("{")} / }} {b.count("}")} 配对')
PYDTS
[ $? = 0 ] && ok 'VS010 DTS 花括号配对（r29.1 时多 1 个 };，dtc 编译失败根因）' || bad 'DTS 花括号不配对'
! grep -Fq 'ATH11K_MEM_PROFILE_256M' target/ipq50xx/device-vs010.inc \
  && grep -Fq 'ipq-wifi-cucc_vs010' target/ipq50xx/device-vs010.inc \
  && ok 'Device/cucc_vs010 包列表与 3000Q 对齐（无裸内存档符号）' || bad 'Device 包列表仍含 config 符号'
! grep -Fq ':wan' target/ipq50xx/board-vs010.inc \
  && grep -Fq '1:lan:4' target/ipq50xx/board-vs010.inc \
  && ok 'board.d VS010 全 LAN，首启不生成 WAN' || bad 'board.d 仍有 wan'
! grep -Fq 'CUCC VS010 (Unicom)' target/inject-vs010.py \
  && grep -Fq 'CUCC VS010 Unicom' target/inject-vs010.py \
  && ok 'ipq-wifi generate 标题无括号' || bad '标题括号未去'
[ -f tools/preflight-vs010.sh ] \
  && grep -Fq 'dtc' tools/preflight-vs010.sh \
  && grep -Fq 'GNU make' tools/preflight-vs010.sh \
  && grep -Fq '花括号' tools/preflight-vs010.sh \
  && ok 'preflight-vs010.sh 在位（DTS 配对 / dtc / make 解析 / 包列表护栏）' || bad '缺 preflight'
grep -Fq 'preflight-vs010.sh' diy-part1.sh \
  && grep -Fq 'preflight-vs010.sh' target/inject-vs010.py \
  && ok 'diy-part1 与 inject 都调用 preflight（编译前即拦）' || bad 'preflight 未接入'
grep -Fq 'tee "$LOG"' ../.github/workflows/build-source.yml \
  && grep -Fq 'compile 失败摘要' ../.github/workflows/build-source.yml \
  && grep -Fq 'tail -n 120' ../.github/workflows/build-source.yml \
  && ok 'workflow 失败时把错误摘要 + 日志尾部打在 step 末尾' || bad 'workflow 缺失败摘要'
python3 -m py_compile target/inject-vs010.py && sh -n tools/preflight-vs010.sh \
  && sh -n diy-part1.sh && ok 'inject / preflight / diy-part1 语法全过' || bad '脚本语法错'
# 负例：把多余的 }; 塞回 → 配对检查必须 FAIL
python3 - <<'PYNEG'
import pathlib,re,subprocess,tempfile,sys
s=pathlib.Path('target/ipq50xx/ipq5000-vs010.dts').read_text()
bad=s.replace('\t};\n};\n\n&blsp1_uart1 {','\t};\n\t};\n};\n\n&blsp1_uart1 {',1)
assert bad!=s, '负例构造失败'
b=re.sub(r'//[^\n]*','',bad); b=re.sub(r'/\*.*?\*/','',b,flags=re.S)
assert b.count('{')!=b.count('}'), '负例没造出不配对'
print('  负例（多 1 个 };）→ 花括号不配对，自检会 FAIL 拦住')
PYNEG
[ $? = 0 ] && ok '负例：DTS 多一个 }; 会被自检拦住' || bad '负例没拦住'

echo "── r29.5：DNS / WAN 编译期删除 + 内核保守精简 + NSS 加速硬护栏 ──"
for CFG3 in .config.rax3000q .config.vs010; do
  BAD5=""
  # r29.7：dnsmasq-full 为 AP 可选 DHCP 服务端编回（默认 ignore=1，零常驻）；其余仍不编入
  grep -Fqx 'CONFIG_PACKAGE_dnsmasq-full=y' "$CFG3" || BAD5="$BAD5 dnsmasq-full(应为 y)"
  for k in dnsmasq rpcd-mod-rrdns block-mount luci-app-filetransfer; do
    grep -Fqx "# CONFIG_PACKAGE_$k is not set" "$CFG3" || BAD5="$BAD5 $k"
  done
  for k in block-mount luci-app-filetransfer; do
    ! grep -Fqx "CONFIG_DEFAULT_$k=y" "$CFG3" || BAD5="$BAD5 DEFAULT_$k"
  done
  [ -z "$BAD5" ] && ok "$CFG3 DNS / 冗余插件编译期全关" || bad "$CFG3 仍开着:$BAD5"
done
# 空壳 INCLUDE 选项（主包没选，纯 config 噪音）零 =y
! grep -hE '^CONFIG_PACKAGE_luci-app-(passwall|ssr-plus|vssr|rclone|diskman)_INCLUDE_.*=y$' .config.rax3000q .config.vs010 \
  && ok '科学上网类空壳 INCLUDE 选项全清（主包本就没选）' || bad '仍有空壳 INCLUDE=y'
# ★ 加速全链路与后台核心一个都不许少
KEEP5="kmod-ath11k kmod-mac80211 kmod-qca-nss-dp kmod-qca-nss-drv kmod-qca-nss-ecm-standard kmod-qca-nss-drv-wifi-meshmgr kmod-qca-ssdk-nohnat qca-nss-fw-ipq50xx-retail MAC80211_NSS_SUPPORT luci luci-base luci-mod-network luci-mod-status uhttpd rpcd opkg dropbear ttyd luci-app-ttyd ethtool swconfig"
for CFG4 in .config.rax3000q .config.vs010; do
  MISS=""
  for k in $KEEP5; do grep -Fqx "CONFIG_PACKAGE_$k=y" "$CFG4" || MISS="$MISS $k"; done
  [ -z "$MISS" ] && ok "$CFG4 NSS 加速 / LuCI 后台 / SSH·TTYD·opkg 全在位" || bad "$CFG4 缺:$MISS"
done
[ -f tools/slim-kernel.sh ] && grep -Fq 'target/linux' tools/slim-kernel.sh \
  && grep -Fq '绝不碰' tools/slim-kernel.sh && ok '内核保守裁剪工具在位' || bad '缺 slim-kernel.sh'
python3 - <<'PYSLIMCHK'
import pathlib,re
s=pathlib.Path('tools/slim-kernel.sh').read_text()
m=re.search(r'BLACK="([^"]+)"',s); assert m,'缺 BLACK 清单'
black=m.group(1).split()
# 🔴 精确排除 IPv6 主体；IPV6_MROUTE / IPV6_SEG6_LWTUNNEL 等只是可选子特性，允许关。
FORBID_EXACT={'IPV6'}
FORBID_PREFIX=('BRIDGE','STP','NF_','NETFILTER','MAC80211','ATH11K','QCA','NSS')
for b in black:
    assert b not in FORBID_EXACT, f'危险主体符号 {b}'
    assert not b.startswith(FORBID_PREFIX), f'危险前缀符号 {b}'
for want in ('IP_MROUTE','IPV6_MROUTE','IPV6_MULTIPLE_TABLES','NAMESPACES'):
    assert want in black, f'漏了 {want}'
print(f'  BLACK {len(black)} 项，零 NSS/bridge/netfilter/IPV6 主体符号')
PYSLIMCHK
[ $? = 0 ] && ok '内核黑名单白名单式护栏（不碰 NSS/bridge/netfilter/IPV6）' || bad '内核黑名单含危险符号'
grep -Fq '99-vs010-no-wan' tools/strip-protocols.sh \
  && grep -Fq 'uci -q delete network.wan' tools/strip-protocols.sh \
  && grep -Fq '不动 switch/GMAC 寄存器' tools/strip-protocols.sh \
  && ok '编译期 uci-defaults 删 WAN/WAN6（不碰 switch 寄存器）' || bad '缺删 WAN 的 uci-defaults'
grep -Fq 'slim-kernel.sh' diy-part2.sh \
  && grep -Fq 'strip-protocols.sh' diy-part2.sh \
  && ok 'diy-part2 在 defconfig 前依次调用 strip → slim-kernel' || bad '调用链缺'
python3 - <<'PYORDER'
import pathlib
s=pathlib.Path('diy-part2.sh').read_text()
assert s.index('strip-protocols.sh') < s.index('slim-kernel.sh'), 'slim 必须在 strip 之后'
print('  顺序 OK：strip（含删 WAN）→ slim-kernel → defconfig')
PYORDER
[ $? = 0 ] && ok '调用顺序正确' || bad '调用顺序不对'
grep -Fq 'MUST_KEEP' tools/check-no-protocols.py \
  && grep -Fq -- '--no-keep' tools/check-no-protocols.py \
  && ok 'check 含 MUST_KEEP 硬护栏（缺加速/后台即拒绝出包）' || bad 'check 缺硬护栏'
# 真跑：造源码树跑 strip + slim-kernel
TMP5=$(mktemp -d)
mkdir -p "$TMP5/target/linux/ipq50xx" "$TMP5/package/base-files/files/etc/uci-defaults"
printf 'include $(TOPDIR)/rules.mk\nDEFAULT_PACKAGES += ppp ppp-mod-pppoe ipv6helper firewall dnsmasq-full dnsmasq rpcd-mod-rrdns block-mount kmod-ath11k kmod-qca-nss-dp luci swconfig\n' > "$TMP5/target/linux/ipq50xx/Makefile"
printf 'CONFIG_IP_MROUTE=y\nCONFIG_IPV6_MROUTE=y\nCONFIG_IPV6_MULTIPLE_TABLES=y\nCONFIG_NAMESPACES=y\nCONFIG_IPV6=y\nCONFIG_BRIDGE=y\nCONFIG_NF_CONNTRACK=y\nCONFIG_MAC80211=y\n' > "$TMP5/target/linux/ipq50xx/config-5.4"
cp .config.rax3000q "$TMP5/.config"
( cd "$TMP5" && sh "$OLDPWD/tools/strip-protocols.sh" && sh "$OLDPWD/tools/slim-kernel.sh" ) > "$TMP5/log" 2>&1 || { cat "$TMP5/log"; bad 'strip/slim 真跑失败'; }
grep -Fq '99-vs010-no-wan' "$TMP5/log" && [ -f "$TMP5/package/base-files/files/etc/uci-defaults/99-vs010-no-wan" ] \
  && grep -Fq 'uci -q delete network.wan' "$TMP5/package/base-files/files/etc/uci-defaults/99-vs010-no-wan" \
  && ok '真跑：uci-defaults 生成且只删 WAN 逻辑接口' || bad 'uci-defaults 没生成'
grep -Fq '# CONFIG_IP_MROUTE is not set' "$TMP5/target/linux/ipq50xx/config-5.4" \
  && grep -Fxq 'CONFIG_IPV6=y' "$TMP5/target/linux/ipq50xx/config-5.4" \
  && grep -Fxq 'CONFIG_BRIDGE=y' "$TMP5/target/linux/ipq50xx/config-5.4" \
  && grep -Fxq 'CONFIG_NF_CONNTRACK=y' "$TMP5/target/linux/ipq50xx/config-5.4" \
  && grep -Fxq 'CONFIG_MAC80211=y' "$TMP5/target/linux/ipq50xx/config-5.4" \
  && ok '真跑：L3 组播/命名空间关掉，IPV6/bridge/netfilter/mac80211 一字未动' || bad '内核裁剪误伤依赖符号'
! grep -Fq 'ppp kmod-ath11k' "$TMP5/target/linux/ipq50xx/Makefile" \
  && grep -Fq 'dnsmasq' "$TMP5/target/linux/ipq50xx/Makefile" | true
grep -Fq 'kmod-ath11k' "$TMP5/target/linux/ipq50xx/Makefile" \
  && grep -Fq 'kmod-qca-nss-dp' "$TMP5/target/linux/ipq50xx/Makefile" \
  && ok '真跑：DEFAULT_PACKAGES 摘掉 PPP/反向DNS，加速包未误删' || bad '加速包被误删'
cp .config.rax3000q "$TMP5/.config"
python3 tools/check-no-protocols.py "$TMP5/.config" > "$TMP5/chk" 2>&1 && ok '真跑：完整 config 过 defconfig 后硬校验' || { cat "$TMP5/chk"; bad '完整 config 校验没过'; }
# 负例：删加速包 → 拒绝出包
sed -i 's/^CONFIG_PACKAGE_kmod-qca-nss-ecm-standard=y$/# CONFIG_PACKAGE_kmod-qca-nss-ecm-standard is not set/' "$TMP5/.config"
python3 tools/check-no-protocols.py "$TMP5/.config" > "$TMP5/chk2" 2>&1 && RC5=0 || RC5=$?
[ "$RC5" = 1 ] && grep -Fq '::error::' "$TMP5/chk2" && ok '负例：删 ECM 加速包会被拒绝出包' || bad '加速护栏没拦住'
# 负例：DNS 回流 → 拒绝出包
cp .config.rax3000q "$TMP5/.config"
  sed -i -e 's/^CONFIG_PACKAGE_dnsmasq-full=y$/# CONFIG_PACKAGE_dnsmasq-full is not set/' \
         -e 's/^CONFIG_DEFAULT_dnsmasq-full=y$/# CONFIG_DEFAULT_dnsmasq-full is not set/' "$TMP5/.config"
python3 tools/check-no-protocols.py "$TMP5/.config" > "$TMP5/chk3" 2>&1 && RC6=0 || RC6=$?
[ "$RC6" = 1 ] && grep -Fq '::error::' "$TMP5/chk3" && ok '负例：删掉 dnsmasq-full（AP DHCP 失效）被拒绝出包' || bad 'dnsmasq 护栏没拦住'
rm -rf "$TMP5"

echo "── r29.4：编译期关闭 IPv6 / PPP 等协议（不只是运行期）──"
MUST="ppp ppp-mod-pppoe kmod-ppp kmod-pppoe kmod-pppox kmod-pptp luci-proto-ppp kmod-qca-nss-drv-pppoe ipv6helper luci-proto-ipv6 odhcp6c 6in4"
BEST="firewall ip6tables ip6tables-mod-nat libip6tc kmod-ip6tables kmod-ipt-nat6 kmod-nf-conntrack6 kmod-nf-ipt6 kmod-nf-nat6 kmod-nf-reject6"
for CFG2 in .config.rax3000q .config.vs010; do
  BAD=""
  for k in $MUST $BEST; do
    grep -Fqx "# CONFIG_PACKAGE_$k is not set" "$CFG2" || BAD="$BAD $k"
  done
  for k in ppp ppp-mod-pppoe ipv6helper firewall; do
    ! grep -Fqx "CONFIG_DEFAULT_$k=y" "$CFG2" || BAD="$BAD DEFAULT_$k"
  done
  [ -z "$BAD" ] && ok "$CFG2 协议包编译期全关" || bad "$CFG2 仍开着:$BAD"
done
# 内核 IPv6 符号保留（QSDK/NSS 编译依赖），但必须靠 sysctl 全网卡关死
grep -Fqx 'CONFIG_KERNEL_IPV6=y' .config.rax3000q \
  && grep -Fq 'net.ipv6.conf.all.disable_ipv6=1' files/etc/sysctl.d/99-vs010-no-ipv6.conf \
  && grep -Fq 'accept_ra=0' files/etc/sysctl.d/99-vs010-no-ipv6.conf \
  && grep -Fq 'autoconf=0' files/etc/sysctl.d/99-vs010-no-ipv6.conf \
  && ok '内核 IPV6 符号保留但 RA/autoconf/转发全封死（NSS 依赖不破）' || bad 'sysctl 未封死 v6'
grep -Fq 'kill_ipv6' files/etc/init.d/vs010-mode \
  && grep -Fq 'uci -q delete network.wan6' files/etc/init.d/vs010-mode \
  && grep -Fq 'dhcp.lan.dhcpv6' files/etc/init.d/vs010-mode \
  && ok '运行期 kill_ipv6 / 删 WAN6 / 关 DHCPv6 仍在' || bad '运行期 IPv6 兜底丢了'
[ -f tools/strip-protocols.sh ] && grep -Fq 'DEFAULT_PACKAGES' tools/strip-protocols.sh \
  && ok '编译期剥离工具在位（连 target 默认包集合一起摘）' || bad '缺 strip-protocols.sh'
[ -f tools/check-no-protocols.py ] && grep -Fq '::error::' tools/check-no-protocols.py \
  && ok 'defconfig 后硬校验工具在位' || bad '缺 check-no-protocols.py'
grep -Fq 'strip-protocols.sh' diy-part2.sh \
  && ok 'diy-part2 在 make defconfig 之前调用剥离' || bad 'diy-part2 没调剥离'
grep -Fq 'check-no-protocols.py' ../.github/workflows/build-source.yml \
  && ok 'workflow 在 make defconfig 之后硬校验' || bad 'workflow 没校验'
python3 - <<'PYR294'
import pathlib,re
s=pathlib.Path('../.github/workflows/build-source.yml').read_text()
a=s.index('\n        make defconfig\n')
b=s.index('check-no-protocols.py',a)
c=s.index('\n        make download -j8\n',b)
print('  顺序 OK：defconfig → 校验 → download')
PYR294
[ $? = 0 ] && ok '校验顺序正确（defconfig 后 / download 前）' || bad '校验顺序不对'
# 真跑：造一份带 =y 的假 .config 验证 check 脚本会拦
TMP=$(mktemp -d)
printf 'CONFIG_PACKAGE_ppp=y\nCONFIG_PACKAGE_ipv6helper=y\nCONFIG_PACKAGE_dropbear=y\n' > "$TMP/.config"
python3 tools/check-no-protocols.py "$TMP/.config" > "$TMP/out" 2>&1 && RC=0 || RC=$?
[ "$RC" = 1 ] && grep -Fq '::error::' "$TMP/out" && ok '负例：defconfig 拉回 ppp/ipv6helper 会被拒绝出包' || bad '校验脚本没拦住'
printf '# CONFIG_PACKAGE_ppp is not set\n# CONFIG_PACKAGE_ipv6helper is not set\n' > "$TMP/.config"
python3 tools/check-no-protocols.py --no-keep "$TMP/.config" >/dev/null 2>&1 && ok '正例：全关时校验通过（单元测试跳过 KEEP）' || bad '正例被误拦'
rm -rf "$TMP"

echo "── r29.2：LuCI 后台 → 网桥 / AP 状态页 双向导航 ──"
CT2=files/usr/lib/lua/luci/controller/admin/vs010.lua
grep -Fq 'entry({"admin", "vs010_home"' "$CT2" \
  && grep -Fq 'function go_home()' "$CT2" \
  && grep -Fq 'http.redirect' "$CT2" \
  && grep -Fq '"/ap/"' "$CT2" && grep -Fq '"/bridge/"' "$CT2" \
  && ok 'LuCI 一级菜单「← 返回网桥/AP 状态」+ 按 mode 302 回独立界面' || bad '缺 LuCI 回跳菜单'
for T in vs010_bridge.htm vs010_ap.htm vs010_console.htm vs010_ports.htm vs010_role.htm vs010_setup.htm; do
  P="files/usr/lib/lua/luci/view/$T"
  grep -Fq 'class="vs010Back"' "$P" && grep -Fq 'border-radius:999px' "$P" \
    && ok "$T 有胶囊「返回状态页」按钮" || bad "$T 缺返回按钮"
done
grep -Fq '网口状态 · PORT STATUS' files/usr/lib/lua/luci/view/vs010_ports.htm \
  && ! grep -Fq '已插网线 · 网口速率' files/usr/lib/lua/luci/view/vs010_ports.htm \
  && ok 'LuCI 网口状态页标题与 r29 统一' || bad 'LuCI 页还叫网口速率'
! grep -R -Fq '网口速率</a>' files/usr/lib/lua/luci/view/ \
  && ok '底部链接文案全改「网口状态」' || bad '仍有旧「网口速率」链接'
! grep -R -Fq 'vs010-theme' files/usr/lib/lua/luci/view/ \
  && ok '不再引用源码线不存在的 vs010-theme 命令' || bad '仍引用不存在的命令'
grep -Fq '也可单独打开' files/usr/lib/lua/luci/view/vs010_bridge.htm \
  && grep -Fq 'LuCI 左侧一级菜单' files/usr/lib/lua/luci/view/vs010_bridge.htm \
  && ok 'iframe 页仍保留独立直链与一级菜单提示' || bad 'bridge iframe 直链丢了'
grep -Fq 'data-mode="auto"' files/usr/lib/lua/luci/view/vs010_setup.htm \
  && ok '常用设置面板本体未动（导航里 /bridge/ /ap/ 仍在）' || bad '设置面板被改坏'

echo "── r29.1：GitHub workflow_dispatch schema（choice options 必须字符串）──"
python3 - <<'PYR291'
import yaml,pathlib
d=yaml.safe_load(pathlib.Path('../.github/workflows/build-source.yml').read_text())
on=d.get('on',d.get(True)); ins=on['workflow_dispatch']['inputs']
for k,v in ins.items():
    if v.get('type')!='choice': continue
    assert all(isinstance(x,str) for x in v['options']), f'{k}.options 含非字符串（GitHub 会报 Invalid workflow file）'
    assert isinstance(v.get('default'),str), f'{k}.default 不是字符串'
    assert v['default'] in v['options'], f'{k}.default 不在 options 里'
    print(f'  {k}: options={v["options"]} default={v["default"]!r} ✅')
assert ins['device']['default']=='all', 'device 默认不是 all，会只编一个机型'
print('  device 默认 all（一次出两个机型）✅')
PYR291
[ $? = 0 ] && ok 'workflow_dispatch 选项全字符串、default 合法、device=all' || bad 'GitHub 手动输入 schema 不合法'
! grep -Eq '^\s+options: \[(true|false), (true|false)\]' ../.github/workflows/build-source.yml \
  && ok '无裸布尔 options 残留' || bad '仍有裸布尔 options'

echo "── r29：网口状态 / 网口信息 + 状态栏与选项全椭圆 ──"
for P in files/www/bridge/index.html files/www/ap/index.html; do
  grep -Fq '网口状态 · PORT STATUS' "$P" && grep -Fq 'id="portStatus"' "$P" \
    && grep -Fq '<th style="padding:6px 8px">链接状态</th>' "$P" \
    && grep -Fq '<th style="padding:6px 8px">速率来源</th>' "$P" \
    && grep -Fq '网口状态 / 网口信息' "$P" \
    && ok "$P 网口信息块：状态/接口/链接状态/链接速率/双工/来源 6 列" || bad "$P 网口状态块不全"
  grep -Fq '内网 LAN</th>' "$P" && grep -Fq '链接速率</th>' "$P" \
    && ok "$P 链接速率仍是其中一列（未丢）" || bad "$P 速率列丢了"
  grep -Fq 'border-radius:999px !important' "$P" \
    && grep -Fq '.netSub,.portState,.badge,.pill' "$P" \
    && grep -Fq '.vsf .nav a,.vsf button' "$P" \
    && ok "$P 状态栏 / 选项卡 / 按钮全部椭圆（两端圆弧）" || bad "$P 椭圆规则缺"
  ! grep -Fq '内网 LAN 口 · LINK UP' "$P" \
    && ok "$P 旧「内网 LAN 口 · LINK UP」标题已换成网口状态栏" || bad "$P 旧标题残留"
done
python3 - <<'PYR29'
import pathlib
c=pathlib.Path('files/www/vs010-setup.js').read_text()
assert '>网口状态</a>' in c, '导航仍叫网口速率'
assert c.count('border-radius:999px')>=9, 'setup.js 圆角改漏了'
assert 'border-radius:19px' not in c and 'border-radius:16px' not in c, '滑块还是旧圆角'
lu=pathlib.Path('files/usr/lib/lua/luci/controller/admin/vs010_ports.lua').read_text()
assert '_("网口状态")' in lu, 'LuCI 菜单名没统一'
print('  SETUP 导航 / 9 处圆角 / 滑块 / LuCI 菜单名 全统一 ✅')
PYR29
[ $? = 0 ] && ok '设置控制台与 LuCI 菜单也统一「网口状态」+ 全椭圆' || bad '设置控制台未同步'

echo "── r28 深度核验：无法编译 / 网页打不开 / 无线无法使用 ──"
python3 - <<'PYWF'
import pathlib,re,subprocess
w=pathlib.Path('../.github/workflows/build-source.yml').read_text()
assert 'name: Build 5.4 source firmware' in w
assert 'mode: [wds, ap]' not in w and 'matrix.mode' not in w, '又变回 4 个包'
assert "default: 'wds'" in w and 'openwrt/files/etc/vs010/mode' in w
lines=w.splitlines(); runs=[]; i=0
while i<len(lines):
    if re.match(r'^\s+run:\s*\|',lines[i]):
        base=len(lines[i])-len(lines[i].lstrip()); j=i+1; blk=[]
        while j<len(lines) and (not lines[j].strip() or len(lines[j])-len(lines[j].lstrip())>base):
            blk.append(lines[j]); j+=1
        runs.append('\n'.join(blk)); i=j; continue
    i+=1
for k,b in enumerate(runs):
    r=subprocess.run(['bash','-n'],input=b.replace('${{','${').replace('}}','}'),text=True,capture_output=True)
    assert r.returncode==0,('run 块 %d bash -n 失败'%k,r.stderr[:200])
man=[l.strip() for l in pathlib.Path('files.manifest').read_text().splitlines()
     if l.strip() and not l.startswith('#')]
for f in man: assert pathlib.Path('files/'+f).is_file(), ('清单缺文件',f)
print('  WORKFLOW',len(runs),'个 run 块 bash -n OK / manifest',len(man),'文件全在 ✅')
PYWF
[ $? = 0 ] && ok '编译护栏：YAML 关键项 / 全部 run 块 bash -n / manifest 文件齐备' || bad '编译链有断点'


# ① 致命：LuCI controller 语法（r28 实测出 jesc 字符串内裸换行 → LuCI require 失败 → 后台 500）
[ -s tools/luacheck.py ] || bad '缺 Lua 词法护栏 tools/luacheck.py'
python3 tools/luacheck.py > /tmp/luacheck.out 2>&1 \
  && ok '全部 LuCI controller Lua 词法通过（含 jesc 重写）' || bad "$(cat /tmp/luacheck.out)"
python3 - <<'PYLUA'
import pathlib,subprocess,sys,tempfile
src=pathlib.Path('files/usr/lib/lua/luci/controller/admin/vs010_setup.lua').read_text()
a=src.index('local function jesc(v)'); b=src.index('\nend',a)+4
bad='local function jesc(v)\n    return (tostring(v or ""):gsub("\\", "\\\\"):gsub(\'"\', \'\\"\'):gsub("[\n\t]", " "))\nend'
t=pathlib.Path(tempfile.mkdtemp())/'bad.lua'; t.write_text(src[:a]+bad+src[b:])
r=subprocess.run([sys.executable,'tools/luacheck.py',str(t)],capture_output=True,text=True)
assert r.returncode!=0, '护栏没拦住旧 jesc BUG'
print('  LUA 护栏负例：旧 jesc 写法被拦住 ✅')
PYLUA
[ $? = 0 ] && ok 'Lua 词法护栏能拦住同类回归' || bad '护栏失效'

# ② 根路径跳转（LuCI postinst 的 index_page=cgi-bin/luci 会让静态 index.html 永不生效）
python3 - <<'PYIDX'
import pathlib
s=pathlib.Path('files/etc/init.d/vs010-luci-fix').read_text()
a=s.index('luci_fix(){'); b=s.index('\nstart(){',a)
body=s[a:b]
code=[l for l in body.splitlines() if not l.strip().startswith('#')]
assert any('uci -q set uhttpd.main.index_page=index.html' in l for l in code), 'S18 函数体内缺有效设置'
assert 'luci-base postinst' in body, '缺原因说明'
print('  INDEXPAGE S18 函数体内有效设置 OK')
PYIDX
[ $? = 0 ] && ok 'S18 显式把 index_page 指回 index.html（只输 IP 才真的跳状态页）' || bad '根跳转会被 LuCI 覆盖'
grep -Fq '/cgi-bin/luci/' files/www/index.html \
  && ok '根跳转页仍保留高级设置后台直达链接' || bad '根页漏了 LuCI 直达'
sh -n files/etc/init.d/vs010-luci-fix && ok 'vs010-luci-fix sh -n' || bad 'luci-fix 语法错'

# ③ 无线：htmode 只放行该源码线已验证的 QSDK 约定值（.config 是 ath11k+mac80211+wpad-wolfssl，
#    但脚本沿用 qcawifi.sh 的 11axa + HT160 表示 HE160；写 HE160 会让 5G 起不来）
python3 - <<'PYHT'
import pathlib
ac=pathlib.Path('files/usr/sbin/vs010-apply-config').read_text()
md=pathlib.Path('files/etc/init.d/vs010-mode').read_text()
wp=pathlib.Path('files/usr/sbin/vs010-wds-pair').read_text()
assert "case \"$v\" in ''|HT160|HT80|HT40)" in ac, '后台白名单没收紧'
assert 'HE160|HE80|VHT80' not in ac, '后台仍放行未验证频宽'
assert 'HE160 请用 HT160' in ac, '错误提示没说明原因'
assert 'case "$HT" in HT160|HT80|HT40)' in md, '开机脚本缺非法值跳过保护'
assert 'uci -q set "wireless.$d.htmode=HT160"' in wp, 'wds-pair 的已验证 HT160 被改坏'
assert 'HT160' in md and '勿改 HE160' in md, '默认值说明丢失'
js=pathlib.Path('files/www/vs010-setup.js').read_text()
assert "['HT160','HT80','HT40']" in js, '前端下拉仍含 HE160/VHT80'
# ── r29.12 追加：双频段频宽互不串写 ──
assert "case \"$v\" in ''|HT40|HT20)" in ac, '2.4G ht24 白名单缺'
assert '2.4G 频宽只支持 HT40' in ac, 'ht24 错误提示缺'
assert 'htmode ht24 txpower' in ac, 'get/apply/save 清单漏 ht24'
assert '"ht24":"HT40"' in ac, '2.4G 默认不是 20/40 共存'
assert '"htmode":"HT160"' in ac, '5.8G 默认不是 160MHz'
assert 'H5=$(cfg_get htmode)' in ac and 'H2=$(cfg_get ht24)' in ac, 'AP 内联未分频段'
assert 'case "$H5" in HT160|HT80|HT40)' in ac, 'AP 内联 5G 未写频宽'
assert 'case "$H2" in HT40|HT20)' in ac, 'AP 内联 2.4G 未写频宽'
assert 'HT2=$(cfg_get ht24)' in md and 'case "$HT2" in HT40|HT20)' in md, '开机脚本 2.4G 分支缺'
assert 'ht24(2.4G)=$HT2' in md, '开机日志缺双频宽'
assert 'WDS 回程固定在 5.8G 160MHz' in wp, 'wds-pair 未注明 160MHz'
assert 'selLabels(' in js and "[['HT40','HT40 · 20/40MHz 共存']" in js, '前端 2.4G 下拉缺'
assert "'htmode','ht24','txpower'" in js and "ht24:'HT40'" in js, '前端字段/默认值缺'
print('  HTMODE 5.8G / ht24 2.4G / 开机双分支 / AP 内联 / wds-pair 160 / 双下拉 OK')
PYHT
[ $? = 0 ] && ok '无线频宽不会写入 qcawifi.sh 不认的 HE160（防 5G 起不来）' || bad '无线频宽仍有踩雷值'
for f in files/etc/init.d/vs010-mode files/usr/sbin/vs010-apply-config files/usr/sbin/vs010-wds-pair \
         files/www/cgi-bin/vs010-links files/www/cgi-bin/vs010 files/www/cgi-bin/bridge files/www/cgi-bin/apstatus; do
  sh -n "$f" || bad "$f sh -n 失败"
done
ok '全部业务脚本 / CGI sh -n 通过'

# ④ links CGI 真跑：造 mock sysfs，验证「只插第 3 个物理口 → 内网LAN3」+ JSON 合法 + br-lan 不出现
python3 - <<'PYLINKS'
import pathlib,subprocess,os,json,shutil,tempfile
base=pathlib.Path(tempfile.mkdtemp())
sysd=base/'sys/class/net'; sysd.mkdir(parents=True)
for d,sp in [('eth2','1000'),('br-lan','-1')]:
    p=sysd/d; p.mkdir()
    (p/'carrier').write_text('1\n'); (p/'operstate').write_text('up\n'); (p/'speed').write_text(sp+'\n')
    (p/'address').write_text('00:11:22:33:44:55\n')
b=base/'bin'; b.mkdir()
for n,body in {'ethtool':'#!/bin/sh\necho "Link detected: yes"; echo "Duplex: Full"\n',
               'swconfig':'#!/bin/sh\nexit 1\n','uci':'#!/bin/sh\nexit 0\n',
               'ip':'#!/bin/sh\nexit 0\n','logger':'#!/bin/sh\nexit 0\n','lsmod':'#!/bin/sh\nexit 0\n'}.items():
    f=b/n; f.write_text(body); f.chmod(0o755)
src=pathlib.Path('files/www/cgi-bin/vs010-links').read_text().replace('/sys/class/net',str(sysd))
cg=base/'cgi'; cg.write_text(src); cg.chmod(0o755)
r=subprocess.run(['sh',str(cg)],env=dict(os.environ,PATH=str(b)+':/usr/sbin:/usr/bin:/sbin:/bin'),
                 capture_output=True,text=True,timeout=30)
body=r.stdout[r.stdout.find('{'):]
j=json.loads(body)
names=[(x['lan'],x['speed']) for x in j['links']]
assert names==[('内网LAN3',1000)], ('物理口编号/过滤不对',names)
assert 'br-lan' not in [x['if'] for x in j['links']], 'br-lan 仍出现在表里'
assert j['ok']==1 and 'wifi_temp' in j and 'net' in j
print('  LINKS 真跑：只插 eth2 →',names,'/ JSON 合法 / br-lan 已过滤 ✅')
shutil.rmtree(base,ignore_errors=True)
PYLINKS
[ $? = 0 ] && ok 'links CGI 真跑：LAN 编号对应实际物理口、JSON 合法' || bad 'links CGI 输出异常'

# ⑤ 两页都能打开：所有资源在 manifest 内、内联 JS 零语法错、根跳转页在清单
python3 - <<'PYWEB'
import pathlib,re,subprocess
man=set(pathlib.Path('files.manifest').read_text().split())
need=['www/index.html','www/bridge/index.html','www/ap/index.html','www/vs010-setup.js',
      'www/cgi-bin/bridge','www/cgi-bin/apstatus','www/cgi-bin/vs010','www/cgi-bin/vs010-links',
      'usr/lib/lua/luci/controller/admin/vs010_setup.lua']
for f in need:
    assert f in man, ('清单漏了',f)
    assert pathlib.Path('files/'+f).is_file(), ('文件不存在',f)
for pg in ('bridge','ap'):
    s=pathlib.Path('files/www/'+pg+'/index.html').read_text()
    for b in re.findall(r'<script(?![^>]*src)[^>]*>(.*?)</script>',s,re.S):
        r=subprocess.run(['node','--check'],input='(function(){'+b+'})',text=True,capture_output=True)
        assert r.returncode==0,(pg,r.stderr[:200])
    assert 'hdrActions' in s and '高级设置后台' in s
print('  WEB 资源齐备 / 两页内联 JS 零语法错 / 高级入口在位 ✅')
PYWEB
[ $? = 0 ] && ok '两个界面依赖的资源全在包内且脚本零语法错' || bad '网页资源/脚本异常'

[ "$F" = 0 ] && echo "RESULT: PASS —— 第 29.12 次：2.4G 20/40 共存 / 5.8G 160MHz / WDS-AP（仿UBNT）标识 / WDS 客户端搜索 SSID / 自动跟随频段 / 四界面全互访 / 登录贯通 / 三界面同款 UBNT / UBNT 概览页 / VS010 6.4 基线 / AP DHCP / 时间·运行时长 / 3000Q 6.4 基线 / VS010 DTS 编译失败根因修复 / DNS/WAN 删除 + NSS 加速护栏 / IPv6/PPP 编译期关闭 / README 精简 / LuCI 双向导航 / workflow schema 合法 / 网口状态 6 列 / 状态栏·选项全椭圆 / Lua 后台可加载 / 根跳转生效 / 无线频宽安全 / 编译链无断点 / 默认网桥 / 未登录只读" \
             || echo "RESULT: FAIL"
exit $F
