> ⚠ 历史记录（r20~r23）。当前基线见根 `CHANGELOG.md` / `STANDARDS.md`；
> r25 起融合线已移除、本目录为唯一编译线。

# 更新记录

| 版本 | 内容 |
|---|---|
| **第 23 次** | 按用户要求核对仓库里的 VS010 实机资料并修正板级参数：`VS010文件.txt` / `A 好固件·阶段1.txt` 原是 GBK 实机日志（已转 UTF-8 留档），里面没有 GPIO 编号，但有更硬的证据 —— `Downloading BDF: IPQ5018/bdwlan.b10, size: 131072` / `qcn6122/bdwlan.b60, size: 131072` 直接证实 r22 拉的 BDF 就是这台机器用的；`iw dev` 给出 2 phy / 4 interface 基线；`mtd15 rootfs=0x06e00000` 证实已刷三方 U-Boot 大分区；`/proc/cmdline` 证明 r22 漏了 `ubi.mtd=rootfs swiotlb=1`。GPIO 数值取自 `DTS/vs010.dtb`：按键只留 wps GPIO34(KEY_WPS_BUTTON)、删掉 3000Q 的 23/38；LED 改 mesh GPIO33 / pwr GPIO31；pinctrl 与 bias 同步；bootargs 补回两参数；分区结论更正为「由 U-Boot 填充、不写死 24 分区」。🔴 switch 私有寄存器（8 对 initvals / 位图 0x40,0x1e,0x00 / 4 个 PHY 口）逐字段提取留档但**默认不改**（有线已验证可用，改错会网口全灭），做成 `vs010_switch_oem` 可选档 + 逐字节回退脚本。 |
| **第 22 次** | 按用户要求去第三方仓库拉取 VS010 无线文件并修复 010 无线：从 `whmzsu/vs010-openwrt`（与 `xiangye277` 同一份）的 `oem_extract/` 拿到 VS010 2.4G/5G 裸 BDF（各 131072 B），用本仓库两份 VS010 ART 交叉校验（99.2% / 97.7%）。逆向 `kkstone` 的 `board-2.bin` 容器格式（84 B 头 + 131072 B body），生成 `board-cucc_vs010.ipq5018`/`.qcn6122`，`diy-part1` 注入主树并注册 `ipq-wifi-cucc_vs010` 包，Device 选入该包 + 双频段 `ath11k-firmware-*`。🔴 更正 r21 结论：本线是开源 ath11k，Q6/m3 固件由 `ath11k-firmware-*` 提供，不需原厂 `q6_fw.mdt`，缺的只是 VS010 板级 BDF；010 源码线改为默认可编。新增 `vs010-wifi-check` 实机诊断、`make-vs010-bdf.py`（支持从本机 ART 生成每台专属校准）、board-id 16 备选容器。 |
| **第 21 次** | 推倒重来，从「官方 factory.bin 融合重打包」切到 `kkstone/immortalwrt-ipq50xx @ openwrt-21.02` 真实 `make` 编译。`.config` 两份（3000Q / 010 实验），关 14 个杂项包降内存，编译期替换 Argon **v2.4.3**（最后一个 Lua 兼容 tag，v2.4.4+ 是 ucode）。沿用 r20 的单常驻 `vs010-tick` 与网桥/AP 界面物理隔离，新增 `files.manifest` 白名单杜绝历史残留混入。固件名 `Nwrt-QSDK12.2-5.4-<YYYYMMDD-HHMM>-...`。🔴 取证 `vs010.dtb`：VS010 是闭源 `cnss-qca5018` + `bdwlan.b10/b60`，与源码线开源 ath11k + `board-2.bin` 三处不兼容，故 010 源码线默认关闭、无线满血仍由融合线保证；ART 每台独立、不进固件、不硬编码 MAC。 |
| 第 20 次 | 4 个 procd 常驻 loop → 1 个 `vs010-tick`；网桥固件不含 AP 页、AP 固件不含网桥页 |
| 第 19 次 | 修 CI `Apply installed baseline` 幂等截断 BUG |
| 第 18 次 | 合并冲突善后包 |
| 第 17 次 | Argon 2.4.3（Lua）注入 + WDS 主/客 .241/.242 开关 |
| 第 16 次 | 修登录密码占位 hash、AP 弱信号、IPv6 全关、防火墙全关 |
| 第 1–15 次 | 官方 5.4.213 双机型融合底座、双模式、TTYD/机器狗/NTP/STP/主题守卫等 |
