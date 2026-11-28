#!/bin/sh
# DIY part 1：feeds update 之前，在 openwrt/ 源码树里执行。
# 只做「源码树注入」，不碰 feeds（feeds update -a 会覆盖 feeds/ 下的改动）。
#
# r25：源码线全部文件隔离在仓库 sourcebuild/ 下；融合线已移除，
#      仓库里只有一个 workflow，不再有同名冲突。
set -eu
D=${1:-cmcc_rax3000q}
W="$GITHUB_WORKSPACE/sourcebuild"
echo "[diy-p1] device=$D / 源码树注入（r24 隔离路径）"
if [ "$D" = cucc_vs010 ]; then
  echo "[diy-p1] 🔴 VS010：注入实机 GPIO/LED/bootargs DTS + Device + board.d + 板级 BDF"
  echo "[diy-p1]    BDF body 来自本机 0:ART（r24 备份实证），头沿用 kkstone 84B"
  python3 "$W/target/inject-vs010.py" "$W"
  sh "$W/tools/preflight-vs010.sh" "$W"
else
  echo "[diy-p1] 3000Q 用源码树原生 Device/cmcc_rax3000q，无需注入"
fi
echo "[diy-p1] ✅ 完成"
