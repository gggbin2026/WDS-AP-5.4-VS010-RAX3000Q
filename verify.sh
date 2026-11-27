#!/bin/sh
# r25 全能包 · 单线统一自检入口
# 只做：冲突标记扫描 → 源码线完整自检。不依赖任何外部文件/网络。
set -u
cd "$(dirname "$0")" || exit 1
HITS=$(grep -R -I -nE '^(<<<<<<< |>>>>>>> )' \
        .github sourcebuild reference README.md CHANGELOG.md STANDARDS.md 2>/dev/null | head -20)
if [ -n "$HITS" ]; then
  echo "$HITS" | sed 's/^/  /'
  echo "  🔴 发现冲突标记，先解决再提交"; exit 1
fi
echo "  OK  零冲突标记"
exec sh sourcebuild/tools/verify.sh "$@"
