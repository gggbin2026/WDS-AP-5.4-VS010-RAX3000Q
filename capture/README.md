# 实机清单（两种来源，任选其一）

## A. 保留基线 `installed-allowlist.txt`（第 12 次，推荐）

设备上是「最干净的好固件」，只把没用的插件/服务关掉，没有执行 `opkg remove` 时：

```sh
opkg list-installed > /tmp/installed.txt
```

把结果存成 **`capture/installed-allowlist.txt`**。

🔴 `find /overlay -name '.wh.*'` **输出为空是正常的**，不是命令没反应 —— 只 `stop + disable` 不会留下 whiteout 删除标记。这时不用再导任何东西，`installed-allowlist.txt` 本身就是「还剩什么」的权威基线。

`Actions → Build 5.4 firmware` 会自动跑 `tools/apply-installed-baseline.sh --dryrun`：**VS010 与 RAX3000Q 两个机型共用同一份标准**，只删基线外杂项的配置 / 自启链接 / LuCI 控制器；二进制与内核模块保留（不启动就不占资源）。基线缺 5.4.213 闭源栈 / Argon / TTYD / SSH 任一项、或回灌块与 `prune.keep` 有交集，直接拒绝出包。

## B. 删除清单 `prune-real.txt`（可选，执行过 opkg remove 才用）

把刷好、删完没用插件、且验证服务仍正常的机器上导出的 **`prune-real.txt`** 放到本目录，文件名必须是 `prune-real.txt`。

```
capture/prune-real.txt
```

`Actions → Build 5.4 firmware` 每次运行会自动检测它 → 回灌 `build/prune.list` → 先跑 `sh verify.sh` → 再出 4 个固件。清单含无线栈 / 主题 / SSH 关键路径会被 `tools/build-from-capture.sh` 拒绝，构建早停。

**设备侧怎么导出**（刷了 r8 及以后的固件，脚本已随固件刷入）：

```sh
sh /usr/sbin/vs010-capture                 # → /tmp/prune-real.txt + installed.txt
# 取回 PC（密码 password）：
# scp root@172.10.10.241:/tmp/prune-real.txt ./capture/prune-real.txt
```

也可以本地直接回灌出固件，不必等 Actions：

```sh
sh tools/build-from-capture.sh --capture=capture/prune-real.txt --device=all --mode=all
```

⚠️ 清单是**相对官方 rootfs 的路径**，不含 ART / MAC / 密钥 / 首启 stamp。两份机型共用同一份即可（机型相关的固件路径会被护栏挡掉）。改完清单要 `git add -A && commit && push`。

不放这个文件也完全没问题：仓库用默认 `prune.list` 正常出固件。
