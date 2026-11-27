# 变更记录

> 本仓库于 **2026-11-27** 按 r25 重整为**单线自包含全能包**：清空仓库后解压即用。
> 历史增量包（r1~r24 的各种 zip / md）不再保留，历史结论已并入下列文档。
> 验收基线见 `STANDARDS.md`，实机参数见 `reference/vs010-oem/VS010-实机参数.log`。

| 版本 | 关键内容 |
|---|---|
| **r25** | **全能包 / 单线**：移除融合线全部资产，只留 `build-source.yml`；BDF·CDT·MIBIB·ART·U-Boot 等 10 个实机二进制落库 `reference/vs010-oem/`（带 sha256）；`VS010-实机参数.log` 逐项注明「实机读取、✅ 可直接使用」；网桥/AP 界面新增**链接速率**与**无线芯片温度**；**网桥只用 5G**（2.4G 关闭）、**AP 用 2.4G**；去开机 `sleep 15`、loop `35s→5s / 60s→120s`；关 `autocore-arm`；`STANDARDS.md` 写成每版硬验收项；解析工具加 sha256 缓存，不再重复拉取/解包 |
| **r24** | 解析用户上传的 NAND 备份（15 分区 sha256 全匹配）：MIBIB **16 分区**实证、`rootfs 0x00900000/0x06e00000`；U-Boot `godsun 2026-08-14` 单槽；env.bootargs 只给 console → `bootargs-append` 双硬断言不可删；CDT 无 wifi board-id；BDF body 改从本机 ART 提取（100% 校准）；源码线隔离进 `sourcebuild/` 解决 workflow 同名合并冲突 |
| **r23** | 按实机 `vs010.dtb` 修正 VS010 板级参数：GPIO34(wps)/33(mesh)/31(pwr)、bootargs 补 `ubi.mtd=rootfs swiotlb=1`；switch 实机档做成可选开关（默认保留已验证档） |
| **r22** | 010 无线修复：注入 `board-cucc_vs010.ipq5018/.qcn6122` BDF 容器 + 双频段 Q6/m3 固件，与 3000Q 包互斥防 `CONFLICTS` |
| **r21** | 从「官方 factory.bin 融合重打包」切到 `kkstone/immortalwrt-ipq50xx @ openwrt-21.02` 真实 `make`；编译期装 Argon v2.4.3；两份 `.config` 精简包集合 |
| **r20** | 4 个 procd 常驻 loop 合并为单常驻 `vs010-tick`；网桥/AP 界面物理隔离 |
| **r15~r19** | `/bridge/` `/ap/` 丰富状态页、链接速率 PHY 兜底、单 5G SSID 收敛、模式隔离白名单 |

🔴 贯穿所有版本的三条红线：**WDS 两端都绝不能开 DHCP 服务端**、
**不重建 radio / 不 `wifi down`**、**SSH + 串口 + TTYD 必须可用**。
