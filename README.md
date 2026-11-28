# WDS-AP 5.4 · VS010 / RAX3000Q

源码编译仓库。`Actions → Build 5.4 source firmware` 一次编译，按机型各出一个固件。

## 内核与平台

- 源码：`kkstone/immortalwrt-ipq50xx` @ `openwrt-21.02`，**Linux 5.4**（QSDK 12.2 / IPQ5018，32-bit arm）
- 无线：`kmod-ath11k` + `ath11k-firmware`（IPQ5018 / QCN6122）+ `kmod-qca-nss-dp`；VS010 板级 BDF 取自实机 ART
- 机型：`cucc_vs010`、`cmcc_rax3000q`
- 协议：**仅 IPv4 纯二层桥**；IPv6、PPP / PPPoE / PPTP 等拨号协议**编译期不编入**，LuCI 里不出现
- 精简：**无 WAN 逻辑接口、无防火墙**；DNS 转发与 DHCP 服务端默认关闭（AP 界面可按需开启 DHCP），WAN 物理口桥进 LAN

## 内置功能与插件

| 类 | 包 |
|---|---|
| 管理 | `dropbear`(SSH)、`ttyd` + `luci-app-ttyd`、串口 `ttyMSM0`、LuCI |
| 主题 | **Argon 2.4.3**（编译期替换，最后一个 Lua 兼容版） |
| 网络 / 无线 | `ethtool`、`swconfig`、`wpad-wolfssl`、`hostapd-common`；**NSS 有线/无线加速**（`qca-nss-dp` / `nss-drv` / ECM / `MAC80211_NSS_SUPPORT` / TurboACC）；AP 可选 DHCP 服务端（`dnsmasq-full`，默认关闭） |
| 自研界面 | **WDS/AP（仿UBNT）**：`/bridge/` 网桥状态、`/ap/` AP 状态、`/ubnt/` 概览、常用设置控制台、网口状态、LuCI 状态菜单，四界面全互访 |

服务与配置的运行期状态见 `STANDARDS.md`。

## 编译产物

- **一种机型 1 个包，共 2 个**；产物标识 `WDS-AP-UBNT`，**AP 与 WDS 桥接在同一个固件里**，刷完在界面里随时切，不用重刷
- 文件名：`Nwrt-QSDK12.2-5.4-<YYYYMMDD-HHMM>-ipq50xx-arm-<机型>-dual-squashfs-nand-factory.ubi`，附 `sha256sums.txt`
- 发到 Releases（永久保存，只保留最新 5 个）；首次真 `make` 约 1–2 小时

## 编译

```bash
sh verify.sh && git add -A && git commit -m "build" && git push
```
`Actions → Run workflow`：`device=all`、`default_mode=wds`。

## 入口

刷完默认网桥，只输管理 IP（`172.10.10.241`）自动进 `/bridge/`；AP 模式进 `/ap/`。不登录可看状态，改设置需登录；后台 `http://172.10.10.241/cgi-bin/luci/`（根路径 `/` 现为状态页跳转，不再直达 LuCI）。

## 资料索引

- 版本与修复记录 → `CHANGELOG.md`
- 验收标准 / 运行期配置 → `STANDARDS.md`
- 界面、刷机、边界 → `VS010-r29-使用说明.md`
- 实机 BDF / GPIO / 分区原始参数 → `reference/vs010-oem/`


## 界面（UBNT / UniFi 深色风格 · 四界面全互访）

**r29.9 起三个界面都要、都同款**：`/ubnt/` 概览、`/bridge/` 网桥状态、`/ap/` AP 状态，统一深色侧栏（宽屏）/ 顶部横向 pill（手机竖屏）、KPI 条、时间与运行时长，导航五入口互通。

- `/ubnt/`：概览页 —— KPI 四卡、上行拓扑、无线射频、客户端表、网口状态
- `/bridge/` / `/ap/`：原有 GAUGE 圆环、网口 6 列、客户端、BDF、加速、守卫、**全部保留**，只在外层包一层共享皮肤（`vs010-ubnt.css` + `vs010-ubnt-skin.js`）
- 共享注入器只搬移 DOM 外层、不删不改任何原有节点与 id；KPI 靠 hook 原生 fetch + `Response.clone()` 拿，**零额外请求、零写入端点**，未登录只读
- 设置仍走受 LuCI 会话保护的 `vs010-setup.js`；模式守卫 `data-mode` 不变

**r29.10 起「所有界面互相点开 + 都能登录」**：`/bridge/`、`/ap/`、`/ubnt/`、根跳转 `/`、以及 LuCI 六个视图，**每一页都有一排同样的按钮**：概览 / 网桥状态 / AP 状态 / 常用设置 / OpenWrt·LuCI / 登录·退出。竖屏按钮条横向滚动、不隐藏。
登录按钮按 `vs010_setup/probe` 的会话态自动切换：未登录 →「🔑 登录 LuCI」(`/cgi-bin/luci/`)；已登录 →「🔑 已登录 · 退出」(`/cgi-bin/luci/admin/logout`)。两页复用共用控制台已发的 probe（hook + `clone()`），**零新增请求、零写入端点**；LuCI 视图本身在 admin 树下，能打开即已登录。

**WDS 客户端搜索主端**（r29.11）：网桥界面「常用设置 → ② WDS 主 / 客户端」有「🔎 搜索周边 WDS 主端 SSID」，列出 SSID / BSSID / 频段 / 信道 / 信号 / 加密；点「选用」自动填桥接目标并**跟随主端信道**，密码手填后保存即可关联 WDS 组。扫描是只读端点，需登录。

离线看效果：`demo/ubnt-预览.html` 双击即可（file:// 自动切内嵌演示数据）；`demo/ubnt-*-宽屏.png` / `ubnt-*-竖屏.png` 共 6 张，是三页两种尺寸的 Chromium 真渲染截图。

## 无线频宽（r29.12）

| 频段 | 默认 | 可选 | 说明 |
|---|---|---|---|
| **5.8G** | `HT160` = **160MHz 满速** | HT160 / HT80 / HT40 | QSDK `qcawifi.sh` 约定，`HT160` 就是 HE160；WDS 回程固定此值 |
| **2.4G** | `HT40` = **20/40MHz 共存** | HT40 / HT20 | `HT40` 下 20MHz 客户端照样能关联；`HT20` 强制仅 20MHz |

两个频段**独立字段**（`htmode` / `ht24`），互不串写：2.4G 绝不写 HT160/HT80，5G 绝不写 HT20。面板「④ WiFi 射频参数」分别下拉，后台与开机脚本各按 radio 的 `hwmode` 分组下发，非法残留值一律跳过。

## 产品标识 WDS/AP（仿UBNT）

固件标识 **WDS/AP（仿UBNT）**：编译产物名带 `WDS-AP-UBNT`、Release 名称标注、`/etc/vs010/product` + SSH banner、三界面侧栏与顶栏均可见。
