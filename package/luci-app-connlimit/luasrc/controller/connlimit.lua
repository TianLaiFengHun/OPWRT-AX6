module("luci.controller.connlimit", package.seeall)

function index()
	if not nixio.fs.access("/etc/config/connlimit") then
		return
	end

	entry({"admin", "network", "connlimit"}, cbi("connlimit"), _("连接数限制"), 90).dependent = false
end
