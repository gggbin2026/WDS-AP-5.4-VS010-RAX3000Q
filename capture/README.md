# 实机删除清单（可选）

把刷好、删完没用插件、且验证服务仍正常的机器上导出的 **`prune-real.txt`** 放到本目录，文件名必须是 `prune-real.txt`。

```
capture/prune-real.txt
```

`Actions → Build 5.4 firmware` 每次运行会自动检测它 → 回灌 `build/prune.list` → 先跑 `sh verify.sh` → 再出 4 个固件。清单含无线栈 / 主题 / SSH 关键路径会被 `tools/build-from-capture.sh` 拒绝，构建早停。

**设备侧怎么导出**（刷了 r8 及以后的固件，脚本已随固件刷入）：

```sh
sh /usr/sbin/vs010-capture                 # → /tmp/prune-real.txt + installed.txt
# 取回 PC（密码 admin）：
# scp root@172.10.10.241:/tmp/prune-real.txt ./capture/prune-real.txt
```

也可以本地直接回灌出固件，不必等 Actions：

```sh
sh tools/build-from-capture.sh --capture=capture/prune-real.txt --device=all --mode=all
```

⚠️ 清单是**相对官方 rootfs 的路径**，不含 ART / MAC / 密钥 / 首启 stamp。两份机型共用同一份即可（机型相关的固件路径会被护栏挡掉）。改完清单要 `git add -A && commit && push`。

不放这个文件也完全没问题：仓库用默认 `prune.list` 正常出固件。
