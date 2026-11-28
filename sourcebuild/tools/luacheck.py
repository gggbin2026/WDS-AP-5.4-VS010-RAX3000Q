#!/usr/bin/env python3
"""纯标准库 Lua 词法护栏（r28 核验新增）。

GitHub Actions / 本地都没有 lua 解释器，但 r28 之前出过真事故：
controller 里 jesc() 把真实换行/制表符嵌进字符串字面量，Lua 编译报
"')' expected near '\\'" → 整个 LuCI controller require 失败，后台 500、
设置面板 probe/save 全挂。grep 断言抓不到这种语法错，故加此词法检查。

检查项：短字符串未闭合 / 字符串内裸换行、长字符串与长注释未闭合、()[]{} 配对。
不依赖任何第三方库，OpenWrt 编译机与 ubuntu runner 都能直接跑。
"""
import pathlib, re, sys

def check(path):
    src = pathlib.Path(path).read_text(encoding='utf-8')
    i, n, line = 0, len(src), 1
    stack, errs = [], []
    long_re = re.compile(r'\[(=*)\[')
    while i < n:
        c = src[i]
        # ── 注释 ──
        if src.startswith('--', i):
            m = re.match(r'--\[(=*)\[', src[i:])
            if m:
                close = ']' + m.group(1) + ']'
                j = src.find(close, i + len(m.group(0)))
                if j < 0:
                    errs.append('L%d: 长注释 --[[ 未闭合' % line); break
                line += src.count('\n', i, j); i = j + len(close); continue
            j = src.find('\n', i)
            if j < 0: break
            i = j; continue
        # ── 长字符串 [[..]] / [=[..]=] ──
        if c == '[':
            m = long_re.match(src, i)
            if m:
                close = ']' + m.group(1) + ']'
                j = src.find(close, i + m.end())
                if j < 0:
                    errs.append('L%d: 长字符串 [[ 未闭合' % line); break
                line += src.count('\n', i, j); i = j + len(close); continue
            stack.append(('[', line)); i += 1; continue
        # ── 短字符串（必须同行闭合，反斜杠转义跳过 2 字符）──
        if c in '"\'':
            q, sl, closed = c, line, False
            i += 1
            while i < n:
                d = src[i]
                if d == '\\':
                    if i + 1 < n and src[i + 1] == '\n': line += 1
                    i += 2; continue
                if d == q:
                    i += 1; closed = True; break
                if d == '\n':
                    errs.append('L%d: 字符串内裸换行（Lua 会报 unfinished string）' % sl)
                    break
                i += 1
            if not closed and not any('裸换行' in e for e in errs):
                errs.append('L%d: 字符串未闭合' % sl)
            continue
        if c in '({':
            stack.append((c, line)); i += 1; continue
        if c in ')]}':
            want = {')': '(', ']': '[', '}': '{'}[c]
            if not stack or stack[-1][0] != want:
                errs.append('L%d: 括号不匹配 %r（栈顶 %r）' % (line, c, stack[-1] if stack else None))
            else:
                stack.pop()
            i += 1; continue
        if c == '\n': line += 1
        i += 1
    if stack and not errs:
        errs.append('未闭合括号 %r' % (stack[-1],))
    return errs

def main():
    root = pathlib.Path(__file__).resolve().parent.parent / 'files'
    files = sys.argv[1:] or sorted(str(p) for p in root.rglob('*.lua'))
    bad = 0
    for f in files:
        e = check(f)
        if e:
            bad += 1
            print('  FAIL %s' % f)
            for x in e: print('       ' + x)
        else:
            print('  OK   %s' % pathlib.Path(f).name)
    print('  luacheck: %d 文件 / %d 失败' % (len(files), bad))
    return 1 if bad else 0

if __name__ == '__main__':
    sys.exit(main())
