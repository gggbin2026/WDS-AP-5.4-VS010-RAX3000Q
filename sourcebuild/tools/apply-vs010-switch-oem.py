#!/usr/bin/env python3
"""第 23 次（可选）：把 VS010 DTS 的 QCA8337 段在两档之间切换。

  默认档 = 3000Q 已验证值（用户实机「网卡什么都能起来」）
  OEM 档 = 仓库 vs010.dtb 的实机值

默认【不跑】。改 QSDK 私有寄存器（qca,ar8327-initvals / port_phyinfo /
switch_*_bmp）有让网口全灭的风险；只有在刷完发现 WAN/LAN 物理口顺序
不对、且 TTL 在手边时才切。

用法：
  python3 tools/apply-vs010-switch-oem.py                 # 切到 OEM 档
  python3 tools/apply-vs010-switch-oem.py --restore      # 回退到默认档
  python3 tools/apply-vs010-switch-oem.py --dts <路径>   # CI 里指定源码树里的 DTS

数值逐字段取自仓库 3000Q-VS010-固件/DTS/vs010.dtb（运行态 FDT）：
  switch_cpu_bmp = <0x40>   port6 是唯一 CPU 口
  switch_lan_bmp = <0x1e>   port1..4 为 LAN
  switch_wan_bmp = <0x00>   QCA8337 上无独立 WAN 位（WAN 走 gmac0/GE PHY）
  qca,ar8327-initvals 8 对（3000Q 只有 4 对）
  qcom,port_phyinfo 4 个 PHY 口（port_id 1..4 / phy_address 0..3）

注意：02_network 的 ucidef_add_switch 端口标签【未改】—— QSDK ESS 内部
port_id 与 uci 端口编号的映射无法从现有材料确定，需实机 swconfig / 插线核对。
"""
import argparse
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
B = "// BEGIN_SWITCH_OEM"
E = "// END_SWITCH_OEM"

OEM = """\t\t// r23 实机 OEM 档：逐字段取自 vs010.dtb（需实机核对 WAN/LAN 标签）
\t\t// BEGIN_SWITCH_OEM
\t\tess-switch1@1 {
\t\t\tcompatible = "qcom,ess-switch-qca83xx";
\t\t\tdevice_id = <1>;

\t\t\treset_gpio = <26>;

\t\t\tswitch_access_mode = "mdio";
\t\t\tmdio-bus = <&mdio1>;

\t\t\t// vs010.dtb 的 8 对（3000Q 只有 4 对）
\t\t\tqca,ar8327-initvals = <
\t\t\t\t0x0004 0x07600000
\t\t\t\t0x0008 0x01000000
\t\t\t\t0x000c 0x00000080
\t\t\t\t0x0010 0x002613a0
\t\t\t\t0x00e4 0x000aa545
\t\t\t\t0x00e0 0xc74164de
\t\t\t\t0x007c 0x0000004e
\t\t\t\t0x0094 0x0000004e
\t\t\t>;

\t\t\t// vs010.dtb: cpu=0x40 / lan=0x1e / wan=0x00
\t\t\tswitch_cpu_bmp = <0x40>;
\t\t\tswitch_lan_bmp = <0x1e>;
\t\t\tswitch_wan_bmp = <0x00>;

\t\t\tqcom,port_phyinfo {
\t\t\t\t// vs010.dtb 只有 4 个 PHY 口：port_id 1..4 / phy_address 0..3
\t\t\t\tport@1 { port_id = <1>; phy_address = <0>; };
\t\t\t\tport@2 { port_id = <2>; phy_address = <1>; };
\t\t\t\tport@3 { port_id = <3>; phy_address = <2>; };
\t\t\t\tport@4 { port_id = <4>; phy_address = <3>; };

\t\t\t\t// QSDK 必要的 CPU 口骨架，沿用 3000Q
\t\t\t\tport@6 {
\t\t\t\t\tport_id = <6>;
\t\t\t\t\tforced-speed = <1000>;
\t\t\t\t\tforced-duplex = <1>;
\t\t\t\t};
\t\t\t};
\t\t};
\t\t// END_SWITCH_OEM"""

def default_block():
    """默认档逐字节留档在 reference/variants/，保证 --restore 完全还原。"""
    f = ROOT / "reference/variants/switch-default.dts.inc"
    if not f.exists():
        sys.exit("缺默认档留档：" + str(f))
    return f.read_text()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dts", default=str(ROOT / "target/ipq50xx/ipq5000-vs010.dts"))
    ap.add_argument("--restore", action="store_true", help="回退到 3000Q 已验证档")
    a = ap.parse_args()

    p = pathlib.Path(a.dts)
    s = p.read_text()
    if B not in s or E not in s:
        sys.exit("DTS 缺 BEGIN/END_SWITCH_OEM 标记，无法安全切换")

    lines = s.splitlines(keepends=True)
    bi = next(i for i, l in enumerate(lines) if B in l)
    ei = next(i for i, l in enumerate(lines) if E in l)
    # 连 BEGIN 上面紧邻的注释行一起换掉
    while bi > 0 and lines[bi - 1].lstrip().startswith("//"):
        bi -= 1

    text = default_block() if a.restore else OEM
    block = text.splitlines(keepends=True)
    block = [l + "\n" if not l.endswith("\n") else l for l in block]
    lines[bi:ei + 1] = block
    out = "".join(lines)
    assert out.count(B) == 1 and out.count(E) == 1, "标记数异常"
    p.write_text(out)

    print("  ✅ 已切到", "3000Q 已验证档" if a.restore else "VS010 实机 OEM 档", "→", p)
    print("  ⚠ 刷前请 TTL 在手边；02_network 的 WAN/LAN 标签需实机核对")


if __name__ == "__main__":
    main()
