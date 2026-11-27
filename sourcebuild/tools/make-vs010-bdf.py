#!/usr/bin/env python3
"""第 22 次：生成 VS010 的 ipq-wifi board-2.bin 容器。

用法：
  # 用仓库里的通用 VS010 BDF（默认，板级校准）
  python3 tools/make-vs010-bdf.py
  # 用【本机】0:ART 分区 dump 生成每台专属校准（最准，推荐刷机后自行重编）
  python3 tools/make-vs010-bdf.py --art /tmp/VS010-smem_0-ART.bin
  # 2.4G 改用 board-id 16（对应 VS010 原厂 dtb 的 qcom,board_id=0x10）
  python3 tools/make-vs010-bdf.py --id24 16

ART 偏移（QSDK 5.4 线，来自 VS010 原厂分区表）：
  2.4G BDF  @ 0x1000   长 0x20000 (131072 B)
  5G  BDF  @ 0x26800  长 0x20000 (131072 B)
容器头 84 B 取自 kkstone 的 board-cmcc_rax3000q.*，与其格式逐字节同构。
"""
import argparse,pathlib,struct,hashlib,sys
ROOT=pathlib.Path(__file__).resolve().parent.parent
REF=ROOT/'reference/upstream/kkstone'
VS =ROOT/'reference/upstream/whmzsu-vs010'
OUT=ROOT/'package/ipq-wifi'

def build(template, body, out, bid=None):
    t=pathlib.Path(template).read_bytes()
    assert len(t)==131156 and t[:17]==b'QCA-ATH11K-BOARD\0', '模板格式不对'
    head=bytearray(t[:84])
    if bid is not None:
        name=f'bus=ahb,qmi-chip-id=0,qmi-board-id={bid}'.encode()
        assert len(name)==37
        head[36:73]=name
    b=pathlib.Path(body).read_bytes() if isinstance(body,(str,pathlib.Path)) else body
    assert len(b)==131072, f'板数据必须 131072 B，实际 {len(b)}'
    d=bytes(head)+b
    assert len(d)==131156
    pathlib.Path(out).write_bytes(d)
    print(f'  {pathlib.Path(out).name}: {head[36:73].decode().rstrip("m")}  sha256={hashlib.sha256(d).hexdigest()[:16]}')

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument('--art',help='本机 0:ART 分区 dump（1 MiB）')
    ap.add_argument('--id24',type=int,default=36,help='2.4G qmi-board-id（默认 36，备选 16）')
    ap.add_argument('--id5',type=int,default=96,help='5G qmi-board-id（默认 96）')
    a=ap.parse_args()
    if a.art:
        art=pathlib.Path(a.art).read_bytes()
        if len(art)<0x26800+0x20000: sys.exit('ART 文件太短')
        b24=art[0x1000:0x1000+0x20000]; b5=art[0x26800:0x26800+0x20000]
        print(f'  用本机 ART：{a.art}（2.4G sha={hashlib.sha256(b24).hexdigest()[:12]} / 5G sha={hashlib.sha256(b5).hexdigest()[:12]}）')
    else:
        b24=(VS/'bdwlan.bin').read_bytes(); b5=(VS/'qcn6102_bdwlan.bin').read_bytes()
        print('  用仓库通用 VS010 BDF（whmzsu oem_extract）')
    OUT.mkdir(parents=True,exist_ok=True)
    build(REF/'board-cmcc_rax3000q.ipq5018',b24,OUT/'board-cucc_vs010.ipq5018',a.id24)
    build(REF/'board-cmcc_rax3000q.qcn6122',b5,OUT/'board-cucc_vs010.qcn6122',a.id5)
    print('  ✅ 完成。重跑 Actions 即可把本机专属校准编进固件。')

if __name__=='__main__': main()
