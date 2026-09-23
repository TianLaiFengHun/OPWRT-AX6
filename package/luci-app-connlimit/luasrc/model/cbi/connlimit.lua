local m = Map("connlimit", translate("连接数限制"),
	translate("按设备限制并发连接数，超出上限的新建连接将被丢弃。仅影响下方列出的设备，其他设备不受限制。填写 MAC 可同时限制该设备的 IPv4 与 IPv6 流量；未填 MAC 时按 IP 限制。"))

local g = m:section(NamedSection, "global", "limit", translate("全局设置"))
g:option(Flag, "enabled", translate("启用"))

local devs = m:section(TypedSection, "device", translate("受限设备"),
	translate("添加需要限制的设备。推荐从“从已连接设备选择”中选取，会自动填充 IP 与 MAC；也可手动填写。"))
devs.anonymous = true
devs.addremove = true
devs.template = "cbi/tblsection"

local name = devs:option(Value, "name", translate("备注"))
name.rmempty = true

-- 已连接设备快速选择：读邻居表，选中后自动填充 ip + mac
local pick = devs:option(Value, "_pick", translate("从已连接设备选择"))
pick.widget = "select"
pick:value("", translate("-- 请选择 --"))

local function load_neighbors()
	local list = {}
	local ok, nb = pcall(luci.sys.net.neighbors)
	if ok and type(nb) == "table" then
		for _, e in ipairs(nb) do
			if e.ip and e.mac and e.mac ~= "00:00:00:00:00:00" then
				table.insert(list, e)
			end
		end
		return list
	end
	-- fallback：直接解析 /proc/net/arp
	local f = io.open("/proc/net/arp", "r")
	if not f then return list end
	for line in f:lines() do
		local ip, hw = line:match("^(%d+%.%d+%.%d+%.%d+)%s+%S+%s+%S+%s+([0-9a-fA-F:]+)")
		if ip and hw and hw ~= "00:00:00:00:00:00" then
			table.insert(list, { ip = ip, mac = hw })
		end
	end
	f:close()
	return list
end

for _, e in ipairs(load_neighbors()) do
	pick:value(e.ip .. "|" .. e.mac, e.ip .. " (" .. e.mac .. ")")
end

pick.write = function(self, section, value)
	if not value or value == "" then return end
	local ip, mac = value:match("^([^|]+)|(.+)$")
	if ip then self.map.uci:set(self.map.config, section, "ip", ip) end
	if mac then self.map.uci:set(self.map.config, section, "mac", mac) end
end
pick.rmempty = true

local mac = devs:option(Value, "mac", translate("设备 MAC"))
mac.datatype = "macaddr"
mac.rmempty = true
mac.description = translate("填 MAC 后同时限制该设备的 IPv4/IPv6 流量，推荐填写。留空则按下方 IP 限制。")

local ip = devs:option(Value, "ip", translate("设备 IP (IPv4)"))
ip.datatype = "ipaddr"
ip.rmempty = true
ip.description = translate("未填 MAC 时生效；若填了 MAC 可留空。")

local ip6 = devs:option(Value, "ip6", translate("设备 IP (IPv6)"))
ip6.datatype = "ip6addr"
ip6.rmempty = true
ip6.description = translate("可选。仅在 MAC 为空时生效；IPv6 地址多变，建议优先使用 MAC。")

local limit = devs:option(Value, "limit", translate("连接数上限"))
limit.datatype = "uinteger"
limit.default = "256"
limit.rmempty = false

local enabled = devs:option(Flag, "enabled", translate("启用"))
enabled.default = "1"

function m.on_apply(self)
	luci.sys.call("/etc/init.d/connlimit restart >/dev/null 2>&1")
end

return m
