#!/bin/sh
# r29.5：保守裁剪内核网络协议符号。
# 🔴 白名单式：只关【明确与 QSDK NSS / ath11k / bridge / netfilter 无关】的 L3 特性。
#    绝不碰 CONFIG_IPV6 / CONFIG_BRIDGE / CONFIG_STP / CONFIG_NF_* / CONFIG_NETFILTER*
#    / CONFIG_MAC80211* / CONFIG_ATH11K* —— 这些是无线与有线加速的编译期依赖。
#    文件不存在或符号被 Kconfig 拉回时只给 notice，不阻断编译。
set -eu
BLACK="IP_MROUTE IP_PIMSM_V1 IP_PIMSM_V2 IPV6_MROUTE IPV6_PIMSM_V2 IPV6_MULTIPLE_TABLES IPV6_SUBTREES IPV6_SEG6_LWTUNNEL IP_SCTP IP_DCCP NET_IPGRE NET_IPIP NET_FOU VLAN_8021Q NAMESPACES"
python3 - "$BLACK" <<'PYSLIM'
import sys,pathlib,re
black=set(sys.argv[1].split())
files=list(pathlib.Path('target/linux').rglob('config-5.4*'))
# 🔴 护栏：绝不出现在黑名单里的依赖符号
# 🔴 精确排除 IPv6 主体符号；IPV6_MROUTE / IPV6_SEG6_LWTUNNEL 等只是可选子特性，允许关。
FORBID_EXACT={'IPV6'}
FORBID_PREFIX=('BRIDGE','STP','NF_','NETFILTER','MAC80211','ATH11K','QCA','NSS')
for b in black:
    assert b not in FORBID_EXACT, f'危险主体符号 {b}'
    assert not b.startswith(FORBID_PREFIX), f'危险前缀符号 {b}'
if not files:
    print('::notice::[slim] 未找到 target/linux/config-5.4*，跳过内核裁剪（不影响包级精简）'); sys.exit(0)
n=0
for f in files:
    try: s=f.read_text()
    except (UnicodeDecodeError,OSError): continue
    out=[]
    for l in s.splitlines():
        m=re.match(r'^CONFIG_([A-Z0-9_]+)=y$',l)
        if m and m.group(1) in black:
            out.append(f'# CONFIG_{m.group(1)} is not set'); n+=1; continue
        out.append(l)
    ns='\n'.join(out)+'\n'
    if ns!=s: f.write_text(ns)
print(f'[slim] ✅ 内核符号关闭 {n} 行；NSS/bridge/netfilter/IPV6 主体一字未动')
PYSLIM
