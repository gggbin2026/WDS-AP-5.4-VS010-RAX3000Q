# VS010 MIBIB 分区表（实测，r24）

> 数据源：`reference/backup/VS010-flash-backup-20240414-135754.tar.gz` →
> `mtd01-0_MIBIB.bin`（512 KiB，sha256 `82f7685461086b6256…`）。
> 解析工具：`sourcebuild/tools/parse-vs010-backup.py`（可复跑）。
> 校验：备份包 15 个分区的 sha256 与 `manifest.txt` **15/15 全部匹配**。
> 该工具与 workflow 的 `Validate real-hardware backup evidence` step 会把下面数字当断言复核。

## 表头（@0x800）

| 字段 | 值 |
|---|---|
| magic1 | `0x55ee73aa`（磁盘字节 `aa 73 ee 55`） |
| magic2 | `0xe35ebddb`（磁盘字节 `db bd 5e e3`） |
| version | `4` |
| **numparts** | **16** |
| 条目起点 | `0x810`，每条 **28 B**（`name[16] + u32 off + u32 size + u32 attr`） |
| **off/size 单位** | **`0x20000` = 128 KiB 擦除块**（不是字节） |
| attr | 全部 `0xffff` |

🔴 **更正 r23 的推断**：之前按 `vs010.dtb` 写「原厂 24 分区，分区由 U-Boot 经 `qcom,smem-part` 填充」。
实机 MIBIB 是**16 分区**，且这份 MIBIB 本身就是大分区布局（`rootfs` 110 MiB）——
分区表确实由 SMEM 提供给内核，但**表本体已在这份备份里，可以逐字节核对**，不再是推断。

## 16 个分区

| # | 分区 | 块(off,size) | 偏移 | 大小 | 对应 `/proc/mtd` |
|---|---|---|---|---|---|
| 0 | `0:SBL1` | 0, 4 | `0x00000000` | `0x00080000` (512K) | mtd0 |
| 1 | `0:MIBIB` | 4, 4 | `0x00080000` | `0x00080000` | mtd1 |
| 2 | `0:BOOTCONFIG` | 8, 2 | `0x00100000` | `0x00040000` | mtd2 |
| 3 | `0:BOOTCONFIG1` | 10, 2 | `0x00140000` | `0x00040000` | mtd3 |
| 4 | `0:QSEE` | 12, 8 | `0x00180000` | `0x00100000` (1M) | mtd4 |
| 5 | `0:QSEE_1` | 20, 8 | `0x00280000` | `0x00100000` | mtd5 |
| 6 | `0:DEVCFG` | 28, 2 | `0x00380000` | `0x00040000` | mtd6 |
| 7 | `0:DEVCFG_1` | 30, 2 | `0x003c0000` | `0x00040000` | mtd7 |
| 8 | `0:CDT` | 32, 2 | `0x00400000` | `0x00040000` | mtd8 |
| 9 | `0:CDT_1` | 34, 2 | `0x00440000` | `0x00040000` | mtd9 |
| 10 | `0:APPSBLENV` | 36, 4 | `0x00480000` | `0x00080000` | mtd10 |
| 11 | `0:APPSBL` | 40, 10 | `0x00500000` | `0x00140000` (1.25M) | mtd11 |
| 12 | `0:APPSBL_1` | 50, 10 | `0x00640000` | `0x00140000` | mtd12 |
| 13 | **`0:ART`** | 60, 8 | **`0x00780000`** | **`0x00100000` (1M)** | mtd13 |
| 14 | `0:TRAINING` | 68, 4 | `0x00880000` | `0x00080000` | mtd14 |
| 15 | **`rootfs`** | 72, 880 | **`0x00900000`** | **`0x06e00000` (110M)** | mtd15 |

- 前 15 项合计 `0x00900000` = **9 MiB**，与 `/proc/mtd` 的 mtd0..mtd14 逐项吻合
- `rootfs` 起始 `0x900000`、大小 `0x6e00000`（110 MiB）→ **大分区 U-Boot**，实锤
- `0:ART @0x780000` 与 `vs010.dtb` 的 `qcom,bdf-addr` / 实机 dmesg 的 BDF 加载位置一致

## 与 `/proc/mtd` 的关系

Linux 侧看到的 `mtd16 kernel / mtd17 rootfs / mtd18 rootfs_data` 是 **UBI 卷**，
不是 MIBIB 分区 —— 它们是 `rootfs` 这个 MTD 分区内部再切出来的：

```
mtd15 rootfs 0x00900000 (110 MiB)
   └─ UBI: kernel 0x003e0000 / rootfs 0x01531000 / rootfs_data 0x04e97000
```

所以源码编译线的 DTS 里**不应该**把这 16 个偏移写死（内核走 `qcom,smem-part` 从 SMEM 拿），
但**偏移量必须按这份表理解**：`make` 出来的 `nand-factory.ubi` 写到 `rootfs` 分区起点 `0x900000`。

## 回刷 / 救砖提示

- 刷机只写 `rootfs`（U-Boot web 的 `POST /upload`），**绝不动 mtd0..mtd14**
- `0:ART`、`0:TRAINING`、`0:MIBIB`、`0:CDT` 每台/每板唯一，**不跨机复制**
- 回刷原厂小分区固件前，必须先把 MIBIB 换回原厂分区表，否则 `rootfs` 偏移对不上
- 请保留 `mtd01-0_MIBIB.bin` 这份 512 KiB 原件，它是恢复分区表的唯一依据
