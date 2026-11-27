# WDS-AP-5.4-VS010-RAX3000Q

> **基于两台机器原本能正常使用的官方好固件做叠加**，不改内核、不改 BDF、不改闭源无线驱动。
> 目标只有一个：**有线无线照常用**，顺带把「时间不准 / 网口速率显示不准」修好，其他都是锦上添花。

一个仓库、一套 `files/` 共用文件、**两机型 × 两模式** 共 4 个固件。

---

## 1. 底座（最关键）

| 机型 | 底座文件 | 内核 / 无线 |
|---|---|---|
| `cucc_vs010`（联通 VS010） | `3000Q-VS010-固件/Nwrt-QSDK12.2-...-cucc_vs010-...factory.bin` | **5.4.213 + 闭源 qca-wifi**，满血 |
| `cmcc_rax3000q`（移动 RAX3000Q） | `...-cmcc_rax3000qy-...factory.bin` | 同上 |

构建方式：**kernel FIT 卷逐字节原样保留**，只解 rootfs squashfs、叠加运行期文件后重新打包。

全量逐文件比对：官方 2513 项 → 2511 项，**被修改 0 / 删除 36（全是无关自启与控制器）/ 新增 34（全是运行期脚本）**；`qca_ol / umac / wifi_3_0 / ipq_cnss2`、`bdwlan.b10`、`qcn6122/bdwlan.b60`、`/lib/firmware`、`/lib/modules`、`board.d/02_network` MD5 全一致。

> 🔴 刷错机型（VS010 刷 RAX3000Q 固件）会无线起不来；两份底座的 DTS / ART / BDF 不通用。

---

## 2. 编译与固件命名

- **主构建**：`Actions → Build 5.4 firmware → Run workflow`，`device=all / mode=all` 默认出 **4 个**固件。
- 原生源码编译线（仅 RAX3000Q）：`Build source`，沿用上游 `.config` / diy 脚本，**与本叠加线互不影响**。
- 本地出包：`sh build/build.sh --device=cucc_vs010 --mode=wds`。
- 自检：`sh verify.sh` → `RESULT: PASS`。

固件名统一：

```
Nwrt-QSDK12.2-5.4-<日期>-ipq50xx-arm-<机型>-<模式>-squashfs-nand-factory.bin
Nwrt-QSDK12.2-5.4-...sha256
```

带 **`5.4`** 便于识别内核；每个 Release 含 `.bin` + `.sha256` + 简洁下载说明。

**刷机**：按机型严格对应；🔴 **不要勾「保留配置」**（旧 overlay 会把旧配置 / 官方 board.d 生成的 WAN 带回来）。

---

## 3. 登录与管理（刷完第一件事）

| 项 | 值 |
|---|---|
| 管理 IP | **`172.10.10.241`** |
| 子网掩码 | **`255.255.252.0`**（/22，网段 `172.10.8.0 ~ 172.10.11.255`） |
| 账号 | SSH / LuCI / 串口 **`root` / `password`**（官方好固件内置，保留不改） |
| SSH | `ssh root@172.10.10.241`，dropbear 不绑 Interface |
| 串口 | `ttyMSM0 115200n8`，官方 inittab `askfirst` 保住 + 缺失兜底 |
| 网页终端 | **TTYD** `/ttyd/` |
| 状态页 | `/bridge/`（网桥，33.9K）/ `/ap/`（AP，32.3K）—— 旧版丰富界面，10 秒刷新 |
| LuCI | `/cgi-bin/luci/`，**Argon 主题**，427 已修，纯 HTTP 80 |

改 IP：`vs010-mode set-ip 172.10.10.241`；改模式：`vs010-mode set wds|ap`；`vs010-mode status` 看全部。

---

## 4. 网络配置（纯二层桥）

| 项 | 状态 |
|---|---|
| 桥 | `br-lan`，`eth0 eth1` 全进桥（**WAN 口与 LAN 口桥接过来**），`type bridge` |
| WAN / WAN6 | 🔴 **每次开机都删**（`scrub()` 不受首启 stamp 限制；官方 `board.d` 每次会重新生成，只首启删一次不够） |
| STP | **开**（`network.lan.stp=1`），`vs010-mode stp on|off` |
| IPv6 | **关**：sysctl + `ipv6=0` + `ra/dhcpv6/ndp=off` + 停 odhcpd；`ip -6 addr` 应无地址 |
| 防火墙 | **关**（服务停用），纯二层桥不需要 iptables 转发 |
| DHCP | AP 模式本机不做服务端（`dhcp.lan.ignore=1`），交给上级 |

**网口速率**：官方自带 `ethtool` / `swconfig`，netdev 不上报不是真跑不满。`portstat` 用 ethtool + `/sys/class/net/*/speed` 只读取数，`/bridge/` `/ap/` 页面自动显示 1000M/Full。不改驱动、不写配置。

---

## 5. 时间（你最初的两个诉求之一）

官方板子**无 RTC**（`hctosys: unable to open rtc0`），开机停在 1970 是正常现象。已修：

- **NTP 纯内网客户端**：`enable_server=0`，不对外供时
- 三台服务器：`172.10.10.254` / `172.100.10.254` / `192.168.1.254`
- **每 5 分钟（300 秒）循环同步**：`ntp-sync` 跑 `同步 → sleep 300 → 再同步 …`，单轮失败照样进下一轮；procd `respawn` 意外退出 5 秒拉回
- `ntp-sync status` 看轮次 / 距下轮；`ntp-sync set-interval N` 自定义

> `172.10.10.254` 与本机 /22 同网段直连可达；另两台跨网段，需上级路由，不通会自动试下一台。

---

## 6. 无线与两种模式

底座的闭源无线**一个字节没动**，以下都是 `uci` 增量（不重建 radio、不 `wifi down`、不重启）。

### WDS 网桥模式
| 项 | 值 |
|---|---|
| 角色 | **WDS 主 / WDS 客户端**，按 MAC 字典序自动收敛（小=主 / 大=客户端） |
| SSID | `WDS-Bridge-Z` / `WDS123456` / `psk2+ccmp` |
| 链路 | 4addr 纯二层，`wireless.wds_z` 段 `network=lan` 进 br-lan |
| 频段 | **5G HE160 桥接**（`11axa + HT160 + ch36`，QSDK `qcawifi.sh` 转 `11AHE160`）；**2.4G 不桥接**（清残留 wds 标记，保留本地覆盖） |
| 设备名 | 主 `WDS-Z` / 客户端 `WDS-K` |
| 命令 | `vs010-wds-pair status` / `set-role master|client|auto` / `apply` / `off` |

### AP 模式
| 机型 | SSID | 密码 | 设备名 |
|---|---|---|---|
| VS010 | `VS010-AP` | `AP123456` | `AP` |
| RAX3000Q | `RAX3000Q-AP` | `AP123456` | `AP` |

只改现有 wifi-iface 的 ssid/key，不改 radio。

> ⚠️ 4addr 是否真正建立、HE160 是否跑满，实机用 `wlanconfig ath1 list` / `wifi-check` 确认；脚本只写 QSDK 官方识别字段 + 一次标准 `/sbin/wifi reload`，不代写未经验证的私有命令。

---

## 7. 插件 / 组件清单

### ✅ 保留（官方底座，原样）
`qca_ol` `umac` `wifi_3_0` `ipq_cnss2`（闭源满血无线）、NSS 硬件 offload 全套、`LuCI` + **Argon 主题**、**TTYD**（`terminal.lua`）、`dropbear` SSH、串口 `ttyMSM0`、`ethtool` / `swconfig` / `iw` / `wlanconfig` / `uhttpd`。

### ✅ 新增（我方运行期注入，全部在 `files/`）
| 组件 | 出厂状态 | 作用 |
|---|---|---|
| `/bridge/` `/ap/` + 3 个 CGI | 启用 | 旧版丰富状态页（CPU/内存/端口/射频/距离/加速/日志） |
| `portstat` | 启用 | 网口速率只读显示 |
| `wifi-check` | 启用 | 无线栈 / BDF / 射频一行取证 |
| `luci-check` | 启用 | 主题不报错一行自证 |
| `vs010-mode` (S99) | 启用 | 首启业务配置（IP/STP/WAN/IPv6/NTP/主题） |
| `vs010-luci-fix` (S18) | 启用 | 抢在 uhttpd(50) 前修 named main / 清 indexcache / 关无证书 HTTPS 重定向 |
| `vs010-wds-pair` (S94) | 仅 WDS | 自动配对主/客户端 + HE160 |
| `vs010-host` | 启用 | 设备名 WDS-Z / WDS-K / AP |
| `ntp-sync` (S96) | 启用 | 300 秒循环同步 |
| `dhcp-guard` (S95) | **monitor** | 无线 DHCP Snooping，只记录不阻断、不重启 |
| `bridge-watchdog` 机器狗 (S97) | 🔴 **出厂停用** `enabled=0 / dryrun=1` | 插件，`bridge-watchdog on` 才启用；ever_ok 保护（从未关联成功绝不重启） |
| `/etc/bridge.conf` | 只读配置 | 旧版 CGI 的 KEY=VALUE 配置，官方 rootfs 无此文件 → 零冲突 |
| `99-vs010-no-ipv6.conf` | 启用 | 关 IPv6 sysctl |

### ❌ 已剔除（不启动 = 不占内存/CPU；物理二进制不删以免破坏 opkg / 无线依赖）
DDNS / ddns-go / UPnP / ZeroTier / **定时重启 autoreboot** / mia / filetransfer / wireguard / quagga / ripd / pppoe / relayd / lldpd / macsec / dhcrelay / cnss_diag / breakpad / diag_socket_app / odhcpd / firewall 的配置、自启链接与 7 个无关 LuCI 控制器。共 36 项，由 `build/prune.keep` 白名单硬断言兜底，**误删即停止出包**。

---

## 8. 主题界面不报错（刷完一行自证）

```sh
luci-check
# RESULT: PASS —— 主题界面具备不报错条件
```

核查结论：4 个页面/CGI 全在 `www/` 下，`fused.py` 的「撞名即停止构建」保证 `etc/config/luci` / `dispatcher.lua` / `uhttpd` / `controller/` / `themes/argon/` 零覆盖。官方 `/etc/config/luci` 本来就是 `config core main`（**named section**）→ `dispatcher.lua:225` 不会取到 nil（旧仓 427 那类错是匿名段造成的）。

`S18 vs010-luci-fix` 修了 4 个真隐患：按段名 `rename`（不 `delete @core[0]` 自毁）、早于 uhttpd、两侧 `/tmp`+`/var` indexcache 全清、**官方无证书却 `redirect_https=1` → 关掉，纯 HTTP 80**、`lua_prefix` 兜底。

---

## 9. 命令速查

```sh
vs010-mode status                # 模式 / IP / STP / 构建版本
vs010-mode set wds|ap            # 切模式
vs010-mode set-ip 172.10.10.241  # 改管理 IP
vs010-mode stp on|off            # STP
vs010-wds-pair status            # WDS 角色 / HE160 / 对端 / 设备名
vs010-wds-pair set-role master|client|auto
bridge-watchdog status           # 机器狗（出厂停用）
bridge-watchdog on|off|dryrun on|set-delay N|set-peer IP
ntp-sync status                  # 轮次 / 距下轮
ntp-sync set-interval 300
dhcp-guard status                # Snooping
portstat                         # 网口速率
wifi-check                       # 无线取证
luci-check                       # 主题自证
```

---

## 10. 目录结构

```
.github/workflows/     构建入口（Build 5.4 firmware / Build source）
build/
  fused.py             官方 factory.bin → 融合固件（kernel FIT 原样 + rootfs 叠加）
  build.sh             本地/云端打包 + rc.d 链接 + 精简 + 断言
  prune.list           剔除清单      prune.keep  白名单（误删即停）
  verify.sh            总自检
files/                 两机型两模式共用叠加层（全部运行期文件）
files.vs010/ files.rax3000q/   机型差异层
3000Q-VS010-固件/      两份官方 factory.bin + ART / DTS / U-Boot（未改动）
vs010/                 r1 无线修复相关源码
CHANGELOG.md           一行一次的更新记录
修复说明.md            每轮根因 / 修法 / 验证 / 边界
```

---

## 11. 自检与边界

`sh verify.sh` 覆盖：命名带 5.4、两机型两模式、官方文件被修改 0、kernel FIT 逐字节一致、25 项白名单、主题 427 守卫、WDS/AP/NTP/HE160/设备名、WAN 每次开机删、旧 CGI 实跑 JSON 合法。

⚠️ **如实边界**：
- 没实机、没跑 GitHub Actions 的 `make`；融合构建在沙盒真跑通过，刷机环节（ART / U-Boot / 机型对应）不在固件里。
- 物理二进制不删，flash 占用几乎不变；**不启动才是不占资源的关键**。
- `kernel.panic=3` 保留（真 panic 时可抓日志重启，不设 0 —— 0 会永久停死）。
- 要 100% 回到「原厂逐字一致」的无线行为，可把 `vs010-wds-pair` 默认关掉（见修复说明）。

---

## 12. 更新记录（详见 `CHANGELOG.md` / `修复说明.md`）

| 次 | 要点 |
|---|---|
| 1 | 好固件叠加底座，无线修复（kernel FIT / BDF / 闭源驱动零改动） |
| 2 | WDS/AP 双模式 + 双可视化 + TTYD / 机器狗 / NTP / STP / IP / Snooping / 速率 |
| 3 | 关 IPv6、WAN+LAN 桥接、自动配对、精简 36 项、关防火墙、修 SSH/串口、rc.d 链接 |
| 4 | Argon 保留、WDS 主/客户端、NTP 三台 5 分钟、`172.10.10.241/22` |
| 5 | 换回旧版丰富状态页、AP 机型 SSID、设备名、HE160、2.4 不桥接、WAN 每次开机删 |
| 6 | 主题 427 核验 + `S18 vs010-luci-fix` + `luci-check` |
| 7 | **仓库主页详版说明 + 下载页补齐 IP / 设置 / 插件清单**（纯文档，编译链零改动） |
| 8 | **ART 每机自读 / 网口速率 PHY 实测兜底 / Argon 主题速率页 / 实机清单回灌**（无线栈零改动） |
| 9 | **导出脚本随固件刷入 + 清单上传仓库后 Actions 自动出优化版固件**（完整操作见第 14 节） |
| 10 | **修 CI `Init` 失败**：上传丢可执行位（全 664）→ `build.sh` 注入前强制 755、自检不依赖 mode、去掉 PyYAML 依赖 |
| 11 | **复查补漏**：第 10 次负例写死开发机绝对路径（本地 PASS 是假象，runner 必挂）→ 改 `os.getcwd()` + 工具守卫；只改 `build/verify.sh` 1 个文件 |

---

## 13. 第 8 次：ART、速率显示与「实机优化版」回灌

### 13.1 ART 不用搬，也不用清

解析两份官方 `factory.bin`（各 209 PEB）的 UBI 卷表，只有三个卷：

```
layout(0x7fffefff) / kernel(vol 0) / rootfs(vol 1)
```

**没有 ART 卷**。ART / caldata 是独立 MTD 分区（本仓 `3000Q-VS010-固件/VS010-smem_0-ART.bin`，1 MB），刷 `factory.bin` 只写 kernel + rootfs，**不覆盖 ART**。所以每台机器刷完由官方闭源栈自动读自己的那份校准数据，MAC 也由 `board.d/02_network` 按本机 ART 生成。

🔴 需要清掉的不是 ART，而是**实机 merged rootfs 里已经生成好的机器唯一数据**：`/etc/config/network|wireless` 里写死的 MAC、`/etc/shadow`、dropbear host key、`/etc/hostname`、首启 stamp、`172.10.10.241`。`tools/rootfs-capture.sh` 全部硬排除，打包后还有断言复查。

### 13.2 网口速率：显示层纠偏，不动驱动

官方 5.4.213 闭源 `qca-nss-dp` 的 netdev 不上报协商速率（`/sys/class/net/ethX/speed` 报 `-1` 或 `10M/Half`），**链路实际是通的**。没有命令能让驱动改成显示 1000；强设 `ethtool -s` 反而会断链。

`portstat` 现在会去交换芯片读 **PHY 实测值**（`swconfig dev switch0 show` 的 `speed:` / `duplex:`）并标注来源，读不到就如实写「未上报」，绝不写死假速率：

```sh
portstat              # 人读表格，带来源
portstat --json       # 旧 CGI 用
portstat --rows       # Argon 主题页用
```

**主题界面入口**：`/cgi-bin/luci/admin/status/vs010_ports` → Argon 主题里的「网口速率」页（新增 `vs010_ports` controller + view，**零覆盖官方文件**）。旧版丰富页 `/bridge/` `/ap/` 仍自带同源 `phy_link_probe()`。LuCI 原生概览页是官方文件，没动，仍可能显示 10M/未知。

### 13.3 实机关完服务 → 导出 → 回灌出「优化版」

```sh
# 设备侧（脚本已随固件刷入；删完先静置 12 分钟 + wifi-check 确认不重启）
sh /usr/sbin/vs010-capture                # → /tmp/prune-real.txt + installed.txt
sh /usr/sbin/vs010-capture --tar          # 可选：净化后的 rootfs 参考包

# PC 侧（只回灌【清单】，不做整树替换 → kernel FIT / BDF / 闭源驱动仍是官方原卷）
sh tools/build-from-capture.sh --capture=capture/prune-real.txt --device=all --mode=all
```

回灌脚本带**无线栈硬护栏**：清单里出现 `lib/firmware` / `lib/modules` / `bdwlan` / `qca_ol` / `ART` / `etc/config/network` 等即拒绝；先跑 `sh verify.sh` 再出 4 个固件（仍带 `5.4`），`prune.keep` 白名单在 `fused.py` 里二次兜底，误删即停止出包。

⚠️ 这样得到的是「可刷任意多台同机型、无线不变、杂项服务不跑」的固件；**再删二进制只省几 MB flash，不会让内核更快**（服务本来就没启动）。`opkg remove` 前先 `opkg whatdepends <包名>`，别带走 `uhttpd` / `libuci`。

> 跨机型不行：VS010 / RAX3000Q 的 DTS、BDF、ART 不通用，只能同机型克隆。

---

## 14. 完整操作：刷完 → 删插件 → 导出 → 上传仓库 → 出优化版固件

> **第 9 次修复**补通了这条闭环：导出脚本随固件刷入 `/usr/sbin/vs010-capture`，`capture/prune-real.txt` 上传后 Actions 自动回灌出固件。

🔴 **先说破一个误区**：**设备上不会生成 `.bin` 固件**。`dd` / `nanddump` 整片拷出来不能直刷（会带 ART / MAC / IP / 密钥 / 首启 stamp，第二台必冲突或无线坏）。设备只导出**一份文本清单**（你删了哪些路径），`.bin` 永远在仓库 / PC 上以官方 `factory.bin` 为底座重新合成。

### 步骤 1 · 刷 r9 固件并确认健康

`Actions → Build 5.4 firmware`（device=all / mode=all）→ 下载对应机型+模式的 `Nwrt-QSDK12.2-5.4-*.bin` → U-Boot web failsafe 刷入（PC `192.168.1.8`、LAN1、按复位通电），**别勾「保留配置」**。

```sh
wifi-check; portstat; luci-check; uptime
ssh root@172.10.10.241      # 密码 password
```

### 步骤 2 · 删你不想要的插件/服务（在设备上）

```sh
opkg whatdepends <包名>     # 🔴 先查依赖，别带走 uhttpd / libuci / luci
/etc/init.d/<服务> stop
/etc/init.d/<服务> disable  # 必须 disable：只 stop 重启会回来，也不留删除标记
opkg remove <包名>          # 真删时才用；只读 squashfs 上会写 overlay whiteout
```

想留个后路就先只 `disable`，验证几天没问题再 `remove`。**别碰** `qca_ol` / `umac` / `wifi_3_0` / `ipq_cnss2` / `ttyd` / `dropbear` / `uhttpd` / `luci` / Argon。

### 步骤 3 · 验证「删完服务仍正常」（不可跳过）

```sh
wifi-check && portstat && luci-check
# 浏览器开 /bridge/ 或 /ap/、/cgi-bin/luci/、/ttyd/
uptime                       # 🔴 静置 12 分钟不归零，确认不自动重启
```

任何一项不对，先 `opkg install` 装回来或重新刷，别带着坏状态导出。

### 步骤 4 · 导出清单（脚本已随 r9 固件刷入）

```sh
sh /usr/sbin/vs010-capture
#   → /tmp/prune-real.txt   （overlay 里的删除标记 = 你真正删掉的路径）
#   → /tmp/installed.txt    （已装包清单，交叉核对用）
cat /tmp/prune-real.txt     # 自己看一眼，通常几十行
```

可选 `sh /usr/sbin/vs010-capture --tar` 生成净化后的 rootfs 参考包（**只供比对，不拿来当注入层**）。它硬排除 ART / MAC / `/etc/shadow` / dropbear host key / hostname / 首启 stamp / `172.10.10.241`，打包后还有断言复查，混进机器唯一数据会直接删包退出。

### 步骤 5 · 把清单取回电脑

```sh
# 在电脑的终端里（不是路由器上）：
cd ~/WDS-AP-5.4-VS010-RAX3000Q
mkdir -p capture
scp root@172.10.10.241:/tmp/prune-real.txt ./capture/prune-real.txt
```

没 SSH 就用串口 `cat /tmp/prune-real.txt`，把文字复制成同名文件；或在 TTYD 里 `base64 /tmp/prune-real.txt` 贴回来解码。

### 步骤 6 · 本地先干跑一次（强烈建议）

```sh
sh tools/build-from-capture.sh --capture=capture/prune-real.txt --dryrun
```

会做三件事：① 护栏检查（含 `lib/firmware` / `bdwlan` / `qca_ol` / `ART` / `etc/config/network` 等即拒绝）② 幂等追加到 `build/prune.list` ③ 跑 `sh verify.sh`。**不构建**，纯看有没有被挡。看到 `RESULT: PASS` 再往下。

### 步骤 7 · 两条路出固件，任选

**A. 推仓库让 Actions 出（推荐，可重复、可追溯）**

```bash
git add -A && git commit -m "实机删除清单" && git push
# Actions → Build 5.4 firmware → Run workflow（device=all / mode=all）
```

workflow 的 `Apply captured prune list` 步会自动发现 `capture/prune-real.txt` → 回灌 → `verify.sh` → Build → 出 4 个 Release（名字仍带 `5.4`）。**以后每次编译都自动带上这份清单**，不用重复操作。

**B. 本地直接出（不等 Actions）**

```sh
sh tools/build-from-capture.sh --capture=capture/prune-real.txt --device=all --mode=all
# 4 个 .bin 直接落在仓库根目录，可自己传 Release
```

### 步骤 8 · 刷到别的同型机

按机型严格对应（`cucc_vs010` ↔ VS010、`cmcc_rax3000qy` ↔ RAX3000Q），U-Boot web failsafe 刷 `factory.bin`，**别勾「保留配置」**。每台机器自动读自己的 ART、生成自己的 MAC，首启脚本重新跑一遍设 IP / 密码 / 主题。

```sh
wifi-check; portstat; luci-check; ip -4 addr show br-lan; uptime
```

### 常见疑问

| 问 | 答 |
|---|---|
| 两台机型要各导一份吗 | 不用。清单是**通用运行期路径**，机型相关固件路径会被护栏挡掉；同一份给 4 个组合用 |
| ART 要不要一起导 | **不要**。ART 是独立 MTD，刷机不覆盖，每台自读 |
| 删二进制会让内核变快吗 | 不会。服务本来就没启动，内存/CPU 早就省了；只省几 MB flash |
| 清单传上去后想撤销 | 删掉 `capture/prune-real.txt` 再 `git push`；`prune.list` 里的 `FROM CAPTURE` 块也可整段删 |
| 清单里出现禁止路径 | 构建会**早停**并打印具体行，删掉那几行重新提交即可 |

---

## 15. 第 10 次：CI `Init` 报 `exit code 1` 的真相

**现象**：`Build 5.4 firmware` 的 `Init` 步 13 秒失败，annotation 写 `Process completed with exit code 1`；页面里 `This step has been truncated` / `There was an error while loading` / `Sign in to view logs` 是 GitHub 页面渲染与未登录提示，`Node.js 20 is deprecated` 只是 warning —— 都不是原因。

**根因**：仓库里所有文件被记成 `100644`（`664`）。GitHub 网页上传、Windows 解压 zip、或 `core.filemode=false` 都会抹掉 unix 可执行位。`Init` 里 `sh verify.sh` 的三处 `-x` 断言（CGI / `luci-check` / `portstat`）FAIL → 退出 1。

🔴 更严重的是：`fused.py` 用 `shutil.copy2()` 注入文件，**沿用源 mode**。就算放它过 CI，刷出来的固件里 `/www/cgi-bin/*`、`/etc/init.d/*`、`/usr/sbin/*` 也是 664 → 丰富页面打不开、首启脚本不跑。

**修法**：`build.sh` 在打进固件前统一 `chmod 755`（脚本类）/ `644`（其余），**从此不再依赖 git 里存的 mode**；`verify.sh` 三处断言改为「文件在位 + 构建期有 chmod 兜底」；两处 `import yaml` 改纯文本解析，去掉对 runner 预装 PyYAML 的依赖。

**验证**：把整棵仓库树故意抹成 `664` 再真跑构建 → 成功出包 → 解包回读固件内 6 个关键脚本，**全部 755**。所以传 r10 之后**不需要**手工 `chmod` / `git update-index --chmod=+x`，直接重跑 Actions 即可。

想自查线上 mode：

```bash
git ls-files -s | awk '$1=="100644" && $4 ~ /^(files|tools)\// {print}' | head
```

**第 11 次补漏**：r10 上传后复查发现，第 10 次的负例里写死了开发机路径 `/data/workspace/_newrepo`。本地自检 PASS 是假象 —— GitHub runner 上是 `/home/runner/work/...`，`copytree` 会抛异常让 `Init` 再次退出 1。已改成 `os.getcwd()`（本脚本开头已 `cd` 到仓库根）并加 `shutil.which` 工具守卫。验证方式：临时移走本地目录，在线上全 664 快照里跑 `sh verify.sh`，仍 PASS。**这一版只改 `build/verify.sh` 一个文件**，编译链、底座、无线栈零改动。

---

## 16. 第 12 次：双机型共用「实机保留基线」

设备刷的是**最干净的好固件**（没打过我方注入层），只把没用的插件/服务关掉。此时：

```sh
opkg list-installed > /tmp/installed.txt
find /overlay -name '.wh.*' …        # 🔴 输出为空是【正常】，不是命令没反应
```

空输出说明当时是 `stop + disable` 而不是 `opkg remove`，overlay 里没有 whiteout 删除标记 —— **不用再导任何东西**。`installed.txt`（还剩哪些包）本身就是最可靠的依据，存成 `capture/installed-allowlist.txt` 即可。

`tools/apply-installed-baseline.sh` 把它作为 **VS010 / RAX3000Q 两个机型共用**的保留标准：

- 基线**里**的包（5.4.213 闭源栈、Argon、TTYD、SSH、ethtool/swconfig…）→ 一律保留；
- 基线**外**的杂项（DDNS / UPnP / ZeroTier / WireGuard / 定时重启 / odhcpd / firewall / dnsmasq…）→ 只删 UCI 配置、`rc.d` 自启链接、LuCI 控制器；**二进制与内核模块不删**（不启动就不占内存 CPU，也不冒破坏闭源依赖的风险）；
- 护栏：基线缺 5.4.213 闭源栈 / Argon / TTYD / SSH 任一项，或回灌块与 `prune.keep` 有交集，直接拒绝出包；写入幂等，重复运行不累积。

`Actions → Build 5.4 firmware` 新增 `Apply installed baseline (both devices)` 自动回灌；同时显式写入 `permissions: contents: write`，钉死之前 `Resource not accessible by integration` 那个 Release 权限问题（不再依赖仓库 Settings）。

**无线一字未动**：全量逐文件比对两机型均为「官方 rootfs 被修改 0 / 删除 38 项全是杂项 / 新增 37 项全是我方注入」，kernel FIT 卷 `4063232 B` 逐字节一致，4 个闭源 `.ko` + `bdwlan.b10/b60` MD5 全一致。之前所有插件与配置（IP `172.10.10.241/22`、root/admin、NTP 三台 5 分钟、WDS-Z/K、AP 机型 SSID、HE160、Argon 速率页、SSH/串口/TTYD、机器狗出厂停用）照旧。

---

## 17. 第 13 次：实机反馈的两个 BUG（已修）

刷完发现「**登陆密码不是 admin**」「**5G 出现两个 SSID**」，根因都在运行期脚本，不在无线栈：

| 现象 | 根因 | 修法 |
|---|---|---|
| 密码不是 admin | 官方 `/etc/shadow` 是 `root::`（空）。旧 `printf 'admin\nadmin\n' \| passwd root` 在 squashfs 只读底层 + 非 tty 下静默失败，而 `apply()` 不管成败都写 `applied` stamp，之后每次开机见 stamp 就 `return` → 密码永远没设上；LuCI 首登还会因空密码强制用户自己设一个 | 固定 MD5-crypt（`$1$VS010Z$…`，= `openssl passwd -1 -salt VS010Z admin`）直接写 overlay；`fix_login()` 在 **`scrub()` 每次开机** + **`apply()` 的 stamp 检查之前** 各跑一次，幂等；SSH / LuCI / 串口同读 shadow，一处修三处好 |
| 5G 两个 SSID | 官方 QSDK 首启给 5G 生成多个 `wifi-iface`；旧脚本再**新增** `wireless.wds_z`，且 `vs010-mode` 把 `wifi-device` **和 `wifi-iface` 一起** `disabled=0` → 原厂 SSID 与 `WDS-Bridge-Z` 同时广播 | **不再新增段**：`converge()` 复用 5G 上第一个 `wifi-iface` 作唯一 WDS VAP，同 radio 其余 `disabled=1`（不删段，保住闭源 VAP 索引）；只清 `wifi-device` 的 disabled；AP 模式同样按 radio 分组只留一个；`scrub()` 开机即收敛，不等 loop 的 35 秒 |

**刷完 4 行自证**：

```sh
grep '^root:' /etc/shadow                 # 第二字段应为 $1$VS010Z$UZ4qew78etSeRS5gXbjrR1
ssh root@172.10.10.241                    # 密码 password
uci show wireless | grep -E '=wifi-iface|ssid|disabled'   # 5G 应只剩 1 个 disabled=0 且 ssid=WDS-Bridge-Z
vs010-wds-pair status                     # 显示「唯一 WDS 段 / 5G 仅 1 个 SSID」
```

若极少数机型的 crypt 后端不认 `$1$`，串口敲一次 `passwd root` 手动设 `password` 即可（脚本下次开机会再归一）。

**这轮没动**：`build/prune.list` / 实机保留基线 / workflow / `fused.py` / 官方底座 / BDF / 驱动 / ART。自检新增两个真跑 mock：空密码→password hash（openssl 反算一致、其它账号不变、二次幂等）；2 个 5G VAP → 仅 1 个 `WDS-Bridge-Z`（2.4G 不动、HE160、二次幂等）。

---

## 18. 第 14 次：固件长期保存，只保留 5 个

| 载体 | 保存时长 | 说明 |
|---|---|---|
| **Releases**（正式来源） | **永久** | 每个 Release 挂 1 个 `.bin` + `.sha256`，不会过期 |
| Actions artifacts | 90 天 | `retention-days: 90`（GitHub 上限），仅临时下载，会过期 |

`Build 5.4 firmware` 末尾新增独立 `cleanup` job（`needs: build`）：等 4 个 matrix job **全部发完**再按创建时间倒序清理，只删 `fw-5.4-` 前缀的旧 Release 并连带删 tag，**不会误删手动建的 Release**，也不会并发互删。

```yaml
env:
  KEEP_RELEASES: 5      # 改数字即可：20 = 保留 5 轮构建（20 个固件）；0 = 不清理
```

一次 `device=all / mode=all` 出 4 个 Release，所以默认「保留最新 5 个」= 当前一轮 4 个 + 上一轮最新 1 个；再跑一次就把更早的挤掉，Releases 页始终 ≤5 条，干净且随时有固件可下。

⚠️ 清理只在 4 个构建 job 全成功时执行；某个 job 失败则本轮不清理（旧固件不会被误删）。已下载的 `.bin` 不受影响。

---

## 19. 第 15 次：实机两张图逐条对照 + 操作手册

图里是 `172.10.10.241/cgi-bin/luci/admin/status/overview`：Argon 主题、`WDS-Z`、左侧已有「网口速率」，5G 协商 **2401 Mbit/s**（HE160 满血，无线本身是好的），但 **5G 同时广播 `Nwrt_5G` + `WDS-Bridge-Z`**，LAN 高级设置里「使用内置的 IPv6 管理」还勾着。

🔴 **先说破：这是 r12 及更早的固件**（r13 才修密码/双 SSID，r12 才加实机基线）。下面这些在这版里都已修好，**必须重刷 r15 才生效**：

| 你提的 | 状态 / 做法 |
|---|---|
| 网桥和 AP 都开 MU-MIMO + WMM | ✅ 字段名全部来自官方 `lib/wifi/qcawifi.sh`（`config_get_bool wmm "$vif"`、`he_ulmumimo` / `he_mubfer` / `he_dlofdma` / `he_ulofdma`），hostapd 内建 `wmm_enabled=1`；WDS 主 VAP 与 AP 每个 enabled iface 都写 |
| AP 剔除弱信号 / 弱信号拒绝连接 | ✅ QSDK 私有 `db_rssi_thr` + `db_timeout`（`iwpriv` 下发）。阈值改 `/etc/vs010/weak.rssi`（默认 `-70`，单位 dBm），改完 `wifi reload` |
| 5G 还是两个 SSID | ✅ r13 `converge()` 复用首个 5G VAP + 其余 `disabled=1`；r15 再加 `wifi_single_5g()` 内联兜底（不依赖外部脚本）+ 15 秒重试。只留 `WDS-Bridge-Z` |
| 无线 MAC 读 ART，不要手动填 | ✅ 全仓**零硬编码 MAC**；`mymac()` 读 `/sys/class/net/br-lan\|eth0\|eth1/address`（驱动按本机 ART 生成），WDS 配对/BSSID 全由此来 |
| 关闭所有 IPv6 | ✅ `kill_ipv6()` 每次开机：删 `ip6assign/ip6prefix/ip6class/ip6hint/ip6ifaceid`、ULA、`wan6`、`dhcp.wan6`；`ra/dhcpv6/ndp=off`；`all/default` + **逐个网卡** `disable_ipv6=1`；停 odhcpd |
| 密码还是好固件内置 password | ✅ r13 `fix_login()` 固定 hash 每次开机在 stamp 之前写 overlay；SSH / LuCI / 串口同密 `password` |
| 防火墙没关 | ✅ 构建期删 `etc/config/firewall` / `S19firewall` / `controller/firewall.lua`；运行期 `kill_firewall()` 每次开机 stop+disable+`iptables -F/-X`+`nft flush ruleset` |
| 网桥界面内置到主题 | ✅ Argon「状态」菜单新增 **网桥状态 / AP 状态 / WDS·机器狗·Snooping 控制台**（iframe 内嵌 `/bridge/` `/ap/`，原页面 CGI 一字未改，零覆盖官方 LuCI 文件） |
| 🔴 WDS 有 DHCP 会乱网 | ✅ 本机出厂 `dhcp.lan.ignore=1` + 停 `dnsmasq`，**wds 与 ap 都关**；<u>**客户端那台也绝不能开 DHCP**</u>。开机日志 `[!!! DHCP !!!]`、CHANGELOG、本页、Release 下载页全部标红划线 |

### 刷完 10 行自证

```sh
grep '^root:' /etc/shadow                          # $1$VS010Z$UZ4qew78etSeRS5gXbjrR1 = password
ssh root@172.10.10.241                             # 密码 password
uci show wireless | grep -E '=wifi-iface|ssid|disabled|wmm|he_ulmumimo|db_rssi_thr'
                                                   # 5G 只 1 个 enabled，wmm/he_ulmumimo=1，db_rssi_thr=-70
uci -q get network.lan.ipv6; ip -6 addr            # 0 / 无 v6 地址
uci -q get dhcp.lan.ignore; ps | grep dnsmasq      # 1 / 无进程
/etc/init.d/firewall status; iptables -L -n        # 未运行 / 空规则
vs010-wds-pair status                              # 唯一 WDS 段 / 5G 仅 1 个 SSID
logread | grep '\[!!! DHCP !!!\]'                  # 开机红字警示
```

### 机器狗怎么设置（出厂停用，不会自己重启）

```sh
bridge-watchdog status          # 看 enabled / dryrun / ever_ok / peer
bridge-watchdog on              # 启用：enabled=1 + dryrun=0 + 起守护
bridge-watchdog dryrun on       # 先只演练不真重启（推荐第一次这样试）
bridge-watchdog set-peer 172.10.10.240    # 手动指定对端；auto = 自动解析
bridge-watchdog set-delay 5; bridge-watchdog set-interval 30; bridge-watchdog set-grace 6
bridge-watchdog off             # 停用
```

🔴 **ever_ok 保护**：从未成功关联过对端时**只记录、绝不重启**。WDS 自动配对解析到对端 IP 会自动 `set-peer`。

### 无线 DHCP Snooping 开了吗？怎么查

```sh
dhcp-guard status               # mode / 最近 OFFER 计数
dhcp-guard once                 # 立刻扫一轮
logread | grep dhcp-guard       # monitor 模式只记录，不阻断、不重启
dhcp-guard on                   # 才切到阻断（会装 ebtables 规则，确认无误再开）
dhcp-guard off                  # 回 monitor
```

默认 **monitor（只记录）**，这是刻意的安全档：无线侧若真有第二个 DHCP，日志里能看到 `可疑 DHCP OFFER` 而不会把网络打断。配合上面「两端都不发地址」才是根治。

### 主题里的入口

`/cgi-bin/luci/` → 左侧「**状态**」→ 网桥状态 / AP 状态 / **WDS·机器狗·Snooping 控制台** / 网口速率。控制台一页同时显示 WDS 角色、机器狗、Snooping、IPv6 地址、DHCP ignore、防火墙状态。

> 图里「状态 → 防火墙」那个菜单是 LuCI 自带的**状态页**（`admin/status/iptables`），不是服务，菜单项本身不会消失。r15 构建期删的是 `etc/config/firewall` / `S19firewall` / `controller/firewall.lua`，运行期再 `stop+disable+iptables -F/-X+nft flush ruleset`。判断真关没关看 `/etc/init.d/firewall status` 与 `iptables -L -n`，别看菜单。


---

## 20. 第 15 次追加：三张实机图 + 「网桥也要」全部落地

第三张图是 **AP 界面**的「网络与本机 · NETWORK」三卡（网桥 / 地址分配 / 固件），你要求网桥界面也要、AP 界面补网口速率、两页只显示已插线口、系统总览速率与 IPv6 一起修。

| 项 | 做法 |
|---|---|
| **网桥页也显示 NETWORK 三卡** | `/bridge/` 新增 `<div id="netgrid">`，与 AP 页同款三卡；WDS 卡显示角色（主 `WDS-Z` / 客户端 `WDS-K`），不再写死「另一套固件」 |
| **AP 页补网口速率** | 两页都新增「**已插网线 · LINK UP**」精简表，由共用端点 `/cgi-bin/vs010-links` 供数；只有 `carrier=1` / `ethtool yes` 的口才出现 |
| **太多太乱 → 收敛** | 网桥原「端口四宫格」过滤掉未插线口；`portstat` 默认只列已插线以太网口（`--all` 才看全部）；Argon「**已插网线速率**」页改取 `portstat --rows-up`，去掉「说明」列 |
| **系统总览 IPv6 块** | 构建期删 `usr/sbin/ip6tables` 符号链接 → 官方 overview 的 `has_ipv6 = fs.access(...)` 变 false → **IPv6 WAN Status / DUID / IPv6-Address 三块自动消失**，零覆盖官方视图；`iptables` 仍是指向同一个 multi 的另一条链接，不受影响 |
| **主题里的网口速率显示不正常** | 统一改读交换芯片 PHY 实测值并标注来源，不写死假 1000M；总览页不再残留 IPv6 空块，速率统一到主题「已插网线速率」页与两个丰富页 |
| **AP 弱信号命令真能用** | 补 `ap-rssi-guard`（`status` / `dryrun on` / `off` / `on` / `set reject -90` / `set kick -92` / `set interval 3` / `loop`），写 `ap-rssi-guard.main.*` 并把 `reject_dbm` 同步进 QSDK `db_rssi_thr`；AP 页 CGI 读的正是这套 UCI 字段 |
| **登录密码** | 🔴 按最新指令定为 **`admin`**：上一版 `PW_HASH` 是带 `...` 的占位串（不是合法 crypt）且注释写着 `password`；第 16 次换成 `openssl passwd -1 -salt VS010Z admin` 的真实值，自检用 openssl 反算校验。SSH / LuCI / 串口同密 |

### 刷完一行看新页

```sh
portstat                      # 只列已插网线口 + PHY 实测
portstat --all                # 需要排障时才看全部
ap-rssi-guard status          # AP 弱信号阈值 / 统计
dhcp-guard status             # 无线 DHCP Snooping（默认 monitor）
bridge-watchdog status        # 机器狗（默认停用）
```

浏览器：`/cgi-bin/luci/` → 状态 → **网桥状态 / AP 状态 / 已插网线速率 / WDS·机器狗·Snooping 控制台**。

> 旧仓那两个丰富页 HTML/CGI 仍是**逐字节替换过来的原件**，本轮只在它们里面加区块和过滤，没有重写；新增的 `vs010-links` 是独立端点，失败也不影响主页面渲染。


---

## 20. 第 16 次：信道自动 / 网桥网络设置 / 主题新版说明

### 信道改成自动

官方 `lib/wifi/qcawifi.sh:1846` 写着 `[ auto = "$channel" ] && channel=0` —— **`auto` 是 QSDK 原生合法值**，转 0 后由 ACS 自动选道；后面的 `[ $channel -eq 36 ]` 拿到 0 不会崩。`vs010-mode` 的 `auto_channel()` 每次开机把**所有** `wifi-device` 写 `channel=auto`，防官方 `board.d` 又生成固定信道。HE160 不变：`hwmode=11axa` + `htmode=HT160` → `qcawifi.sh:2578` 转 `11AHE160`。

### 网桥弱信号（「网桥那也要有」）

`vs010-wds-pair` 的 WDS 主 VAP 与 AP 同口径：`db_rssi_thr`（-70，改 `/etc/vs010/weak.rssi`）+ `db_timeout=10`。字段来自官方 `qcawifi.sh:2617/2620` 的 `iwpriv` 下发，剔除与拒绝连接都开。

### 🔴 网桥页「网络设置」真 BUG 已修

之前 `/bridge/` 定义了 `drawNetCards()` 却只靠 `/cgi-bin/vs010-links` 兜底，主 CGI 从没调用 `drawNet(j)`；共用端点一失败，`netgrid` 整块空白——这就是「AP 有网络设置、网桥没有」。现在**主 CGI 直接渲染**（网桥/地址分配/固件三卡，含 🔴 双 DHCP 红字划线），`vs010-links` 只作兜底。

**只显示上线网卡**：`vs010-links` 对 `carrier=1 / operstate=up / ethtool Link detected: yes` 三重判定，未插线的口根本不返回；主 `/bridge/` `/ap/` 的 `ports` 也再过滤一次。NSS netdev 不上报时改读交换芯片 **PHY 实测**并标注来源。

**MAC**：`vs010-links` 新增 `mac` 字段，从 `br-lan`/`eth0` 的 sysfs 读（驱动按本机 **ART** 生成），全仓零硬编码 MAC。

### Argon 新版：拉到了，但不整体替换

上游 `jerrykuku/luci-theme-argon` **v3.2.0 / 2026-11-24**（11 MB / 323 条目）已拉取，关键元数据留档 `reference/argon-upstream/` + 说明 `reference/ARGON-NOTE.md`。它是 **ucode 模板 + menu.d + rpcd** 架构，本机是 **Lua 模板 + controller** 的 `argonv3 1.7.2`；硬换会让后台打不开（违反「系统不能再出 BUG」），CSS 类名也已重写会花屏。**所以留档不替换**。

速率显示错误根因是 QSDK 闭源 `qca-nss-dp` 的 netdev 不上报（`-ENODEV`），**换主题修不了**；正确值在 Argon「状态 → 网口速率」、`/bridge/`、`/ap/`（PHY 实测）。`prune.keep` 已把官方 Argon 9 个关键文件列进白名单，构建期一个字节不许动。

### 刷完自证（新增项）

```sh
uci show wireless | grep -E 'channel|wmm|he_ulmumimo|db_rssi_thr|ssid|disabled'
# 全部 wifi-device channel=auto；wmm/he_ulmumimo=1；db_rssi_thr=-70；5G 只 1 个 enabled
grep '^root:' /etc/shadow                 # admin
ip -6 addr; uci -q get network.lan.ipv6   # 空 / 0
uci -q get dhcp.lan.ignore; logread | grep '\[!!! DHCP !!!\]'
/etc/init.d/firewall status; iptables -L -n
bridge-watchdog status; dhcp-guard status
```

### 机器狗 / Snooping / 防火墙（重申）

```sh
bridge-watchdog status | on | dryrun on | set-peer auto | off
dhcp-guard status      # 默认 monitor，只记录不阻断；on 才启用 ebtables 阻断
dhcp-guard once; logread | grep dhcp-guard
/etc/init.d/firewall status; iptables -L -n   # 未运行 / 空规则
```

机器狗**出厂停用**（`enabled=0 / dryrun=1`），`ever_ok` 保护保证从未成功关联绝不重启。LuCI「状态 → 防火墙」是自带**状态菜单**，r15 已连控制器一起删；判断真关没关看上面两条命令，别看菜单。


---

## 21. 第 17 次：能用的新版 Argon + WDS 主/客开关（两机型通用）

### 主题：不是「拉不到」，是之前找错了版本

逐个解包上游 tag 核实：

| tag | 模板 | rpcd | 结论 |
|---|---|---|---|
| 本机好固件 | `argonv3 1.7.2` · Lua `.htm` | 无 | 基线 |
| **v2.4.3 (2025-07-22)** | **Lua `.htm` ×6** | **0** | ✅ **最后一个兼容版，已注入** |
| v2.4.4 / 2.4.5 / 2.4.8 | ucode `.ut` ×6 | 2 | ❌ 架构断了 |
| v3.2.0 (2026-11-24) | ucode + menu.d + ACL | 4 | ❌ 后台打不开 |

v2.4.3 的 `Makefile` 是 `PKG_VERSION:=2.4.3 / PKG_RELEASE:=20250722`、`LUCI_DEPENDS:=+curl +jsonfilter`，**零 ucode / 零 rpcd / 零 menu.d**。相对 1.7.2 的改进：移除 jQuery 依赖、Pure CSS 3.0、Google Sans woff2 字体、CSP/XSS/点击劫持安全头、菜单动画重写、暗色修正、移动端与 PWA 适配 —— 正好服务于「设备内查看配置、设置」。

**注入方式：新增独立目录，零覆盖官方**：

- 模板 `usr/lib/lua/luci/view/themes/argon2/`（6 个 `.htm`）
- 静态 `www/luci-static/argon2/`（CSS/字体/图标/背景 28 项）
- 模板里唯一两处硬编码 `/www/luci-static/argon/css/dark.css` 改成 `argon2`
- 登录页 `sysauth.htm` 沿用**官方 1.7.2 实机验证过**的那份：v2.4.3 那份会调不存在的 `/usr/libexec/argon/online_wallpaper` 且本机缺 `curl`，会拖慢/报错登录

官方 `argon` 目录一个字节没动，`prune.keep` 已锁死官方 Argon 9 项。**默认仍是 1.7.2**，新版有问题一键切回。

```sh
vs010-theme status       # 看当前主题
vs010-theme argon243     # 切到 v2.4.3
vs010-theme argon        # 切回官方 1.7.2
```

LuCI「状态 → **主题与 WDS 角色**」页有两个按钮；也可「系统 → 语言与界面 → 设计」选 `Argon_243`。切换只改 `luci.main.mediaurlbase` + 清缓存 + 重启 uhttpd，**不重启机器、不动网络、不动无线**。S18 `vs010-luci-fix` 每次开机注册 `Argon_243`，且本轮修掉了「无条件把主题打回 argon」会覆盖用户选择的真 BUG。

### WDS 主 / 客户端开关：进系统自己选，不用重刷

| 角色 | 设备名 | 管理地址 | 掩码 |
|---|---|---|---|
| **WDS 主** | `WDS-Z` | `172.10.10.241` | `255.255.252.0` (/22) |
| **WDS 客户端** | `WDS-K` | `172.10.10.242` | `255.255.252.0` (/22) |
| AP 模式 | `AP` | `172.10.10.241`（恒定，不受开关影响） | /22 |

```sh
vs010-role status      # 看当前模式/角色/IP/设备名/指定方式/DHCP
vs010-role master      # 本机 = 主 WDS-Z → .241
vs010-role client      # 本机 = 客户端 WDS-K → .242
vs010-role auto        # 恢复按 MAC 字典序自动收敛
```

两台设备各自进系统选一次即可。命令会写 `/etc/vs010/role` + `/etc/vs010/ipaddr`，复用已验证的 `vs010-wds-pair set-role`（只 `converge` + 一次 `/sbin/wifi reload`，**不碰 IP、不重启机器**），3 秒后 `network reload` 让新 IP 生效。

🔴 **切完请用输出里的新地址重新打开页面**（连着旧 IP 会断一下）。LuCI「状态 → 主题与 WDS 角色」页有同样两个按钮，GET 参数走严格白名单，不会命令注入。

### DHCP：WDS / AP 两种模式、两台机型全关

- `kill_dhcp()` 在 `scrub()` 里**每次开机无条件跑**：`dhcp.lan.ignore=1`、`ra/dhcpv6/ndp=off`、停 `dnsmasq` / `odhcpd`
- `vs010-role` 切角色后**再兜底一次**
- 构建期已删 `etc/rc.d/S60dnsmasq` 等自启

🔴 <u>**WDS 主 / 客户端两端都绝不能开 DHCP 服务端**</u>：内网只允许上级一台发地址，否则客户端那台也发地址会让整网地址错乱。开机日志 `[!!! DHCP !!!]`、CHANGELOG、下载页、网桥页、开关页全部标红划线。

### 刷完一行取证（新增项）

```sh
vs010-role status; vs010-theme status
uci -q get network.lan.ipaddr; uci -q get dhcp.lan.ignore   # .241 或 .242 / 1
uci show luci | grep -E 'mediaurlbase|Argon'                 # 两项都在
ls /usr/lib/lua/luci/view/themes/argon2/                    # 6 个 .htm
```

### 两种设备

主题、角色开关、DHCP 全关都在**公共 `files/` 层**，`cucc_vs010` 与 `cmcc_rax3000qy` 的 4 个组合（wds/ap）同时生效，无需机型差异文件。


---

## 22. 第 18 次：合并冲突善后（怎么传这个包）

> 这一版**不是固件更新**。`files/` 汇总 sha256 与 r17 完全一致；实测重编后解包 **2259 个 rootfs 文件逐项一致、kernel FIT 卷一致**，仅 `mksquashfs` 的容器时间戳让 `.bin` 字节不同（功能等价、已刷机器不用重刷）。它只是把仓库从「合并冲突」状态拉回干净终态。

### 你截到的那个弹窗是什么

| 文件 | 提示 | 该怎么处理 |
|---|---|---|
| `.github/workflows/build-openwrt.yml` | 文件在 `origin/master` 不存在 | 远端删了/没有主构建入口 → **必须保留本地版**，选「接受远端删除」会让 `device=all / mode=all` 那套 4 组合矩阵消失 |
| `build/verify.sh` | 1 个冲突 | 本地 r18 版含第 17/18 次断言 → **整份以本地为准**，不要手工拼 `<<<<<<< / ======= / >>>>>>>` |

🔴 **别点「继续合并」**：冲突没解决就提交，会把带标记的文件推上去，Actions 里 YAML 解析失败、`verify.sh` 语法崩。

### 路径 A（推荐，零手工解冲突）

1. GitHub Desktop 点 **「停止合并」**
2. 解压 **`VS010-full-5.4-r18.zip`**，整体覆盖仓库目录（`.github/` 是隐藏目录，别漏）
3. 仓库根执行：

```bash
sh tools/apply-r18.sh
# 自动：abort 残留合并 → 查冲突标记 → 修权限 → 核 files/ 哈希 → 跑 verify.sh
# 最后一行应是 RESULT: PASS —— 第 18 次
git add -A && git commit -m "VS010 5.4 r18" && git push origin master
```

### 路径 B（增量包，仓库没乱时用）

```bash
cp -a VS010-patch-5.4-r18.zip解压目录/. .
sh tools/apply-r18.sh
git add -A && git commit -m "VS010 5.4 r18" && git push origin master
```

### 路径 C（本地已经一团乱、想彻底清空重建）

```bash
cd ~/WDS-AP-5.4-VS010-RAX3000Q
find . -mindepth 1 -maxdepth 1 ! -name .git -exec rm -rf {} +   # 保留 .git，保留历史
unzip -q ~/Downloads/VS010-full-5.4-r18.zip -d .
sh tools/apply-r18.sh
git add -A && git commit -m "r18 清空重建" && git push origin master
```

### 解完 3 个必查

```bash
grep -R -nE '^(<<<<<<<|=======|>>>>>>>)' .github build files README.md CHANGELOG.md   # 应无输出
sh verify.sh                                                                          # PASS —— 第 18 次
git status --short                                                                    # 别把 .bin/.sha256 提交进去
```

push 后 `Actions → Build 5.4 firmware → Run workflow`（device=all / mode=all）出 4 个带 `5.4` 的 Release。

### 两个不用管

- **权限**：网页上传/Windows 解压抹成 664 不影响 —— `build.sh` 打进固件前统一强制 755，`apply-r18.sh` 也会先把仓库侧修一遍。
- **Release 权限**：workflow 里已显式 `permissions: contents: write`，本轮**没动这个文件**，不会重新引入冲突。


---

## 23. 第 19 次：修 Actions 的 `Apply installed baseline` 报错

**现象**：`Build 5.4 firmware #5` 里 `Apply installed baseline (both devices)` → `Process completed with exit code 1`。页面其余 `This step has been truncated` / `There was an error while loading` 都是 GitHub 渲染提示，不是失败。

**根因**：`tools/apply-installed-baseline.sh` 的幂等逻辑把「FROM INSTALLED BASELINE 块起始行之后的所有内容」一并截掉，吃掉了第 15 次追加的 `usr/sbin/ip6tables`（用来让 LuCI 总览 IPv6 WAN/DUID 块消失）→ `verify.sh` FAIL → `set -e` 退出 1。**每次构建都会悄悄少一条精简项**，不只是自检红。

**修法**：块用显式 `(begin)/(end)` 包起来，独立 `tools/baseline-block.awk` 只替换块本身；`cat >` 原地写保留权限；自检失败补 `::error::`。新增 mock 回归断言：块在中间、连跑两次、`ip6tables` 不丢、块不重复。

```bash
cp -a VS010-patch-5.4-r19.zip解压目录/. .
sh tools/apply-r18.sh          # 顺手再查一次冲突标记/权限
sh verify.sh                  # RESULT: PASS —— 第 19 次
git add -A && git commit -m "VS010 5.4 r19" && git push origin master
# Actions → Build 5.4 firmware → Re-run / Run workflow（device=all / mode=all）
```

🔴 本轮**没有改 `.github/workflows/` 任何文件**（r18 那个冲突就是它引起的），`files/` 汇总哈希不变 → 固件内容与 r17 等价，**已刷机器不用重刷**。重跑 Actions 只为拿到 4 个带 `5.4` 的 Release。
