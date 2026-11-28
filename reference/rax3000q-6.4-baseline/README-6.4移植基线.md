# RAX3000Q 5.4 → 6.4 内核移植基线

> 本目录是**依据与证据包**，不是可直接编译的 6.4 源码。
> 来源：本仓库 5.4 源码编译线（kkstone/immortalwrt-ipq50xx @ openwrt-21.02，QSDK 12.2 / Linux 5.4）
> 中 **3000Q 编译成功**那一版实际用到的全部板级资产。逐项 sha256 见 `MANIFEST.json`。

## 一、可以直接搬到 6.4 的（二进制 / 板级事实，与内核版本无关）

| 文件 | 用途 | 6.4 怎么用 |
|---|---|---|
| `bdf/board-cmcc_rax3000q.ipq5018` | 2.4G/IPQ5018 板级校准 `board-2.bin` | 原样装到 `/lib/firmware/ath11k/IPQ5018/hw1.0/board-2.bin` |
| `bdf/board-cmcc_rax3000q.qcn6122` | 5G/QCN6122 板级校准 | 原样装到 `/lib/firmware/ath11k/qcn6122/hw1.0/board-2.bin` |
| `art/RAX3000Q-mtd13-0ART.bin` | 实机 1 MiB ART（校准 + MAC） | 偏移 `0x1000` / `0x26800` 各取 131072 B 可重生成 BDF；⚠ 含本机 MAC，公开仓库建议脱敏 |
| `dts/ipq5000-rax3000q.dts` 里的 GPIO/LED/按键号 | 硬件事实 | `reset GPIO23`、`mesh GPIO38`、LED `24/19/17`；6.4 用主线 `gpio-keys`/`leds-gpio` 绑定重写即可，编号照抄 |
| `source-snippets/02_network-cmcc_rax3000q.inc` 的 switch 位图 | 网口物理顺序 | `switch1 6u@eth1 3u@eth0`、`2:lan:1 4:lan:2 5:lan:3 1:wan`；6.4 用 `dsa`/`qca8k` 或对应驱动重写标签，物理口映射不变 |
| `source-snippets/Device-cmcc_rax3000q.inc` 的 `DEVICE_DTS_CONFIG=config@mp02.1`、`BLOCKSIZE=128k`、`PAGESIZE=2048` | FIT/NAND 参数 | 6.4 的 image 规则里照抄这几个值 |
| `misc/uboot-ipq50xx-cmcc_rax3000q.bin` | 已验证能启动的三方 U-Boot | 分区表由 U-Boot 经 `qcom,smem-part` 填充；**U-Boot 不要动**，升级内核不刷它 |

## 二、必须重做的（5.4 / QSDK 专用，6.4 搬过去必然编译失败或功能缺失）

| 项 | 为什么不能搬 |
|---|---|
| `dts/ipq5000-rax3000q.dts` **整体** | 用 QSDK 私有绑定：`qcom,ess-switch-ipq50xx`、`qcom,ess-switch-qca83xx`、`ar8327-initvals`、`qcom,nss-dp`、`qcom,ipq5018-q6-mpd`、remoteproc PD、`#ifndef CONFIG_ATH11K_MEM_PROFILE_256M`。6.4 主线没有这些节点，必须按主线 qcom 绑定重写 |
| `linux-5.4-qsdk-11.5.0.5.tar.xz` + `backports-20210222-5.4-qsdk-11.5.0.5.tar.xz` | QSDK 11.5 专用内核与 backports；6.4 要换 6.4 内核 + 对应 mac80211/ath11k backports |
| `kmod-qca-nss-dp` / `nss-drv` / `nss-ecm-standard` / `qca-ssdk-nohnat` / `qca-nss-fw-ipq50xx-retail` / `MAC80211_NSS_SUPPORT` | 🔴 **NSS 全链路是 QSDK 5.4 闭源驱动，6.4 没有对应包**。有线/无线硬件加速不能照搬；6.4 线要么找开源 NSS 实现，要么接受无硬件加速（用主线 flow offload 兜底） |
| `ath11k-firmware-ipq5018` / `-qcn6122` 的包定义 | 固件二进制本身可复用，但 6.4 源码树的 `ath11k-firmware` 打包路径、`board-2.bin` 索引方式、Q6 `m3_fw.mdt`/`q6_fw.mdt` 加载链要按 6.4 驱动重新对 |
| `source-snippets/ipq-wifi.Makefile` | `PKG_FLAGS:=nonshared` + `generate-ipq-wifi-package` 宏是这条 21.02 源码线的写法；6.4 用上游 `ipq-wifi` 包或在设备里直接放 `board-2.bin` |
| `config/.config.rax3000q` **整体** | `CONFIG_TARGET_ipq50xx_arm_*`、`CONFIG_PACKAGE_kmod-qca-nss-*`、`CONFIG_LINUX_5_4` 全是 5.4 线符号；只对照「哪些功能开着、哪些关着」，不要整体 copy |
| `source-snippets/02_network-cmcc_rax3000q.inc` 的 `ucidef_add_switch` 写法 | 21.02 的 board.d API；6.4 / 新版 OpenWrt 用 DSA 或不同 `ucidef` 接口 |
| `Device/UbiFit` / `append-ubi` 规则 | 5.4 这条线的 image 生成规则；6.4 要按目标源码树的 image Makefile 重写 |

## 三、已归档的 6.x 参考材料（本会话沙盒，不在本仓库）

`25.12_拉取与评估.md`、`25.12_材料/`、`README_5.4.213内核源码.md`、`OEM_QSDK10.4_4.4.60_闭源无线与NSS加速栈_资产归档.zip`
—— 里面是另一条 6.x / 25.12 与 5.4.213 闭源无线栈的评估结论。**建议 6.4 另起一个仓库**，复用本目录的二进制资产（BDF/ART/GPIO/分区/U-Boot），而**不要**把 kkstone 21.02 源码树直接升级到 6.4：两者的 target、feeds、内核补丁、闭源 wifi 栈都不兼容。

## 四、6.4 编译前自检清单

1. 先确认 6.4 源码树对 IPQ5018 的支持程度：主线 `ipq5018.dtsi`、 ath11k `IPQ5018/hw1.0`、`qcn6122/hw1.0`、Q6 remoteproc 是否齐。
2. 把本目录两个 BDF 放进新树，编译后 `dmesg | grep -i board-2` 确认 `qmi-board-id=36/96` 命中（与 5.4 同编号）。
3. DTS 按主线绑定重写后**先跑花括号配对 + dtc**（r29.6 教训：多一个 `};` 会编译 1 小时才在打包阶段失败）。
4. 明确加速方案：有开源 NSS 就接，没有就关掉 `MAC80211_NSS_SUPPORT` 等符号，别留空依赖。
5. 分区与 U-Boot 不刷、不改；ART 不覆盖。
6. 刷机 TTL 在手边（1.8V `ttyMSM0 115200n8`）。

---
⚠ `art/` 与 `misc/uboot-*` 可能含本机 MAC / 环境变量，公开仓库建议脱敏或私有保存。
