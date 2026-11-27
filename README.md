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
| 账号 | SSH / LuCI / 串口 **`root` / `admin`**（官方 root 密码为空，首启已修） |
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
ssh root@172.10.10.241      # 密码 admin
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
