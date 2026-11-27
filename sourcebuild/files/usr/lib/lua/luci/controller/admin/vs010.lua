-- VS010 / RAX3000Q 5.4.213 融合固件：把 /bridge/ /ap/ 丰富页和
-- WDS 配对 / 机器狗 / 无线 DHCP Snooping 控制台内置进 Argon 主题「状态」菜单。
-- 只读，不写配置、不碰驱动；写法与已验证的 vs010_ports.lua 完全一致。
module("luci.controller.admin.vs010", package.seeall)

-- 第 20 次：模式隔离。mode 由 build.sh 构建期写入 /etc/vs010/mode（squashfs 只读，
-- 首启即固定），controller 只注册【本模式】那一个界面，菜单里不再出现另一套。
local function cur_mode()
    local f = io.open("/etc/vs010/mode", "r")
    if not f then return "wds" end
    local m = f:read("*l") or "wds"; f:close()
    m = tostring(m):gsub("%s+", "")
    return (m == "ap") and "ap" or "wds"
end

function index()
    local m = cur_mode()
    if m == "wds" then
        entry({"admin", "status", "vs010_bridge"}, call("show_bridge"), _("网桥状态"), 55)
    else
        entry({"admin", "status", "vs010_ap"},     call("show_ap"),     _("AP 状态"), 56)
    end
    entry({"admin", "status", "vs010_console"}, call("show_console"), _("状态控制台"), 57)
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
    end
    local st = sys.exec("/usr/sbin/vs010-role status 2>&1")
    tpl.render("vs010_role", { st = st, out = out, mode = cur_mode() })
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
    local m = cur_mode()
    local head = (m == "wds")
      and "printf '[ WDS 配对 ]\\n'; vs010-wds-pair status 2>&1; "
      or  "printf '[ AP 弱信号 ]\\n'; ap-rssi-guard status 2>&1; "
    local ok, out = pcall(function()
        return sys.exec("PATH=/usr/sbin:/usr/bin:/sbin:/bin; "
          .. head
          .. "printf '\\n[ 机器狗 ]\\n'; bridge-watchdog status 2>&1; "
          .. "printf '\\n[ 无线 DHCP Snooping ]\\n'; dhcp-guard status 2>&1; "
          .. "printf '\\n[ IPv6 地址（应为空） ]\\n'; ip -6 addr 2>/dev/null | head -6; "
          .. "printf '\\n[ 本机 DHCP 服务端 ]\\n'; echo lan.ignore=$(uci -q get dhcp.lan.ignore); "
          .. "printf '\\n[ 防火墙 ]\\n'; /etc/init.d/firewall status 2>&1 | head -4")
    end)
    tpl.render("vs010_console", {
        out = (ok and tostring(out or "")) or "状态读取失败（命令不存在或服务未起）",
        mode = m
    })
end
