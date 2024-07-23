--[[
   /usr/lib/lua/luci/controller/apiapp.lua
   Browse to: /cgi-bin/luci/;stok=.../apiappp/{API List}
   {API List} :
    get_info, get_m2muid,
    handle_ls,
    upload, upload.htm, download
    fw_check, fw_upgrade
    usb_check
    init_check
    reg_stok
    set_psw

    last update 2017/10/26

    This code is based on LuCI under Apache License, Version 2.0.
    http://luci.subsignal.org/trac/wiki/License
    http://www.apache.org/licenses/LICENSE-2.0
    Copyright (C) Realtek Semiconductor Corp. All rights reserved.
--]]

--[[

  ASUS BIOS Update Project

  gpio_action --> depends on GPIO script design
    power button (can set low/high active and delay time in runtime?)
    reset button
    clear CMOS
  upload (need SPI write)
  download (need SPI read)
  watchdog_enable (enable/disable watchdog timer)

  2018/04/13

]]--

--[[

v0.9.3-u2 : bug fix

  1. reg_stok only check if 8117 is initialized
     (api_init() will check both if 8117 is initilaized and if stok is registered)
  2. code refactory on _init_check and stok check

---

v0.9.3-u1 : bug fix

  1.add is_dir checking before handle_ls

  2.make more checking on the form parameter - path of handle_ls and upload

  3.except init_check and set_psw, all APIs need initialized

  4.re-organize code (library of upload was moved to library area)

v0.9.3
  1.IB and OOB check for new EHCI driver
    if IB then no access to USB
    (cat /proc/rtl8117-ehci/ehci_enabled ==> 0 in OOB, 1 in IB)
    upload, download, upload.htm, handle_ls, fw_upgrade

  2.fw_check bug fixed for version.txt with empty line

  3.fw_check add BuildDate checking

  4.fw_upgrade : add the option - '-n' to sysupgrade command

  5.RealWoW URL
    change from
    local g_img_url = 'http://realwow.realtek.com/rtl8117/rtl8117-factory.img'
    to
    local g_img_url = 'http://realwow.realtek.com/rtl8117/openwrt-rtl8117-factory-bootcode.img


v0.9.2
  1.add multiple user API
  2.add handle_mkg_img_urlAPI
  3.modify upload API to save file in a given sub directory
  4.modify upload API to rename file if the given file is already existen
  5.code refactory for using luci.* code as much as possible
    (1) use luci.http.protocol.mime.to_mime() , unknow ext will be application/octet-stream, NOT application/unknown


  error cases
     USB flash not mounted
     file not exist (download)
     file exist (upload)
     path not exist (upload)
     path exist (mkdir)

]]

module("luci.controller.apiapp", package.seeall)

function index()
  -- define parent node as the alias of apiapp.apiapp.htm
  --[[
  -- Remove apiapp entry
  page = entry({"apiapp"},
               alias("apiapp", "apiapp.htm"), "API App")
  page.dependent = false

  page = entry({"apiapp","get_info"},    call("get_info"))
  page = entry({"apiapp","get_m2muid"},  call("get_m2muid"))

  page = entry({"apiapp","handle_ls"},   call("handle_ls"))

  page = entry({"apiapp","upload"},      call("upload"))
  page = entry({"apiapp","upload.htm"},  call("upload_htm"))
  page = entry({"apiapp","download"},    call("download"))

  page = entry({"apiapp","fw_check"},    call("fw_check"))
  page = entry({"apiapp","fw_upgrade"},  call("fw_upgrade"))

  page = entry({"apiapp","usb_check"},   call("usb_check"))

  page = entry({"apiapp","init_check"},  call("init_check"))
  page = entry({"apiapp","reg_stok"},    call("reg_stok"))
  page = entry({"apiapp","set_psw"},     call("set_psw"))

  page = entry({"apiapp","test"},  call("test"))
]]--
  --[[
  [api name] description

  [upload] upload (need SPI write)
  [download] download (need SPI read)
  [get_info] get_info (add ASUS test field)
  [get_dxe_info] ]get_dxe_info (add ASUS DXE test message)
  [set_psw] set_psw (alreay has)
  [wd_enable] watchdog_enable (enable/disable watchdog timer)
  [gpio_op] gpio_action --> depends on GPIO script design
    power button (can set low/high active and delay time in runtime?)
    reset button
    clear CMOS
    get status of main power
]]--
  page = entry({"apiasus"},
               alias("apiasus", "apiapp.htm"), "API ASUS")
  page.dependent = false

  page = entry({"apiasus","init_check"},  call("init_check"))
  page = entry({"apiasus","reg_stok"},    call("reg_stok_asus"))
  page = entry({"apiasus","set_psw"},     call("set_psw_asus"))
  page = entry({"apiasus","restart_wsmand"},     call("restart_wsmand_asus"))

  page = entry({"apiasus","get_info"},    call("get_info_asus"))

  page = entry({"apiasus","get_dxe_info"},    call("get_dxe_info_asus")) -- ***

  page = entry({"apiasus","upload"},      call("upload_asus"))
  page = entry({"apiasus","upload.htm"},  call("upload_htm_asus"))
  page = entry({"apiasus","download"},    call("download_asus"))

  page = entry({"apiasus","wd_enable"},    call("wd_enable_asus"))
  page = entry({"apiasus","wd_set_timer"},    call("wd_set_timer_asus"))
  page = entry({"apiasus","wd_set_interval"},    call("wd_set_interval_asus"))

  page = entry({"apiasus","gpio_op"},  call("gpio_op_asus"))

  page = entry({"apiasus","function_status"},   call("function_status_asus"))


  page = entry({"apiasus","test"},  call("test"))

  page = entry({"apiasus","get_pcstate"}, call("get_pcstate"))
  page = entry({"apiasus","power_on_pc"}, call("power_on_pc"))
  page = entry({"apiasus","power_off_pc"}, call("power_off_pc"))
  page = entry({"apiasus","clear_cmos"}, call("clear_cmos"))
  page = entry({"apiasus","reboot_pc"}, call("reboot_pc"))
  page = entry({"apiasus","switch_spi_to_pc"}, call("switch_spi_to_pc"))
  page = entry({"apiasus","switch_spi_to_8117"}, call("switch_spi_to_8117"))

  page = entry({"apiasus","probe_bios_flash"},    call("probe_bios_flash_asus"))
  page = entry({"apiasus","remove_bios_flash"},    call("remove_bios_flash_asus"))

  page = entry({"apiasus","descriptor"}, call("descriptor_asus"))
  page = entry({"apiasus","get_device_info"}, call("get_device_info_asus"))

  page = entry({"apiasus","download_dxe"}, call("download_dxe_asus"))

  page = entry({"apiasus","clean_ring_buffer"}, call("clean_ring_buffer_asus"))

  page = entry({"apiasus","upload_file"}, call("upload_file_asus"))
  page = entry({"apiasus","upload.web"},  call("upload_web_asus"))

  page = entry({"apiasus","stop_service"},  call("stop_service_asus"))
  page = entry({"apiasus","restart_service"},  call("restart_service_asus"))

  page = entry({"apiasus","upgrade_fw"}, call("upgrade_fw_asus"))
  page = entry({"apiasus","upgrade_safemode"}, call("upgrade_safemode_asus"))

  page = entry({"apiasus","check_mode"}, call("check_mode_asus"))

  page = entry({"apiasus","uart_module"}, call("uart_module_asus"))

  page = entry({"apiasus","set_ip"}, call("set_ip_asus"))

  page = entry({"apiasus","factory_upload"}, call("factory_upload_asus"))
  page = entry({"apiasus","factory_setenv"}, call("factory_setenv_asus"))

  page = entry({"apiasus","push_rma"}, call("push_rma_asus"))
  page = entry({"apiasus","dump_rma"}, call("dump_rma_asus"))

  page = entry({"apiasus","clear_backup"},    call("clear_backup_asus"))
  page = entry({"apiasus","clear_stok"},    call("clear_stok_asus"))
  page = entry({"apiasus","clear_psw"},    call("clear_psw_asus"))

  page = entry({"apiasus","get_kvm_usbr"},    call("get_kvm_usbr_asus"))
  page = entry({"apiasus","set_kvm_usbr"},    call("set_kvm_usbr_asus"))
  page = entry({"apiasus","get_kvm_display"},    call("get_kvm_display_asus"))
  page = entry({"apiasus","set_kvm_display"},    call("set_kvm_display_asus"))

  page = entry({"apiasus","get_gop_status"},    call("get_gop_status_asus"))

  page = entry({"apiasus","recovery_backup"},    call("recovery_backup_asus"))

  page = entry({"apiasus","dmesg"},    call("dmesg_asus"))

  page = entry({"apiasus","get_firewall_mode"}, call("get_firewall_mode_asus"))
  page = entry({"apiasus","set_firewall_mode"}, call("set_firewall_mode_asus"))
  page = entry({"apiasus","get_firewall_ip"}, call("get_firewall_ip_asus"))
  page = entry({"apiasus","set_firewall_ip"}, call("set_firewall_ip_asus"))

  page = entry({"apiasus","get_machine_name"}, call("get_machine_name_asus"))
  page = entry({"apiasus","set_machine_name"}, call("set_machine_name_asus"))

  page = entry({"apiasus","get_misc"}, call("get_misc_asus"))
  page = entry({"apiasus","set_misc"}, call("set_misc_asus"))
end

-----------------------------------------------------------------------
-- global g_img_urls {begin}
-----------------------------------------------------------------------
local g_api_version = "v0.9.3-u2"
local g_home = '/mnt/sda1/home/'
local g_buffer_size = 2^13 -- good buffer size (8K)
local g_usb_mt = '/mnt/sda1' -- usb mount point
local g_local_ver_file = '/etc/version.txt'
local g_ver_url = 'http://realwow.realtek.com/rtl8117/version.txt'
local g_default_fw = '/tmp/firmware.img'
local g_img_url = 'http://realwow.realtek.com/rtl8117/openwrt-rtl8117-factory-bootcode.img'
local init_file = "/etc/initialized"
local stok_appuid_map = '/tmp/stok_appuid.map'
local g_dxe_data_file  = '/tmp/dxe_info.dat'
local client_ip = '/tmp/client_ip'

ERR_WAR_MSG = {
  [0] = 'OK',
  [-1] = 'FAIL',
}
-----------------------------------------------------------------------
-- global g_img_urls {end}
-----------------------------------------------------------------------


-----------------------------------------------------------------------
-- library {begin}
-----------------------------------------------------------------------
--[[
  {"version":"THE_VERSION",
   "code":STATUS_CODE,
   "message":"STATUS_MESSAGE",
   "data":[]
  }
--]]
function response_mock()
   local data = {}
   data['version'] = g_api_version
   data['code'] = 0
   data['message'] = 'OK'
   data['data'] = {}
   return data
end

-- Extract extension from a filename and return corresponding mime-type
-- or "application/octet-stream" if the extension is unknown.
function get_mime(ext)
   require "luci.http.protocol.mime"
   return luci.http.protocol.mime.to_mime(ext)
end

--[[
The cmd ONLY return the first result.
If you need more that one result, merge all result into the first result.
--]]
function shell_cmd(cmd)
    local i, t, popen = 0, {}, io.popen
    local pfile = popen(cmd)
    for x in pfile:lines() do
        -- print(x)
        t = x
    end
    pfile:close()
    return t
end

--[[
root@OpenWrt:/www/cgi-bin# cat /proc/uptime
8979.39 8201.91
--]]
function sec2DHMS(sec)
   local days, hours, minutes, seconds
   if sec <= 0 then
      days, hours, minutes, seconds = 0, 0, 0, 0
   else
      days = math.floor(sec / (60*60*24))
      sec = sec % (60*60*24)
      hours = math.floor(sec / (60*60))
      sec = sec % (60*60)
      minutes = math.floor(sec / 60)
      seconds = math.floor(sec % 60)
   end

      return days, hours, minutes, seconds
end

--[[
g_img_url file structure :
name=value
like :
FWVER=1.0.1508
KERNEL=4.4.18-g387e391fd59e-dirty
OpenWrt=gd577f398
U-Boot=2016.11-g4f850a533a-dirty  <--optional, only for fw with u-boot
BuildDate=2017-07-20

return array[k]=v
--]]
function read_config(config_file)
  require "lfs"
  local data = {}
  if lfs.attributes(config_file) then
    local file = io.open(config_file, "r")
    if file then
       for x in file:lines() do
         if x then
            k,v = x:match('(.*)=(.*)')
            if k then data[k] = v end
         end
       end
     file:close()
    end
  end

  return data
end

--[[
Get system token
return token
--]]
function read_token()
  require "lfs"
  local data = ''
  if lfs.attributes('/tmp/token.dat') then
    local file = io.open('/tmp/token.dat', "r")
    if file then
        data = file:read()
    end
    file:close()
  end

  return data
end


--[[
root@OpenWrt:/# cat /etc/version.txt
FWVER=1.0.1508
KERNEL=4.4.18-g387e391fd59e-dirty
OpenWrt=gd577f398
U-Boot=2016.11-g4f850a533a-dirty  <--optional, only for fw with u-boot
BuildDate=2017-07-20

FWVER = [0-9]+.[0-9]+.[0-9]+
         major    minor    sn(git commit #)
--]]

-- return major, minor, sn
function get_local_fw_ver()
  local major = 0
  local minor = 0
  local sn = 0
  local year = 0
  local month = 0
  local day = 0

  data = read_config(g_local_ver_file)
  if data['FWVER'] then
    major, minor, sn = data['FWVER']:match('([0-9]+)\.([0-9]+)\.([0-9]+)')
  end

  if data['BuildDate'] then
    year, month, day = data['BuildDate']:match('([0-9]+)\-([0-9]+)\-([0-9]+)')
  end

  return major, minor, sn, year, month, day
end

-- return major, minor, sn
function get_remote_fw_ver()
  local major = 0
  local minor = 0
  local sn = 0
  local year = 0
  local month = 0
  local day = 0
  local data = {}

  -- read remote version.txt
  local i, t, popen = 0, {}, io.popen
  local pfile = popen('wget -q -O - ' .. g_ver_url)
  for x in pfile:lines() do
      if x then
         k,v = x:match('(.*)=(.*)')
         if k then data[k] = v end
      end
  end
  pfile:close()

  if data['FWVER'] then
    major, minor, sn = data['FWVER']:match('([0-9]+)\.([0-9]+)\.([0-9]+)')
  end

  if data['BuildDate'] then
    year, month, day = data['BuildDate']:match('([0-9]+)\-([0-9]+)\-([0-9]+)')
  end

  return major, minor, sn, year, month, day
end

function fw_is_new(l_major, l_minor, l_sn, l_year, l_month, l_day, r_major, r_minor, r_sn, r_year, r_month, r_day)
   local result = 'no'

   if (r_major > l_major) then
       result = 'yes'
   end
   if (r_major == l_major) and (r_minor > l_minor) then
       result = 'yes'
   end
   if (r_major == l_major) and (r_minor == l_minor) and (r_sn > l_sn)  then
       result = 'yes'
   end

   if (r_major == l_major) and (r_minor == l_minor) and (r_sn == l_sn)  then
       if (r_year > l_year) then
          result = 'yes'
       end
       if (r_year == l_year) and (r_month > l_month) then
           result = 'yes'
       end
       if (r_year == l_year) and (r_month == l_month) and (r_day > l_day)  then
           result = 'yes'
       end
   end

   return result
end

function upgrade_test_ok()
    local i, t, popen = 0, {}, io.popen

    -- check the image - download ok?, checksum ok?
    os.remove(g_default_fw) -- clear the previous firmware
    -- the result of 'sysupgrade -T ' .. g_img_url CANNOT be merged into the first result
    local pfile = popen('sysupgrade -T ' .. g_img_url) -- '-T' test mode

    local ok = true
    for x in pfile:lines() do
        --print("*** " .. x)
        if x:match('Image check \'platform_check_image\' failed') then
           ok = false
        end
    end

    pfile:close()

    return ok
end

function upgrade_run()
    -- if the image is ok , upgrade it
   r = shell_cmd('sysupgrade -n ' .. g_img_url)
   -- print(r)
end

--[[
   if g_usb_mt(/mnt/sda1) is mounted with a USB flash then return true
   else return false
--]]
function sda_is_mounted()
    local mounted = false

    -- root@OpenWrt:/mnt/sda1# mount | grep '/mnt/sda1'
    -- /dev/sdb1 on /mnt/sda1 type vfat (rw,relatime,fmask=0000,dmask=0000,allow_utime=
    -- 0022,codepage=437,iocharset=iso8859-1,shortname=mixed,utf8,errors=remount-ro)
    r = shell_cmd('mount')
    -- print(r)
    if r:match(g_usb_mt) then mounted = true end

    return mounted
end

-- Check if file exists --
function _isfile(file)
   local f=io.open(file,"r")
   if f ~= nil then
      io.close(f)
      return true
   else
      return false
   end
end

-- Check if folder exists --
function _isdir(path)
   require 'lfs'
   if lfs.attributes(path:gsub("\\$",""),"mode") == "directory" then
      return true
   else
      return false
   end
end

function append_config(config_file, k,v)
  local mode = ""
  if _isfile(config_file) then
     mode = "a"
  else
     mode = "w"
  end

  require "lfs"
  local file = io.open(config_file, mode)
  file:write(k..'='..v..'\n')
  file:close()
end

-- There is at lease 0.1 second between two function calls of this function
-- or the two result will be the same!!! (seed precision limitation)
function gen_random_filename()
   math.randomseed(os.time()*10^3 + os.clock()*10^3) --time())
   return tostring(math.random()*10^12)
end

-- check if filename_org exist
-- or it will append _N to the file name
function check_filename(path, filename_org)
  local fn = filename_org
  local ext = fn:match("^.+%.(.+)$")
  local name = fn:match("(.+)%..+")
  local counter = 1
  local changed = false

  while _isfile(path..fn) do
      require "nixio.fs"
      fn = string.format("%s-%d.%s", name, counter, ext)
      counter = counter + 1
      changed = true
  end
  return fn, changed
end

-- the mapping of stok and appuid is stored at /tmp/stok_appuid.map
-- the appuid is the user's home directory name under /mnt/sda1/home
function get_user_home(stok)
  local subdir = ''
  if stok then
    local data = read_config(stok_appuid_map)
    if data[stok] then subdir = data[stok] end
  end
  return subdir
end

function get_stok()
   require "nixio"
   http_headers = nixio.getenv()
   param = http_headers['REQUEST_URI']
   stok = ";stok=" .. param:match(";stok=(.*)/apiapp")
   return stok
end

function  _init_check(show_error)
   --[[if show_error == nil then show_error = true end
   -- check if the file existen
   if _isfile(init_file) then
      return true
   else
      if show_error then
        local result = response_mock()
        luci.http.prepare_content('application/json')
        result['code'] = -1
        result['message'] = 'system not initialized'
        luci.http.write_json(result)
      end

      return false
   end]]--
   return true  -- temporarily because have default password
end

function _stok_check(show_error)
   if show_error == nil then show_error = true end
   -- check if the stok is registered
   if get_user_home(get_stok()) ~= '' then
      return true
   else
      if show_error then
        local result = response_mock()
        luci.http.prepare_content('application/json')
        result['code'] = -1
        result['message'] = get_stok()..' not registered.'
        luci.http.write_json(result)
      end

      return false
   end
end


function _client_ip_check(show_error)
    if show_error == nil then show_error = true end
    -- check ip has not been changed

    local addr = luci.http.getenv("REMOTE_ADDR")
    local old_addr = shell_cmd('cat ' .. client_ip)
    if addr == old_addr then
        return true
    else
        if show_error then
            local result = response_mock()
            require "nixio"
            http_headers = nixio.getenv()
            param = http_headers['REQUEST_URI']
            stok = ";stok=" .. param:match(";stok=(.*)/apiasus")
            shell_cmd('rm ' .. stok_appuid_map)
            shell_cmd('rm -rf /tmp/token.dat')

            result['code'] = -1
            result['message'] = 'Please register the stok.'
            luci.http.prepare_content('application/json')
            luci.http.write_json(result)
            return false
        end
    end
end


function api_init(show_error)
   if show_error == nil then show_error = true end

   if _client_ip_check(show_error) then
       if _init_check(show_error) and _stok_check(show_error) then
          return true
       else
          return false
       end
   else
       return false
   end

end

function isIB() -- return true for IB, return false for OOB
   local mode
   mode = shell_cmd('cat /proc/rtl8117-ehci/ehci_enabled') -- 0 for OOB, 1 for IB
   if mode == '0' then
      return false
   else
      return true
   end
end

-----------------------------------------------------------------------
-- library {end}
-----------------------------------------------------------------------


function test()
   luci.http.prepare_content('text/plain')

   --luci.http.write('test\ntest')
   --luci.http.write(get_mime('txt') .. '\n')
   --luci.http.write(get_mime('pdf') .. '\n')
   --luci.http.write(get_mime('jpeg') .. '\n')
   --luci.http.write(get_mime('jpg') .. '\n')
   --luci.http.write(get_mime('gif') .. '\n')
   --luci.http.write(get_mime('png') .. '\n')

   --luci.http.write(get_mime('tiff') .. '\n')
   --luci.http.write(get_mime('zip') .. '\n')
   --luci.http.write(get_mime('gzip') .. '\n')
   --luci.http.write(get_mime('html') .. '\n')
   --luci.http.write(get_mime('htm') .. '\n')
   --luci.http.write(get_mime('mpeg') .. '\n')

   --luci.http.write(get_mime('mp4') .. '\n')
   --luci.http.write(get_mime('avi') .. '\n')
   --luci.http.write(get_mime('exe') .. '\n')
   --luci.http.write(get_mime('js') .. '\n')
   --luci.http.write('\n')
--[[
  ['txt']  = 'text/plain',
  ['pdf']  = 'application/pdf',
  ['jpeg'] = 'image/jpeg',
  ['jpg']  = 'image/jpeg',
  ['gif']  = 'image/gif',
  ['png']  = 'image/png',
  ['tiff'] = 'image/tiff',
  ['zip']  = 'application/zip',
  ['gzip'] = 'application/gzip',
  ['html'] = 'text/html',
  ['htm']  = 'text/html',
  ['mpeg'] = 'video/mpeg',
  ['mp4']  = 'video/mp4',
  ['avi']  = 'video/avi',
  ['exe']  = 'application/plain',
  ['js']   = 'application/javascript',
--]]

   --require "luci.sys"
   --luci.http.write(luci.sys.uptime() .. '\n\n')


   --require "luci.sys" -- not works
   --luci.http.write(luci.sys.user.getpasswd('root') .. '\n')

   --require "luci.fs"
   --luci.http.write(luci.fs.isfile('/etc/config/uhttpd') .. '\n')

   --for i=1,100 do
   --      print(gen_random_filename())

      --os.execute("sleep 1")
   --      local ntime = os.clock() + 0.1
   --      repeat until os.clock() > ntime
   --   end

   --if  get_user_home(get_stok()) == '' then
   --   print(get_stok() .. ' not reg. \n')
   --else
   --   print(get_user_home(get_stok()))
   --end

   --fn = check_filename('/mnt/sda1/home/usertest/','1.jpg')
   --print(fn)

   --luci.http.write('IB==1, OOB==0\n')
   --if (isIB()) then
   --   luci.http.write('IB\n')
   -- else
   --   luci.http.write('OOB\n')
   -- end


end

-----------------------------------------------------------------------
-- API {begin}
-----------------------------------------------------------------------
--[[
   json data format {"cpu_usage":12,"mem_usage":{"total":27,"free":12,"buffered":88},"disk_usage":9.8,"uptime":{"days":0,"hours":2,"minutes":0,"seconds":23}}
-]]
function get_info()
   if not api_init() then return end

   local result = response_mock()

   -- usage_cpu
   -- root@OpenWrt:/www/cgi-bin# top -bn1
   -- Mem: 25812K used, 2088K free, 440K shrd, 2268K buff, 14524K cached
   -- CPU:   9% usr   0% sys   0% nic  90% idle   0% io   0% irq   0% sirq
   -- Load average: 1.31 0.66 0.31 1/64 17803
   -- ...
   r = shell_cmd('top -bn1 | grep "CPU" -m 1| awk \'{print 100-$8}\' | sed -e \'s/%//g\'')
   -- print(r)
   result['data']['cpu_usage'] = r

   -- usage_memory
   -- root@OpenWrt:/www/cgi-bin# free -m
   --              total         used         free       shared      buffers
   -- Mem:         27900        25480         2420          440         2360
   -- -/+ buffers:              23120         4780
   -- Swap:            0            0            0
   r = shell_cmd('free -k | awk \'NR==2{printf \"%s %s %s\", $2,$4,$6}\'')
   -- print(r)
   r1,r2,r3 = r:match("(.*) (.*) (.*)")
   result['data']['mem_usage'] = {}
   result['data']['mem_usage']['total']  = r1
   result['data']['mem_usage']['free']   = r2
   result['data']['mem_usage']['buffer'] = r3

   -- usage_disk
   -- OpenWrt:/www/cgi-bin# df /mnt/sda1
   -- Filesystem           1K-blocks      Used Available Use% Mounted on
   -- /dev/sda1             14789088     56880  13957912   0% /mnt/sda1
   r = shell_cmd('df '..g_usb_mt..' | sed -e \'1d;s/%//g\' | awk \'{print $5}\'')
   -- print(r)
   result['data']['disk_usage'] = r

   -- uptime
   -- root@OpenWrt:/www/cgi-bin# cat /proc/uptime
   -- 8979.39 8201.91
   r = shell_cmd('cat /proc/uptime | awk \'{print $1}\'')
   t1,t2,t3,t4 = sec2DHMS(math.floor(tonumber(r)))
   -- print(r_uptime[1],r_uptime[2],r_uptime[3],r_uptime[4])
   result['data']['uptime'] = {}
   result['data']['uptime']['days']    = t1
   result['data']['uptime']['hours']   = t2
   result['data']['uptime']['minutes'] = t3
   result['data']['uptime']['seconds'] = t4

   -- get_ip
   -- root@OpenWrt:/www/cgi-bin# ifconfig eth0 | awk '/inet /{sub(/[^0-9]*/,""); print $1}'
   -- 192.168.0.9
   r = shell_cmd('ifconfig eth0 | awk \'/inet /{sub(/[^0-9]*/,\"\"); print $1}\'')
   -- print(r)
   result['data']['ip'] = r


   data = read_config(g_local_ver_file)
   if data['FWVER'] then
      result['data']['fw_version'] = data['FWVER']
   end
   if data['KERNEL'] then
      result['data']['kernel_version'] = data['KERNEL']
   end

   luci.http.prepare_content('application/json')
   luci.http.write_json(result)
end


--[[
   json data format
   {"m2muid":"AWX5X28PGRQPMVFEVJV7"}
--]]
function get_m2muid()
   if not api_init() then return end

   local result = response_mock()

   -- root@OpenWrt:/www/cgi-bin# cat /proc/uptime
   -- 8979.39 8201.91
   -- root@OpenWrt:/# /usr/sbin/fw_printenv | grep m2muid
   -- m2muid=testuidtest
   -- root@OpenWrt:/# /usr/sbin/fw_printenv | grep m2muid | awk -F "=" '{print $2}'
   -- testuidtest
   m2muid = shell_cmd('/usr/sbin/fw_printenv | grep m2muid | awk -F "=" \'{print $2}\'')

   if m2muid == nil then m2muid='' end
   result['data']['m2muid'] = m2muid

   luci.http.prepare_content('application/json')
   luci.http.write_json(result)

end


function handle_ls()
   if not api_init() then return end
   if isIB() then return end -- IB mode do nothing

   io.stdout.setvbuf(io.stdout,'full')

   require "nixio"
   require "lfs"

   http_headers = nixio.getenv()
   --[[
   -- print http headers
   for k,v in pairs(http_headers) do
     luci.http.write(k .. ':'.. v .. '\n<br>')
   end
   --]]

   param = http_headers['QUERY_STRING']
   path = param:match("path=(.*)")
   if path == nil or path == "" then path = '/' end

--   luci.http.write(param)
--   luci.http.write(path)

   --g_home = '/mnt/sda1/home/'
   local result = response_mock()

   phy_path = g_home ..get_user_home(get_stok()) .. '/'.. path -- path must ends with '/' -- aaa/
   result['data']['items'] = {}

   if _isdir(phy_path) then -- isdir check()
      for file in lfs.dir(phy_path) do
          if file ~= "." and file ~= ".." then
              local f = phy_path..file
              local attr = lfs.attributes (f)
              assert (type(attr) == "table")

              local item = {}
              item['name'] = file
              item['type'] = attr.mode
              item['permissions'] = attr.permissions
              if attr.mode == "file" then
                  item['mime'] = get_mime(file:match("^.+%.(.+)$"))
                  item['size'] = attr.size
                  item['atime'] = attr.access
                  item['mtime'] = attr.modification
                  item['ctime'] = attr.change
              end

              table.insert(result['data']['items'], item)
          end
      end
   else
     result['code'] = -1
     result['message'] = get_user_home(get_stok()) .. '/'.. path .. ' not exist'
   end

   luci.http.prepare_content('application/json')
   luci.http.write_json(result)

end


-- two-steps upload
-- step one : upload to home with a random file name (unique)
-- step two : move the file from home to its target path
--            if the target file exist, then rename it (backup machine)
function upload()
   if not api_init() then return end
   if isIB() then return end -- IB mode do nothing

   local fp, path, filename, random_filename
   luci.http.setfilehandler(
      function(meta, chunk, eof) -- meta.file : the filename, meta.name : <input type=\"file\" name=\"upload\>  (upload)
         if not fp then
            filename = meta.file
            random_filename = gen_random_filename()
            --random_filename = gen_random_filename()
            fp = io.open(g_home .. random_filename, "w") -- random_filename
         end

         if chunk then
            fp:write(chunk)
         end

         if eof then
            fp:close()
         end
      end
   )

   -- app will NOT send formvalue("upload_file") for the summit input
   -- so DO NOT check the form value
   local upload = luci.http.formvalue("upload")
   local result = response_mock()
   luci.http.prepare_content('application/json')
   if upload and #upload > 0 then
      path = luci.http.formvalue("path")
      if path == nil or path == "" then path = './' end
      if not path:match("(.*)\/") then path = path .. '/' end
      result['data']['path'] = path

      -- create the user directory if the directory not exist
      os.execute('mkdir -p ' .. g_home .. get_user_home(get_stok()) .. '/' .. path)
      --need to check if g_home .. get_user_home(get_stok()) .. '/' ..path .. filename exist
      filename, changed = check_filename(g_home .. get_user_home(get_stok()) .. '/' ..path, filename)
      os.rename(g_home .. random_filename, g_home .. get_user_home(get_stok()) .. '/' ..path .. filename)
      if changed then
         result['data']['new_filename'] = filename
      end
   else
      result['code'] = -1
      result['message'] = "ERR: upload fail"
   end
   luci.http.write_json(result)

end


function upload_htm()
   if not api_init() then return end
   if isIB() then return end -- IB mode do nothing

  luci.http.prepare_content("text/html")
  luci.http.write("<h1>upload test page</h1>")
  luci.http.write("<form action=\"upload\" method=\"post\" enctype=\"multipart/form-data\">")
  luci.http.write("<input type=\"file\" name=\"upload\" /><br>")
  luci.http.write("path<input type=\"text\" name=\"path\" /><br>")
  luci.http.write("<input type=\"submit\" name=\"upload_file\" value=\"submit\" />")
  luci.http.write("</form>")
end


function download()
   if not api_init() then return end
   if isIB() then return end -- IB mode do nothing

   require "nixio"
   require "lfs"

   http_headers = nixio.getenv()
   --[[
   -- print http headers
   for k,v in pairs(http_headers) do
     print(k, v)
   end
   --]]


   param = http_headers['QUERY_STRING']
   target = param:match("target=(.*)")

   if target == nil then
      local result = response_mock()
      luci.http.prepare_content('application/json')
      result['code'] = -1
      result['message'] = 'parameter - target not found'
      luci.http.write_json(result)
      return -1
   end

   path_filename = target
   phy_path_filename = g_home .. get_user_home(get_stok()) .. '/' .. path_filename

   if lfs.attributes(phy_path_filename) == nil then
      local result = response_mock()
      luci.http.prepare_content('application/json')
      result['code'] = -1
      result['message'] = target .. ' not exist'
      luci.http.write_json(result)
      return -1
   end

   local file_size = lfs.attributes(phy_path_filename,"size")
   local the_mime = get_mime(phy_path_filename:match("^.+%.(.+)$"))

   luci.http.header("Content-Disposition","attachment; filename=\"" .. target .."\"")
   luci.http.prepare_content(the_mime)

   -- HTTP file output
   local size = g_buffer_size -- good buffer size (8K)
   local file = io.open(phy_path_filename,"rb")
   while true do
      local block
      block = file:read(size)
      if not block then break end
      luci.http.write(block)
   end
   file:close()

end


function fw_check()
   if not api_init() then return end

   l_major, l_minor, l_sn, l_year, l_month, l_day = get_local_fw_ver()
   r_major, r_minor, r_sn, r_year, r_month, r_day= get_remote_fw_ver()

   local result = response_mock()
   result['data']['new_fw'] = fw_is_new(l_major, l_minor, l_sn, l_year, l_month, l_day, r_major, r_minor, r_sn, r_year, r_month, r_day)

   luci.http.prepare_content('application/json')

   result['data']['local_ver'] = string.format('%d.%d.%d (%d-%d-%d)', l_major, l_minor, l_sn, l_year, l_month, l_day)
   result['data']['remote_ver'] = string.format('%d.%d.%d (%d-%d-%d)', r_major, r_minor, r_sn, r_year, r_month, r_day)
   luci.http.write_json(result)

end


function fw_upgrade()
   if not api_init() then return end
   if isIB() then return end -- IB mode do nothing

  local result = response_mock()
   luci.http.prepare_content('application/json')

   l_major, l_minor, l_sn, l_year, l_month, l_day = get_local_fw_ver()
   r_major, r_minor, r_sn, r_year, r_month, r_day= get_remote_fw_ver()
   if fw_is_new(l_major, l_minor, l_sn, l_year, l_month, l_day, r_major, r_minor, r_sn, r_year, r_month, r_day) == 'yes' then
        if upgrade_test_ok() then
            luci.http.write_json(result)
            upgrade_run() -- it will reboot system after the upgrade is finished
        else
            result['code'] = -1
            result['message'] = 'Image check \'platform_check_image\' failed'
            luci.http.write_json(result)
        end
   else
      result['code'] = -1
      result['message'] = 'no new firmware avaliable'
      luci.http.write_json(result)
   end

end


function usb_check()
   if not api_init() then return end

   local result = response_mock()
   result['data']['mounted'] = sda_is_mounted()
   luci.http.prepare_content('application/json')
   luci.http.write_json(result)

end


function  init_check()
   local result = response_mock()
   result['data']['initialized'] = _init_check(false) -- not show the error in _init_check()

   luci.http.prepare_content('application/json')
   luci.http.write_json(result)
end


function reg_stok()
   if not _init_check() then return end

   require "nixio"
   http_headers = nixio.getenv()
   param = http_headers['REQUEST_URI']
   appuid = param:match("appuid=(.*)")
   stok = get_stok() --";stok=" .. param:match(";stok=(.*)/apiapp")

   local result = response_mock()
   if appuid then
      result['data']['appuid'] = appuid
      result['data']['stok'] = stok
      local data = read_config(stok_appuid_map)
      if data[stok] == nil then
         append_config(stok_appuid_map, stok, appuid)
         -- create the user directory if the directory not exist
         os.execute('mkdir -p ' .. g_home .. appuid)
      else
         result['code'] = -1
         result['message'] = 'appuid is registered with ' .. data[stok]
      end
   else
      result['code'] = -1
      result['message'] = 'appuid not given'
   end

   luci.http.prepare_content('application/json')
   luci.http.write_json(result)
end


function set_psw()
   local result = response_mock()

   if _init_check(false) then  -- not show the error in _init_check()
      result['code'] = -1
      result['message'] = 'system is initialized'
   else
    require "nixio"
    http_headers = nixio.getenv()
    param = http_headers['QUERY_STRING']
    psw = param:match("psw=(.*)")
    if psw then
       require "luci.sys"
       luci.sys.user.setpasswd('root', psw)

      -- create the initialized file (tag file)
      os.execute('touch ' .. init_file)
    else
       result['code'] = -1
       result['message'] = 'password not given'
    end
   end

   luci.http.prepare_content('application/json')
   luci.http.write_json(result)
end
-----------------------------------------------------------------------
-- API {end}
-----------------------------------------------------------------------


-----------------------------------------------------------------------
-- API ASUS {begin}
-----------------------------------------------------------------------
function get_stok_asus()
   require "nixio"
   http_headers = nixio.getenv()
   param = http_headers['REQUEST_URI']
   stok = ";stok=" .. param:match(";stok=(.*)/apiasus")
   return stok
end

function _stok_check(show_error)
   if show_error == nil then show_error = true end
   -- check if the stok is registered
   if get_user_home(get_stok_asus()) ~= '' then
       io.popen('ps | grep stok_timeout.sh | grep -v grep | awk \'{print $1}\' | xargs kill; sh /usr/local/sbin/stok_timeout.sh &')
      return true
   else
      if show_error then
        local result = response_mock()
        luci.http.prepare_content('application/json')
        result['code'] = -1
        result['message'] = get_stok_asus()..' not registered.'
        luci.http.write_json(result)
      end

      return false
   end
end

function reg_stok_asus()
   shell_cmd("echo \"[APRO][WEB] reg_stok\" > /dev/kmsg")

   if not _init_check() then return end

   require "nixio"
   http_headers = nixio.getenv()
   param = http_headers['REQUEST_URI']
   appuid = param:match("appuid=(.*)")
   stok = get_stok_asus() --";stok=" .. param:match(";stok=(.*)/apiasus")
   cmp_stok = stok:match(";stok=(.*)")
   sys_stok = read_token()

   local result = response_mock()

   if sys_stok ~= cmp_stok or sys_stok == nil then
      shell_cmd("echo \"[APRO][WEB] reg_stok\": Invalid stok > /dev/kmsg")
      result['code'] = -1
      result['message'] = 'Invalid stok.'
      luci.http.prepare_content('application/json')
      luci.http.write_json(result)
      return
   else
       shell_cmd("echo \"[APRO][WEB] reg_stok\": Valid stok > /dev/kmsg")
   end

   if appuid then
      result['data']['appuid'] = appuid
      result['data']['stok'] = stok
      local data = read_config(stok_appuid_map)
      if data[stok] == nil then
         shell_cmd("echo \\%s=%s > %s" %{stok, appuid, stok_appuid_map})
         -- create the user directory if the directory not exist
         os.execute('mkdir -p ' .. g_home .. appuid)
         local addr = luci.http.getenv("REMOTE_ADDR")
         os.execute('echo ' .. addr .. ' > ' .. client_ip)
      else
         result['message'] = 'appuid is registered with ' .. data[stok]
      end
      io.popen('ps | grep stok_timeout.sh | grep -v grep | awk \'{print $1}\' | xargs kill; sh /usr/local/sbin/stok_timeout.sh &')
   else
      result['code'] = -1
      result['message'] = 'appuid not given'
   end

   luci.http.prepare_content('application/json')
   luci.http.write_json(result)
end

function set_psw_asus()
   shell_cmd("echo \"[APRO][WEB] set_psw\" > /dev/kmsg")

   if not api_init() then return end

   local result = response_mock()

   require "nixio"
   require "nixio.fs"
   http_headers = nixio.getenv()
   param = http_headers['QUERY_STRING']
   psw = luci.http.formvalue("psw")
   if psw then
      require "luci.sys"
      luci.sys.user.setpasswd('root', psw)
      shell_cmd("echo \"[APRO][Backup] bstatus: 3\" > /dev/kmsg")
      shell_cmd("echo bstatus:3 | chpasswd -e")
      shell_cmd("cp -p /etc/shadow /mnt/aproData/shadow; sync")

      --sync psw to wsmand
      nixio.fs.writefile("/etc/wsmand/account", "root:" ..psw.. ":1:00000007")
      shell_cmd("cp -p /etc/wsmand/account /mnt/aproData/account; sync")

      -- create the initialized file (tag file)
      os.execute('touch ' .. init_file)
   else
      result['code'] = -1
      result['message'] = 'password not given'
   end

   luci.http.prepare_content('application/json')
   luci.http.write_json(result)
end

function restart_wsmand_asus()
    shell_cmd("echo \"[APRO][WEB] restart_wsmand\" > /dev/kmsg")

    if not api_init() then return end

    local result = response_mock()
    os.execute('service wsmand restart')
    result['message'] = "restart wsmand"

    luci.http.prepare_content('application/json')
    luci.http.write_json(result)
end

--[[
   json data format
-]]
function get_info_asus()
   shell_cmd("echo \"[APRO][WEB] get_info\" > /dev/kmsg")
   if not api_init() then return end

   local result = response_mock()

   data = read_config(g_local_ver_file)
   if data['FWVER'] then
      result['data']['fw_version'] = data['FWVER']
   end

   if data['KERNEL'] then
      result['data']['kernel_version'] = data['KERNEL']
   end

   if data['OpenWrt'] then
      result['data']['openwrt_version'] = data['OpenWrt']
   end

   if data['U-Boot'] then
      result['data']['u-boot_version'] = data['U-Boot']
   end

   if data['BuildDate'] then
      result['data']['build_date'] = data['BuildDate']
   end

   if data['ASUS'] then
      result['data']['ASUS'] = data['ASUS']
   end


   luci.http.prepare_content('application/json')
   luci.http.write_json(result)
end

--[[
   json data format
-]]

function get_dxe_info_asus()
   shell_cmd("echo \"[APRO][WEB] get_dxe_info\" > /dev/kmsg")

   if not api_init() then return end

   shell_cmd("/usr/local/sbin/dxe-dump 0.0.0.0") -- dump ring buffer to /tmp/dxe

   local file_size = lfs.attributes(g_dxe_data_file,"size")
   local target = "dxe_info.dat"
   local the_mime = get_mime("dat")

   luci.http.header("Content-Disposition","attachment; filename=\"" .. target .."\"")
   luci.http.prepare_content(the_mime)

   -- HTTP file output
   local size = g_buffer_size -- good buffer size (8K)
   local file = io.open(g_dxe_data_file,"rb")
   while true do
      local block
      block = file:read(size)
      if not block then break end
      luci.http.write(block)
   end
   file:close()
   
   shell_cmd("rm " .. g_dxe_data_file)
   
end

-- two-steps upload
-- step one : upload to home with a random file name (unique)
-- step two : move the file from home to its target path
--            if the target file exist, then rename it (backup machine)
function upload_asus()
   shell_cmd("echo \"[APRO][WEB] upload\" > /dev/kmsg")
   if not api_init() then return end
   if isIB() then return end -- IB mode do nothing

   local fp, path, filename, random_filename
   luci.http.setfilehandler(
      function(meta, chunk, eof) -- meta.file : the filename, meta.name : <input type=\"file\" name=\"upload\>  (upload)
         if not fp then
            filename = meta.file
            --random_filename = gen_random_filename()
            fp = io.open("/tmp/2M.upload", "w") -- random_filename
         end

         if chunk then
            fp:write(chunk)
         end

         if eof then
            fp:close()
         end
      end
   )

   -- app will NOT send formvalue("upload_file") for the summit input
   -- so DO NOT check the form value
   local upload = luci.http.formvalue("upload")
   local result = response_mock()
   luci.http.prepare_content('application/json')
   if upload and #upload > 0 then

      sha1sum = luci.http.formvalue("sha1sum")
	   if sha1sum == nil then
		  local result = response_mock()
		  luci.http.prepare_content('application/json')
		  result['code'] = -1
		  result['message'] = 'parameter - sha1sum not found'
		  luci.http.write_json(result)
		  return -1
	   end

      slice_no = luci.http.formvalue("slice_no")
	   if slice_no == nil then
		  local result = response_mock()
		  luci.http.prepare_content('application/json')
		  result['code'] = -1
		  result['message'] = 'parameter - slice_no not found'
		  luci.http.write_json(result)
		  return -1
	   end

      slice_no = tonumber(slice_no)

	   if (slice_no >= 0) and (slice_no <= 15) then
		  sha1sum_local = shell_cmd("sha1sum /tmp/2M.upload | /usr/bin/awk -F \" \" '{print $1}'") -- 7d76d48d64d7ac5411d714a4bb83f37e3e5b8df6  /tmp/2M.upload

		  if sha1sum_local == sha1sum then
                      cmd = 'mtd write /tmp/2M.upload /dev/mtd' .. slice_no + 16
		      r = shell_cmd(cmd)
                      cmp_cmd = 'sha1sum /dev/mtd' ..slice_no+16 .. ' | awk \'{print $1}\''
                      sha1sum_cmp = shell_cmd(cmp_cmd)
                      if sha1sum_cmp == sha1sum then
                          result['message'] = 'put to flash. matched' ..' ' ..sha1sum_local..'=' .. sha1sum
                          set_misc_flag(0, 1, 1);
                      else
                          result['code'] = -1
                          result['message'] = 'mtd verify Fail'
                      end

		  else
   		      result['code'] = -1
   		      result['message'] = 'Wrong' ..' ' ..sha1sum_local..'~=' .. sha1sum
		  end

	   else
		  luci.http.prepare_content('application/json')
		  result['code'] = -1
		  result['message'] = 'parameter - slice_no='..slice_no..' not support'
	   end
   else
      result['code'] = -1
      result['message'] = "ERR: upload fail"
   end
   shell_cmd('rm /tmp/2M.upload')
   shell_cmd("sync;sync;sync;")
   shell_cmd("echo 3 > /proc/sys/vm/drop_caches")

   luci.http.write_json(result)

end


function upload_htm_asus()
   if not api_init() then return end
   if isIB() then return end -- IB mode do nothing

  luci.http.prepare_content("text/html")
  luci.http.write("<h1>upload test page</h1>")
  luci.http.write("<form action=\"upload\" method=\"post\" enctype=\"multipart/form-data\">")
  luci.http.write("<input type=\"file\" name=\"upload\" /><br>")
  luci.http.write("sha1sum<input type=\"text\" name=\"sha1sum\" /><br>")
  luci.http.write("slice_no (0~7)<input type=\"text\" name=\"slice_no\" /><br>")
  luci.http.write("<input type=\"submit\" name=\"upload_file\" value=\"submit\" />")
  luci.http.write("</form>")
end


function download_asus()
   shell_cmd("echo \"[APRO][WEB] download\" > /dev/kmsg")
   if not api_init() then return end
   if isIB() then return end -- IB mode do nothing

   require "nixio"
   require "lfs"

   http_headers = nixio.getenv()
   --[[
   -- print http headers
   for k,v in pairs(http_headers) do
     print(k, v)
   end
   --]]


   slice_no = tonumber(luci.http.formvalue("slice_no"))
   local result = response_mock()

   if slice_no == nil then
	  luci.http.prepare_content('application/json')
	  result['code'] = -1
	  result['message'] = 'parameter - slice_no not found'
	  luci.http.write_json(result)
	  return -1
   end   

   if (slice_no >= 0) and (slice_no <= 15) then
 		  cmd = 'dd of=/tmp/2M.download if=/dev/mtd' .. slice_no+16 .. ' bs=1M count=2'
	      r = shell_cmd(cmd)
		  result['message'] = 'read from flash'

		   if lfs.attributes("/tmp/2M.download") == nil then
			  local result = response_mock()
			  luci.http.prepare_content('application/json')
			  result['code'] = -1
			  result['message'] = "/tmp/2M.download" .. ' not exist'
			  luci.http.write_json(result)
			  return -1
		   end

                   sha1sum_local = shell_cmd("sha1sum /tmp/2M.download | /usr/bin/awk -F \" \" '{print $1}'")
                   luci.sys.exec('echo \'sha1sum=' .. sha1sum_local .. '\' >> /tmp/2M.download' )
		   local file_size = lfs.attributes("/tmp/2M.download","size")
		   local the_mime = get_mime("download")

		   luci.http.header("Content-Disposition","attachment; filename=\"" .. "/tmp/2M.download".."\"")
		   luci.http.prepare_content(the_mime)

		   -- HTTP file output
		   local size = g_buffer_size -- good buffer size (8K)
		   local file = io.open("/tmp/2M.download","rb")
		   while true do
			  local block
			  block = file:read(size)
			  if not block then break end
			  luci.http.write(block)
		   end
		   file:close()

                   shell_cmd('rm /tmp/2M.download')
                   shell_cmd("sync;sync;sync;")
                   shell_cmd("echo 3 > /proc/sys/vm/drop_caches")
   else
		  luci.http.prepare_content('application/json')
		  result['code'] = -1
		  result['message'] = 'parameter - slice_no='..slice_no..' not support'
		  luci.http.write_json(result) 
   end


end


function wd_enable_asus()
   shell_cmd("echo \"[APRO][WEB] wd_enable\" > /dev/kmsg")

   if not api_init() then return end
   if isIB() then return end -- IB mode do nothing

   require "nixio"
   require "lfs"

   http_headers = nixio.getenv()
   --[[
   -- print http headers
   for k,v in pairs(http_headers) do
     print(k, v)
   end
   --]]

   param = http_headers['QUERY_STRING']
   op = tonumber(param:match("op=(.*)")) -- 0:disable, 1:enable, 2:query

   if op == nil then
      local result = response_mock()
      luci.http.prepare_content('application/json')
      result['code'] = -1
      result['message'] = 'parameter - opnot found'
      luci.http.write_json(result)
      return -1
   end
   
   r = 0
   
   if op == 0 then -- watchdog disable
      shell_cmd('echo 0 > /etc/wd_enable')
      r = 0
   elseif op == 1 then -- watchdog enable
      shell_cmd('echo 1 > /etc/wd_enable; /usr/local/sbin/wd_hb_control 1')
      r = 1
   elseif op == 2 then -- watchdog query
      r = shell_cmd('cat /etc/wd_enable')
      local result = response_mock()
      luci.http.prepare_content('application/json')
      result['code'] = 0
      result['message'] = 'enable = '..r
      result['data']['heartbeat'] = shell_cmd('cat /etc/wd_hb_inter')
      result['data']['watchdog'] = shell_cmd('cat /etc/wd_timeout')
      luci.http.write_json(result)
      return true
   else
      local result = response_mock()
      luci.http.prepare_content('application/json')
      result['code'] = -1
      result['message'] = 'parameter - op='..op..' not support'
      luci.http.write_json(result)
      return -1
   end
   

   local result = response_mock()
   luci.http.prepare_content('application/json')
   result['code'] = 0
   result['message'] = 'enable = '..r

   -- post processing ...

   luci.http.write_json(result)

end

function wd_set_timer_asus()
    shell_cmd("echo \"[APRO][WEB] wd_set_timer\" > /dev/kmsg")

    if not api_init() then return end
    if isIB() then return end -- IB mode do nothing

    local result = response_mock()

    require "nixio"
    http_headers = nixio.getenv()
    param = http_headers['QUERY_STRING']
    time = param:match("time=(.*)")

    if time then
        shell_cmd('echo '..time..' > /etc/wd_timeout')
    else
        result['code'] = -1
        result['message'] = 'time not given'
    end

    luci.http.prepare_content('application/json')
    luci.http.write_json(result)

end

function wd_set_interval_asus()
    shell_cmd("echo \"[APRO][WEB] wd_set_interval\" > /dev/kmsg")

    if not api_init() then return end
    if isIB() then return end -- IB mode do nothing

    local result = response_mock()

    require "nixio"
    http_headers = nixio.getenv()
    param = http_headers['QUERY_STRING']
    time = param:match("time=(.*)")

    if time then
        shell_cmd('echo '..time..' > /etc/wd_hb_inter')
    else
        result['code'] = -1
        result['message'] = 'time not given'
    end

    luci.http.prepare_content('application/json')
    luci.http.write_json(result)

end

function msleep(msec)
   socket = require("socket")
   socket.sleep(0.001*msec)
end

function gpio_op_asus()
   if not api_init() then return end
   if isIB() then return end -- IB mode do nothing

   require "nixio"
   require "lfs"

   http_headers = nixio.getenv()
   --[[
   -- print http headers
   for k,v in pairs(http_headers) do
     print(k, v)
   end
   --]]

   param = http_headers['QUERY_STRING']
   op = tonumber(luci.http.formvalue("op"))

   if op == nil then
      local result = response_mock()
      luci.http.prepare_content('application/json')
      result['code'] = -1
      result['message'] = 'parameter - op not found'..param
      luci.http.write_json(result)
      return -1
   else 
      if (op ~= 1) and (op ~= 2) and (op ~= 3) then
         local result = response_mock()
         luci.http.prepare_content('application/json')
         result['code'] = -1
         result['message'] = 'parameter - target='..op..' not support'
         luci.http.write_json(result)
         return -1
      end

   end

   level = tonumber(luci.http.formvalue("level"))
   if level == nil then
      local result = response_mock()
      luci.http.prepare_content('application/json')
      result['code'] = -1
      result['message'] = 'parameter - level not found'
      luci.http.write_json(result)
      return -1
   else
      if (level ~= 0) and (level ~= 1) then
         local result = response_mock()
         luci.http.prepare_content('application/json')
         result['code'] = -1
         result['message'] = 'parameter - level='..level..' not support'
         luci.http.write_json(result)
         return -1
      end
   end

   delay = tonumber(luci.http.formvalue("delay"))
   if delay == nil then
      local result = response_mock()
      luci.http.prepare_content('application/json')
      result['code'] = -1
      result['message'] = 'parameter - delay not found'
      luci.http.write_json(result)
      return -1
   end


   if op == 1 then -- power : GPIO 8 OUTPUT
      if level == 0 then
         shell_cmd('echo 0 > /sys/devices/virtual/gpio/gpio8/value')
      else
         shell_cmd('echo 1 > /sys/devices/virtual/gpio/gpio8/value')      
      end
      msleep(delay)

   elseif op == 2 then -- reset : GPIO 9 OUTPUT
      if level == 0 then
         shell_cmd('echo 0 > /sys/devices/virtual/gpio/gpio9/value')
      else
         shell_cmd('echo 1 > /sys/devices/virtual/gpio/gpio9/value')      
      end
      msleep(delay)

   elseif op == 3 then -- clear CMOS : GPIO 7 OUTPUT
      if level == 0 then
         shell_cmd('echo 0 > /sys/devices/virtual/gpio/gpio7/value')
      else
         shell_cmd('echo 1 > /sys/devices/virtual/gpio/gpio7/value')      
      end
      msleep(delay)
      
   else
      local result = response_mock()
      luci.http.prepare_content('application/json')
      result['code'] = -1
      result['message'] = 'parameter - op='..op..'not support'
      luci.http.write_json(result)
      return -1
   end


   local result = response_mock()
   luci.http.prepare_content('application/json')
   result['code'] = 0
   result['message'] = 'op = '..op..' level='..level..' delay='..delay..' finished'


   -- post processing ...

   luci.http.write_json(result)

end

function function_status_asus()
    shell_cmd("echo \"[APRO][WEB] function_status\" > /dev/kmsg")

    if not api_init() then return end

    local result = response_mock()

    require "nixio"
    http_headers = nixio.getenv()
    param = http_headers['QUERY_STRING']
    func = param:match("f=(.*)")

    luci.http.prepare_content('application/json')
    luci.http.write_json(result)
end

function get_pcstate()
    shell_cmd("echo \"[APRO][WEB] get_pcstate\" > /dev/kmsg")

    if not api_init() then return end
    if isIB() then return end -- IB mode do nothing

    local result = response_mock()
    local pcstatebit_0_1
    local pcstatebit_2
    local pcstatebit
    -- ACPI state; 0->S5, 1->S4, 3->S3, 7->S0
    pcstate_bit0_1 =  shell_cmd('cat /sys/devices/virtual/apro-ctrl/aproctrl/pcstate')
    pcstate_bit2 = shell_cmd('cat /proc/net/r8168oob/eth0/isolate')

    acpi_cal = shell_cmd('cat /tmp/acpi_cal') or "0"
    if (acpi_cal == "1") then
        pcstate_bit0_1 = 0
    end

    pcstate = pcstate_bit0_1 + pcstate_bit2*4


    result['code'] = 0
    result['message'] = 'APCI state'
    result['data'] = pcstate
    luci.http.prepare_content('application/json')
    luci.http.write_json(result)
end

function power_on_pc()
    shell_cmd("echo \"[APRO][WEB] power_on_pc\" > /dev/kmsg")

    if not api_init() then return end
    if isIB() then return end -- IB mode do nothing

    local result = response_mock()
    shell_cmd('echo \'1\' > /sys/class/apro-ctrl/aproctrl/poweron')

    result['code'] = 0
    result['message'] = 'Remote PC'
    result['data'] = 'power on'
    luci.http.prepare_content('application/json')
    luci.http.write_json(result)
end

function power_off_pc()
    shell_cmd("echo \"[APRO][WEB] power_off_pc\" > /dev/kmsg")

    if not api_init() then return end
    if isIB() then return end -- IB mode do nothing

    local result = response_mock()
    shell_cmd('echo \'1\' > /sys/class/apro-ctrl/aproctrl/poweroff')

    result['code'] = 0
    result['message'] = 'Remote PC'
    result['data'] = 'power off'
    luci.http.prepare_content('application/json')
    luci.http.write_json(result)
end

function reboot_pc()
    shell_cmd("echo \"[APRO][WEB] reboot_pc\" > /dev/kmsg")

    if not api_init() then return end
    if isIB() then return end -- IB mode do nothing

    local result = response_mock()
    shell_cmd('echo \'1\' > /sys/class/apro-ctrl/aproctrl/rebootos')

    result['code'] = 0
    result['message'] = 'Remote PC'
    result['data'] = 'reboot'
    luci.http.prepare_content('application/json')
    luci.http.write_json(result)
end

function clear_cmos()
    shell_cmd("echo \"[APRO][WEB] clear_cmos\" > /dev/kmsg")

    if not api_init() then return end
    if isIB() then return end -- IB mode do nothing

    local result = response_mock()
    shell_cmd('echo \'1\' > /sys/class/apro-ctrl/aproctrl/clearcmos')
    set_misc_flag(0, 0, 1)

    result['code'] = 0
    result['message'] = 'Remote PC'
    result['data'] = 'CMOS has been clean'
    luci.http.prepare_content('application/json')
    luci.http.write_json(result)
end

function switch_spi_to_pc()
    shell_cmd("echo \"[APRO][WEB] switch_spi_to_pc\" > /dev/kmsg")

    if not api_init() then return end
    if isIB() then return end -- IB mode do nothing

    local result = response_mock()
    shell_cmd('echo \'0\' > /sys/class/apro-ctrl/aproctrl/spiswitch')

    result['code'] = 0
    result['message'] = 'Remote PC'
    result['data'] = 'Flash was connected with PC'
    luci.http.prepare_content('application/json')
    luci.http.write_json(result)
end

function switch_spi_to_8117()
    shell_cmd("echo \"[APRO][WEB] switch_spi_to_8117\" > /dev/kmsg")

    if not api_init() then return end
    if isIB() then return end -- IB mode do nothing

    local result = response_mock()
    shell_cmd('echo \'1\' > /sys/class/apro-ctrl/aproctrl/spiswitch')

    result['code'] = 0
    result['message'] = 'Remote PC'
    result['data'] = 'Flash was connected with 8117'
    luci.http.prepare_content('application/json')
    luci.http.write_json(result)
end

function probe_bios_flash_asus()
    shell_cmd("echo \"[APRO][WEB] probe_bios_flash\" > /dev/kmsg")

    if not api_init() then return end

    local result = response_mock()

    luci.sys.exec('echo 1 > /proc/spi1/install')
    local npart = shell_cmd('cat /proc/mtd | grep BIOS | wc -l')
    npart = tonumber(npart)
    result['data']['npart'] = npart

    if npart == 16 then
       result['message'] = 'probe BIOS flash Success'
    else
       result['code'] = -1
       result['message'] = 'probe BIOS flash Fail'
    end

    luci.http.prepare_content('application/json')
    luci.http.write_json(result)

end

function remove_bios_flash_asus()
    shell_cmd("echo \"[APRO][WEB] remove_bios_flash\" > /dev/kmsg")

    if not api_init() then return end

    local result = response_mock()
    luci.sys.exec('echo 0 > /proc/spi1/install')
    local npart = shell_cmd('cat /proc/mtd | grep BIOS | wc -l')
    npart = tonumber(npart)
    result['data']['npart'] = npart

    if npart == 0 then
       result['message'] = 'remove BIOS flash Success'
    else
       result['code'] = -1
       result['message'] = 'remove BIOS flash Fail'
    end

    luci.http.prepare_content('application/json')
    luci.http.write_json(result)

end

function descriptor_asus()
    shell_cmd("echo \"[APRO][WEB] descriptor\" > /dev/kmsg")

    require "luci.tools.webadmin"

    local result = {
        ['Function_list'] = {},
        ['Asus_api'] = {},
        ['System'] = {},
        ['Memory'] = {}
    }

    local sysinfo = luci.util.ubus("system", "info") or { }
    local boardinfo = luci.util.ubus("system", "board") or { }
    local unameinfo = nixio.uname() or { }

    result['Function_list']={"Registered/Get stock", "Set password", "Get info", "Get/Download dxe info", "Upload/Download file", "Watchdog", "Gpio control", "Function status", "Test", "Get PC status", "Power on/off PC", "Force power off PC", "Clear cmos", "Reboot PC", "Switch spi to PC/8117", "Probe/Remove bios flash", "Clean ring buffer", "Descriptor", "Get device information", "Stop/Restart Service", "Upgrade FW/Safemode", "Check kernel mode", "Uart module", "Set IP", "Upgrade FW for factory", "KVM", "USB-R", "RMA record", "Clear backup/stok", "Get/Set kvm and usbr status", "Get GOP Status", "Recovery Backup", "KVM Display Mode", "dmesg", "Trust_Zone", "Get/Set machine name", "Get/Set misc"}

    result['Asus_api']={"init_check", "get_stok", "reg_stok", "set_psw", "get_info", "get_dxe_info", "download_dxe", "upload", "upload.htm", "upload_file", "upload.web", "download", "wd_enable", "wd_set_timer", "wd_set_interval", "gpio_op", "function_status", "test", "get_pcstate", "power_on_pc", "power_off_pc", "clear_cmos", "reboot_pc", "switch_spi_to_pc", "switch_spi_to_8117", "probe_bios_flash", "remove_bios_flash", "descriptor", "get_device_info", "clean_ring_buffer", "stop_service", "restart_service", "restart_wsmand", "upgrade_fw", "upgrade_safemode", "check_mode", "uart_module", "set_ip", "factory_upload", "factory_setenv", "push_rma", "dump_rma", "clear_backup", "clear_stok", "get_kvm_usbr", "set_kvm_usbr", "get_gop_status", "recovery_backup", "get_kvm_display", "set_kvm_display", "dmesg", "get_firewall_mode", "set_firewall_mode", "get_firewall_ip", "set_firewall_ip", "get_machine_name", "set_machine_name", "get_misc", "set_misc"}

    result['System']['Hostname'] = luci.sys.hostname() or "?"
    result['System']['Model'] = boardinfo.model or boardinfo.system or "?"
    result['System']['UUID'] = shell_cmd('cat /etc/bios_uuid')
    result['System']['uPath'] = shell_cmd('cat /etc/uPath')
    result['System']['modelname'] = shell_cmd('cat /etc/modelname | grep -v fiRewalL | grep -v MaChInEnAmE')
    result['System']['machinename'] = shell_cmd('cat /etc/machinename')
    result['System']['CPU'] = shell_cmd('cat /proc/cpuinfo | grep "model"|wc -l')
    result['System']['Firmware Version'] = shell_cmd('cat /etc/version.txt |grep FWVER |sed s/FWVER=//g')
    result['System']['kernel'] = shell_cmd('cat /etc/version.txt |grep KERNEL |sed s/^.*=//g | sed s/-.*$//g')
    result['System']['U-Boot'] = shell_cmd('cat /etc/version.txt |grep U-Boot |sed s/U-Boot=//g')
    local local_time = os.time()
    result['System']['Local Time'] = os.date("%Y-%b-%d %a %X", local_time)
    result['System']['Uptime'] = luci.tools.webadmin.date_format(tonumber(sysinfo.uptime or 0))
    result['System']['Load Average'] = string.format('%.02f, %.02f, %.02f',sysinfo.load[1]/65535.0
    ,sysinfo.load[2]/65535.0
    ,sysinfo.load[3]/65535.0 )

    local is_mnt = shell_cmd("mount | grep /dev/mtdblock14 | wc -l")
    if is_mnt == '0' then
        result['System']['bStatus'] = os.date("%H", local_time) + os.date("%M", local_time) + os.date("%S", local_time) + 4
    else
        local bstatus = shell_cmd("cat /etc/shadow | grep bstatus | awk -F \":\" '{print $2}'")
        result['System']['bStatus'] = os.date("%H", local_time) + os.date("%M", local_time) + os.date("%S", local_time) + tonumber(bstatus)
    end

    result['Memory']['Total'] = (sysinfo.memory.total / 1024) .. " kB"
    result['Memory']['Total Available'] = ((sysinfo.memory.free + sysinfo.memory.buffered) / 1024) .. " kB"
    result['Memory']['Free'] = (sysinfo.memory.free / 1024) .. " kB"
    result['Memory']['Buffered'] = (sysinfo.memory.buffered / 1024) .. " kB"

    luci.http.prepare_content("application/json")
    -- post processing ...

    luci.http.write_json(result)

end

function get_device_info_asus()
    shell_cmd("echo \"[APRO][WEB] get_device_info\" > /dev/kmsg")

    local result = {}
    local boardinfo = luci.util.ubus("system", "board") or { }

    result['Model'] = boardinfo.model or "?"
    result['UUID'] = shell_cmd('cat /etc/bios_uuid')
    result['uPath'] = shell_cmd('cat /etc/uPath')
    result['modelname'] = shell_cmd('cat /etc/modelname | grep -v fiRewalL | grep -v MaChInEnAmE')
    result['machinename'] = shell_cmd('cat /etc/machinename')

    luci.http.prepare_content("application/json")
    luci.http.write_json(result)

end

function download_dxe_asus()
    shell_cmd("echo \"[APRO][WEB] download_dxe\" > /dev/kmsg")

    if not api_init() then return end

    local result = response_mock()

    dxe_status = shell_cmd("cat /tmp/dxe_status")

    if (dxe_status == "1") then
        result['message'] = 'dxe data is dumping......'
        luci.http.prepare_content('application/json')
        luci.http.write_json(result)
        return
    elseif (dxe_status == "0") then
        shell_cmd("echo 1 > /tmp/dxe_status")
        shell_cmd("/usr/local/sbin/dxe-dump 0.0.0.0") -- dump ring buffer to /tmp/dxe
    end

    while (dxe_status ~= "2") do
        dxe_status = shell_cmd("cat /tmp/dxe_status")
    end

    if (dxe_status == "2") then
        local the_mime = get_mime("download")
        luci.http.header("Content-Disposition","attachment; filename=\"dxe_info.dat\"")
        luci.http.prepare_content(the_mime)

        filename = '/tmp/dxe_info.dat'
        local size = g_buffer_size
        local file = io.open(filename,"rb")
        while true do
            local block
            block = file:read(size)
            if not block then break end
            luci.http.write(block)
        end

        file:close()
        shell_cmd("rm /tmp/dxe_info.dat")
        shell_cmd("echo 0 > /tmp/dxe_status")
    end

end

function clean_ring_buffer_asus()
    shell_cmd("echo \"[APRO][WEB] clean_ring_buffer\" > /dev/kmsg")
    if not api_init() then return end
    if isIB() then return end -- IB mode do nothing

    local result = response_mock()

    shell_cmd("rm /tmp/dxe_info.dat")
    shell_cmd("/usr/local/sbin/dxe-clean 0.0.0.0")

    result['code'] = 0
    result['message'] = 'Clean ring buffer of RTL8117'
    result['data'] = 'power on'
    luci.http.prepare_content('application/json')
    luci.http.write_json(result)
end

function upload_file_asus()
    shell_cmd("echo \"[APRO][WEB] upload_file\" > /dev/kmsg")
   if not api_init() then return end

   local fp, path, filename

   luci.http.setfilehandler(
   function(meta, chunk, eof) -- meta.file : the filename, meta.name : <input type=\"file\" name=\"upload\>  (upload)
       if not meta then
           luci.http.write("no upload file")
           return
       end

       if not fp then
           filename = meta.file
           if filename ~= nil then
               fp = io.open('/tmp/' .. filename, "w")
           else
               fp = io.open('/tmp/' .. 'upload_file', "w")
           end
       end

       if chunk then
           fp:write(chunk)
       end

       if eof then
           fp:close()
           luci.http.write("Upload file done.")
       end
   end
   )

   local upload = luci.http.formvalue("upload")
   luci.http.prepare_content('application/json')
end

function upload_web_asus()
   if not api_init() then return end

   luci.http.prepare_content("text/html")
   luci.http.write("<h1>upload file</h1>")
   luci.http.write("<form action=\"upload_file\" method=\"post\" enctype=\"multipart/form-data\">")
   luci.http.write("<input type=\"file\" name=\"upload_file\" /><br>")
   luci.http.write("<input type=\"submit\" name=\"upload_file\" value=\"submit\" />")
   luci.http.write("</form>")
end

function stop_service_asus()
    shell_cmd("echo \"[APRO][WEB] stop_services\" > /dev/kmsg")

    if not api_init() then return end

    local result = response_mock()

    require "nixio"
    http_headers = nixio.getenv()
    param = http_headers['QUERY_STRING']
    service = param:match("service=(.*)")

    if service == "wsmand" then
        os.execute("/etc/init.d/wsmand stop >/dev/null")
        result['message'] = "stop wsmand and vnc"
    elseif service == "dxeagent" then
        os.execute("killall dxe-agent >/dev/null")
        result['message'] = "stop dxe-agent"
    elseif service == "watchdog" then
        os.execute("killall rtl8117_wdt >/dev/null")
        os.execute("echo 0 > /etc/rtl8117_wdog/wdog_enable")
        result['message'] = "stop watchdog"
    elseif service == "smbus" then
        os.execute("/etc/init.d/smbus stop >/dev/null")
        os.execute("killall smbus >/dev/null")
        result['message'] = "stop smbus"
    else
        os.execute("killall wsmand >/dev/null")
        os.execute("killall dxe-agent >/dev/null")
        os.execute("/etc/init.d/smbus stop >/dev/null")
        os.execute("killall smbus >/dev/null")
        result['message'] = "stop services"
    end

    shell_cmd("sync;sync;sync;")
    shell_cmd("echo 3 > /proc/sys/vm/drop_caches")

    luci.http.prepare_content('application/json')
    luci.http.write_json(result)
end

function restart_service_asus()
    shell_cmd("echo \"[APRO][WEB] restart_service\" > /dev/kmsg")

    if not api_init() then return end

    local result = response_mock()

    require "nixio"
    http_headers = nixio.getenv()
    param = http_headers['QUERY_STRING']
    service = param:match("service=(.*)")

    local pgrep_wsmand = shell_cmd("pgrep wsmand | wc -l")
    local pgrep_dxe = shell_cmd("pgrep /usr/local/sbin/dxe-agent | wc -l")
    local pgrep_watchdog = shell_cmd("pgrep /usr/local/sbin/rtl8117_wdt | wc -l")
    local pgrep_smbus = shell_cmd("pgrep /bin/smbus | wc -l")

    if service == "wsmand" then
        if (pgrep_wsmand == '1') then
            result['code'] = -1
            result['message'] = "Please check if wsmand is stopped"
        else
            os.execute("service wsmand restart")
            result['message'] = "restart wsmand"
        end
    elseif service == "dxeagent" then
        if (pgrep_dxe == '1') then
            result['code'] = -1
            result['message'] = "Please check if dxe-agent is stopped"
        else
            os.execute("/usr/local/sbin/dxe-agent &")
            result['message'] = "restart dxe-agent"
        end
    elseif service == "watchdog" then
        if (pgrep_watchdog == '1') then
            result['code'] = -1
            result['message'] = "Please check if watchdog is stopped"
        else
            os.execute("/usr/local/sbin/rtl8117_wdt &")
            result['message'] = "restart watchdog"
        end
    elseif service == "smbus" then
        if (pgrep_smbus == '1') then
            result['message'] = "Please check if smbus is stopped"
        else
            os.execute("service smbus start &")
            result['message'] = "restart smbus"
        end
    else
        if (pgrep_wsmand == '1' or pgrep_dxe == '1' or pgrep_smbus == '1') then
            result['code'] = -1
            result['message'] = "Please check if services is stopped"
        else
            os.execute("service wsmand restart")
            os.execute("/usr/local/sbin/dxe-agent &")
            os.execute("service smbus start &")
            result['message'] = "restart services"
        end
    end

    luci.http.prepare_content('application/json')
    luci.http.write_json(result)
end

function check_signature(image_path)
    shell_cmd("echo \"[APRO][WEB] check_signature\" > /dev/kmsg")
    local signature = shell_cmd("dd if=%s of=/tmp/signature bs=1 skip=768 count=256 ; cat /tmp/signature" %{image_path} )
    shell_cmd("sync;sync;sync;")
    shell_cmd("echo 3 > /proc/sys/vm/drop_caches")
    local md5_chk = shell_cmd("dd if=%s bs=1024 skip=1 2>/dev/null | md5sum - | sed 's/  -//g'" %{image_path} )
    shell_cmd("sync;sync;sync;")
    shell_cmd("echo 3 > /proc/sys/vm/drop_caches")
    local result = 1
    shell_cmd("echo %s > /tmp/onlineckimg.md5" %{md5_chk})
    result = luci.sys.call("/usr/local/sbin/verifyimg")

    if result ~= 0 then
        shell_cmd("rm %s" %{image_path})
    end
    shell_cmd("rm /tmp/onlineckimg.md5")

    shell_cmd("rm /tmp/onlineckimg.md5")
    shell_cmd("rm /tmp/signature")
    shell_cmd("sync;sync;sync;")
    shell_cmd("echo 3 > /proc/sys/vm/drop_caches")

    return result
end

function check_image(image_path)
    shell_cmd("echo \"[APRO][WEB] check_image\" > /dev/kmsg")
    local image_check = 0
    local md5_img = shell_cmd("dd if=%s of=/tmp/img_chk bs=2 count=16 ; cat /tmp/img_chk" %{image_path} )
    shell_cmd("sync;sync;sync;")
    shell_cmd("echo 3 > /proc/sys/vm/drop_caches")
    local md5_chk = shell_cmd("dd if=%s bs=1024 skip=1 2>/dev/null | md5sum - | sed 's/  -//g'" %{image_path} )
    shell_cmd("sync;sync;sync;")
    shell_cmd("echo 3 > /proc/sys/vm/drop_caches")
    if (md5_img == md5_chk) then
        image_check = 1
    else
        shell_cmd("rm " .. image_path)
        shell_cmd("sync;sync;sync;")
        shell_cmd("echo 3 > /proc/sys/vm/drop_caches")
    end
    shell_cmd("rm /tmp/img_chk")
    shell_cmd("sync;sync;sync;")
    shell_cmd("echo 3 > /proc/sys/vm/drop_caches")

    return image_check
end

function upgrade_fw_asus()
    shell_cmd("echo \"[APRO][WEB] upgrade_fw\" > /dev/kmsg")
    if not api_init() then return end
    if isIB() then return end -- IB mode do nothing

    local fs  = require "nixio.fs"

    local image_avl = 0
    local result = response_mock()
    local uboot_img = "/tmp/normalmode_uboot.bin"
    local kernel_img = "/tmp/normalmode_kernel.img"
    local fw_img = "/tmp/openwrt-rtl8117-factory-bootcode.img"
    local ck_sign_status = 1

    -- check if /mnt/aproData is work
    local is_mnt = shell_cmd("mount | grep /dev/mtdblock14 | wc -l")
    if is_mnt == '0' then
      shell_cmd("echo \"[APRO][Backup] backup system is broken\" > /dev/kmsg")
      shell_cmd("mtd erase /dev/mtd14")
      shell_cmd("dd if=/dev/zero of=/tmp/aproData bs=1K count=64")
      shell_cmd("mkfs.ext2 /tmp/aproData")
      shell_cmd("mtd write /tmp/aproData /dev/mtd14")
      shell_cmd("mount -t ext2 /dev/mtdblock14 /mnt/aproData")

      shell_cmd("rm /tmp/aproData")
    end

    shell_cmd("cp -p /etc/shadow /mnt/aproData/shadow; sync")
    shell_cmd("cp -p /etc/wsmand/account /mnt/aproData/account; sync")
    shell_cmd("cp -p /etc/bios_uuid /mnt/aproData/bios_uuid; sync")
    shell_cmd("cp -p /etc/uPath /mnt/aproData/uPath; sync")
    shell_cmd("/usr/local/sbin/backup_userdata.sh")
    shell_cmd("sync;sync;sync")
    shell_cmd("echo 3 > /proc/sys/vm/drop_caches")

    -- Start sysupgrade flash
    if fs.access(uboot_img) then
        ck_sign_status = check_signature(uboot_img)
        if ck_sign_status ~= 0 then
            result['code'] = -1
            result['message'] = 'This is not ASUS offical image , error ['..ck_sign_status..'] !'
            luci.http.prepare_content('application/json')
            luci.http.write_json(result)
            return
        end
        image_avl = check_image(uboot_img)
        if image_avl == 1 then
            shell_cmd("echo 0 > /sys/class/apro-ctrl/aproctrl/rtl8117_ready")
            shell_cmd("dd if=%s bs=1024 count=64 skip=1 | mtd write - /dev/mtd2" %{uboot_img})    -- CONF
            shell_cmd("dd if=%s bs=1024 count=384 skip=65 | mtd write - /dev/mtd3" %{uboot_img})  -- U-Boot
            shell_cmd("dd if=%s bs=1024 count=64 skip=449 | mtd write - /dev/mtd4" %{uboot_img})  -- DTB
            shell_cmd("reboot")
            result['message'] = 'upgrade uboot ...'
        else
            result['code'] = -1
            result['message'] = 'invalid uboot image'
        end
    elseif fs.access(kernel_img) then
        ck_sign_status = check_signature(kernel_img)
        if ck_sign_status ~= 0 then
            result['code'] = -1
            result['message'] = 'This is not ASUS offical image , error ['..ck_sign_status..'] !'
            luci.http.prepare_content('application/json')
            luci.http.write_json(result)
            return
        end
        -- check kernel image by /sbin/sysupgrade
        shell_cmd("echo 0 > /sys/class/apro-ctrl/aproctrl/rtl8117_ready")
        shell_cmd("killall vncs && sleep 1 && killall dropbear uhttpd; sleep 1; /sbin/sysupgrade -n %s" %{kernel_img})
        result['message'] = 'upgrade kernel ...'
    elseif fs.access(fw_img) then
        ck_sign_status = check_signature(fw_img)
        if ck_sign_status ~= 0 then
            result['code'] = -1
            result['message'] = 'This is not ASUS offical image , [error:'..ck_sign_status..'] !'
            luci.http.prepare_content('application/json')
            luci.http.write_json(result)
            return
        end
        shell_cmd("echo 0 > /sys/class/apro-ctrl/aproctrl/rtl8117_ready")
        shell_cmd("killall vncs && sleep 1 && killall dropbear uhttpd; sleep 1; /sbin/sysupgrade -n %s" %{fw_img})
        result['message'] = 'upgrade fw ...'
    else
        result['code'] = -1
        result['message'] = 'image dose not exist.'
    end

    luci.http.prepare_content('application/json')
    luci.http.write_json(result)
end

function upgrade_safemode_asus()
    shell_cmd("echo \"[APRO][WEB] upgrade_safemode\" > /dev/kmsg")
    if not api_init() then return end
    if isIB() then return end -- IB mode do nothing

    require "nixio"
    local fs = require "nixio.fs"
    local image_avl = 0
    local result = response_mock()
    local safemode_img = "/tmp/safemode.img"
    local ck_sign_status = 1

    http_headers = nixio.getenv()
    param = http_headers['QUERY_STRING']
    upgrade_partition = param:match("upgrade=(.*)")

    ck_sign_status = check_signature(safemode_img)
    if ck_sign_status ~= 0 then
        result['code'] = -1
        result['message'] = 'This is not ASUS offical image , error ['..ck_sign_status..'] !'
        luci.http.prepare_content('application/json')
        luci.http.write_json(result)
        return
    end
    image_avl = check_image(safemode_img)
    -- Start sysupgrade flash
    if fs.access(safemode_img) then
        if image_avl == 1 then
            shell_cmd("sync;sync;sync")
            shell_cmd("echo 3 > /proc/sys/vm/drop_caches")
            if upgrade_partition == "all" then
                shell_cmd("killall vncs && sleep 1")
                shell_cmd("mtd erase /dev/mtd9 ; mtd erase /dev/mtd10; mtd erase /dev/mtd11; mtd erase /dev/mtd12")
                shell_cmd("dd if=%s bs=1024 count=64 skip=1 | mtd write - /dev/mtd9" %{safemode_img})  -- bDTB
                shell_cmd("sync;sync;sync")
                shell_cmd("echo 3 > /proc/sys/vm/drop_caches")
                shell_cmd("dd if=%s bs=1024 count=1920 skip=65 | mtd write - /dev/mtd10" %{safemode_img})  -- bLinux
                shell_cmd("sync;sync;sync")
                shell_cmd("echo 3 > /proc/sys/vm/drop_caches")
                shell_cmd("dd if=%s bs=1024 count=3584 skip=1985 | mtd write - /dev/mtd11" %{safemode_img})  -- brootfs
                shell_cmd("sync;sync;sync")
                shell_cmd("echo 3 > /proc/sys/vm/drop_caches")
                shell_cmd("dd if=%s bs=1024 count=1984 skip=5569 | mtd write - /dev/mtd12" %{safemode_img})  -- bdata
                shell_cmd("sync;sync;sync")
                shell_cmd("echo 3 > /proc/sys/vm/drop_caches")
                result['message'] = 'upgrade safemode image'
            elseif upgrade_partition == "dtb" then
                shell_cmd("killall vncs && sleep 1")
                shell_cmd("mtd erase /dev/mtd9")
                shell_cmd("dd if=%s bs=1024 count=64 skip=1 | mtd write - /dev/mtd9" %{safemode_img})  -- bDTB
                shell_cmd("sync;sync;sync")
                shell_cmd("echo 3 > /proc/sys/vm/drop_caches")
                result['message'] = 'upgrade safemode dtb'
            elseif upgrade_partition == "kernel" then
                shell_cmd("killall vncs && sleep 1")
                shell_cmd(" mtd erase /dev/mtd10; mtd erase /dev/mtd11; mtd erase /dev/mtd12")
                shell_cmd("dd if=%s bs=1024 count=1920 skip=65 | mtd write - /dev/mtd10" %{safemode_img})  -- bLinux
                shell_cmd("sync;sync;sync")
                shell_cmd("echo 3 > /proc/sys/vm/drop_caches")
                shell_cmd("dd if=%s bs=1024 count=3584 skip=1985 | mtd write - /dev/mtd11" %{safemode_img})  -- brootfs
                shell_cmd("sync;sync;sync")
                shell_cmd("echo 3 > /proc/sys/vm/drop_caches")
                shell_cmd("dd if=%s bs=1024 count=1984 skip=5569 | mtd write - /dev/mtd12" %{safemode_img})  -- bdata
                shell_cmd("sync;sync;sync")
                shell_cmd("echo 3 > /proc/sys/vm/drop_caches")
                result['message'] = 'upgrade safemode kernel'
            else
                result['code'] = -1
                result['message'] = 'upgrade partition not given'
            end
        else
            result['code'] = -1
            result['message'] = 'invalid safemode image'
        end
    else
        result['code'] = -1
        result['message'] = 'image dose not exist.'
    end

    luci.http.prepare_content('application/json')
    luci.http.write_json(result)
end

function check_mode_asus()
    shell_cmd("echo \"[APRO][WEB] check_mode\" > /dev/kmsg")

    if not api_init() then return end

    local result = response_mock()
    local mode = shell_cmd('cat /proc/mtd | grep brootfs | wc -l')

    if (mode == "1") then
        result['data'] = 'Normal Mode'
    else
        result['data'] = 'Safemode Mode'
    end

    luci.http.prepare_content('application/json')
    luci.http.write_json(result)
end

function uart_module_asus()
    shell_cmd("echo \"[APRO][WEB] uart_module\" > /dev/kmsg")

    if not api_init() then return end

    require "nixio"

    local result = response_mock()

    http_headers = nixio.getenv()
    param = http_headers['QUERY_STRING']
    func = param:match("option=(.*)")

    -- UART Enable
    if func == "enable" then
        shell_cmd('fw_setenv uartcfg enable')
        getResult = shell_cmd('fw_printenv | grep uartcfg')

        if getResult == 'uartcfg=enable' then
            result['message'] = 'uart will be enabled after rtl8117 rest'
        else
            result['code'] = -1
            result['message'] = 'It is fail'
        end
    -- UART Disable
    elseif func == "disable" then
        shell_cmd('fw_setenv uartcfg disable')
        getResult = shell_cmd('fw_printenv | grep uartcfg')
        if getResult == 'uartcfg=disable' then
            result['message'] = 'uart will be disabled after rtl8117 rest'
        else
            result['code'] = -1
            result['message'] = 'It is fail'
        end
    -- Other options
    else
        getResult = shell_cmd('fw_printenv | grep uartcfg | wc -l')
        result['code'] = -1

        if getResult == '0' then
            result['message'] = 'uart is not changing and uartcfg setting is empty'
        else
            getResult = shell_cmd('fw_printenv | grep uartcfg')
            result['message'] = 'uart is not changing and '..getResult..' !'
        end
    end

    luci.http.prepare_content('application/json')
    luci.http.write_json(result)
end

function set_ip_asus()
    shell_cmd("echo \"[APRO][WEB] set_ip\" > /dev/kmsg")
    if not api_init() then return end

    local result = response_mock()
    require "nixio"
    http_headers = nixio.getenv()
    param = http_headers['QUERY_STRING']
    ip = param:match("ip=(.*)")

    shell_cmd("ifconfig eth0 %s" %{ip})

    result['data'] = ip
    result['message'] = 'set ip'
    luci.http.prepare_content('application/json')
    luci.http.write_json(result)
end

function factory_upload_asus()
    shell_cmd("echo \"[APRO][WEB] factory_upload\" > /dev/kmsg")
    if not api_init() then return end

    shell_cmd('cat /sys/class/apro-ctrl/aproctrl/upload')
    local result = response_mock()
    local fp, path, filename

    luci.http.setfilehandler(
    function(meta, chunk, eof) -- meta.file : the filename, meta.name : <input type=\"file\" name=\"upload\>  (upload)
        if not meta then
            result['code'] = -1
            result['message'] = 'no upload file'
            luci.http.prepare_content('application/json')
            luci.http.write_json(result)
            return
        end

        if not fp then
            filename = meta.file
            if filename ~= nil then
                fp = io.open('/tmp/' .. filename, "w")
            else
                fp = io.open('/tmp/' .. 'upload_file', "w")
            end
        end

        if chunk then
            fp:write(chunk)
        end

        if eof then
            fp:close()
            result['message'] = 'Upload file done.'
        end
    end
    )

    local upload = luci.http.formvalue("upload")

    local ck_sign_status = 1

    ck_sign_status = check_signature('/tmp/' .. filename)
    if ck_sign_status ~= 0 then
        result['code'] = -1
        result['message'] = 'This is not ASUS offical image , error ['..ck_sign_status..'] !'
        luci.http.prepare_content('application/json')
        luci.http.write_json(result)
        return
    end
    local image_avl = check_image('/tmp/' .. filename)
    if image_avl == 1 then
        result['message'] = 'Valid image'
    else
        result['code'] = -1
        result['message'] = 'Invalid image'
    end

    shell_cmd('cat /sys/class/apro-ctrl/aproctrl/upload')
    luci.http.prepare_content('application/json')
    luci.http.write_json(result)
end

function factory_setenv_asus()
    shell_cmd("echo \"[APRO][WEB] factory_setenv\" > /dev/kmsg")
    if not api_init() then return end

    local result = response_mock()

    shell_cmd("ps | grep factory_upgrade | grep -v grep | awk '{print $1}' | xargs kill")

    shell_cmd('fw_setenv factory_boot enable')
    getResult = shell_cmd('fw_printenv | grep factory_boot')
    if getResult == 'factory_boot=enable' then
        result['message'] = 'set factory upgrade ok'
        io.popen('/usr/local/sbin/factory_upgrade_fw.sh &')
    else
        result['code'] = -1
        result['message'] = 'set factory upgrade failed'
    end

    luci.http.prepare_content('application/json')
    luci.http.write_json(result)
end

function push_rma_asus()
    shell_cmd("echo \"[APRO][WEB] push_rma\" > /dev/kmsg")
    if not api_init() then return end

    local result = response_mock()

    local fp, path, filename

    luci.http.setfilehandler(
    function(meta, chunk, eof) -- meta.file : the filename, meta.name : <input type=\"file\" name=\"upload\>  (upload)
        if not meta then
            result['code'] = -1
            result['message'] = 'No upload file'
            luci.http.prepare_content('application/json')
            luci.http.write_json(result)
            return
        end

        if not fp then
            filename = meta.file
            fp = io.open('/tmp/' .. 'RMA', "w")
        end

        if chunk then
            fp:write(chunk)
        end

        if eof then
            fp:close()
        end
    end
    )

    local upload = luci.http.formvalue("upload")

    local r = os.execute('/usr/local/sbin/push_RMA.sh')

    if (r ~= 0) then
        result['code'] = -1
        result['message'] = 'Upload RMA file fail: ' .. r
    else
        result['message'] = 'Upload RMA file done'
    end

    luci.http.prepare_content('application/json')
    luci.http.write_json(result)
end

function dump_rma_asus()
    shell_cmd("echo \"[APRO][WEB] dump_rma\" > /dev/kmsg")

    if not api_init() then return end

    shell_cmd("dd if=/dev/mtd13 of=/tmp/RMA.dat bs=64K count=1")

    local the_mime = get_mime("download")
    luci.http.header("Content-Disposition","attachment; filename=\"RMA.dat\"")
    luci.http.prepare_content(the_mime)

    filename = '/tmp/RMA.dat'
    local size = g_buffer_size
    local file = io.open(filename,"rb")
    while true do
        local block
        block = file:read(size)
        if not block then break end
        luci.http.write(block)
    end

    file:close()

    shell_cmd("rm /tmp/RMA.dat")
    shell_cmd("sync;sync;sync")
    shell_cmd("echo 3 > /proc/sys/vm/drop_caches; sync")

end

function clear_backup_asus()
    shell_cmd("echo \"[APRO][WEB] clear_backup\" > /dev/kmsg")

    if not api_init() then return end

    local result = response_mock()

    shell_cmd("rm /mnt/aproData/bios_uuid; sync")
    shell_cmd("rm /mnt/aproData/shadow; sync")
    shell_cmd("rm /mnt/aproData/account; sync")
    shell_cmd("rm /mnt/aproData/uPath; sync")
    shell_cmd("rm /mnt/aproData/modelname; sync")

    shell_cmd("sync");

    result['message'] = 'Clear Backup File'

    luci.http.prepare_content('application/json')
    luci.http.write_json(result)

end

function clear_stok_asus()
    shell_cmd("echo \"[APRO][WEB] clear_stok\" > /dev/kmsg")

    if not api_init() then return end

    local result = response_mock()

    shell_cmd("rm %s" %{stok_appuid_map})
    shell_cmd("rm -rf /tmp/token.dat")
    shell_cmd("sync;sync;sync")
    shell_cmd("echo 3 > /proc/sys/vm/drop_caches; sync")

    result['message'] = 'Clear Stok'

    luci.http.prepare_content('application/json')
    luci.http.write_json(result)

end

function clear_psw_asus()
    shell_cmd("echo \"[APRO][WEB] clear_psw\" > /dev/kmsg")
    if not api_init() then return end

    local result = response_mock()

    shell_cmd("/usr/local/sbin/clearpsw.sh")

    result['message'] = 'Clear Password'

    luci.http.prepare_content('application/json')
    luci.http.write_json(result)
end

function get_kvm_usbr_asus()
    shell_cmd("echo \"[APRO][WEB] get_kvm_usbr\" > /dev/kmsg")

    if not api_init() then return end

    local result = response_mock()
    require "nixio"
    http_headers = nixio.getenv()
    param = http_headers['QUERY_STRING']
    status = param:match("get=(.*)")

    if status == "kvm" then
        local kvm_status = shell_cmd('cat /sys/class/apro-ctrl/aproctrl/kvm')
        result['data'] = kvm_status
        result['message'] = 'KVM'
    elseif status == "usbr" then
        local usbr_status = shell_cmd('cat /sys/class/apro-ctrl/aproctrl/usbr')
        result['data'] = usbr_status
        result['message'] = 'USB-R'
    else
        result['code'] = -1
        result['message'] = 'get should be kvm or usbr.'
    end


    luci.http.prepare_content('application/json')
    luci.http.write_json(result)
end

function set_kvm_usbr_asus()
    shell_cmd("echo \"[APRO][WEB] set_kvm_usbr\" > /dev/kmsg")

    if not api_init() then return end

    local result = response_mock()
    require "nixio"
    http_headers = nixio.getenv()
    param = http_headers['QUERY_STRING']
    status = param:match("set=(.*)")

    if status == "kvmon" then
        shell_cmd('echo 1 > /tmp/kvm')
        result['message'] = 'KVM on'
    elseif status == "kvmoff" then
        shell_cmd('echo 0 > /tmp/kvm')
        result['message'] = 'KVM off'
    elseif status == "usbron" then
        shell_cmd('echo 1 > /tmp/usbr')
        result['message'] = 'USB-R on'
    elseif status == "usbroff" then
        shell_cmd('echo 0 > /tmp/usbr')
        result['message'] = 'USB-R off'
    else
        result['code'] = -1
        result['message'] = "set should be one of them. (kvmon, kvmoff, usbron, usbron)"
    end

    luci.http.prepare_content('application/json')
    luci.http.write_json(result)
end

function get_kvm_display_asus()
    shell_cmd("echo \"[APRO][WEB] get_kvm_display\" > /dev/kmsg")

    if not api_init() then return end

    local result = response_mock()

    local bit = require "nixio".bit
    local mode = shell_cmd('cat /tmp/kvm_display')

    result['data'] = string.format("0x%02x", mode)
    result['message'] = 'KVM Display Mode'

    luci.http.prepare_content('application/json')
    luci.http.write_json(result)
end

function set_kvm_display_asus()
    shell_cmd("echo \"[APRO][WEB] set_kvm_display\" > /dev/kmsg")

    if not api_init() then return end

    local result = response_mock()

    if luci.http.formvalue("mode") then
        mode = luci.http.formvalue("mode")
        mode = tonumber(mode)
        result['message'] = "Set kvm display to "..mode
        -- when sw setting display mode, the bit 8 should be setting.
        local bit = require "nixio".bit
        mode = bit.set(mode, bit.lshift(1, 7))
        shell_cmd('echo '..mode..' > /tmp/kvm_display')
        shell_cmd('echo '..mode..' > /sys/class/apro-ctrl/aproctrl/kvm_display')
    else
        result['code'] = -1
        result['message'] = "mode argument not provided"
    end

    luci.http.prepare_content('application/json')
    luci.http.write_json(result)
end

function get_gop_status_asus()
    shell_cmd("echo \"[APRO][WEB] get_gop_status\" > /dev/kmsg")

    if not api_init() then return end
    local result = response_mock()

    gop = shell_cmd('cat /sys/devices/virtual/apro-ctrl/aproctrl/gop')
    if gop == "0" then
        result['message'] = 'GOP ONGOING'
    else
        result['message'] = 'GOP STALLED'
    end

    luci.http.prepare_content('application/json')
    luci.http.write_json(result)

end

function recovery_backup_asus()
    shell_cmd("echo \"[APRO][WEB] recovery_backup\" > /dev/kmsg")

    if not api_init() then return end
    local result = response_mock()

    local is_mnt = shell_cmd("mount | grep /dev/mtdblock14 | wc -l")
    if is_mnt == '0' then
        shell_cmd("echo \"[APRO][Backup] backup system is broken\" > /dev/kmsg")
        shell_cmd("mtd erase /dev/mtd14")
        shell_cmd("dd if=/dev/zero of=/tmp/aproData bs=1K count=64")
        shell_cmd("mkfs.ext2 /tmp/aproData")
        shell_cmd("mtd write /tmp/aproData /dev/mtd14")
        shell_cmd("mount -t ext2 /dev/mtdblock14 /mnt/aproData")

        shell_cmd("rm /tmp/aproData")

        result['message'] = 'Disk was broken, and it is recovery now!'
    else
        result['message'] = 'Backup to disk'
    end

    shell_cmd("cp -p /etc/shadow /mnt/aproData/shadow; sync")
    shell_cmd("cp -p /etc/wsmand/account /mnt/aproData/account; sync")
    shell_cmd("cp -p /etc/bios_uuid /mnt/aproData/bios_uuid; sync")
    shell_cmd("cp -p /etc/uPath /mnt/aproData/uPath; sync")
    shell_cmd("/usr/local/sbin/backup_userdata.sh")

    shell_cmd("sync;sync;sync")
    shell_cmd("echo 3 > /proc/sys/vm/drop_caches")
    shell_cmd("sync");

    luci.http.prepare_content('application/json')
    luci.http.write_json(result)
end

function dmesg_asus()
    shell_cmd("echo \"[APRO][WEB] dmesg\" > /dev/kmsg")

    if not api_init() then return end
    local result = response_mock()

    filename = '/tmp/dmesg'

    local dmesg = luci.sys.dmesg()

    local file = io.open(filename,"wb")
    file:write(dmesg)
    file:close()

    local the_mime = get_mime("download")
    luci.http.header("Content-Disposition","attachment; filename=\"dmesg.log\"")
    luci.http.prepare_content(the_mime)

    local size = g_buffer_size
    local file = io.open(filename,"rb")
    while true do
        local block
        block = file:read(size)
        if not block then break end
        luci.http.write(block)
    end

    file:close()

    shell_cmd("rm /tmp/dmesg")
    shell_cmd("sync;sync;sync")
    shell_cmd("echo 3 > /proc/sys/vm/drop_caches; sync")

end

function set_misc_flag(misc_index, misc_flag, misc_value)

    local bit = require "nixio".bit

    local flags = shell_cmd("sed -n '"..(misc_index+1).."p' /tmp/misc_flags")
    tonumber(flags)

    if (misc_value == 1) then
        flags = bit.set(flags, bit.lshift(1, misc_flag))
    else
        flags = bit.unset(flags, bit.lshift(1, misc_flag))
    end

    shell_cmd("sed -i '"..(misc_index+1).."c "..flags.."' /tmp/misc_flags")
end

function get_firewall_mode_asus()
    shell_cmd("echo \"[APRO][WEB] get_firewall_mode\" > /dev/kmsg")

    if not api_init() then return end

    local result = response_mock()
    local mode = tonumber(shell_cmd('cat /etc/firewall_mode'))

    result['data'] = mode
    result['message'] = 'Firewall Mode'

    luci.http.prepare_content('application/json')
    luci.http.write_json(result)
end

function set_firewall_mode_asus()
    shell_cmd("echo \"[APRO][WEB] set_firewall_mode\" > /dev/kmsg")

    if not api_init() then return end

    local result = response_mock()

    if luci.http.formvalue("mode") then
        local mode = tonumber(luci.http.formvalue("mode"))
		result['data'] = mode
        result['message'] = "Set firewall mode to "..mode
		shell_cmd('/usr/local/sbin/set_firewall_mode.sh ' .. mode)
    else
        result['code'] = -1
        result['message'] = "mode argument not provided"
    end

    luci.http.prepare_content('application/json')
    luci.http.write_json(result)
end

function get_firewall_ip_asus()
    shell_cmd("echo \"[APRO][WEB] get_firewall_ip\" > /dev/kmsg")
    if not api_init() then return end

    local result = response_mock()
    require "nixio"
    http_headers = nixio.getenv()
    param = http_headers['QUERY_STRING']
    local index = tonumber(luci.http.formvalue("index"))
    local ip1 = shell_cmd(string.format("cat /etc/firewall_table | grep 'index=%d ip1' | sed 's/^.*ip1=//g' | sed 's/ ip2=.*$//g'",index))
    local ip2 = shell_cmd(string.format("cat /etc/firewall_table | grep 'index=%d ip1' | sed 's/^.*ip2=//g'",index))
    local num = tonumber(shell_cmd("cat /etc/firewall_table | wc -l"))

    result['data'] = index
    result['ip1'] = ip1
    result['ip2'] = ip2
    result['num'] = num
    if index >= num then
        result['code'] = -1
    end
    result['message'] = 'get firewall ip'
    luci.http.prepare_content('application/json')
    luci.http.write_json(result)
end

function set_firewall_ip_asus()
    shell_cmd("echo \"[APRO][WEB] set_firewall_ip\" > /dev/kmsg")
    if not api_init() then return end

    local result = response_mock()
    require "nixio"
    http_headers = nixio.getenv()
    param = http_headers['QUERY_STRING']
    local index = tonumber(param:match("index=(.*),ip1"))
    local ip1 = param:match("ip1=(.*),ip2")
    local ip2 = param:match("ip2=(.*)")

    os.execute(string.format("sed -i '%dc index=%d ip1=%s ip2=%s' /etc/firewall_table && sync",index+1,index,ip1,ip2))

    result['data'] = index
    result['ip1'] = ip1
    result['ip2'] = ip2
    result['message'] = 'set firewall ip'
    luci.http.prepare_content('application/json')
    luci.http.write_json(result)
end

function get_machine_name_asus()
    shell_cmd("echo \"[APRO][WEB] get_machine_name\" > /dev/kmsg")

    if not api_init() then return end

    local result = response_mock()
    name = shell_cmd('cat /etc/machinename')

    result['data'] = name
    result['message'] = 'Get machine name'

    luci.http.prepare_content('application/json')
    luci.http.write_json(result)
end

function set_machine_name_asus()
    shell_cmd("echo \"[APRO][WEB] set_machine_name\" > /dev/kmsg")

    if not api_init() then return end

    local result = response_mock()
    param = http_headers['QUERY_STRING']
    name = param:match("name=(.*)")

    if name ~= nil then
        result['data'] = name
        result['message'] = "Set machine name to "..name
        shell_cmd('echo "%s" > /etc/machinename' %{name})
        shell_cmd("/usr/local/sbin/backup_userdata.sh")
    else
        result['code'] = -1
        result['message'] = "name argument not provided"
    end

    luci.http.prepare_content('application/json')
    luci.http.write_json(result)
end

function get_misc_asus()
    shell_cmd("echo \"[APRO][WEB] get misc\" > /dev/kmsg")
    if not api_init() then return end

    local result = response_mock()
    require "nixio"
    http_headers = nixio.getenv()
    param = http_headers['QUERY_STRING']

    local misc_0 = tonumber(shell_cmd("sed -n 1p /tmp/misc_flags"))
    local misc_1 = tonumber(shell_cmd("sed -n 2p /tmp/misc_flags"))
    local misc_2 = tonumber(shell_cmd("sed -n 3p /tmp/misc_flags"))
    local misc_3 = tonumber(shell_cmd("sed -n 4p /tmp/misc_flags"))

    result['misc_0'] = misc_0
    result['misc_1'] = misc_1
    result['misc_2'] = misc_2
    result['misc_3'] = misc_3

    result['message'] = 'get_misc'
    luci.http.prepare_content('application/json')
    luci.http.write_json(result)
end

function set_misc_asus()
    shell_cmd("echo \"[APRO][WEB] set misc\" > /dev/kmsg")
    if not api_init() then return end

    local result = response_mock()
    require "nixio"
    http_headers = nixio.getenv()
    param = http_headers['QUERY_STRING']

    local misc_0 = tonumber(param:match("misc_0=(.*),misc_1"))
    local misc_1 = tonumber(param:match("misc_1=(.*),misc_2"))
    local misc_2 = tonumber(param:match("misc_2=(.*),misc_3"))
    local misc_3 = tonumber(param:match("misc_3=(.*)"))

    shell_cmd("sed -i '1c "..misc_0.."' /tmp/misc_flags")
    shell_cmd("sed -i '2c "..misc_1.."' /tmp/misc_flags")
    shell_cmd("sed -i '3c "..misc_2.."' /tmp/misc_flags")
    shell_cmd("sed -i '4c "..misc_3.."' /tmp/misc_flags")

    result['misc_0'] = misc_0
    result['misc_1'] = misc_1
    result['misc_2'] = misc_2
    result['misc_3'] = misc_3
    result['message'] = 'set_misc'
    luci.http.prepare_content('application/json')
    luci.http.write_json(result)
end
-----------------------------------------------------------------------
-- API ASUS {end}
-----------------------------------------------------------------------
