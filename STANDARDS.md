# 固件验收标准（r25 起，每版必须遵守）

> 用户原话：「编译出来的固件一定要运行稳定，内存占用低，无线开启快，
> 即精简好用没有 BUG 的固件（以后都要按此标准修复），固件要保证能用 SSH 及串口等」。

这不是愿望清单，是**硬验收项**。`sourcebuild/tools/verify.sh` 与
`sourcebuild/diy-part2.sh` 每版逐条断言，缺任何一条直接 FAIL、不出包。

## 一、稳定（最高优先级，压倒一切新功能）

| # | 标准 | 落实 |
|---|---|---|
| 1 | 官方/实机验证过的东西绝不为了「更漂亮」去改 | switch `ar8327-initvals` 默认保留已验证档；U-Boot 本体不动；BDF 容器头沿用 kkstone 已验证 84 B |
| 2 | 配置每次开机幂等重写，重置后能长回来 | `vs010-mode` 的 `scrub()` 不受 applied stamp 限制 |
| 3 | 删服务不删依赖链 | 只删配置/自启链接/控制器，不动 `libuci`/`uhttpd`/闭源 `.ko` |
| 4 | 🔴 `bootargs-append` 不可删 | U-Boot env 实测只给 `console=ttyMSM0,115200n8`；`ubi.mtd=rootfs swiotlb=1` 必须来自内核 DTS，删了挂载不上 rootfs |
| 5 | 不重建 radio / 不 `wifi down` / 不重启机器 | 只改既有 `wifi-device`/`wifi-iface` 的 option |
| 6 | 一台机器一个常驻 | 仅 `vs010-tick`；机器狗出厂停用、DHCP guard 默认 monitor |
| 7 | 双线不再互相覆盖 | r25 全能包本身即单线：只留 `build-source.yml`，无融合线残留，清空仓库解压即用 |

## 二、内存占用低

- `.config` 关闭 `autocore-arm` 等纯装饰/杂项包；`luci-app-firewall`、`bootstrap`、
  `odhcpd-ipv6only`、`dnsmasq` 冗余特性、`autoreboot` 全关
- **单常驻 `vs010-tick`** 合并 NTP / Snooping / WDS / 机器狗分频，不再一个功能一个 daemon
- `vs010-wds-pair loop` 开机延迟 `35s → 5s`、轮询 `60s → 120s`，少占 CPU
- 不启动 = 不占内存；不为了省几 MB flash 去删二进制冒破坏闭源依赖的风险

## 三、无线开启快

- 去掉开机 `sleep 15` 后台重试收敛，改成同步一次 `converge`
- 5G 单 VAP 收敛（`WDS-Bridge-Z`），同 radio 其余 VAP `disabled=1` 而非删段
- 信道 `auto`（ACS）是用户明确要求，保留；HE160 与 4addr 以实机 `wlanconfig ath1 list` 为准

## 四、精简好用、没有 BUG

- 网桥固件**只有** `/bridge/`，AP 固件**只有** `/ap/`，互不混装（`files.manifest` + `mode-exclude.*` 物理排除）
- Argon **2.4.3**（最后一个 Lua 兼容 tag），内置状态菜单
- 网桥/AP 界面的网卡信息必须显示**链接速率**（netdev 不上报时读交换芯片 PHY 实测并标注来源）
- 网桥/AP 界面必须显示**无线芯片温度**；无传感器时如实留白「—（无温度传感器）」，**绝不报错、绝不写假数值**
- 只列已插网线的口（carrier / operstate / ethtool 三重判定）
- 登录 `root / admin`，IP `172.10.10.241/22`（WDS 主 `.241`、客户端 `.242`、AP 恒 `.241`）

## 五、🔴 管理通道必须可用（每版硬断言）

| 通道 | 编译期 | 运行期 |
|---|---|---|
| SSH | `CONFIG_PACKAGE_dropbear=y` | `PasswordAuth=on` / `RootPasswordAuth=on`，不绑 Interface |
| 串口 | — | `ttyMSM0::askfirst:/bin/ash --login`，115200n8，TTL **1.8V** |
| TTYD | `CONFIG_PACKAGE_ttyd=y` + `luci-app-ttyd=y` | `/ttyd/` |
| LuCI | `uhttpd` + `luci-base` | `/cgi-bin/luci` |

## 六、网络与无线角色

- WAN / WAN6 删除、IPv6 全关、防火墙服务关、DHCP 服务端全关
- 🔴 <u>**WDS 主 / 客户端两端都绝不能开 DHCP 服务端**</u>：日志、下载页、网桥页标红划线
- **网桥模式只用 5G**：5G HE160 / `channel=auto` / `WDS-Bridge-Z`，**2.4G radio `disabled=1`**
- **AP 模式 2.4G 作为 AP 用**：`VS010-AP` / `RAX3000Q-AP`，密码 `AP123456`，5G 同时作为 AP
- MU-MIMO / WMM / 弱信号剔除与拒绝连接，两种模式都有

## 七、实机参数来源

- 全部 GPIO / LED / bootargs / MIBIB / BDF / U-Boot / CDT 参数来自
  `reference/vs010-oem/VS010-实机参数.log`，**实机读取、✅ 可直接使用**，不是推断
- 原始二进制在 `reference/vs010-oem/`（`MANIFEST.json` 带 sha256）
- `0:ART` / `0:APPSBLENV` 含本机 MAC，公开仓库建议脱敏

## 八、效率约定（回应用户「别老重复跑」）

- **不重复拉取远端**：素材已本地落库，后续版本直接复用，不重新 `git clone`、不重新下载上游
- **不重复解包**：`parse-vs010-backup.py` 校验 tar.gz sha256，命中
  `reference/backup/VS010-备份解析.json` 的 `source_sha256` 就直接复用
- 自检只读本地文件；`make` 只在用户显式 `Run workflow` 时跑一次
- 新增版本只做增量修改，不整树重出

## 九、边界（如实说明，不许包装成确定结论）

- 没实机、没跑 GitHub Actions 的 `make` 时，只交静态/注入/自检真跑结果
- `iw dev` 双频接口、HE160、4addr 以刷完实机为准
- 010 按键 GPIO 改的是内核 DTS；U-Boot 单槽（`APPSBL_1` 全 FF），救砖 TTL 在手边
