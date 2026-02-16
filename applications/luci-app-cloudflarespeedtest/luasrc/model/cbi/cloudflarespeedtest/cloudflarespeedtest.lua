-- [[ Cloudflare Speed Test - 看板化深度美化版 (方案 B 定时器对齐优化) ]] --
require("luci.sys")
local uci = luci.model.uci.cursor()

m = Map("cloudflarespeedtest")

-- 1. 标题：项目地址链接与动态图标联动
m.title = [[<a href="https://github.com/mingxiaoyu/luci-app-cloudflarespeedtest" target="_blank" style="text-decoration: none; color: inherit; display: inline-flex; align-items: center;">]] .. 
          translate("Cloudflare 自动优选 IP") .. 
          [[<span style="margin-left: 6px; font-size: 0.9em; transition: opacity 0.2s; opacity: 0.6;" onmouseover="this.style.opacity=1" onmouseout="this.style.opacity=0.6;">🔗</span></a>]]

-- 2. 描述：看板化提示框样式
m.description = [[
<div style="margin-top: 10px; padding: 12px 16px; background-color: #ebf5ff; border-left: 4px solid #3b82f6; border-radius: 8px; color: #1e40af; font-size: 13px; line-height: 1.6; box-shadow: 0 2px 4px rgba(0,0,0,0.05);">
    <strong style="display: block; margin-bottom: 4px; font-size: 14px;">💡 功能介绍</strong>
    自动测试 Cloudflare 节点延迟与速度，并将最优结果同步至相关插件或 DNS 记录。访问 
    <a href="https://github.com/mingxiaoyu/luci-app-cloudflarespeedtest" target="_blank" style="color: #2563eb; text-decoration: underline; font-weight: bold;">GitHub 项目主页</a>
</div>
]]

-- ---------------------------------------------------------
-- 1. 核心样式注入
-- ---------------------------------------------------------
local style_injector = m:section(TypedSection, "global")
style_injector.anonymous = true

o = style_injector:option(DummyValue, "_style_fix")
o.rawhtml = true
o.value = [[
<style>
    .cbi-map-descr {padding: 0 16px !important;}
    /* 1. 状态控制栏修复 */
    div[id$="-_actions"].cbi-value {
        display: flex !important;
        align-items: center !important;
        flex-wrap: nowrap !important;
        padding: 15px 0 !important;
        border-bottom: 1px solid rgba(0,0,0,0.05) !important;
    }
    div[id$="-_actions"] .cbi-value-title {
        flex: 0 0 100px !important;
        width: 100px !important;
        margin: 0 !important;
        text-align: right !important;
        padding-right: 15px !important;
        font-weight: bold !important;
        color: #4b5563 !important;
        float: none !important;
    }
    div[id$="-_actions"] .cbi-value-field {
        flex: 0 0 auto !important;
        margin: 0 !important;
        padding: 0 10px 0 0 !important;
        display: flex !important;
        align-items: center !important;
        float: none !important;
    }

    /* 2. 定时任务行内显示核心优化 (修复换行问题) */
    /* 强制字段区域采用水平排列 */
    div[id$="-hour"] .cbi-value-field, 
    div[id$="-minute"] .cbi-value-field {
        display: flex !important;
        align-items: center !important;
        flex-wrap: nowrap !important;
    }

    /* 强制移除破坏布局的 <br> 换行标签 */
    div[id$="-hour"] .cbi-value-field br, 
    div[id$="-minute"] .cbi-value-field br {
        display: none !important;
    }

    /* 将描述文字强制改为行内块，并设置间距 */
    div[id$="-hour"] .cbi-value-description, 
    div[id$="-minute"] .cbi-value-description {
        display: inline-block !important;
        margin: 0 0 0 12px !important;
        padding: 0 !important;
        white-space: nowrap !important;
        font-size: 13px !important;
        color: #94a3b8 !important;
    }

    /* 输入框物理限宽 */
    div[id$="-hour"] input, 
    div[id$="-minute"] input {
        width: 100px !important;
        min-width: 100px !important;
        text-align: center !important;
        margin: 0 !important;
    }

    /* 3. 看板表格美化 */
    div[id$="-syipstext"].cbi-value .cbi-value-title { display: none !important; }
    div[id$="-syipstext"].cbi-value .cbi-value-field { width: 100% !important; margin: 0 !important; padding: 0 !important; }

    .cf-dashboard {
        width: 100%;
        background: #fff;
        border-radius: 12px;
        border: 1px solid #e2e8f0;
        overflow: hidden;
        box-shadow: 0 4px 20px rgba(0,0,0,0.06);
        margin: 10px 0 25px 0;
    }
    .cf-db-header {
        background: #3b82f6;
        color: #ffffff;
        padding: 10px 16px;
        font-weight: bold;
        display: flex;
        align-items: center;
        font-size: 14px;
    }
    .cf-db-header::before { content: "📊"; margin-right: 8px; }
    .cf-st-table { width: 100%; border-collapse: collapse; }
    .cf-st-table th { background: #f8fafc; color: #64748b; font-weight: 600; padding: 12px; text-align: center; border-bottom: 2px solid #f1f5f9; font-size: 12px; }
    .cf-st-table td { padding: 12px; border-bottom: 1px solid #f1f5f9; text-align: center; font-size: 13px; color: #334155; }
    .cf-st-table tr:hover { background-color: #f1f5f9; transition: 0.2s; }
    
    .ip-badge { font-family: "SFMono-Regular", Consolas, monospace; color: #2563eb; background: #eff6ff; padding: 2px 8px; border-radius: 4px; font-weight: 600; border: 1px solid #dbeafe; }
    .speed-badge { background: #dcfce7; color: #166534; padding: 2px 10px; border-radius: 20px; font-weight: bold; font-size: 12px; }
</style>
]]

-- ---------------------------------------------------------
-- 2. 运行控制中心
-- ---------------------------------------------------------
s = m:section(NamedSection, "global", "section", translate("运行控制中心"))
s.anonymous = true

o = s:option(DummyValue, "_actions")
o.rawhtml = true
o.template = "cloudflarespeedtest/actions"

tvIPs = s:option(DummyValue, "syipstext")
tvIPs.rawhtml = true
function tvIPs.cfgvalue(self, section)
    local file_path = "/usr/share/cloudflarespeedtestresult.txt"
    local f = io.open(file_path, "r")
    if not f then
        return string.format('<div class="cf-dashboard"><div class="cf-db-header">%s</div><div style="padding:30px; text-align:center; color:#94a3b8;">%s</div></div>', 
            translate("IP 优选看板"), translate("暂无测速记录，请点击上方按钮开始执行。"))
    end
    local header = f:read("*l")
    if not header then f:close() return "" end
    local html = '<div class="cf-dashboard"><div class="cf-db-header">' .. translate("IP 优选看板 (Top 8 最佳结果)") .. '</div><table class="cf-st-table"><thead><tr>'
    for col in header:gmatch("([^,]+)") do html = html .. string.format('<th>%s</th>', luci.util.pcdata(col)) end
    html = html .. "</tr></thead><tbody>"
    local count = 0
    for line in f:lines() do
        if count >= 8 then break end
        html = html .. "<tr>"
        local col_idx = 1
        for col in line:gmatch("([^,]+)") do
            local content = luci.util.pcdata(col)
            if col_idx == 1 then content = string.format('<span class="ip-badge">%s</span>', content)
            elseif col:find("MB/s") or (tonumber(col) and col_idx >= 5) then content = string.format('<span class="speed-badge">%s</span>', content) end
            html = html .. string.format('<td>%s</td>', content)
            col_idx = col_idx + 1
        end
        html = html .. "</tr>"
        count = count + 1
    end
    f:close()
    return html .. "</tbody></table></div>"
end

-- ---------------------------------------------------------
-- 3. 核心参数配置
-- ---------------------------------------------------------
s = m:section(NamedSection, "global", "section", translate("核心配置参数"))
s.anonymous = true
s:tab("basic", translate("基础配置"))
s:tab("timer", translate("定时任务"))
s:tab("proxy", translate("环境检测"))
s:tab("advanced", translate("高级调优"))

-- [ 基础配置 ]
o = s:taboption("basic", Flag, "enabled", translate("启用定时任务"))
o.default = 0
o = s:taboption("basic", Flag, "ipv6_enabled", translate("启用 IPv6 模式"))
o = s:taboption("basic", Value, "speed", translate("目标速度 (MB/s)"))
o.datatype = "uinteger"; o.default = 10
o = s:taboption("basic", Value, "custome_url", translate("自定义测速 URL"))

-- [ 定时任务 - 方案 B 深度对齐版 ]
o = s:taboption("timer", Flag, "custome_cors_enabled", translate("使用 Cron 表达式"))
o = s:taboption("timer", Value, "custome_cron", translate("Cron 表达式"))
o:depends("custome_cors_enabled", 1)
o.placeholder = "*/30 * * * *"

-- 小时设置
o = s:taboption("timer", Value, "hour", translate("每日执行时间"))
o.datatype = "range(0,23)"
o.description = translate("点 (24小时制)")
o:depends("custome_cors_enabled", 0)

-- 分钟设置 (引导式)
o = s:taboption("timer", Value, "minute", translate("└ 细化执行分钟"))
o.datatype = "range(0,59)"
o.description = translate("分 (0-59)")
o:depends("custome_cors_enabled", 0)

-- [ 环境检测 ]
o = s:taboption("proxy", ListValue, "proxy_mode", translate("测速时代理策略"))
o:value("nil", translate("保持不变")); o:value("gfw", translate("绕过 GFW 列表")); o:value("close", translate("临时关闭代理"))
o.default = "gfw"

-- [ 高级调优 ]
o = s:taboption("advanced", Flag, "advanced", translate("开启高级参数"))
local pl = { {"threads", "线程 Thread", 200}, {"tl", "平均延迟上限", 200}, {"tll", "平均延迟下限", 50}, {"t", "延迟测速次数", 4}, {"dt", "下载测速时长", 10}, {"dn", "下载测速数量", 1}, {"tp", "指定下载端口", 443} }
for _, p in ipairs(pl) do
    o = s:taboption("advanced", Value, p[1], translate(p[2]))
    o.default = p[3]; o:depends("advanced", 1)
end
o = s:taboption("advanced", Flag, "dd", translate("禁用下载测试")); o:depends("advanced", 1)

-- ---------------------------------------------------------
-- 4. 第三方集成联动
-- ---------------------------------------------------------
s = m:section(NamedSection, "servers", "section", translate("应用插件联动"))
s.description = translate("测速完成后自动更新最优 IP 到以下插件中")

local function add_app(cfg, tid, title, sec, alias, proto)
    if nixio.fs.access("/etc/config/" .. cfg) then
        s:tab(tid, title)
        o = s:taboption(tid, Flag, cfg .. "_enabled", translate("启用同步到 ") .. title)
        local nodes = {}
        uci:foreach(cfg, sec, function(n)
            local label = n[alias] or n.remarks or n.server
            if label then nodes[n[".name"]] = string.format("[%s] %s", string.upper(n[proto] or n.type or "NODE"), label) end
        end)
        local keys = {}
        for k in pairs(nodes) do table.insert(keys, k) end
        table.sort(keys)
        o = s:taboption(tid, DynamicList, cfg .. "_services", translate("目标节点选择"))
        for _, k in ipairs(keys) do o:value(k, nodes[k]) end
        o:depends(cfg .. "_enabled", 1)
    end
end

add_app("shadowsocksr", "ssr", "SSR Plus+", "servers", "alias", "v2ray_protocol")
add_app("passwall", "passwall", "Passwall", "nodes", "remarks", "protocol")
add_app("passwall2", "passwall2", "Passwall2", "nodes", "remarks", "protocol")
add_app("bypass", "bypass", "Bypass", "servers", "alias", "protocol")
add_app("vssr", "vssr", "Vssr", "servers", "alias", "protocol")

-- DNS 解析同步
s:tab("dnstab", translate("DNS 解析"))
o = s:taboption("dnstab", Flag, "DNS_enabled", translate("启用域名同步"))
o = s:taboption("dnstab", ListValue, "DNS_type", translate("DNS 服务商"))
o:value("aliyu", "阿里云 (Aliyun)"); o:depends("DNS_enabled", 1)
o = s:taboption("dnstab", Value, "app_key", translate("Access Key ID")); o:depends("DNS_enabled", 1)
o = s:taboption("dnstab", Value, "app_secret", translate("Access Key Secret")); o.password = true; o:depends("DNS_enabled", 1)
o = s:taboption("dnstab", Value, "main_domain", translate("主域名")); o:depends("DNS_enabled", 1)
o = s:taboption("dnstab", DynamicList, "sub_domain", translate("子域名记录")); o:depends("DNS_enabled", 1)
o = s:taboption("dnstab", ListValue, "line", translate("线路选择")); o:value("default", "默认线路"); o:value("telecom", "电信"); o:value("unicom", "联通"); o:value("mobile", "移动"); o:depends("DNS_enabled", 1)

-- HOST/MosDNS 集成
s:tab("dnshost", translate("HOST 注入"))
o = s:taboption("dnshost", Flag, "HOST_enabled", translate("启用 HOST 修改"))
o = s:taboption("dnshost", Value, "host_domain", translate("指定域名")); o:depends("HOST_enabled", 1)

s:tab("mosdns", translate("MosDNS"))
o = s:taboption("mosdns", Flag, "MosDNS_enabled", translate("启用 MosDNS 同步"))
o = s:taboption("mosdns", Flag, "openclash_restart", translate("完成后重启 OpenClash")); o:depends("MosDNS_enabled", 1)

return m
