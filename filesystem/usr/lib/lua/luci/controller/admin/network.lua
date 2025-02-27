-- Copyright 2008 Steven Barth <steven@midlink.org>
-- Copyright 2011 Jo-Philipp Wich <jow@openwrt.org>
-- Licensed to the public under the Apache License 2.0.

module("luci.controller.admin.network", package.seeall)

function index()
	local uci = require("luci.model.uci").cursor()
	local page

	page = node("admin", "network")
	page.target = firstchild()
	page.title  = _("Network")
	page.order  = 50
        page.sysauth = "admin"
	page.index  = true

--	if page.inreq then
		local has_switch = false

		uci:foreach("network", "switch",
			function(s)
				has_switch = true
				return false
			end)

		if has_switch then
			page  = node("admin", "network", "vlan")
			page.target = cbi("admin_network/vlan")
			page.title  = _("Switch")
			page.order  = 20

			page = entry({"admin", "network", "switch_status"}, call("switch_status"), nil)
			page.leaf = true
		end


		local has_wifi = false

		uci:foreach("wireless", "wifi-device",
			function(s)
				has_wifi = true
				return false
			end)

		if has_wifi then
			page = entry({"admin", "network", "wireless_join"}, call("wifi_join"), nil)
			page.leaf = true

			page = entry({"admin", "network", "wireless_cmssid"}, call("wifi_cmssid"), nil)
			page.leaf = true

			page = entry({"admin", "network", "wireless_wps"}, call("wifi_wps"), nil)
			page.leaf = true

			page = entry({"admin", "network", "wireless_wps_pin"}, call("wifi_wps_pin"), nil)
			page.leaf = true

			page = entry({"admin", "network", "wireless_wps_status"}, call("wifi_wps_status"), nil)
			page.leaf = true

			page = entry({"admin", "network", "wireless_add"}, call("wifi_add"), nil)
			page.leaf = true

			page = entry({"admin", "network", "wireless_delete"}, call("wifi_delete"), nil)
			page.leaf = true

			page = entry({"admin", "network", "wireless_status"}, call("wifi_status"), nil)
			page.leaf = true

			page = entry({"admin", "network", "wireless_reconnect"}, call("wifi_reconnect"), nil)
			page.leaf = true

			page = entry({"admin", "network", "wireless_shutdown"}, call("wifi_shutdown"), nil)
			page.leaf = true

			page = entry({"admin", "network", "wireless"}, arcombine(template("admin_network/wifi_overview"), cbi("admin_network/wifi")), _("Wifi"), 15)
			page.leaf = true
			page.subindex = true

			if page.inreq then
				local wdev
				local net = require "luci.model.network".init(uci)
				for _, wdev in ipairs(net:get_wifidevs()) do
					local wnet
					for _, wnet in ipairs(wdev:get_wifinets()) do
						entry(
							{"admin", "network", "wireless", wnet:id()},
							alias("admin", "network", "wireless"),
							wdev:name() .. ": " .. wnet:shortname()
						)
					end
				end
			end
		end


		page = entry({"admin", "network", "iface_add"}, cbi("admin_network/iface_add"), nil)
		page.leaf = true

		page = entry({"admin", "network", "iface_delete"}, call("iface_delete"), nil)
		page.leaf = true

		page = entry({"admin", "network", "iface_status"}, call("iface_status"), nil)
		page.leaf = true

		page = entry({"admin", "network", "iface_reconnect"}, call("iface_reconnect"), nil)
		page.leaf = true

		page = entry({"admin", "network", "iface_shutdown"}, call("iface_shutdown"), nil)
		page.leaf = true

		page = entry({"admin", "network", "network"}, arcombine(cbi("admin_network/network"), cbi("admin_network/ifaces")), _("Interfaces"), 10)
		page.leaf   = true
		page.subindex = true

		if page.inreq then
			uci:foreach("network", "interface",
				function (section)
					local ifc = section[".name"]
					if ifc ~= "loopback" then
						entry({"admin", "network", "network", ifc},
						true, ifc:upper())
					end
				end)
		end


		if nixio.fs.access("/etc/config/dhcp") then
			page = node("admin", "network", "dhcp")
			page.target = cbi("admin_network/dhcp")
			page.title  = _("DHCP and DNS")
			page.order  = 30

			page = entry({"admin", "network", "dhcplease_status"}, call("lease_status"), nil)
			page.leaf = true

			page = node("admin", "network", "hosts")
			page.target = cbi("admin_network/hosts")
			page.title  = _("Hostnames")
			page.order  = 40
		end

		page  = node("admin", "network", "routes")
		page.target = cbi("admin_network/routes")
		page.title  = _("Static Routes")
		page.order  = 50

		page = node("admin", "network", "diagnostics")
		page.target = template("admin_network/diagnostics")
		page.title  = _("Diagnostics")
		page.order  = 60

		page = entry({"admin", "network", "diag_ping"}, call("diag_ping"), nil)
		page.leaf = true

		page = entry({"admin", "network", "diag_nslookup"}, call("diag_nslookup"), nil)
		page.leaf = true

		page = entry({"admin", "network", "diag_traceroute"}, call("diag_traceroute"), nil)
		page.leaf = true

		page = entry({"admin", "network", "diag_ping6"}, call("diag_ping6"), nil)
		page.leaf = true

		page = entry({"admin", "network", "diag_traceroute6"}, call("diag_traceroute6"), nil)
		page.leaf = true
--	end
end

function wifi_join()
	local function param(x)
		return luci.http.formvalue(x)
	end

	local function ptable(x)
		x = param(x)
		return x and (type(x) ~= "table" and { x } or x) or {}
	end

	local dev  = param("device")
	local ssid = param("join")

	if dev and ssid then
		local cancel  = (param("cancel") or param("cbi.cancel")) and true or false

		if cancel then
			luci.http.redirect(luci.dispatcher.build_url("admin/network/wireless_join?device=" .. dev))
		else
			local cbi = require "luci.cbi"
			local tpl = require "luci.template"
			local map = luci.cbi.load("admin_network/wifi_add")[1]

			if map:parse() ~= cbi.FORM_DONE then
				tpl.render("header")
				map:render()
				tpl.render("footer")
			end
		end
	else
		luci.template.render("admin_network/wifi_join")
	end
end

function wifi_add()
	local dev = luci.http.formvalue("device")
	local ntm = require "luci.model.network".init()

	dev = dev and ntm:get_wifidev(dev)

	if dev then
		local net = dev:add_wifinet({
			mode       = "ap",
			ssid       = "OpenWrt",
			guest      = "disable",
			encryption = "none"
		})

		ntm:save("wireless")
		luci.http.redirect(net:adminlink())
	end
end

function set_cmssid()
	local uci  = require "luci.model.uci".cursor()
	local ssid = uci:get("wireless", "cmssid", "ssid")
	local enabled = uci:get("wireless", "cmssid", "enabled")
	local ntm = require "luci.model.network".init()
	local devices  = ntm:get_wifidevs()
	
	if (enabled ~= "1") or (not ssid) then
		return
	end
	
	local wdev
	for _, wdev in ipairs(devices) do
		local wnet
		for _, wnet in ipairs(wdev:get_wifinets()) do
			if wnet:mode() == "ap" and wnet:get("guest") ~= "enable" then
					wnet:set("ssid", ssid)
			end
		end
	end
	
	ntm:commit("wireless")
	luci.sys.call("env -i /bin/ubus call network reload >/dev/null 2>/dev/null")
end

function wifi_cmssid()
	local function param(x)
		return luci.http.formvalue(x)
	end
	local cbi = require "luci.cbi"
	local tpl = require "luci.template"
	local map = luci.cbi.load("admin_network/wifi_cmssid")[1]
	local ntm = require "luci.model.network".init()

	local cancel  = (param("cancel") or param("cbi.cancel")) and true or false

	if cancel then
		luci.http.redirect(luci.dispatcher.build_url("admin/network/wireless"))
	else
		if map:parse() ~= cbi.FORM_DONE then
			tpl.render("header")
			map:render()
			tpl.render("footer")
		else
			set_cmssid()
			luci.http.redirect(luci.dispatcher.build_url("admin/network/wireless"))
		end
	end
end

function wifi_wps_pin(cfg)
	local util, randompin

	local util = io.popen("/usr/bin/wps.sh genpin")
	if util then
		randompin = util:read("*l")
		util:close()
	end

	luci.http.prepare_content("text/plain")
	luci.http.write(randompin)
end

function wifi_check_pin(pincode)
	local ret = nil
	if pincode and pincode:match("^[0-9]+$") then
		local util = io.popen("/usr/sbin/hostapd_cli wps_check_pin %q | tail -n1" % pincode)
		if util then
			ret = util:read("*l")
			util:close()
		end
	end

	return ret
end

function get_wps_possible_device(method)
	local ntm = require "luci.model.network".init()
	local devices  = ntm:get_wifidevs()
	local wpsdevs = {}

	local wdev
	for _, wdev in ipairs(devices) do
		if wdev:get("disabled") ~= "1" then
			local wnet
			for _, wnet in ipairs(wdev:get_wifinets()) do
				if wnet:get("disabled") ~= "1" and wnet:mode() == "ap" then
					if method == "pbc" and wnet:get("wps_pushbutton") == "1" then
						wpsdevs[#wpsdevs+1] = wnet
					elseif method == "pin" and wnet:get("wps_label") == "1" then
						wpsdevs[#wpsdevs+1] = wnet
					end
				end
			end
		end
	end

	return wpsdevs
end

function wifi_wps(cfg)
	local wpsdevs = {}
	local cfgmethod, pincode, ret

	luci.http.prepare_content("text/plain")
	if cfg == "pbc" then
		cfgmethod = "pbc"
		pincode = "00000000"
	else
		cfgmethod = "pin"
		pincode = cfg
		ret = wifi_check_pin(pincode)

		if ret ~= pincode then
			luci.http.write("Invalid Pin Code...")
			return
		end
	end

	wpsdevs = get_wps_possible_device(cfgmethod)
	if #wpsdevs == 0 then
		luci.http.write("No WPS network is available...")
		return
	end

	local ifnames = ""
	for i, wpsdev in pairs(wpsdevs)
	do
		ifnames = ifnames .. " " .. wpsdev:ifname()
		luci.http.write("%q is \"Active\"...<br />" % wpsdev:get("ssid"))
	end

	luci.sys.call("/usr/bin/wps.sh %s %s %s" % {cfgmethod, pincode, ifnames})
end

function wifi_wps_status()
	local wpsdevs = {}
	local util, cfgmethod, status
	local rv = {
		status = "NONE",
		nets = {}
	}

	util = io.popen("/usr/bin/wps.sh curcfg")
	if util then
		cfgmethod = util:read("*l")
		util:close()
	end

	if cfgmethod ~= "pbc" and cfgmethod ~= "pin" then
		return
	end

	util = io.popen("/usr/bin/wps.sh status")
	if util then
		rv.status = util:read("*l")
		util:close()
	end

	wpsdevs = get_wps_possible_device(cfgmethod)
	for i, wpsdev in pairs(wpsdevs)
	do
		rv.nets[i] = wpsdev:get("ssid")
	end

	luci.http.prepare_content("application/json")
        luci.http.write_json(rv)
end

function wifi_delete(network)
	local ntm = require "luci.model.network".init()
	local wnet = ntm:get_wifinet(network)
	if wnet then
		local dev = wnet:get_device()
		local nets = wnet:get_networks()
		if dev then
			ntm:del_wifinet(network)
			ntm:commit("wireless")
			local _, net
			for _, net in ipairs(nets) do
				if net:is_empty() then
					ntm:del_network(net:name())
					ntm:commit("network")
				end
			end
			luci.sys.call("env -i /bin/ubus call network reload >/dev/null 2>/dev/null")
		end
	end

	luci.http.redirect(luci.dispatcher.build_url("admin/network/wireless"))
end

function iface_status(ifaces)
	local netm = require "luci.model.network".init()
	local rv   = { }

	local iface
	for iface in ifaces:gmatch("[%w%.%-_]+") do
		local net = netm:get_network(iface)
		local device = net and net:get_interface()
		if device then
			local data = {
				id         = iface,
				proto      = net:proto(),
				uptime     = net:uptime(),
				gwaddr     = net:gwaddr(),
				dnsaddrs   = net:dnsaddrs(),
				name       = device:shortname(),
				type       = device:type(),
				ifname     = device:name(),
				macaddr    = device:mac(),
				is_up      = device:is_up(),
				rx_bytes   = device:rx_bytes(),
				tx_bytes   = device:tx_bytes(),
				rx_packets = device:rx_packets(),
				tx_packets = device:tx_packets(),

				ipaddrs    = { },
				ip6addrs   = { },
				subdevices = { }
			}

			local _, a
			for _, a in ipairs(device:ipaddrs()) do
				data.ipaddrs[#data.ipaddrs+1] = {
					addr      = a:host():string(),
					netmask   = a:mask():string(),
					prefix    = a:prefix()
				}
			end
			for _, a in ipairs(device:ip6addrs()) do
				if not a:is6linklocal() then
					data.ip6addrs[#data.ip6addrs+1] = {
						addr      = a:host():string(),
						netmask   = a:mask():string(),
						prefix    = a:prefix()
					}
				end
			end

			for _, device in ipairs(net:get_interfaces() or {}) do
				data.subdevices[#data.subdevices+1] = {
					name       = device:shortname(),
					type       = device:type(),
					ifname     = device:name(),
					macaddr    = device:mac(),
					macaddr    = device:mac(),
					is_up      = device:is_up(),
					rx_bytes   = device:rx_bytes(),
					tx_bytes   = device:tx_bytes(),
					rx_packets = device:rx_packets(),
					tx_packets = device:tx_packets(),
				}
			end

			rv[#rv+1] = data
		else
			rv[#rv+1] = {
				id   = iface,
				name = iface,
				type = "ethernet"
			}
		end
	end

	if #rv > 0 then
		luci.http.prepare_content("application/json")
		luci.http.write_json(rv)
		return
	end

	luci.http.status(404, "No such device")
end

function iface_reconnect(iface)
	local netmd = require "luci.model.network".init()
	local net = netmd:get_network(iface)
	if net then
		luci.sys.call("env -i /sbin/ifup %q >/dev/null 2>/dev/null" % iface)
		luci.http.status(200, "Reconnected")
		return
	end

	luci.http.status(404, "No such interface")
end

function iface_shutdown(iface)
	local netmd = require "luci.model.network".init()
	local net = netmd:get_network(iface)
	if net then
		luci.sys.call("env -i /sbin/ifdown %q >/dev/null 2>/dev/null" % iface)
		luci.http.status(200, "Shutdown")
		return
	end

	luci.http.status(404, "No such interface")
end

function iface_delete(iface)
	local netmd = require "luci.model.network".init()
	local net = netmd:del_network(iface)
	if net then
		luci.sys.call("env -i /sbin/ifdown %q >/dev/null 2>/dev/null" % iface)
		luci.http.redirect(luci.dispatcher.build_url("admin/network/network"))
		netmd:commit("network")
		netmd:commit("wireless")
		return
	end

	luci.http.status(404, "No such interface")
end

function wifi_status(devs)
	local s    = require "luci.tools.status"
	local rv   = { }

	local dev
	for dev in devs:gmatch("[%w%.%-]+") do
		rv[#rv+1] = s.wifi_network(dev)
	end

	if #rv > 0 then
		luci.http.prepare_content("application/json")
		luci.http.write_json(rv)
		return
	end

	luci.http.status(404, "No such device")
end

local function wifi_reconnect_shutdown(shutdown, wnet)
	local netmd = require "luci.model.network".init()
	local net = netmd:get_wifinet(wnet)
	local dev = net:get_device()
	if dev and net then
		dev:set("disabled", nil)
		net:set("disabled", shutdown and 1 or nil)
		netmd:commit("wireless")

		luci.sys.call("env -i /bin/ubus call network reload >/dev/null 2>/dev/null")
		luci.http.status(200, shutdown and "Shutdown" or "Reconnected")

		return
	end

	luci.http.status(404, "No such radio")
end

function wifi_reconnect(wnet)
	wifi_reconnect_shutdown(false, wnet)
end

function wifi_shutdown(wnet)
	wifi_reconnect_shutdown(true, wnet)
end

function lease_status()
	local s = require "luci.tools.status"

	luci.http.prepare_content("application/json")
	luci.http.write('[')
	luci.http.write_json(s.dhcp_leases())
	luci.http.write(',')
	luci.http.write_json(s.dhcp6_leases())
	luci.http.write(']')
end

function switch_status(switches)
	local s = require "luci.tools.status"

	luci.http.prepare_content("application/json")
	luci.http.write_json(s.switch_status(switches))
end

function diag_command(cmd, addr)
	if addr and addr:match("^[a-zA-Z0-9%-%.:_]+$") then
		luci.http.prepare_content("text/plain")

		local util = io.popen(cmd % addr)
		if util then
			while true do
				local ln = util:read("*l")
				if not ln then break end
				luci.http.write(ln)
				luci.http.write("\n")
			end

			util:close()
		end

		return
	end

	luci.http.status(500, "Bad address")
end

function diag_ping(addr)
	diag_command("ping -c 5 -W 1 %q 2>&1", addr)
end

function diag_traceroute(addr)
	diag_command("traceroute -q 1 -w 1 -n %q 2>&1", addr)
end

function diag_nslookup(addr)
	diag_command("nslookup %q 2>&1", addr)
end

function diag_ping6(addr)
	diag_command("ping6 -c 5 %q 2>&1", addr)
end

function diag_traceroute6(addr)
	diag_command("traceroute6 -q 1 -w 2 -n %q 2>&1", addr)
end
