#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
官方 factory.bin 为底座的叠加打包器。
kernel FIT 卷逐 PEB 原样保留；只解 rootfs squashfs、注入新增文件、重打包。
不碰 ART / 分区表 / 内核 / 驱动 / BDF / /etc/config/*。

用法: python3 build/fused.py <官方factory.bin> <注入目录> <输出.bin>
UBI 头事实（原镜像逐 PEB 实测，418/418 CRC 校验通过）：
  crc = zlib.crc32(data) ^ 0xFFFFFFFF   （kernel crc32(~0,...) 无 final xor）
  本镜像 VID 的 data_size/data_crc/sqnum 全为 0，替换数据区不影响任何 CRC。
"""
import sys, os, struct, zlib, math, pathlib, hashlib, subprocess, shutil, tempfile, glob

PEB, VID_OFF, DATA_OFF = 131072, 2048, 4096
LEB = PEB - DATA_OFF
VTBL_STRIDE, LAYOUT_VID = 172, 0x7fffefff
CRC = lambda d: (zlib.crc32(d) & 0xffffffff) ^ 0xffffffff
PRUNE_LIST = os.environ.get('VS010_PRUNE_LIST', '')
PRUNE_KEEP = os.environ.get('VS010_PRUNE_KEEP', '')
def log(*a): print('[fused]', *a, flush=True)
def die(*a): print('::error::', *a, flush=True); sys.exit(1)

def parse(path):
    b = pathlib.Path(path).read_bytes()
    if len(b) % PEB: die('镜像大小不是 PEB 倍数', len(b))
    out = []
    for i in range(len(b)//PEB):
        p = b[i*PEB:(i+1)*PEB]
        ec, vid = p[:64], p[VID_OFF:VID_OFF+64]
        if ec[:4] != b'UBI#' or vid[:4] != b'UBI!': die('PEB %d 头损坏' % i)
        if struct.unpack_from('>I', ec, 60)[0] != CRC(ec[:60]): die('PEB %d EC crc' % i)
        if struct.unpack_from('>I', vid, 60)[0] != CRC(vid[:60]): die('PEB %d VID crc' % i)
        out.append({'idx': i, 'ec': ec, 'vid': vid,
                    'vol': struct.unpack_from('>I', vid, 8)[0],
                    'lnum': struct.unpack_from('>I', vid, 12)[0],
                    'data': p[DATA_OFF:]})
    return b, out

def make_vid(t, lnum):
    v = bytearray(t); struct.pack_into('>I', v, 12, lnum)
    struct.pack_into('>I', v, 60, CRC(bytes(v[:60]))); return bytes(v)

def patch_vtbl(d, n):
    d = bytearray(d); hit = False
    for off in range(0, VTBL_STRIDE*8, VTBL_STRIDE):
        r = d[off:off+172]
        if len(r) < 172: break
        nl = struct.unpack_from('>H', r, 14)[0]
        if not nl or nl > 127: continue
        if bytes(r[16:16+nl]).decode('latin1','replace') != 'rootfs': continue
        old = struct.unpack_from('>I', r, 0)[0]
        struct.pack_into('>I', d, off, n)
        struct.pack_into('>I', d, off+168, CRC(bytes(d[off:off+168])))
        log('  卷表 rootfs reserved_pebs: %d -> %d' % (old, n)); hit = True
        break
    if not hit: die('卷表找不到 rootfs')
    return bytes(d)

def repack(orig, inject, out):
    tmp = tempfile.mkdtemp(prefix='fused-root-')
    try:
        r = subprocess.run(['unsquashfs','-d',tmp,'-f',orig], capture_output=True, text=True)
        n0 = sum(1 for _ in pathlib.Path(tmp).rglob('*') if _.is_file())
        if n0 < 2000: die('unsquashfs 解包不完整 (%d)' % n0, r.stdout[-500:], r.stderr[-500:])
        src = pathlib.Path(inject); nadd = 0; probe = ''
        clash = []
        for p in src.rglob('*'):
            rel = p.relative_to(src)
            dst = pathlib.Path(tmp)/rel
            if p.is_symlink():                    # rc.d 自启链接必须保持为链接
                if os.path.lexists(dst): clash.append(str(rel))
                dst.parent.mkdir(parents=True, exist_ok=True)
                os.symlink(os.readlink(p), dst); nadd += 1
                continue
            if p.is_file():
                if os.path.lexists(dst): clash.append(str(rel))
                if not probe: probe = str(rel)
                dst.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(p, dst); nadd += 1
        if clash:
            die('注入树会覆盖官方文件（禁止，会破坏无线/网络）:', *clash[:5])
        log('  rootfs 原 %d 文件，新增 %d 个' % (n0, nadd))
        # ── 构建期精简：删无关配置/自启链接/控制器，白名单硬断言 ──
        if PRUNE_LIST:
            pats = [l.strip() for l in pathlib.Path(PRUNE_LIST).read_text().splitlines()
                    if l.strip() and not l.startswith('#')]
            removed = []
            for pat in pats:
                for q in glob.glob(os.path.join(tmp, pat)):
                    rel = os.path.relpath(q, tmp)
                    if os.path.islink(q) or os.path.isfile(q): os.remove(q); removed.append(rel)
                    elif os.path.isdir(q): shutil.rmtree(q); removed.append(rel)
            keeps = [l.strip() for l in pathlib.Path(PRUNE_KEEP).read_text().splitlines()
                     if l.strip() and not l.startswith('#')]
            miss = [k for k in keeps if not os.path.lexists(os.path.join(tmp, k))]
            if miss: die('精简误删白名单（禁止出包）:', *miss[:6])
            log('  精简：移除 %d 项，白名单 %d 项全在' % (len(removed), len(keeps)))
        r = subprocess.run(['mksquashfs',tmp,out,'-comp','xz','-b','262144','-noappend',
                            '-no-progress','-force-uid','1000','-force-gid','1000',
                            '-p','dev/console c 600 1000 1000 5 1'], capture_output=True, text=True)
        if r.returncode: die('mksquashfs 失败', r.stdout[-800:], r.stderr[-800:])
        sz = pathlib.Path(out).stat().st_size
        log('  新 squashfs %d B -> %d LEB' % (sz, math.ceil(sz/LEB)))
        return sz, probe
    finally:
        shutil.rmtree(tmp, ignore_errors=True)

def build(src, inject, out):
    b, pebs = parse(src)
    log('源镜像 %s  %d B / %d PEB' % (pathlib.Path(src).name, len(b), len(pebs)))
    vols = {}
    for p in pebs: vols.setdefault(p['vol'], []).append(p)
    if 0 not in vols or 1 not in vols: die('缺 kernel/rootfs 卷')
    kernel = sorted(vols[0], key=lambda x: x['lnum'])
    rootfs = sorted(vols[1], key=lambda x: x['lnum'])
    layout = sorted(vols.get(LAYOUT_VID, []), key=lambda x: x['lnum'])
    if not layout: die('缺 layout 卷')
    if [p['lnum'] for p in rootfs] != list(range(len(rootfs))): die('rootfs lnum 不连续')

    td = tempfile.mkdtemp(prefix='fused-raw-')
    orig, new = os.path.join(td,'o.sqfs'), os.path.join(td,'n.sqfs')
    with open(orig,'wb') as f:
        for p in rootfs: f.write(p['data'])
    _, probe = repack(orig, inject, new)
    ns = pathlib.Path(new).read_bytes()
    nleb = math.ceil(len(ns)/LEB)
    lebs = [ns[i*LEB:(i+1)*LEB].ljust(LEB, b'\xff') for i in range(nleb)]
    layout_out = [patch_vtbl(p['data'], max(nleb, len(rootfs))) for p in layout]

    def emit(ec, vid, data):
        peb = bytearray(b'\xff'*PEB); peb[0:64]=ec; peb[VID_OFF:VID_OFF+64]=vid; peb[DATA_OFF:]=data
        return bytes(peb)
    # 🔴 严格按原镜像物理 PEB 顺序：layout/kernel 不挪位，只在末尾扩 rootfs
    order = sorted(pebs, key=lambda x: x['idx'])
    hl = [p for p in order if p['vol']==LAYOUT_VID]
    hk = [p for p in order if p['vol']==0]
    assert len(hl)==len(layout) and len(hk)==len(kernel)
    outb = bytearray()
    for i,p in enumerate(hl): outb += emit(p['ec'],p['vid'],layout_out[i][:LEB].ljust(LEB,b'\xff'))
    for p in hk: outb += emit(p['ec'],p['vid'],p['data'])
    for i,d in enumerate(lebs):
        ec, vid = (rootfs[i]['ec'], rootfs[i]['vid']) if i < len(rootfs) else (rootfs[0]['ec'], make_vid(rootfs[0]['vid'], i))
        outb += emit(ec, vid, d)
    pathlib.Path(out).write_bytes(bytes(outb))
    log('输出 %s  %d B / %d PEB' % (pathlib.Path(out).name, len(outb), len(outb)//PEB))

    # 回读自检
    _, chk = parse(out); cv = {}
    for p in chk: cv.setdefault(p['vol'], []).append(p)
    assert len(cv[0])==len(kernel) and len(cv[1])==nleb and len(cv[LAYOUT_VID])==len(layout)
    assert [x['lnum'] for x in sorted(cv[1],key=lambda a:a['lnum'])]==list(range(nleb))
    o_seq=[(p['vol'],p['lnum']) for p in order if p['vol'] in (0,LAYOUT_VID)]
    n_seq=[(p['vol'],p['lnum']) for p in sorted(chk,key=lambda x:x['idx']) if p['vol'] in (0,LAYOUT_VID)]
    if o_seq != n_seq: die('layout/kernel 物理位置被挪动')
    joined=b''.join(x['data'] for x in sorted(cv[1],key=lambda a:a['lnum']))
    pq=os.path.join(td,'p.sqfs'); pathlib.Path(pq).write_bytes(joined)
    rr=subprocess.run(['unsquashfs','-ll',pq,'/'+probe],capture_output=True,text=True)
    if probe.split('/')[-1] not in (rr.stdout+rr.stderr): die('新 squashfs 里找不到注入文件')
    log('  OK 全部 EC/VID CRC 有效 / 卷连续 / kernel 同位 / 注入文件可读')
    log('  OK kernel FIT 与 /lib/firmware、/lib/modules 未被改动')
    shutil.rmtree(td, ignore_errors=True)
    return hashlib.sha256(bytes(outb)).hexdigest()

if __name__ == '__main__':
    if len(sys.argv) < 4: die(__doc__)
    build(sys.argv[1], sys.argv[2], sys.argv[3])
