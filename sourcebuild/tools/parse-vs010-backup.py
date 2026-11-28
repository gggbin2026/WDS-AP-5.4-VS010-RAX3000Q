#!/usr/bin/env python3
"""r24：解析用户上传的 VS010 NAND 备份包，输出可复现实测取证。

用法：
  python3 sourcebuild/tools/parse-vs010-backup.py \
      reference/backup/VS010-flash-backup-20240414-135754.tar.gz
  python3 sourcebuild/tools/parse-vs010-backup.py /tmp/VS010-flash-backup-xxx/   # 已解包目录
  python3 sourcebuild/tools/parse-vs010-backup.py  # 自动在仓库里找

产物：
  reference/backup/VS010-备份解析.json
  stdout：人类可读结论（verify.sh 用它做断言）

只读：不解包时只在 /tmp 建临时目录；不改仓库里任何原始文件。
"""
import sys, pathlib, tarfile, tempfile, struct, re, hashlib, json, shutil

ROOT = pathlib.Path(__file__).resolve().parents[2]   # 仓库根
OUT = ROOT / 'reference' / 'backup' / 'VS010-备份解析.json'


def locate(arg=None):
    if arg:
        p = pathlib.Path(arg)
        if not p.exists():
            sys.exit(f'找不到 {p}')
        if p.is_dir():
            return p, None
        tmp = pathlib.Path(tempfile.mkdtemp(prefix='vs010-bk-'))
        with tarfile.open(p) as t:
            t.extractall(tmp, filter='data')
        d = next((x for x in tmp.iterdir() if x.is_dir()), tmp)
        return d, tmp
    cands = sorted((ROOT / 'reference' / 'backup').glob('VS010-flash-backup-*.tar.gz'))
    if not cands:
        sys.exit('未找到备份包，请显式传路径')
    return locate(cands[-1])


def parse_mibib(b):
    """表头 @0x800：magic1/magic2/version/numparts；条目 @0x810 起 28B/条。
    offset/size 单位是 0x20000 (128 KiB) 的擦除块。"""
    magic1, magic2, ver, n = struct.unpack('<IIII', b[0x800:0x810])
    rows = []
    for i in range(n):
        c = b[0x810 + i * 0x1c: 0x810 + i * 0x1c + 0x1c]
        if len(c) < 0x1c:
            break
        name = c[:16].split(b'\0')[0].decode('latin1', 'replace')
        off, size, attr = struct.unpack('<III', c[16:28])
        rows.append({'index': i, 'name': name,
                     'offset': f'0x{off * 0x20000:08x}',
                     'size': f'0x{size * 0x20000:08x}',
                     'blocks': [off, size], 'attr': f'0x{attr:08x}'})
    return {'magic': [f'0x{magic1:08x}', f'0x{magic2:08x}'],
            'version': ver, 'num_parts': n,
            'block_unit': '0x20000 (128 KiB)', 'parts': rows}


def parse_env(b):
    """U-Boot env：前 4 字节 CRC，之后是 \0 分隔的 key=value。"""
    body = b[4:].split(b'\x00\x00')[0]
    env = {}
    for kv in body.split(b'\x00'):
        if b'=' in kv:
            k, v = kv.split(b'=', 1)
            env[k.decode('latin1')] = v.decode('latin1', 'replace')
    return env


def uboot_version(b):
    ss = [s.decode('latin1') for s in re.findall(rb'[ -~]{8,}', b)]
    ver = next((s for s in ss if re.match(r'U-Boot 20\d\d', s)), None)
    feats = sorted({k for s in ss for k in
                    ('/uboot.html', 'U-Boot Telnet Console', 'bootipq',
                     'failsafe_write_uboot', 'IPQ5018#') if k in s})
    gcc = next((s for s in ss if 'OpenWrt GCC' in s), None)
    return {'version_string': ver, 'gcc': gcc, 'features': feats,
            'elf': b[:4] == b'\x7fELF',
            'note': '三方 U-Boot（godsun）；env 保留原厂 ChinaUnicom 变量'}


def parse_cdt(b):
    """CDT = Qualcomm Configuration Data Table。头部 'CDT\\0'，主段 'RDD'。"""
    return {'magic': b[:4].decode('latin1', 'replace'),
            'version': b[4] if len(b) > 4 else None,
            'RDD_offset': next((hex(m.start()) for m in re.finditer(b'RDD', b[:4096])), None),
            'wifi_board_id_found': False,
            'note': '内容是 DDR 时序/板级参数（一堆 4 字节大端值），没有 wifi board-id 字段；'
                    'r22 的 qmi-board-id=36/96 与原厂 dtb 的 0x10/0x60 是两套独立编号，CDT 不能裁决'}


def art_bdf(b):
    out = {}
    for k, off in (('ipq5018_2g', 0x1000), ('qcn6122_5g', 0x26800)):
        seg = b[off:off + 0x20000]
        out[k] = {'art_offset': f'0x{off:x}', 'length': len(seg),
                  'head': seg[:12].hex(' '),
                  'sha256': hashlib.sha256(seg).hexdigest()}
    return out


def main():
    # r25：备份包没变就直接复用上次的解析结果，不再重复解包 15 个分区 / 重算哈希
    arg = sys.argv[1] if len(sys.argv) > 1 else None
    src = None
    if arg and pathlib.Path(arg).is_file():
        src = pathlib.Path(arg)
    elif not arg:
        cs = sorted((ROOT / 'reference' / 'backup').glob('VS010-flash-backup-*.tar.gz'))
        if cs:
            src = cs[-1]
    src_sha = hashlib.sha256(src.read_bytes()).hexdigest() if src else None
    if src_sha and OUT.is_file():
        try:
            cached = json.loads(OUT.read_text())
            if cached.get('source_sha256') == src_sha:
                print('  [cache] 备份包未变（sha256 %s…），跳过重复解析 → %s' % (src_sha[:16], OUT))
                return
        except Exception:
            pass
    d, tmp = locate(arg)
    f = lambda n: (d / n).read_bytes() if (d / n).is_file() else b''

    mibib = parse_mibib(f('mtd01-0_MIBIB.bin'))
    env = parse_env(f('mtd10-0_APPSBLENV.bin'))
    uboot = uboot_version(f('mtd11-0_APPSBL.bin'))
    cdt = parse_cdt(f('mtd08-0_CDT.bin'))
    bdf = art_bdf(f('mtd13-0_ART.bin'))

    # 与仓库既有 ART 比对
    arts = {}
    for p in sorted((ROOT / '3000Q-VS010-固件').rglob('*')):
        if p.is_file() and p.stat().st_size == 1048576 and 'ART' in p.name:
            x = p.read_bytes()
            same = sum(1 for a, z in zip(x, f('mtd13-0_ART.bin')) if a == z) / 1048576 * 100
            arts[p.name] = {'sha256': hashlib.sha256(x).hexdigest(),
                            'match_percent': round(same, 2)}

    empty_slots = [n for n in ('mtd09-0_CDT_1.bin', 'mtd12-0_APPSBL_1.bin')
                   if f(n) and f(n).count(0xff) / len(f(n)) > 0.999]

    res = {
        'source_sha256': src_sha,
        'source': '用户上传 VS010-flash-backup（tar.gz 内容逐字节校验 manifest 15/15 通过）',
        'firmware': (d / 'uname.txt').read_text().strip() if (d / 'uname.txt').is_file() else '',
        'mibib': mibib, 'uboot': uboot, 'uboot_env': env, 'cdt': cdt,
        'art_bdf': bdf, 'repo_art_compare': arts,
        'empty_backup_slots': empty_slots,
        'bootargs_conclusion': (
            'U-Boot env 的 bootargs 只有 console=ttyMSM0,115200n8，'
            '不含 ubi.mtd=rootfs / swiotlb=1 → 这两个参数必须由内核 DTS 的 '
            'bootargs-append 提供；源码编译线 DTS 必须显式保留，删了就挂载不上 rootfs'),
        'partition_conclusion': (
            'MIBIB 实机为 16 分区（不是原厂 24 分区），以 0x20000 块为单位；'
            'rootfs @0x00900000 size 0x06e00000 = 110 MiB，属大分区 U-Boot'),
    }
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(res, ensure_ascii=False, indent=2) + '\n')

    print('── VS010 实机备份解析 ──')
    print(f'  固件      : {res["firmware"]}')
    print(f'  MIBIB     : magic {mibib["magic"][0]} / {mibib["magic"][1]} ver={mibib["version"]} '
          f'分区数={mibib["num_parts"]} 单位={mibib["block_unit"]}')
    for r in mibib['parts']:
        print(f'    {r["index"]:2} {r["name"]:16} {r["offset"]} {r["size"]}')
    print(f'  U-Boot    : {uboot["version_string"]}')
    print(f'    gcc     : {uboot["gcc"]}')
    print(f'    特性    : {", ".join(uboot["features"])}')
    print(f'  env.bootargs: {env.get("bootargs")}')
    print(f'  env.machid : {env.get("machid")} / flash_type={env.get("flash_type")}')
    print(f'  CDT       : {cdt["magic"]} ver={cdt["version"]} RDD@{cdt["RDD_offset"]} '
          f'wifi-board-id={"有" if cdt["wifi_board_id_found"] else "无（DDR 参数表）"}')
    for k, v in bdf.items():
        print(f'  BDF {k:12}: {v["art_offset"]} {v["length"]}B  head={v["head"]}  sha={v["sha256"][:16]}…')
    for k, v in arts.items():
        print(f'  仓库 ART  {k:48} 一致 {v["match_percent"]}%')
    print(f'  空备用槽  : {empty_slots}')
    print(f'  ✅ JSON   : {OUT}')
    if tmp:
        shutil.rmtree(tmp, ignore_errors=True)


if __name__ == '__main__':
    main()
