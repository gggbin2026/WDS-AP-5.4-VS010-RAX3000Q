# 更新日志

| 版本 | 内容 |
|---|---|
| **第 1 次** | 推倒重来，以 `ByteArray0` fork 为底。查明 VS010 无线起不来是**机型错配**：刷的是 `cmcc_rax3000q` 开源 ath11k 固件（RAX3000Q 的 DTS / `ipq-wifi-cmcc_rax3000q` / ART 校准），VS010 的 BDF 与射频前端完全不同。 |
| **第 1 次** | 改为**以仓库内 `cucc_vs010` 官方 5.4.213 固件为底座**：kernel FIT 卷逐 PEB 原样保留，只叠加共用运行期文件；无线栈 / BDF / 驱动一字不动，不自动重启。 |
| **第 1 次** | 一个 workflow、两机型 matrix、`files/` 共用 + `files.<机型>/` 差异；RAX3000Q 原生编译线另存 `build-source.yml` 保留。 |
| **第 1 次** | 固件名统一带 `5.4`；Release 简介 3 行；注入树禁止覆盖 `etc/config` / `lib/firmware` / `lib/modules`，冲突直接停止构建。 |

> 注：好固件的 `bdwlan.b10` / `qcn6122/bdwlan.b60` 是**闭源 cnss2** 格式，不能搬去开源 ath11k 的 `board-2.bin`（会 `invalid board magic → QMI 失败 → panic → 自动重启`）。ART 在好固件里 `Caldata not present`，也不是无线启动的必要条件。
| **第 2 次** | 加入 WDS 网桥 / AP 双模式 + 双可视化 `/bridge/` `/ap/`；TTYD（官方已装，仅启用）、机器狗插件（出厂停用 + ever_ok 保护）、`172.10.10.241/22`、NTP 300 秒循环、STP、DHCP/无线 Snooping 监测、网口速率只读显示。**无线修复（第 1 次）一字未动**：kernel FIT / BDF / 驱动 / `/etc/config` 全零覆盖，注入树撞名即停构建。 |
| **第 3 次** | 合并第 1/2 次（无线修复在内）；关 IPv6、WAN+LAN 全桥接、关防火墙、精简杂项插件（只留 TTYD）、修复 SSH 空密码、保住串口、**网桥自动配对**（MAC 收敛主备，不碰无线配置）；`build/prune.list` + 白名单硬断言防误删无线栈。 |
| **第 4 次** | 恢复 **Argon 主题**（配置/控制器/静态资源全保留 + 427 守卫）；网桥 WDS **主(ap+wds)/客户端(mode=wds)** 4addr 纯二层进 br-lan，SSID `WDS-Bridge-Z` / `WDS123456`，自动配对 + 可 `set-role master\|client`；NTP 纯内网客户端三台 `172.10.10.254` / `172.100.10.254` / `192.168.1.254`，5 分钟循环；IP `172.10.10.241/22`、root/admin、串口、主题不报错。 |
| **第 5 次** | 换回旧版丰富状态页（4 文件：2 HTML + 2 CGI，补 `/etc/bridge.conf`）；AP 模式 SSID 按机型 `VS010-AP` / `RAX3000Q-AP` / `AP123456`；设备名主 `WDS-Z` / 客户端 `WDS-K` / `AP`；5G 桥接 **HE160**（`11axa+HT160`）、2.4G 不桥接；**WAN/WAN6 每次开机都删**（scrub 移出首启 stamp）；旧页面兼容垫片。 |
| **第 6 次** | 核验「替换丰富页面后主题是否报 427」：注入树零覆盖官方 LuCI；新增 `S18 vs010-luci-fix`（早于 uhttpd 50）修 named main / 清两侧 indexcache / **无证书关 HTTPS 重定向** / lua_prefix 兜底；修正 r4 守卫 `delete @core[0]` 自毁隐患改 `rename`；`luci-check` 一行自证。 |
| **第 7 次** | 纯文档：`README.md` 重写为 218 行详版（底座/编译/登录/网络/NTP/无线/插件清单/命令/目录/边界）；Release 下载页改为「一张设置表 + 插件清单 + 刷机必读」，补齐 IP `172.10.10.241/22`、账号、模式、NTP、SSID、机器狗状态。编译链零改动。 |
| **第 8 次** | 核实 `factory.bin` 卷表仅 layout / kernel / rootfs —— **ART 是独立 MTD 分区，每机自读、刷机不覆盖**；`portstat` 补交换芯片 **PHY 实测**兜底（netdev 不上报不写死假 1000M）+ `--rows`；Argon 主题新增「网口速率」菜单 `vs010_ports`（零覆盖官方文件）；新增设备侧 `tools/rootfs-capture.sh`（只导出删除清单，硬排 ART/MAC/密钥/stamp）与 PC 侧 `tools/build-from-capture.sh`（回灌 `prune.list` + 无线栈硬护栏 + 重出固件）。**无线修复与编译链零改动**。 |
| **第 9 次** | 补通「刷完→删插件→导出→上传→出固件」闭环：`build.sh` 把导出脚本注入 `/usr/sbin/vs010-capture`（此前只在 `tools/`，刷完机器找不到）；workflow 新增 `Apply captured prune list`，检测 `capture/prune-real.txt` 自动回灌再 Build；`capture/README.md` + 主页第 14 节给出完整操作。**无线栈零改动**。 |
| **第 10 次** | 修 CI `Init` 退出 1：线上 commit 全部文件 `664`（网页上传/Windows 解压抹掉可执行位），`verify.sh` 三处 `-x` 断言 FAIL；且 `fused.py` 用 `copy2` 沿用源 mode，固件里 CGI/init.d 会真不可执行。`build.sh` 注入前统一 `chmod 755`（不再依赖 git mode）；三处断言改为「文件在位 + 构建期兜底」；两处 `import yaml` 改纯文本解析，**去掉 runner 预装 PyYAML 依赖**。负例实跑：整树抹成 664 → 构建成功 → 固件内 6 个关键脚本全 755。**无线栈零改动**。 |
