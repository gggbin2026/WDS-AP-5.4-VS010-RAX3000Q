# sourcebuild/ · 源码编译线

本目录是**唯一编译线**的全部输入，由根目录 `.github/workflows/build-source.yml` 使用。

- `.config.rax3000q` / `.config.vs010`：两份编译期配置
- `diy-part1.sh` / `diy-part2.sh`：源码树注入 + 验收断言
- `files/` + `files.manifest`：按白名单注入固件的 39 个文件（模式隔离见 `mode-exclude.*`）
- `target/`：VS010 的 DTS / Device / board.d / `inject-vs010.py`
- `package/ipq-wifi/`：从本机 `0:ART` 提取的两个 BDF 容器
- `tools/`：`verify.sh`（单线自检）、`parse-vs010-backup.py`（备份解析，带缓存）、BDF/switch 工具
- `reference/`：上游资料与 r20~r23 取证留档

总说明见根 `README.md`，验收基线见根 `STANDARDS.md`。
