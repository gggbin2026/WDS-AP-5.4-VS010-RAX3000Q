# 第 19 次：只替换【本脚本自己生成的 FROM INSTALLED BASELINE 块】，
# 保留块之后所有历史追加项。旧实现用 awk '/起始行/{exit}' 把后面全截掉了。
# 用法: awk -v blk=<含 begin/路径/end 的块文件> -f tools/baseline-block.awk < prune.list > new
BEGIN { done = 0; inblk = 0 }
/^# ── FROM INSTALLED BASELINE \(end\)/ { inblk = 0; next }
/^# ── FROM INSTALLED BASELINE/ {
    if (!done) { while ((getline ln < blk) > 0) print ln; close(blk); done = 1 }
    inblk = 1; next
}
inblk && /^(etc|usr)\// { next }
inblk { inblk = 0 }
{ print }
END { if (!done) { while ((getline ln < blk) > 0) print ln; close(blk) } }
