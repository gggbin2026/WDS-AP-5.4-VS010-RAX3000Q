#!/usr/bin/env python3
"""第 22 次：把 VS010 的 DTS / Device / board.d / 板级 BDF 注入 kkstone 源码树。

只改主树 package/ 与 target/，不碰 feeds/（feeds update -a 会覆盖 feeds 下的改动）。
"""
import pathlib,sys
W=pathlib.Path(sys.argv[1]); root=pathlib.Path('.')

def put(dst,src):
    p=root/dst; p.parent.mkdir(parents=True,exist_ok=True)
    p.write_bytes((W/src).read_bytes()); print('  [inject]',dst)

# ── 1. 设备树 ──
put('target/linux/ipq50xx/dts/ipq5000-vs010.dts','target/ipq50xx/ipq5000-vs010.dts')

# ── 2. image/Makefile：Device/cucc_vs010 ──
im=root/'target/linux/ipq50xx/image/Makefile'; s=im.read_text()
if 'Device/cucc_vs010' not in s:
    inc=(W/'target/ipq50xx/device-vs010.inc').read_text()
    anchor='$(eval $(call BuildImage))'
    assert anchor in s, 'image/Makefile 缺 eval 锚点'
    s=s.replace(anchor,inc+'\n'+anchor,1); im.write_text(s)
print('  [inject] Device ->',im)

# ── 3. board.d ──
b=root/'target/linux/ipq50xx/base-files/etc/board.d/02_network'; s=b.read_text()
if 'cucc,vs010)' not in s:
    inc=(W/'target/ipq50xx/board-vs010.inc').read_text()
    anchor='\tcmcc,rax3000q)'
    assert anchor in s, '02_network 缺 cmcc,rax3000q 锚点'
    s=s.replace(anchor,inc+anchor,1); b.write_text(s)
print('  [inject] board.d ->',b)

# ── 4. 🔴 板级 BDF（无线修复核心）──
for n in ['board-cucc_vs010.ipq5018','board-cucc_vs010.qcn6122']:
    put('package/firmware/ipq-wifi/'+n,'package/ipq-wifi/'+n)

# ── 5. ipq-wifi Makefile 注册新包 ──
mk=root/'package/firmware/ipq-wifi/Makefile'; s=mk.read_text()
if 'cucc_vs010' not in s:
    assert 'cmcc_rax3000q \\' in s, 'ALLWIFIBOARDS 缺锚点'
    s=s.replace('\tcmcc_rax3000q \\\n','\tcmcc_rax3000q \\\n\tcucc_vs010 \\\n',1)
    gen='$(eval $(call generate-ipq-wifi-package,cmcc_rax3000q,CMCC RAX3000Q))'
    assert gen in s, 'generate 列表缺锚点'
    s=s.replace(gen,gen+'\n$(eval $(call generate-ipq-wifi-package,cucc_vs010,CUCC VS010 (Unicom)))',1)
    mk.write_text(s)
print('  [inject] ipq-wifi/Makefile 注册 cucc_vs010')

# ── 6. 硬断言 ──
assert 'Device/cucc_vs010' in im.read_text()
assert 'cucc,vs010)' in b.read_text()
assert 'cucc_vs010' in mk.read_text()
for n in ['board-cucc_vs010.ipq5018','board-cucc_vs010.qcn6122']:
    p=root/'package/firmware/ipq-wifi'/n
    d=p.read_bytes()
    assert len(d)==131156 and d[:17]==b'QCA-ATH11K-BOARD\0', n+' 容器格式错'
    assert b'qmi-board-id=' in d[36:73], n+' 缺 board-id'
print('  [inject] ✅ DTS / Device / board.d / 2 个 BDF / 包注册 全部落位')
