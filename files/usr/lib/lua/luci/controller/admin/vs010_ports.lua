-- VS010 / RAX3000Q 5.4.213 融合固件：在 Argon 主题里加「网口速率」页。
-- 只读，不写配置、不碰驱动。官方 netdev 不上报速率时由 portstat 去交换芯片
-- 读 PHY 实测值；本页只是把结果读出来显示，绝不假装 1000M。
module("luci.controller.admin.vs010_ports", package.seeall)

function index()
    entry({"admin", "status", "vs010_ports"}, call("show"), _("网口速率"), 90)
end

function show()
    local sys = require "luci.sys"
    local tpl = require "luci.template"
    local rows = {}
    local ok, raw = pcall(function()
        return sys.exec("/usr/sbin/portstat --rows 2>/dev/null")
    end)
    if ok and raw then
        for line in tostring(raw):gmatch("[^\r\n]+") do
            local p = {}
            for seg in line:gmatch("[^|]+") do p[#p + 1] = seg end
            if #p >= 6 then rows[#rows + 1] = p end
        end
    end
    tpl.render("vs010_ports", { rows = rows })
end
