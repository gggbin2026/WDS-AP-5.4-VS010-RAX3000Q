# VS010（cucc_vs010）5.4 → 6.4 内核移植基线

> 本目录是**依据与证据包**，不是可直接编译的 6.4 源码。
> 与 `reference/rax3000q-6.4-baseline/` 是同批双机型基线。逐项 sha256 见 `MANIFEST.json`。

## 🔴 先看这一条：别拿错 DTS

`dts/ipq5000-vs010.dts` 是 **r29.6 修正版，59 个 `{` / 59 个 `}`**。
r29.1 那个版本在 `&tlmm` 块尾多留了一行 `};`（r23 删 `button_reset`/`button_mesh` 换 `wps_button` 时残留），
表现是「3000Q 编译成功、VS010 跑到 1h19m 才 `exit code 2`」—— DTC 在镜像打包阶段才编 DTB。
**6.4 编译前第一件事：花括号配对 + `dtc -I dts -O dtb` 真编译一次。**

## 一、可以直接搬到 6.4 的（二进制 / 板级事实，与内核版本无关）

| 文件 | 用途 | 6.4 怎么用 |
|---|---|---|
| `bdf/board-cucc_vs010.ipq5018` | 2.4G/IPQ5018 `board-2.bin` | 原样装 `/lib/firmware/ath11k/IPQ5018/hw1.0/board-2.bin` |
| `bdf/board-cucc_vs010.qcn6122` | 5G/QCN6122 `board-2.bin` | 原样装 `/lib/firmware/ath11k/qcn6122/hw1.0/board-2.bin` |
| `bdf/variants/*` | board-id 16 / 96 变体 | 6.4 ath11k 若枚举出不同 `qmi-board-id`，换对应变体；`dmesg | grep -i board` 确认命中 36/96 |
| `bdf/oem/bdwlan.b10`、`qcn6122_bdwlan.b60` | 原厂裸 131072 B 板数据 | 重做 BDF 时的校准源（未加 84B 容器头） |
| `art/VS010-smem_0-ART.bin` | 实机 1 MiB ART | 偏移取 131072 B 可重生成 BDF；⚠ 含本机 MAC，公开仓库建议脱敏 |
| `dts/VS010-反编译DTS.dts` / `dts/vs010.dtb` | 实机运行态 FDT（311 节点） | **硬件事实唯一权威源**：wps 键 GPIO34、mesh LED GPIO33、pwr LED GPIO31、`switch_cpu_bmp=0x40`/`lan=0x1e`/`wan=0x00`、8 对 `ar8327-initvals`、4 个 `port_phyinfo`、`ubi.mtd=rootfs swiotlb=1`。6.4 重写 DTS 时编号照抄 |
| `misc/VS010_原厂MTD分区表.txt` | 分区布局 | 注意区分：原厂 24 分区 ≠ 实机布局。这台机器已刷三方 U-Boot + 大分区 MIBIB，`mtd15 rootfs = 0x06e00000`（110 MiB）。分区由 U-Boot 经 `qcom,smem-part` 填充，**DTS 里不要写死偏移** |
| `source-snippets/02_network-cucc_vs010.inc` | 网口物理顺序 | `switch1 6u@eth1 3u@eth0`、`2:lan:1 4:lan:2 5:lan:3 1:lan:4`；6.4 用主线 DSA/`qca8k` 重写标签，物理映射不变 |
| `source-snippets/Device-cucc_vs010.inc` | FIT/NAND 参数 | `SOC=ipq5000`、`DEVICE_DTS_CONFIG=config@mp02.1`、`BLOCKSIZE=128k`、`PAGESIZE=2048`、`IMAGES=nand-factory.ubi` 照抄 |
| `misc/uboot-ipq50xx-cucc_vs010.bin` | 已验证能启动的三方 U-Boot | **升级内核不刷 U-Boot**；TTL 在手边（1.8V `ttyMSM0 115200n8`） |

## 二、必须重做的（5.4 / QSDK 专用，6.4 搬过去必挂）

| 项 | 为什么 |
|---|---|
| `dts/ipq5000-vs010.dts` **整体** | 用 QSDK 私有绑定：`qcom,ess-switch-ipq50xx`、`qcom,ess-switch-qca83xx`、`ar8327-initvals`、`qcom,nss-dp`、`qcom,ipq5018-q6-mpd`、remoteproc PD、`#ifndef CONFIG_ATH11K_MEM_PROFILE_256M`。6.4 主线没有，必须按主线 qcom 绑定重写 |
| QSDK 11.5 内核 + `backports-20210222-5.4-qsdk-11.5.0.5` | 换成 6.4 内核 + 对应 mac80211/ath11k backports |
| `kmod-qca-nss-dp` / `nss-drv` / `nss-ecm-standard` / `qca-ssdk-nohnat` / `qca-nss-fw-ipq50xx-retail` / `MAC80211_NSS_SUPPORT` | 🔴 **NSS 全链路是 QSDK 5.4 闭源驱动，6.4 没有对应包**。要么找开源实现，要么接受无硬件加速（主线 flow offload 兜底） |
| `ath11k-firmware-ipq5018/-qcn6122` 的包定义与 Q6 `m3_fw.mdt`/`q6_fw.mdt` 加载链 | 固件二进制可复用，但 6.4 驱动加载路径/索引方式要重新对 |
| `source-snippets/ipq-wifi.Makefile` | `PKG_FLAGS:=nonshared` + `generate-ipq-wifi-package` 是 21.02 这条线的写法；6.4 用上游 `ipq-wifi` 包或直接放 `board-2.bin` |
| `config/.config.vs010` **整体** | 全是 5.4 线符号（`CONFIG_TARGET_ipq50xx_arm_DEVICE_cucc_vs010`、`CONFIG_LINUX_5_4`、`CONFIG_PACKAGE_kmod-qca-nss-*`）；只对照「哪些功能开/关」 |
| `source-snippets/inject-vs010.py` | 针对 kkstone 21.02 目录结构的锚点注入（image/Makefile、02_network、ipq-wifi/Makefile）；6.4 目标树路径不同，**逻辑可参考、锚点必须重写** |
| `Device/UbiFit` / `append-ubi` 规则 | 5.4 这条线的 image 生成规则；6.4 按目标源码树重写 |

## 三、VS010 比 3000Q 多出来的坑（6.4 尤其注意）

1. **GPIO 完全不同**：3000Q `reset GPIO23` / `mesh GPIO38` / LED `24,19,17`；VS010 实机**只有一个 wps 键 GPIO34**、两颗 LED `mesh 33` / `pwr 31`。恩山互刷变砖案例正是复位键 GPIO 不一致。
2. **switch 私有寄存器两套档**：默认编译线用 3000Q 档（`cpu=0x48 / lan=0x34 / wan=0x02`、4 对 initvals、6 个 port），实机档是 `cpu=0x40 / lan=0x1e / wan=0x00`、8 对 initvals、4 个 port（`dts/switch-default.dts.inc`）。改私有寄存器有让网口全灭的风险，6.4 上线前用 `swconfig` 实机核对 WAN/LAN 标签。
3. **board-id / BDF 变体**：默认 `qmi-board-id=36/96`，另有 `boardid16`/`boardid96` 变体；6.4 驱动升级后枚举可能变，`dmesg` 先确认再选 BDF。
4. **分区不是原厂布局**：别把 `misc/VS010_原厂MTD分区表.txt` 当实机分区写进 DTS。

## 四、建议做法

**6.4 另起仓库**，复用本目录 + `rax3000q-6.4-baseline/` 的二进制板级资产（BDF / ART / GPIO / switch 位图 / 分区 / U-Boot / FIT 参数），
**不要**把 kkstone 21.02 源码树直接升级到 6.4：target、feeds、内核补丁、闭源 wifi/NSS 栈都不兼容。

编译前自检：
1. `dtc` 真编译 DTS（花括号 59/59，r29.6 教训）；
2. BDF 放好后 `dmesg | grep -i board-2` 确认 `qmi-board-id=36/96` 命中；
3. 明确 NSS/加速方案，别留空依赖；
4. 分区与 U-Boot 不刷、ART 不覆盖；
5. 双机型对照 `misc/VS010与CMCC机型DTS资料核查报告.md`，避免把 3000Q 的 GPIO 抄过来。

---
⚠ `art/`、`oem/0-*`、`oem/VS010-flash-backup-*.tar.gz` 含本机 MAC / 校准 / U-Boot 环境变量，公开仓库建议脱敏或私有保存。
