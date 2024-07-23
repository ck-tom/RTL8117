-- Copyright 2008 Steven Barth <steven@midlink.org>
-- Copyright 2011 Jo-Philipp Wich <jow@openwrt.org>
-- Copyright 2013 Manuel Munz <freifunk@somakoma.de>
-- Licensed to the public under the Apache License 2.0.

module("luci.controller.oobwake", package.seeall)

function index()
	local fs = require "nixio.fs"

	if fs.access("/proc/net/r8168oob/eth0/lanwake") then
		entry({"admin", "network", "oobwake"}, call("oob_wake"), _("Wakeup Host"), 90)
	end
end

function oob_wake()
	local wakeup = luci.http.formvalue("wakeup")
	luci.template.render("oobwake", {wakeup=wakeup})
	if wakeup then
		local pid = nixio.fork()
		if pid > 0 then
			return
		elseif pid == 0 then
			nixio.chdir("/")
			local null = nixio.open("/dev/null", "w+")
			if null then
				nixio.dup(null, nixio.stderr)
				nixio.dup(null, nixio.stdout)
				nixio.dup(null, nixio.stdin)
				if null:fileno() > 2 then
					null:close()
				end
			end
		nixio.exec("/bin/sh", "-c", "echo 1 > /proc/net/r8168oob/eth0/lanwake")
		end
	end
end
