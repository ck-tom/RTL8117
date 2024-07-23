some stuff about trying to mess around with the Asus Pro-WS x570 board.

This board has an embedded Realtek MIPS CPU (RTL8117), which is apperently used by the Asus Control Center (ACC) and Asus Control Center Express (ACCE) software. Some things about ACC and ACCE:

- ACC has a paid licensing model
- Although ACCE is free, from what I understand, ACCE is significantly limited in functions exposed. 
- As usual with Asus, almost no documentation available online (it's disappointing, do better Asus).
- Proprietary
- ACCE is distributed as images which need to be run in it's own VM, and (from what I understand) requires agent softwart to be installed. The agent software is Windows only. 

So obviously ACC and ACCE are not going to be options.

Researching this board, and specifically the RTL8117 component I found [this level1techs forum post](https://forum.level1techs.com/t/remote-management-on-the-asus-pro-ws-x570-ace-under-linux/146432/55) where people had been sharing their work trying to get this to be usable without ACC/ACCE. 
They had discovered that the RTL8117 was running a (super old) version of [OpenWRT](https://openwrt.org). This was good news for me, as I am very familiar with OpenWRT. **Anssi** on [level1techs](https://forum.level1techs.com/t/remote-management-on-the-asus-pro-ws-x570-ace-under-linux/146432/55) had figured out that Asus had used the last 15 characters of the UUID for the root password. 
You could obtain the UUID with an unauthenticated REST GET
`https://IP-ADDRESS/cgi-bin/luci/apiasus/descriptor` 
From UUID returned you can derive the default root password (last 15 characters of UUID).

Using this you can create a token as root.
`https://IP-ADDRESS/cgi-bin/luci/?luci_username=root&luci_password=LAST15CHAR`

This will do a redirect with a new token.

`https://IP-ADDRESS/cgi-bin/luci/;stok=TOKEN`

Register the token
`https://IP-ADDRESS/cgi-bin/luci/;stok=TOKEN/apiasus/reg_stok?appuid=consoleTest`

Apperently any reasonable appuid can be used but consoleTest is what ACCE uses.

With the registered token you have full access to all the asus api's. This of course seems like a huge security issue, so I changed the root passwd 
`https://IP-ADDRESS/cgi-bin/luci/apiasus/set_psw?psw=NEWPASSWORD`

An nmap default scan of the RTL8117's IP shows port 22 is open so let's try to ssh into this using the new root password.


`ssh -v root@IP-ADDRESS`

`no matching key exchange method found. Their offer: diffie-hellman-group14-sha1,diffie-hellman-group1-sha1,kexguess2@matt.ucc.asn.au`
I forgot that it was a super old version of OpenWRT running so we need to tell ssh to use these depricated algorithms. Instead of changing my default ssh_config to allow these insecure algorithms I'll create a config file to use just for this connection. 
./rtl8117_ssh_config
`
kexAlgorithms diffie-hellman-group1-sha1
PubkeyAcceptedAlgorithms +ssh-rsa
IdentitiesOnly yes
`
Now I'll try again

`ssh -v -F ./rtl8117_ssh_config root@IP-ADDRESS`

`no matching host key type found. Their offer: ssh-rsa,ssh-dss`

Let's also add this to ./rtl8117_ssh_config
`
HostKeyAlgorithms +ssh-rsa
`

`ssh -v -F ./rtl8117_ssh_config root@IP-ADDRESS`

After entering the passwd I had a root shell in the RTL8117. Success! 
Now to poke around a bit and see what is available in the RTL8117 to interface with the host system. 



`dmesg`
`
[    0.000000] Linux version 4.4.18-g10f6016-dirty (jenkins@fdc-13) (gcc version 4.9.4 (OpenWrt/Linaro GCC 4.9-2015.06 r48422) ) #2 PREEMPT Mon Jul 1 19:21:31 CST 2019
[    0.000000] MIPS: machine is RTL8117 Embedded Linux Platform
[    0.000000] bootconsole [early0] enabled
[    0.000000] CPU0 revision is: 0000dc01 (Taroko)
[    0.000000] MIPS: machine is Realtek RTL8117
[    0.000000] Determined physical RAM map:
[    0.000000]  memory: 02000000 @ 08000000 (usable)
[    0.000000] Wasting 1048576 bytes for tracking 32768 unused pages
[    0.000000] Zone ranges:
[    0.000000]   Normal   [mem 0x0000000008000000-0x0000000009ffffff]
[    0.000000] Movable zone start for each node
[    0.000000] Early memory node ranges
[    0.000000]   node   0: [mem 0x0000000008000000-0x0000000009ffffff]
[    0.000000] Initmem setup node 0 [mem 0x0000000008000000-0x0000000009ffffff]
[    0.000000] On node 0 totalpages: 8192
[    0.000000] free_area_init_node: node 0, pgdat 884596c0, node_mem_map 884f9300
[    0.000000]   Normal zone: 64 pages used for memmap
[    0.000000]   Normal zone: 0 pages reserved
[    0.000000]   Normal zone: 8192 pages, LIFO batch:0
[    0.000000] cma: fdt region 0
[    0.000000] cma: Reserved 4 MiB at 0x09000000
[    0.000000] icache: 64kB/32B, dcache: 64kB/32B, scache: 0kB/0B
[    0.000000] pcpu-alloc: s0 r0 d32768 u32768 alloc=1*32768
[    0.000000] pcpu-alloc: [0] 0 
[    0.000000] Built 1 zonelists in Zone order, mobility grouping on.  Total pages: 8128
[    0.000000] Kernel command line: console=ttyS0,57600 init=/sbin/init rootfstype=squashfs root=/dev/mtdblock6 mtdparts=RtkSFC0:64k(PXE),64K(ENV),64K(CONF),384K(U-Boot),64K(DTB),1920K(Linux),3584K(rootfs),1984K(data),64K(bioscfg),64K(bDTB),1920K(bLinux),3584K(brootfs),1984K(bdata),64K(RMA),64K(aproData),-(reserve);RtkSFC1:2M(BIOS-0),2M(BIOS-1),2M(BIOS-2),2M(BIOS-3),2M(BIOS-4),2M(BIOS-5),2M(BIOS-6),2M(BIOS-7),2M(BIOS-8),2M(BIOS-9),2M(BIOS-10),2M(BIOS-11),2M(BIOS-12),2M(BIOS-13),2M(BIOS-14),-(BIOS-15)
[    0.000000] PID hash table entries: 128 (order: -3, 512 bytes)
[    0.000000] Dentry cache hash table entries: 4096 (order: 2, 16384 bytes)
[    0.000000] Inode-cache hash table entries: 2048 (order: 1, 8192 bytes)
[    0.000000] Memory: 23260K/32768K available (3909K kernel code, 120K rwdata, 508K rodata, 192K init, 324K bss, 5412K reserved, 4096K cma-reserved)
[    0.000000] Preemptible hierarchical RCU implementation.
[    0.000000] NR_IRQS:16
[    0.000000] ERROR: could not get clock /timer@1a800000:pclk(1)
[    0.000000] sched_clock: 32 bits at 100 Hz, resolution 10000000ns, wraps every 21474836475000000ns
[    0.010000] Calibrating delay loop... 383.38 BogoMIPS (lpj=1916928)
[    0.080000] pid_max: default: 32768 minimum: 301
[    0.090000] Mount-cache hash table entries: 1024 (order: 0, 4096 bytes)
[    0.100000] Mountpoint-cache hash table entries: 1024 (order: 0, 4096 bytes)
[    0.110000] clocksource: jiffies: mask: 0xffffffff max_cycles: 0xffffffff, max_idle_ns: 19112604462750000 ns
[    0.120000] NET: Registered protocol family 16
[    0.130000] [GPIO] No default gpio need to set
[    0.190000] SCSI subsystem initialized
[    0.190000] usbcore: registered new interface driver usbfs
[    0.200000] usbcore: registered new interface driver hub
[    0.210000] usbcore: registered new device driver usb
[    0.220000] NET: Registered protocol family 2
[    0.230000] TCP established hash table entries: 1024 (order: 0, 4096 bytes)
[    0.240000] TCP bind hash table entries: 1024 (order: 0, 4096 bytes)
[    0.250000] TCP: Hash tables configured (established 1024 bind 1024)
[    0.260000] UDP hash table entries: 256 (order: 0, 4096 bytes)
[    0.270000] UDP-Lite hash table entries: 256 (order: 0, 4096 bytes)
[    0.280000] NET: Registered protocol family 1
[    0.290000] PCI: CLS 0 bytes, default 32
[    0.290000] [EHCI] rtl8117_ehci_probe: gpio -2 is not valid
[    0.300000] [EHCI] enter ehci_usb_enabled
[    0.310000] [EHCI] enter rtl8117_ehci_init
[    0.320000] [EHCI] rtl8117_ehci_init done
[    0.330000] [EHCI] set usb otg power to high
[    0.340000] register_swisr swisr=70 88009f6c 89c5e980 
[    0.350000] register_swisr swisr=71 88009f44 89c5e980 
[    0.360000] rtk_vga_probe.
[    0.390000] [CMAC] rtl8117_cmac_probe: gpio is not valid
[    0.400000] vga_handler.
[    0.410000] [CMAC] bsp_enable_cmac_tx: Tx 
[    0.420000] [CMAC] bsp_enable_cmac_tx: alloc tx 
[    0.430000] [CMAC] bsp_enable_cmac_tx: alloc tx 
[    0.440000] [CMAC] bsp_enable_cmac_tx: alloc tx 
[    0.450000] [CMAC] bsp_enable_cmac_tx: alloc tx 
[    0.460000] [CMAC] bsp_enable_cmac_rx: Rx 
[    0.460000] bsp_cmac_handler_sw 80 
[    0.460000] bsp_cmac_handler_sw 80 
[    0.460000] [CMAC] bsp_disable_cmac_tx: Rx 
[    0.460000] [CMAC] bsp_disable_cmac_rx: Rx 
[    0.460000] [CMAC] bsp_enable_cmac_rx: Rx 
[    0.460000] [CMAC] bsp_enable_cmac_tx: Tx 
[    0.470000] futex hash table entries: 256 (order: -1, 3072 bytes)
[    0.480000] squashfs: version 4.0 (2009/01/31) Phillip Lougher
[    0.490000] io scheduler noop registered
[    0.500000] io scheduler cfq registered (default)
[    0.510000] Serial: 8250/16550 driver, 1 ports, IRQ sharing disabled
[    0.520000] console [ttyS0] disabled
[    0.540000] 1a000000.serial0: ttyS0 at MMIO 0x1a000000 (irq = 7, base_baud = 12125000) is a 16550A
[    0.550000] console [ttyS0] enabled
[    0.560000] bootconsole [early0] disabled
[    0.570000] [rtk_spi_probe] get spi controller base addr : 0xbc000000 
[    0.580000] [rtk_spi_probe] get cpu-frequency : 388000000 
[    0.590000] #0sck_div is 0x2.
[    0.600000] #1sck_div is 0x7.
[    0.610000] [rtk_spi_probe] spi controller driver is registered.
[    0.620000] [rtk_spi_probe] get spi controller base addr : 0xbc010000 
[    0.630000] [rtk_spi_probe] get cpu-frequency : 388000000 
[    0.640000] #0sck_div is 0x2.
[    0.650000] #1sck_div is 0x6.
[    0.660000] [rtk_spi_probe] spi controller driver is registered.
[    0.670000] RtkSFC MTD init ...
[    0.670000] [rtk_sfc_dev_init] get spi controller base addr : 0xbc000000 
[    0.680000] --RDID Seq: 0xc8 | 0x40 | 0x18
[    0.690000] RtkSFC MTD: GD 25Q128B detected.
[    0.700000] Supported Erase Size: 64KB 32KB 4KB.
[    0.700000] 16 cmdlinepart partitions found on MTD device RtkSFC0
[    0.710000] Creating 16 MTD partitions on "RtkSFC0":
[    0.720000] 0x000000000000-0x000000010000 : "PXE"
[    0.730000] 0x000000010000-0x000000020000 : "ENV"
[    0.740000] 0x000000020000-0x000000030000 : "CONF"
[    0.750000] 0x000000030000-0x000000090000 : "U-Boot"
[    0.760000] 0x000000090000-0x0000000a0000 : "DTB"
[    0.770000] 0x0000000a0000-0x000000280000 : "Linux"
[    0.780000] 0x000000280000-0x000000600000 : "rootfs"
[    0.790000] mtd: device 6 (rootfs) set to be root filesystem
[    0.800000] 0x000000600000-0x0000007f0000 : "data"
[    0.800000] 0x0000007f0000-0x000000800000 : "bioscfg"
[    0.810000] 0x000000800000-0x000000810000 : "bDTB"
[    0.820000] 0x000000810000-0x0000009f0000 : "bLinux"
[    0.830000] 0x0000009f0000-0x000000d70000 : "brootfs"
[    0.840000] 0x000000d70000-0x000000f60000 : "bdata"
[    0.850000] 0x000000f60000-0x000000f70000 : "RMA"
[    0.860000] 0x000000f70000-0x000000f80000 : "aproData"
[    0.880000] 0x000000f80000-0x000001000000 : "reserve"
[    0.890000] Rtk SFC: (for SST/SPANSION/MXIC SPI Flash)
[    0.900000] Realtek SFC Driver is successfully installing.
[    0.900000] 
[    0.910000] r8168oob Gigabit Ethernet driver 2.7LK-NAPI loaded
[    0.930000] r8168oob 1af70000.nic eth0: RTL8117 at 0xbaf70000, re:da:ct:ma:ca:dd, XID 0000000b IRQ 6
[    0.940000] r8168oob 1af70000.nic eth0: jumbo features [frames: 9200 bytes, tx checksumming: ko]
[    0.950000] [Ethernet] Watch isolate status change.
[    0.960000] [Ethernet] Watch link status change.
[    1.190000] dwc2 1b400000.usb: EPs: 8, dedicated fifos, 4634 entries in SPRAM
[    1.580000] dwc2 1b400000.usb: DWC OTG Controller
[    1.580000] dwc2 1b400000.usb: new USB bus registered, assigned bus number 1
[    1.590000] dwc2 1b400000.usb: irq 12, io mem 0x00000000
[    1.600000] hub 1-0:1.0: USB hub found
[    1.610000] hub 1-0:1.0: 1 port detected
[    1.620000] usbcore: registered new interface driver usb-storage
[    1.630000] apro-ctrl: apro_ctrl_init 
[    1.640000] apro-ctrl: driver loaded
[    1.650000] devone driver(major 251) installed.
[    1.660000] apro-ctrl: aproctrl_gpio_init , HW_GPIO_0 is ok
[    1.670000] apro-ctrl: aproctrl_gpio_init , HW_GPIO_4 is ok
[    1.680000] apro-ctrl: aproctrl_gpio_init , HW_GPIO_5 is ok
[    1.690000] apro-ctrl: aproctrl_gpio_init , HW_GPIO_6 is ok
[    1.700000] apro-ctrl: aproctrl_gpio_init , HW_GPIO_9 is ok
[    1.710000] apro-ctrl: aproctrl_gpio_init , HW_GPIO_10 is ok
[    1.710000] apro-ctrl: aproctrl_gpio_init , HW_GPIO_11 is ok
[    1.720000] apro-ctrl: aproctrl_gpio_init , HW_GPIO_7 is ok
[    1.730000] apro-ctrl: aproctrl_gpio_init , HW_GPIO_8 is ok
[    1.850000] [PCIE] start the connection
[    4.600000] [PCIE] polling L0 state failed
[    4.600000] PCI host bridge /pcie@1afa0000 ranges:
[    4.610000]  MEM 0x00000000c0000000..0x00000000c0ffffff
[    4.620000]   IO 0x0000000000030000..0x000000000003ffff
[    4.630000] PCI host bridge to bus 0000:00
[    4.640000] pci_bus 0000:00: root bus resource [mem 0xc0000000-0xc0ffffff]
[    4.650000] pci_bus 0000:00: root bus resource [io  0xffffffff]
[    4.660000] pci_bus 0000:00: root bus resource [??? 0x00000000 flags 0x0]
[    4.670000] pci_bus 0000:00: No busn resource found for root bus, will use [bus 00-ff]
[    4.680000] [PCIE] read config slot = 0x0, , func = 0x0, reg = 0x0, value = 0xffffffff
[    4.690000] pci_bus 0000:00: busn_res: [bus 00-ff] end is updated to 00
[    4.690000] register_swisr swisr=ff 882dc8fc 89d96810 
[    4.690000] NET: Registered protocol family 10
[    4.700000] NET: Registered protocol family 17
[    4.710000] bridge: automatic filtering via arp/ip/ip6tables has been deprecated. Update your scripts to load br_netfilter if you need this.
[    4.720000] 8021q: 802.1Q VLAN Support v1.8
[    4.730000] UBI: auto-attach mtd7
[    4.730000] ubi0: attaching mtd7
[    4.740000] ubi0: scanning is finished
[    4.760000] ubi0: attached mtd7 (name "data", size 1 MiB)
[    4.770000] ubi0: PEB size: 65536 bytes (64 KiB), LEB size: 65024 bytes
[    4.780000] ubi0: min./max. I/O unit sizes: 256/256, sub-page size 256
[    4.790000] ubi0: VID header offset: 256 (aligned 256), data offset: 512
[    4.800000] ubi0: good PEBs: 31, bad PEBs: 0, corrupted PEBs: 0
[    4.810000] ubi0: user volume: 1, internal volumes: 1, max. volumes count: 128
[    4.820000] ubi0: max/mean erase counter: 105/58, WL threshold: 4096, image sequence number: 869194721
[    4.830000] ubi0: available PEBs: 0, total reserved PEBs: 31, PEBs reserved for bad PEB handling: 0
[    4.840000] ubi0: background thread "ubi_bgt0d" started, PID 52
[    4.850000] fdt: not creating '/sys/firmware/fdt': CRC check failed
[    4.860000] UBIFS error (pid: 1): cannot open "ubi0:rootfs", error -19
[    4.870000] VFS: Mounted root (squashfs filesystem) readonly on device 31:6.
[    4.880000] Freeing unused kernel memory: 192K (88470000 - 884a0000)
[    4.890000] This architecture does not have kernel memory protection.
[    6.130000] zram: Added device: zram0
[    6.150000] zram0: detected capacity change from 0 to 14106624
[    6.720000] random: mkfs.ext4 urandom read with 10 bits of entropy available
[    6.870000] EXT4-fs (zram0): noquota option not supported
[    6.880000] EXT4-fs (zram0): mounted filesystem with ordered data mode. Opts: errors=continue,noquota
[    6.890000] init: Using up to 13774 kB of RAM as ZRAM storage on /mnt
[    6.900000] init: Console is alive
[    6.910000] init: - watchdog -
[    7.080000] init: - preinit -
[    9.130000] mount_root: mounting /dev/root
[    9.140000] mount_root: loading kmods from internal overlay
[    9.540000] block: attempting to load /etc/config/fstab
[    9.690000] block: extroot: not configured
[    9.720000] UBIFS (ubi0:0): background thread "ubifs_bgt0_0" started, PID 90
[    9.740000] UBIFS (ubi0:0): recovery needed
[   10.260000] UBIFS (ubi0:0): recovery completed
[   10.270000] UBIFS (ubi0:0): UBIFS: mounted UBI device 0, volume 0, name "etc"
[   10.280000] UBIFS (ubi0:0): LEB size: 65024 bytes (63 KiB), min./max. I/O unit sizes: 256 bytes/256 bytes
[   10.290000] UBIFS (ubi0:0): FS size: 1040384 bytes (0 MiB, 16 LEBs), journal size 585217 bytes (0 MiB, 8 LEBs)
[   10.300000] UBIFS (ubi0:0): reserved for root: 0 bytes (0 KiB)
[   10.310000] UBIFS (ubi0:0): media format: w4/r0 (latest is w4/r0), UUID ZZZZZZZ-ZZZZ-ZZZZ-ZZZZ-ZZZZZZZZZZZZ, small LPT model
[   10.390000] procd: - early -
[   10.400000] procd: - watchdog -
[   11.400000] procd: - ubus -
[   11.450000] procd: - init -
[   14.690000] EXT4-fs (mtdblock8): mounting ext2 file system using the ext4 subsystem
[   14.990000] EXT4-fs (mtdblock8): mounted filesystem without journal. Opts: (null)
[   15.630000] EXT4-fs (mtdblock14): mounting ext2 file system using the ext4 subsystem
[   15.940000] EXT4-fs (mtdblock14): mounted filesystem without journal. Opts: (null)
[   16.100000] loop: module loaded
[   21.700000] r8168oob 1af70000.nic eth0: link up
[   29.040000] 
[   29.040000]  cmac register interrupt to gmac
[   29.060000] register_swisr swisr=25 88010280 89c82260 
[   29.080000] register_swisr swisr=26 88010fd8 89c82260 
[   77.520000] random: nonblocking pool is initialized
`
Let's check out the fw env.

`fw_printenv
baudrate=57600
board=realtek
bootcmd=if safemode; then run safemodeboot; else run spiboot; fi;run safemodeboot; run netboot; run usbboot; run upgrade_img_usb;run upgrade_img_tftp; 
bootdelay=3
bootfile=uImage
check_env=if test -n ${flash_env_version}; then env default env_version; else env set flash_env_version ${env_version}; env save; fi; if test ${flash_env_version} -lt ${env_version}; then env set flash_env_version ${env_version}; env default -a; env save; fi; 
env_version=4
ethact=r8168#0
ethaddr=re:da:ct:ma:ca:dd
factoryimgaddr=0x20000
factoryimgname=openwrt-rtl8117-factory-bootcode.img
factoryimgsize=0x7e0000
fdtcontroladdr=89f1eb64
fdtfile=rtl8117.dtb
flash_env_version=4
gatewayip=192.168.0.254
imgaddr=0x88000400
ipaddr=192.168.0.10
loadaddr=0x88000000
netboot=tftp ${uimageaddr} ${bootfile};tftp ${fdtcontroladdr} ${fdtfile};bootm ${uimageaddr} - ${fdtcontroladdr}
netmask=255.255.255.0
oftaddr=0x82090000
preboot=run check_env;
safemodeboot=bootm ${safemodespiimgaddr} - ${safemodeoftaddr}
safemodeoftaddr=0x82800000
safemodespiimgaddr=0x82810000
serverip=192.168.0.100
spiboot=bootm ${spiimgaddr} - ${oftaddr}
spiimgaddr=0x820a0000
stderr=serial0@1a000000
stdin=serial0@1a000000
stdout=serial0@1a000000
uimageaddr=0x88800000
upgrade_img_tftp=tftp ${loadaddr} ${factoryimgname} && setenv upfwtftp 1; if test -n ${upfwtftp}; then sf probe; sf erase ${factoryimgaddr} ${factoryimgsize}; sf write ${imgaddr} ${factoryimgaddr} ${factoryimgsize}; reset; fi;
upgrade_img_usb=usb start;fatload usb 0:1 ${loadaddr} ${factoryimgname} && setenv upfwusb 1; if test -n ${upfwusb}; then sf probe; sf erase ${factoryimgaddr} ${factoryimgsize}; sf write ${imgaddr} ${factoryimgaddr} ${factoryimgsize}; reset; fi;
usbboot=usb start;fatload usb 0:1 ${uimageaddr} ${bootfile};fatload usb 0:1 ${fdtcontroladdr} ${fdtfile};bootm ${uimageaddr} - ${fdtcontroladdr}
ver=U-Boot 2017.09 (May 08 2019 - 19:58:24 +0800)
factory_boot=disable
`


Ok interesting. Let's see what kind of nonsense Asus stuck in rc.local.

`cat /etc/rc.local`


># Put your custom commands here that should be executed once
># the system init finished. By default this file does nothing.
>
># enable cmac driver
>echo 1 > /proc/rtl8117-cmac/cmac_enabled
>
># set value in KVM and USBR of sw_setting
>KVM=$(cat /sys/class/apro-ctrl/aproctrl/kvm)
>echo ${KVM} > /tmp/kvm
>
>USBR=$(cat /sys/class/apro-ctrl/aproctrl/usbr)
>echo ${USBR} > /tmp/usbr
>
># kernel ready
>echo 1 > /sys/class/apro-ctrl/aproctrl/rtl8117_ready
>
># boot PC when factory is enable
>FACTORY_BOOT=$(fw_printenv | grep factory_boot | awk 'BEGIN {FS="="} {print $2}')
>if [ "$FACTORY_BOOT" == "enable" ]; then
>    echo 1 > /sys/class/apro-ctrl/aproctrl/poweron
>fi
>fw_setenv factory_boot disable
>
>exit 0

What is **cmac driver**? I'm not familiar with this. Also **apro-ctl**.

`ls -l /sys/class/apro-ctrl/aproctrl`
`lrwxrwxrwx    1 root     root             0 Jan  1  1970 /sys/class/apro-ctrl/aproctrl -> ../../devices/virtual/apro-ctrl/aproctrl`

`ls -l /sys/devices/virtual/apro-ctrl/aproctrl`
`-rw-r--r--    1 root     root          4096 Jul  2 11:26 clear_psw
-rw-r--r--    1 root     root          4096 Jul  2 11:26 clearcmos
-r--r--r--    1 root     root          4096 Jan  1  1970 dev
-rw-r--r--    1 root     root          4096 Jul  2 11:26 gop
-rw-r--r--    1 root     root          4096 Jul  2 11:26 gpio_status
-rw-r--r--    1 root     root          4096 Jul  2 11:26 inband
-rw-r--r--    1 root     root          4096 Jul  2 11:13 kvm
-rw-r--r--    1 root     root          4096 Jul  2 11:26 pcstate
-rw-r--r--    1 root     root          4096 Jul  2 11:26 poweroff
-rw-r--r--    1 root     root          4096 Jul  2 11:26 poweron
-rw-r--r--    1 root     root          4096 Jul  2 11:26 rebootos
-rw-r--r--    1 root     root          4096 Jul  2 11:13 rtl8117_ready
-rw-r--r--    1 root     root          4096 Jul  2 11:26 safemode
-rw-r--r--    1 root     root          4096 Jul  2 11:26 spiswitch
lrwxrwxrwx    1 root     root             0 Jul  2 11:26 subsystem -> ../../../../class/apro-ctrl
-rw-r--r--    1 root     root          4096 Jan  1  1970 uevent
-rw-r--r--    1 root     root          4096 Jul  2 11:26 upload
-rw-r--r--    1 root     root          4096 Jul  2 11:13 usbr`

it looks like /sys/devices/virtual/apro-ctrl/aproctrl exposes a bunch of the motherboard controls. Lets try turning the motherboard on

`echo 1 > /sys/devices/virtual/apro-ctrl/aproctrl/poweron`

Well doing this causes the ssh connection to drop out. But it looks like this turned on the device so that's something.
