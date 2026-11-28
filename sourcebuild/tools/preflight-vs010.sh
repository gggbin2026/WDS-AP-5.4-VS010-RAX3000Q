#!/bin/sh
# r29.6：VS010 注入后、make 之前的编译前护栏。在 openwrt/ 源码树根用 sh 执行。
# 目的：把「VS010 专属、3000Q 没有」的注入错误在 DIY part 1 阶段就拦住，
#       不再等到 Compile the firmware 跑 1h19m 才以 exit 2 失败。
set -u
W="${1:-$GITHUB_WORKSPACE/sourcebuild}"
fail(){ echo "::error::[preflight-VS010] $*"; exit 1; }
ok(){ echo "  [preflight] OK  $*"; }

IM=target/linux/ipq50xx/image/Makefile
MK=package/firmware/ipq-wifi/Makefile
DTS=target/linux/ipq50xx/dts/ipq5000-vs010.dts
BD=target/linux/ipq50xx/base-files/etc/board.d/02_network

[ -f "$IM" ] || fail "缺 $IM"
[ -f "$MK" ] || fail "缺 $MK"
[ -f "$DTS" ] || fail "缺 $DTS"
[ -f "$BD" ] || fail "缺 $BD"

# ① Device 定义：DEVICE_PACKAGES 不许出现裸 config 符号
grep -q 'define Device/cucc_vs010' "$IM" || fail "image/Makefile 没有 Device/cucc_vs010"
SEG=$(sed -n '/define Device\/cucc_vs010/,/^endef/p' "$IM" | grep -v '^[[:space:]]*#')
echo "$SEG" | grep -q 'ATH11K_MEM_PROFILE_256M' && \
  fail "DEVICE_PACKAGES 含 ATH11K_MEM_PROFILE_256M（不是包名，3000Q 定义里没有）"
echo "$SEG" | grep -qE 'CONFIG_[A-Z0-9_]+' && \
  fail "DEVICE_PACKAGES 含 CONFIG_ 裸符号"
echo "$SEG" | grep -q 'TARGET_DEVICES += cucc_vs010' && \
  fail "TARGET_DEVICES 写进了 Device 定义块内"
grep -q 'TARGET_DEVICES += cucc_vs010' "$IM" || fail "缺 TARGET_DEVICES += cucc_vs010"
python3 - "$IM" <<'PY'
import sys,pathlib
s=pathlib.Path(sys.argv[1]).read_text()
a=s.index('TARGET_DEVICES += cucc_vs010'); b=s.index('$(eval $(call BuildImage))')
assert a < b, 'TARGET_DEVICES 必须在 BuildImage 之前'
print('  顺序 OK：Device → TARGET_DEVICES → BuildImage')
PY
[ $? = 0 ] || fail "TARGET_DEVICES / BuildImage 顺序不对"
ok 'image/Makefile：Device 定义干净、无裸 config 符号、顺序正确'

# ② ipq-wifi Makefile：注册齐全、标题无括号、两个 BDF 格式
grep -q 'cucc_vs010' "$MK" || fail "ipq-wifi/Makefile 未注册 cucc_vs010"
grep -q 'CUCC VS010 (Unicom)' "$MK" && fail "generate 标题含括号（make call 参数隐患）"
grep -q 'generate-ipq-wifi-package,cucc_vs010' "$MK" || fail "缺 generate-ipq-wifi-package,cucc_vs010"
for f in board-cucc_vs010.ipq5018 board-cucc_vs010.qcn6122; do
  [ -s "package/firmware/ipq-wifi/$f" ] || fail "缺 BDF $f"
  sz=$(wc -c < "package/firmware/ipq-wifi/$f")
  [ "$sz" = 131156 ] || fail "$f 大小 $sz 不等于 131156（84B 头 + 131072B 板数据）"
done
ok 'ipq-wifi：ALLWIFIBOARDS / generate / 2 个 BDF 格式与大小全对'

# ③ DTS：花括号配对、include 目标存在、bootargs-append 在位；有 dtc 就真编译
python3 - "$DTS" <<'PY'
import sys,pathlib,re
p=pathlib.Path(sys.argv[1]); s=p.read_text()
body=re.sub(r'//[^\n]*','',s); body=re.sub(r'/\*.*?\*/','',body,flags=re.S)
assert body.count('{')==body.count('}'), 'DTS 花括号不配对'
assert '#include "ipq5018.dtsi"' in s, '缺 ipq5018.dtsi include'
assert (p.parent/'ipq5018.dtsi').is_file(), 'include 目标 ipq5018.dtsi 不存在'
assert 'bootargs-append' in s, '缺 bootargs-append（删了 UBI 挂不上 rootfs）'
print('  DTS 花括号配对 / include / bootargs-append OK')
PY
[ $? = 0 ] || fail "DTS 自检未过"
# 软检查：DIY part 1 阶段内核 dtsi / 交叉 dtc 可能还没就位，
#          真编译失败只给提示，不阻断（硬护栏是上面的静态花括号配对）。
CPP="cpp -P -nostdinc -I. -undef -D__ARM32__ -DCONFIG_ATH11K_MEM_PROFILE_256M -x assembler-with-cpp"
if command -v cpp >/dev/null 2>&1; then
  if ( cd "$(dirname "$DTS")" && $CPP "$(basename "$DTS")" > /tmp/vs010-preflight.dtsi ) 2>/tmp/preflight-cpp.log; then
    ok 'cpp 真预处理通过（include / 条件宏展开正常）'
  else
    echo "  [preflight] NOTE cpp 预处理未完成（内核 dtsi 尚未就位），静态配对已通过"
  fi
fi
if command -v dtc >/dev/null 2>&1; then
  if ( cd "$(dirname "$DTS")" && $CPP "$(basename "$DTS")" \
      | dtc -I dts -O dtb -o /tmp/vs010-preflight.dtb - ) >/tmp/preflight-dtc.log 2>&1 \
     && [ -s /tmp/vs010-preflight.dtb ]; then
    ok 'dtc 真编译通过（DTS 花括号 / 语法全对）'
  else
    echo "::warning::[preflight-VS010] dtc 预编译未通过（可能是源码树未齐，编译阶段会再编一次）"
    tail -n 8 /tmp/preflight-dtc.log 2>/dev/null || true
  fi
else
  echo "  [preflight] NOTE 无 dtc，跳过 dtb 预编译（硬护栏：静态花括号配对已过）"
fi

# ④ board.d：case 没粘连、不生成 wan
grep -nE ';;[[:space:]]*cmcc,rax3000q\)' "$BD" && fail "board.d 注入粘连"
grep -q 'cucc,vs010)' "$BD" || fail "board.d 没有 cucc,vs010) case"
sed -n '/cucc,vs010)/,/;;/p' "$BD" | grep -q ':wan' && fail "board.d 仍生成 wan 口（要求全 LAN）"
ok 'board.d：case 独立、全 LAN 无 WAN'

# ⑤ GNU make 真解析注入后的 ipq-wifi/Makefile（stub include，只查语法致命错）
TMP=$(mktemp -d); mkdir -p "$TMP/inc"
cp "$MK" "$TMP/Makefile"
: > "$TMP/rules.mk"
: > "$TMP/inc/version.mk"
printf 'define BuildPackage\nendef\nINSTALL_DIR:=/bin/true\nINSTALL_DATA:=/bin/true\n' > "$TMP/inc/package.mk"
( cd "$TMP" && make -f Makefile TOPDIR="$TMP" INCLUDE_DIR="$TMP/inc" -p -n > /tmp/preflight-make.log 2>&1 ) || true
grep -qE 'missing separator|unterminated call|recipe commences' /tmp/preflight-make.log \
  && { tail -20 /tmp/preflight-make.log; fail "ipq-wifi/Makefile GNU make 解析失败"; }
grep -q 'define Package/ipq-wifi-cucc_vs010' /tmp/preflight-make.log \
  || fail "GNU make 没有生成 Package/ipq-wifi-cucc_vs010 定义"
rm -rf "$TMP"
ok 'GNU make 真解析：ipq-wifi-cucc_vs010 包定义生成，零语法错误'

echo "[preflight-VS010] ✅ 全部通过，可以进入 make defconfig / compile"
