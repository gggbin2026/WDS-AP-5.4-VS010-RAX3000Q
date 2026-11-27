# WDS-AP 5.4 · VS010 / RAX3000Q（r25 全能包）

> **这是一个自包含仓库快照（r28）**：清空仓库后，把本包解压进去就能直接
> `verify → commit → push → Actions 编译`，**不需要任何已有文件、不需要联网拉取资料、不需要再跑清理脚本**。
> 唯一编译入口：`.github/workflows/build-source.yml`（真实 `make`）。

---

## 0. 清空仓库后怎么铺（照抄即可）

```bash
cd ~/WDS-AP-5.4-VS010-RAX3000Q

# 只保留 .git，清空工作区（不要在网页上删 .git）
find . -mindepth 1 -maxdepth 1 ! -name .git -exec rm -rf {} +

unzip -o VS010-全能包-r26.zip          # 解压到仓库根目录
sh verify.sh                            # RESULT: PASS —— 第 25 次
git add -A && git commit -m "r26 全能包：单线自包含" && git push
```

如果是在 GitHub 网页上把文件删空了，本地 clone 下来执行上面第 2 步起即可。
**别删本地 `.git`**，否则要重新 `git remote add origin`。

> 两个 27 MB 的官方 `factory.bin` 是救砖/回退归档，**不参与编译**。
> 不想让仓库多 54 MB，删掉 `3000Q-VS010-固件/*factory.bin` 即可，`verify.sh` 只会给一条 NOTE，不影响 PASS。

## 1. 编译

```
Actions → Build 5.4 source firmware (r25 · 3000Q / VS010 · WDS + AP) → Run workflow
    device = all        mode = all
    vs010_experimental = true（默认）
    vs010_switch_oem   = false（默认；切实机 switch 档需 TTL 在手边）
```

一次触发 4 个 job（2 机型 × 2 模式），各出一个带 **`YYYYMMDD-HHMM` 详细日期**的
`Nwrt-QSDK12.2-5.4-…-squashfs-nand-factory.ubi` + `.sha256`，发到 Releases
（永久保存，`KEEP_RELEASES: 5` 只留最新 5 个）。首次真 `make` 约 **1–2 小时**。

编译前会强制跑 `Validate real-hardware backup evidence`：解包实机备份 → 断言
MIBIB 16 分区 / `rootfs @0x00900000` / U-Boot env 不含 `ubi.mtd` / CDT 无 wifi-id /
BDF body == 本机 ART。任一不成立就停止出包。

## 2. 目录（全能 = 什么都在，且编译入口唯一）

| 路径 | 内容 |
|---|---|
| `.github/workflows/build-source.yml` | **唯一 workflow**（融合线已按要求移除） |
| `verify.sh` | 单线自检入口 → `sourcebuild/tools/verify.sh` |
| `STANDARDS.md` | 🔴 **以后每版强制遵守的验收基线**（稳定/低内存/无线快/SSH 串口） |
| `CHANGELOG.md` | 版本里程碑与 r25 重整说明 |
| `demo/` | r28 两个界面的**离线演示页与截图**（内置样例数据，浏览器直接打开 `bridge.html` / `ap.html`）|
| `sourcebuild/` | 源码编译线全部（含 r26 的 `files/usr/sbin/vs010-apply-config`、`files/www/vs010-setup.js`、LuCI `vs010_setup` 端点与模板）：`.config.*`、`diy-*.sh`、`files/`(39)、`target/`、`package/ipq-wifi/`、`tools/`、上游取证资料 |
| `reference/vs010-oem/` | **实机原始二进制 ×10** + `MANIFEST.json`(sha256) + `VS010-实机参数.log` |
| `reference/backup/` | 原始 NAND 备份 tar.gz、解析 JSON、MIBIB 16 分区表、全量取证 |
| `reference/argon-upstream/` | Argon v2.4.3 版本证据（编译期实际从 GitHub clone） |
| `3000Q-VS010-固件/` | 救砖全资料：ART ×3、`vs010.dtb`、U-Boot ×2、刷机教程、实机日志、官方 factory.bin ×2 |

## 3. 配置速查

| 项 | 值 |
|---|---|
| 管理地址 | `172.10.10.241 / 255.255.252.0`；WDS 主 `WDS-Z`=`.241`、客户端 `WDS-K`=`.242`、AP 恒 `.241` |
| 账号 | `root / admin`；**SSH**(dropbear) · **串口** `ttyMSM0 115200n8`(TTL **1.8V**) · TTYD |
| 主题 | Argon **2.4.3**（最后一个 Lua 兼容 tag，编译期 `clone -b v2.4.3`） |
| **界面布局（r28）** | 两页顶部顺序完全一致：**系统仪表盘 · GAUGE（置顶，详细数值不显示）→ 常用设置控制台 · SETUP → 网络与本机 · NETWORK（含内网 LAN 表）**；后面才是各自业务显示。网口按实际物理口显示 **内网LAN1 / 内网LAN2**，`1000M → 1G`；旧的「连接端口」卡片已删除 |
| **默认与入口** | 刷完默认**网桥模式**；浏览器只输管理 IP 自动跳 `/bridge/`（AP 模式跳 `/ap/`）。**不登录可看全部状态，修改必须登录**；右上角「⚙ 高级设置后台」进 OpenWrt / LuCI |
| **OpenWrt 后台直达路径** | `http://<设备IP>/cgi-bin/luci/`（默认 `http://172.10.10.241/cgi-bin/luci/`，`/cgi-bin/luci` 同效）。根路径 `/` 现为状态页跳转，**不再直达 LuCI**；界面「查看日志 / 一键自检」输出首行、后端日志末尾、CHANGELOG 与 Release 日志均注明此路径 |
| 模式界面 | 网桥 `/bridge/` 或 AP `/ap/`（菜单只注册当前模式一套，页面带 mode 守卫，不串界面）；Argon 状态菜单内置入口 |
| **编译产物** | **一种机型只出 1 个固件**（VS010 / 3000Q 共 2 个），AP + WDS **都在同一个包里**；`Run workflow` 里 `default_mode` 只决定刷完首次开机的模式，之后在界面里随时切，不用重刷 |
| **常用设置** | 主题「状态 → 常用设置」，或两页内嵌的 SETUP 卡片：**必须登录才能保存**（直接输网址时配置锁定，引导登录 LuCI）。改 SSID/密码、WDS 主客滑动开关、桥接目标、信道、信号剔除值、工作模式；保存即联动写后台 + 一次 `wifi reload`，重启不丢 |
| 工作模式 | **AP ⇄ WDS 桥接可在面板里直接切**，不用重刷；切完清 LuCI 菜单缓存 + reload uhttpd，主题菜单与网桥/AP 界面**自动跟着换**，2 秒后自动打开对应页面；手动输错网址也会被引导过去 |
| 设置控制台 | 两页与主题共用 7 个分组：工作模式 / WDS 主客 / AP 双频 SSID / 射频（信道·频宽·功率·WMM·MU-MIMO·弱信号）/ 网络本机 / 主题 / 维护自检。常用设置全在页面完成；改 root 密码、升级、VLAN 等回 **LuCI 高级设置** |
| 网卡信息 | **链接速率**（netdev 不上报时读交换芯片 PHY 实测并标来源）+ **无线芯片温度**（无传感器如实留白） |
| 网桥 WDS | **只用 5G**：`WDS-Bridge-Z` / `WDS123456` / HE160 / `channel=auto`；**2.4G radio 关闭** |
| AP | **2.4G 作为 AP 用**：`VS010-AP` / `RAX3000Q-AP` / `AP123456`；5G 同时作为 AP |
| 网络 | WAN+LAN 桥、STP 开、IPv6 / WAN / WAN6 / DHCP 服务端 / 防火墙全关 |
| 🔴 DHCP | <u>**WDS 主 / 客户端两端都绝不能开 DHCP 服务端**</u>，日志+下载页+网桥页标红划线 |
| 内存 | 单常驻 `vs010-tick`；杂项包编译期关闭；机器狗出厂停用 |

## 4. 实机参数（✅ 实机读取，可直接使用，非推断）

完整日志见 `reference/vs010-oem/VS010-实机参数.log`（98 行，逐项注明来源）。

| 项 | 实测值 |
|---|---|
| 按键 | 只有 wps **GPIO34** / `KEY_WPS_BUTTON` / debounce 60 / 低有效；**无独立 reset** |
| LED | mesh **GPIO33**、pwr **GPIO31**（均低有效）；3000Q 的 23/38/24/19/17 已清 |
| MIBIB | **16 分区**，magic `0x55ee73aa/0xe35ebddb` ver4，128 KiB 块单位 |
| rootfs | `@0x00900000 / 0x06e00000`（110 MiB）= 大分区 U-Boot |
| BDF | `0:ART @0x1000`(2.4G) / `@0x26800`(5G)，各 131072 B，**100% 本机校准** |
| 容器头 | `QCA-ATH11K-BOARD` 84 B，`qmi-board-id=36/96` |
| U-Boot | `2016.01-3e89586-godsun (2026-08-14)`，web failsafe / Telnet / `bootipq`，**单槽** |
| bootargs | env 只给 `console=ttyMSM0,115200n8` → `ubi.mtd=rootfs swiotlb=1` **必须由内核 DTS `bootargs-append` 提供，删了起不来** |
| CDT | `CDT\0` ver2 + `RDD@0x24`，DDR 参数表，**不含 wifi board-id** |
| switch | 实机 `0x40/0x1e/0x00` + 8 对 initvals；默认保留已验证档 `0x48/0x34/0x02`（私有寄存器，改错网口全灭） |

⚠ `0-ART.bin` / `0-APPSBLENV.bin` 含本机 MAC 与序列号，公开仓库建议脱敏；
BDF 取的是 ART 校准段，不含 MAC。

## 5. 边界（如实说明）

- **没跑真实 `make`、没实机刷入**：交付的是静态/注入/自检/备份解析全真跑通过的仓库，编译要你在 Actions 上跑
- `iw dev` 双频接口、HE160、4addr 以刷完实机为准；无线芯片无温度传感器时会显示「—（无温度传感器）」，不是 BUG
- U-Boot **单槽**（`APPSBL_1` 全 FF），改内核 DTS 的 gpio-keys 不会硬砖，但 **U-Boot 本体绝对不要动**；首次刷建议 TTL 在手边
- 融合线（官方 5.4.213 闭源栈重打包）已按你的要求移除；官方 factory.bin 只作救砖归档，不参与编译
- **效率约定**：素材全部本地落库，`parse-vs010-backup.py` 带 sha256 缓存，命中即跳过重复解包；不重复拉取远端（`STANDARDS.md` 第八节）
