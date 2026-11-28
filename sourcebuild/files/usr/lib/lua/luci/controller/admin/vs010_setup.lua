-- r26：网桥 / AP「常用设置」的唯一写入端点。
-- 🔴 全部挂在 admin 树下，LuCI 的 root.sysauth=root 会自动继承到子节点：
--    未登录访问 /cgi-bin/luci/admin/status/vs010_setup* 会被 dispatcher 302 到登录页，
--    配置写不进来。页面本身只读状态可以公开，能改配置的入口必须登录。
-- 🔴 字段二次白名单 + 校验在 /usr/sbin/vs010-apply-config 里，不信任前端。
module("luci.controller.admin.vs010_setup", package.seeall)

local KEYS = { "mode", "role", "ap_ssid", "ap_key", "ap2_ssid", "ap2_key",
               "ap5_ssid", "ap5_key", "wds_ssid", "wds_key", "peer_ssid",
               "peer_key", "peer_bssid", "ch5g", "ch24g", "htmode", "txpower",
               "wmm", "mumimo", "weak_rssi", "weak_timeout", "mgmt_ip",
               "mgmt_mask", "hostname", "stp", "ntp_server", "ntp_interval",
               "theme" }

-- ★ r27：维护动作白名单。键是枚举、值是【固定命令串】，不接受任何用户参数，
--   所以不存在命令注入面；未登录一律 403。改配置仍只走 save()。
local ACTS = {
    selfcheck   = "PATH=/usr/sbin:/usr/bin:/sbin:/bin; wifi-check 2>&1 | head -30; echo; portstat 2>&1; echo; luci-check 2>&1 | head -20",
    wds_status  = "PATH=/usr/sbin:/usr/bin:/sbin:/bin; vs010-wds-pair status 2>&1",
    watchdog_status = "PATH=/usr/sbin:/usr/bin:/sbin:/bin; bridge-watchdog status 2>&1",
    watchdog_on = "PATH=/usr/sbin:/usr/bin:/sbin:/bin; bridge-watchdog on 2>&1; bridge-watchdog status 2>&1",
    watchdog_off= "PATH=/usr/sbin:/usr/bin:/sbin:/bin; bridge-watchdog off 2>&1; bridge-watchdog status 2>&1",
    watchdog_dryrun = "PATH=/usr/sbin:/usr/bin:/sbin:/bin; bridge-watchdog dryrun on 2>&1; bridge-watchdog status 2>&1",
    guard_status= "PATH=/usr/sbin:/usr/bin:/sbin:/bin; dhcp-guard status 2>&1",
    guard_on    = "PATH=/usr/sbin:/usr/bin:/sbin:/bin; dhcp-guard on 2>&1; dhcp-guard status 2>&1",
    guard_monitor = "PATH=/usr/sbin:/usr/bin:/sbin:/bin; dhcp-guard monitor 2>&1; dhcp-guard status 2>&1",
    log         = "logread 2>/dev/null | grep -Ei 'vs010|wds|dhcp|ath11k|wifi' | tail -40; printf '\\n[vs010] 高级设置后台（OpenWrt / LuCI）直达路径: http://<设备IP>/cgi-bin/luci/ （根路径 / 现为状态页跳转）\\n'",
}

local function authed()
    local http = require "luci.http"
    local sid = http.getcookie("sysauth")
    if not sid or sid == "" then return false end
    -- admin 树已由 dispatcher 校验过；这里再做一次会话核实（API 版本差异不致命）
    local ok, sauth = pcall(require, "luci.sauth")
    if ok and sauth and type(sauth.sid_to_user) == "function" then
        local ok2, u = pcall(sauth.sid_to_user, sid)
        if ok2 and u then return true end
        if ok2 and not u then return false end
    end
    return true
end

local function json(s)
    local http = require "luci.http"
    http.prepare_content("application/json; charset=utf-8")
    http.write(s)
end

function index()
    entry({"admin", "status", "vs010_setup"}, call("show"), _("常用设置"), 59)
    entry({"admin", "status", "vs010_setup", "state"}, call("state"))
    entry({"admin", "status", "vs010_setup", "probe"}, call("probe"))
    entry({"admin", "status", "vs010_setup", "save"}, call("save"))
    entry({"admin", "status", "vs010_setup", "act"},  call("act"))
      -- r29.11：WDS 客户端「搜索周边主端」只读扫描，继承 admin 树 sysauth
      entry({"admin", "status", "vs010_setup", "scan"}, call("scan"))
end

function show()
    local bare = require("luci.http").formvalue("bare")
    require("luci.template").render("vs010_setup", { bare = bare })
end

function state()
    if not authed() then json('{"ok":0,"msg":"未登录"}'); return end
    local sys = require "luci.sys"
    local out = sys.exec("/usr/sbin/vs010-apply-config get 2>/dev/null")
    json((out ~= "" and out) or '{"ok":0,"msg":"后台读取失败"}')
end

function probe()
    json(authed() and '{"ok":1}' or '{"ok":0,"msg":"未登录"}')
end

function save()
    local http = require "luci.http"
    if not authed() then
        http.status(403, "Forbidden")
        json('{"ok":0,"msg":"🔒 未登录或会话已过期：请先登录 LuCI，再修改配置"}')
        return
    end
    -- CSRF 软校验：dispatcher 提供 token 时才比对，版本差异不会误伤
    local ok, dsp = pcall(require, "luci.dispatcher")
    if ok and dsp and dsp.context and dsp.context.token and dsp.context.token ~= "" then
        if http.formvalue("token") ~= dsp.context.token then
            http.status(403, "Forbidden")
            json('{"ok":0,"msg":"会话令牌无效，请刷新页面重试"}')
            return
        end
    end
    -- 🔴 临时文件由系统生成，文件名不含任何用户值 → 命令注入面为零
    local tmp = os.tmpname()
    local f = io.open(tmp, "w")
    if not f then json('{"ok":0,"msg":"临时文件不可写"}'); return end
    for _, k in ipairs(KEYS) do
        local v = http.formvalue(k) or ""
        v = v:gsub("[\r\n]", "")
        f:write(k .. "=" .. v .. "\n")
    end
    f:close()
    local sys = require "luci.sys"
    local out = sys.exec("/usr/sbin/vs010-apply-config apply " .. tmp .. " 2>/dev/null")
    os.remove(tmp)
    json((out ~= "" and out) or '{"ok":0,"msg":"后台未返回，请查看 logread | grep vs010-apply-config"}')
end

local function jesc(v)
    -- ★ r28 核验修复：旧写法把真实换行/制表符嵌进字符串字面量，Lua 直接报
    --   "' )' expected near '\'" → 整个 controller require 失败，LuCI 后台 500。
    --   这里全部用合法转义，且反斜杠/引号/换行都正确转义再拼进 JSON。
    local s = tostring(v or "")
    s = s:gsub("\\", "\\\\")
    s = s:gsub('"', '\\"')
    s = s:gsub("\r", " "):gsub("\n", " "):gsub("\t", " ")
    return s
end

  -- ★ r29.11：只读扫描。零用户参数（接口由 /usr/sbin/vs010-scan 自己探测），
  --   不写 UCI、不 reload、不重启；未登录 403。输出直接透传，绝不伪造 SSID。
  function scan()
      local http = require "luci.http"
      if not authed() then
          http.status(403, "Forbidden")
          json('{"ok":0,"msg":"🔒 未登录，扫描已锁定"}')
          return
      end
      local sys = require "luci.sys"
      local out = sys.exec("/usr/sbin/vs010-scan 2>/dev/null")
      json((out ~= "" and out) or '{"ok":0,"msg":"扫描未返回，请查看 logread"}')
  end

function act()
    local http = require "luci.http"
    if not authed() then
        http.status(403, "Forbidden")
        json('{"ok":0,"msg":"🔒 未登录，维护操作已锁定"}')
        return
    end
    local a = tostring(http.formvalue("a") or "")
    local cmd = ACTS[a]
    if not cmd then
        json('{"ok":0,"msg":"未知操作（只允许白名单枚举）"}')
        return
    end
    local sys = require "luci.sys"
    local out = sys.exec(cmd .. " 2>/dev/null")
    json('{"ok":1,"act":"' .. jesc(a) .. '","out":"' .. jesc(out) .. '"}')
end
