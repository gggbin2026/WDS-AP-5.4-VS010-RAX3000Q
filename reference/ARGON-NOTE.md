# Argon 主题：找出**能用的新版**并已注入（第 17 次）

## 版本谱系（逐个 tag 解包核实）

| tag | 模板 | rpcd | 结论 |
|---|---|---|---|
| 本机好固件 | `argonv3 1.7.2` · Lua `.htm` | 无 | 基线 |
| **v2.4.3 (2025-07-22)** | **Lua `.htm` ×6** | **0** | ✅ **最后一个兼容版，已注入** |
| v2.4.4 / 2.4.5 / 2.4.8 | ucode `.ut` ×6 | 2 | ❌ 架构断了 |
| v3.2.0 (2026-11-24) | ucode `.ut` + menu.d + ACL | 4 | ❌ 后台打不开 |

上游 `jerrykuku/luci-theme-argon` v2.4.3 的 `Makefile` 是 `PKG_VERSION:=2.4.3 / PKG_RELEASE:=20250722`、`LUCI_DEPENDS:=+curl +jsonfilter`，`luasrc/view/themes/argon/*.htm` 6 个模板、**零 ucode / 零 rpcd / 零 menu.d**。这就是「比 1.7.2 新、且这台 Lua LuCI 能直接用」的最新版。v2.4.4 起模板全换 `.ut`，硬换登录页/后台渲染必失败。

v2.4.3 相对 1.7.2：移除 jQuery 依赖、Pure CSS 3.0、Google Sans 字体（woff2）、CSP/XSS/点击劫持安全头、菜单动画重写、暗色修正、移动端与 PWA 优化 —— 正好服务于「设备内查看配置、设置」。

## 怎么注入：新增目录，零覆盖

- 模板 → `usr/lib/lua/luci/view/themes/argon2/`（6 个 `.htm`）
- 静态 → `www/luci-static/argon2/`（CSS/字体/图标/背景）
- 模板里唯一两处硬编码 `/www/luci-static/argon/css/dark.css` 改成 `argon2`
- 登录页 `sysauth.htm` 沿用**官方 1.7.2 实机验证过**的那份：v2.4.3 那份会调不存在的 `/usr/libexec/argon/online_wallpaper` 且缺 `curl`，拖慢/报错登录
- `luci.jsonc.so` / `nixio.fs` / `luci.model.uci` 等模块本机全在位 ✅

**官方 `argon` 目录一个字节没动**，`prune.keep` 已锁死官方 Argon 9 项。

## 怎么切换（系统里自己选，不用重刷）

```sh
vs010-theme status        # 看当前主题
vs010-theme argon243      # 切到新版 2.4.3
vs010-theme argon         # 切回官方 1.7.2
```

LuCI「状态 → 主题与 WDS 角色」页也有两个按钮；或「系统 → 语言与界面 → 设计」选 `Argon_243`。切换只改 `luci.main.mediaurlbase` + 清缓存，**不重启、不动网络、不动无线**。默认仍是官方 1.7.2，新版有问题一键切回。

S18 `vs010-luci-fix` 每次开机注册 `luci.themes.Argon_243=/luci-static/argon2`，且**不再强行把 mediaurlbase 改回 argon**（上一版会覆盖用户选择，本轮已修）。

## 速率显示

根因是 QSDK 闭源 `qca-nss-dp` 的 netdev 不上报（`-ENODEV`），**换主题修不了**；正确值在「状态 → 网口速率」、`/bridge/`、`/ap/`（PHY 实测）。
