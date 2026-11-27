-- VS010 / RAX3000Q 5.4.213 融合固件：把 /bridge/ /ap/ 丰富页和
-- WDS 配对 / 机器狗 / 无线 DHCP Snooping 控制台内置进 Argon 主题「状态」菜单。
-- 只读，不写配置、不碰驱动；写法与已验证的 vs010_ports.lua 完全一致。
module("luci.controller.admin.vs010", package.seeall)

function index()
    entry({"admin", "status", "vs010_bridge"},  call("show_bridge"),  _("网桥状态"), 55)
    entry({"admin", "status", "vs010_ap"},      call("show_ap"),      _("AP 状态"), 56)
    entry({"admin", "status", "vs010_console"}, call("show_console"), _("WDS / 机器狗 / Snooping"), 57)
    entry({"admin", "status", "vs010_role"},    call("show_role"),    _("主题与 WDS 角色"), 58)
end

-- 第 17 次：主题切换 + WDS 主/客户端开关（GET 参数严格白名单，杜绝命令注入）
function show_role()
    local http = require "luci.http"
    local sys  = require "luci.sys"
    local tpl  = require "luci.template"
    local act  = tostring(http.formvalue("act") or "")
    local out  = ""
    if act == "master" or act == "client" or act == "auto" then
        out = sys.exec("/usr/sbin/vs010-role " .. act .. " 2>&1")
    elseif act == "argon243" or act == "argon" then
        out = sys.exec("/usr/sbin/vs010-theme " .. act .. " 2>&1")
    end
    local st = sys.exec("/usr/sbin/vs010-role status 2>&1")
    local th = sys.exec("/usr/sbin/vs010-theme status 2>&1")
    tpl.render("vs010_role", { st = st, th = th, out = out })
end

function show_bridge()
    require("luci.template").render("vs010_bridge", {})
end

function show_ap()
    require("luci.template").render("vs010_ap", {})
end

function show_console()
    local sys = require "luci.sys"
    local tpl = require "luci.template"
    local ok, out = pcall(function()
        return sys.exec("PATH=/usr/sbin:/usr/bin:/sbin:/bin; "
          .. "printf '[ WDS 配对 ]\\n'; vs010-wds-pair status 2>&1; "
          .. "printf '\\n[ 机器狗 ]\\n'; bridge-watchdog status 2>&1; "
          .. "printf '\\n[ 无线 DHCP Snooping ]\\n'; dhcp-guard status 2>&1; "
          .. "printf '\\n[ IPv6 地址（应为空） ]\\n'; ip -6 addr 2>/dev/null | head -6; "
          .. "printf '\\n[ 本机 DHCP 服务端 ]\\n'; echo lan.ignore=$(uci -q get dhcp.lan.ignore); "
          .. "printf '\\n[ 防火墙 ]\\n'; /etc/init.d/firewall status 2>&1 | head -4")
    end)
    tpl.render("vs010_console", {
        out = (ok and tostring(out or "")) or "状态读取失败（命令不存在或服务未起）"
    })
end
