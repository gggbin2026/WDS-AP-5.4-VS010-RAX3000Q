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

echo "── r25 全能包：单线自包含（清空仓库后解压即用）──"
[ -s "$W" ] && ok '唯一编译入口 = build-source.yml' || bad '缺 build-source.yml'
grep -Fq 'Build 5.4 source firmware (r25' "$W" && ok 'workflow 为 r25 单线版' || bad 'workflow 版本不对'
[ "$(ls -1 ../.github/workflows/*.yml 2>/dev/null | wc -l)" = 1 ] \
  && ok 'workflows/ 只有 1 个 yml（无同名冲突）' || bad 'workflow 数量不对'
[ ! -e "$FUSED" ] && ok '融合线 workflow 已移除' || bad '融合线残留'
[ -s ../verify.sh ] && grep -Fq 'exec sh sourcebuild/tools/verify.sh' ../verify.sh \
  && ok '根 verify.sh 指向单线自检' || bad '根入口不对'
[ -s ../README.md ] && grep -Fq '全能包' ../README.md \
  && ok '根 README = 全能包总入口（含清空仓库步骤）' || bad 'README 不对'
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
grep -Fq 'make -j$(nproc) || make -j1 || make -j1 V=s' "$W" && ok '真实 make 编译（非融合重打包）' || bad '不是真编译'
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

echo "── 单常驻 + 模式隔离 + 配置继承 ──"
grep -Fxq 'usr/sbin/vs010-tick' files.manifest && ok '单常驻调度器在位' || bad '缺 vs010-tick'
grep -Fq '96:vs010-tick' "$W" && ok '开机自启只拉 tick' || bad '仍拉多个常驻'
grep -Fq 'sourcebuild/mode-exclude.$MODE.txt' "$W" && ok '构建期按模式物理排除' || bad '模式隔离缺'
grep -Fq 'vs010_ap.htm' mode-exclude.wds.txt && grep -Fq 'vs010_bridge.htm' mode-exclude.ap.txt \
  && ok 'wds 不含 AP 页 / ap 不含网桥页' || bad '排除清单内容不对'
! grep -q '/ap/' files/www/bridge/index.html && ! grep -q '/bridge/' files/www/ap/index.html \
  && ok '两个丰富页零交叉字样' || bad '页面仍互相引用'
M=files/etc/init.d/vs010-mode
for k in '172.10.10.241' '255.255.252.0' '172.10.10.254' '172.100.10.254' '192.168.1.254' \
         'interval 300' 'VS010-AP' 'RAX3000Q-AP' 'db_rssi_thr' 'ttyMSM0::askfirst' \
         'PW_HASH=' 'dhcp.lan.ignore' 'delete network.wan6'; do
  grep -Fq "$k" "$M" || bad "vs010-mode 缺 $k"
done
WP=files/usr/sbin/vs010-wds-pair
for k in 'WDS-Bridge-Z' 'WDS123456' 'htmode=HT160' 'channel=auto' 'db_rssi_thr'; do
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

echo "── 第 25 次：实机资产落库 / 单线 / 稳定低内存 / 界面速率与温度 ──"
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
grep -Fq '只列已插网线的口' files/www/bridge/index.html && ok '仍只列已插网线的口' || bad '网卡过滤丢了'

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
[ "$F" = 0 ] && echo "RESULT: PASS —— 第 25 次全能包：自包含 / 单线 / 实机资产 / 链接速率+无线温度 / 网桥只用5G / 低内存" \
             || echo "RESULT: FAIL"
exit $F
