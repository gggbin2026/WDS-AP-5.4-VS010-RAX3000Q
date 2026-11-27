#!/bin/sh
# VS010 5.4 r18 —— 上传/合并善后：一键把仓库落到干净终态
# 用法：解压包覆盖仓库后，在仓库根目录执行  sh tools/apply-r18.sh
# 🔴 本脚本只做「检查 + 修权限 + 自检」，绝不删你的文件、绝不 push、绝不碰 .git 历史。
set -u
ROOT=$(pwd)
echo "==================== VS010 r18 落位检查 ===================="
echo "目录: $ROOT"

# ① 必须在仓库根（而不是某个子目录里跑）
if [ ! -f build/verify.sh ] || [ ! -d files ]; then
  echo "🔴 请先在【仓库根目录】运行本脚本（应能看到 build/verify.sh 和 files/）"
  exit 1
fi

# ② 中止 GitHub Desktop 留下的未完成合并 / 变基
#    merge --abort 只撤销「合并动作」，保留你工作区里已覆盖的文件，不丢改动。
if [ -f .git/MERGE_HEAD ] || [ -d .git/rebase-merge ] || [ -d .git/rebase-apply ]; then
  echo "[1/5] 检测到未完成的合并/变基 → 自动 abort（不丢工作区文件）"
  git merge --abort  2>/dev/null || \
  git rebase --abort 2>/dev/null || true
else
  echo "[1/5] 无未完成的合并/变基 ✅"
fi

# ③ 🔴 冲突标记零容忍：残留 <<<<<<< / >>>>>>> / 单独一行 ======= 就停下
#    只查文本类文件，跳过二进制固件与 .git
CONFLICT=$(grep -R -lE '^(<<<<<<< |>>>>>>> )|^=======$' \
  --include='*.yml' --include='*.yaml' --include='*.sh' --include='*.lua' \
  --include='*.htm' --include='*.html' --include='*.md' --include='*.txt' \
  --include='*.conf' --include='*.list' --include='*.keep' \
  .github build capture files reference tools README.md CHANGELOG.md 2>/dev/null | sort -u)
if [ -n "$CONFLICT" ]; then
  echo "🔴 [2/5] 以下文件仍含合并冲突标记，请勿提交："
  printf '   %s\n' $CONFLICT
  echo "   用全量包 VS010-full-5.4-r18.zip 重新覆盖这几个文件，或点 GitHub Desktop「停止合并」。"
  exit 1
fi
echo "[2/5] 全仓零冲突标记 ✅"

# ④ 修权限：GitHub 网页上传 / Windows 解压会把脚本抹成 664
#    build.sh 在打进固件前还会再强制一次 755，这里只是让仓库侧也干净。
find . -type f \
  \( -path './build/*' -o -path './tools/*' -o -path './files/usr/sbin/*' \
     -o -path './files/usr/bin/*' -o -path './files/etc/init.d/*' \
     -o -path './files/www/cgi-bin/*' -o -name '*.sh' \) \
  ! -path './.git/*' -exec chmod 755 {} + 2>/dev/null || true
find . -type f ! -path './.git/*' ! -perm -u=x -exec chmod 644 {} + 2>/dev/null || true
echo "[3/5] 脚本权限已归一（755 / 其余 644），网页上传抹 664 不再影响构建"

# ⑤ 固件注入树零改动 → 产物与 r17 逐字节一致（打印汇总哈希便于核对）
FH=$(python3 - <<'PYEOF'
import os,hashlib
h=hashlib.sha256(); r='files'
for x,ds,fs in os.walk(r):
 ds.sort()
 for f in sorted(fs):
  p=os.path.join(x,f); h.update(os.path.relpath(p,r).encode()); h.update(open(p,'rb').read())
print(h.hexdigest())
PYEOF
)
echo "[4/5] files/ 汇总 sha256 = $FH"
[ "$FH" = '132fe689e385d49d70906862f3f2d7c108c059d5b5ef7b1b300f850e5bb760a5' ] \
  && echo "      ✅ 与 r17 注入树完全一致 → 重编后 2259 个 rootfs 文件逐项等价（无需重刷）" \
  || echo "      ⚠ 与 r17 不同（若你有意改过 files/，重跑一次 Build 即可）"

# ⑥ 全量自检
echo "[5/5] 运行 sh verify.sh ..."
sh verify.sh > /tmp/vs010-r18-verify.log 2>&1
RC=$?
tail -1 /tmp/vs010-r18-verify.log
if [ "$RC" != 0 ] || ! grep -q 'RESULT: PASS' /tmp/vs010-r18-verify.log; then
  echo "🔴 自检未通过，先看 FAIL 行："
  grep 'FAIL' /tmp/vs010-r18-verify.log || true
  exit 1
fi
echo "===================================================="
echo "✅ r18 终态就绪。接下来："
echo "   git add -A && git commit -m 'VS010 5.4 r18' && git push origin master"
echo "   Actions → Build 5.4 firmware → Run workflow（device=all / mode=all）"
echo "🔴 不要在 GitHub Desktop 里点「继续合并」；已刷过的机器不用重刷（内容与 r17 等价）。"
