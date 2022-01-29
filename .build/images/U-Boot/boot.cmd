# DO NOT EDIT THIS FILE
#
# Please edit /boot/dietpiEnv.txt to set supported parameters
#
# If you must edit this file, recompile with:
# mkimage -C none -A arm64 -T script -d /boot/boot.cmd /boot/boot.scr

# Default values
setenv rootdev "/dev/mmcblk0p1"
setenv rootfstype "ext4"
setenv consoleargs "console=tty1"
setenv verbosity "4"
setenv docker_optimizations "off"
setenv overlay_path "amlogic"
setenv overlay_prefix "meson"

# Load addresses
setenv load_addr "0x32000000"
setenv kernel_addr_r "0x34000000"
setenv fdt_addr_r "0x4080000"
setenv overlay_error "false"

# Load dietpiEnv.txt
if test -e ${devtype} ${devnum} ${prefix}dietpiEnv.txt; then
	load ${devtype} ${devnum} ${load_addr} ${prefix}dietpiEnv.txt
	env import -t ${load_addr} ${filesize}
fi

# Get PARTUUID of first partition on SD/eMMC it was loaded from
# mmc 0 is always mapped to device u-boot (2016.09+) was loaded from
if test "${devtype}" = "mmc"; then part uuid mmc ${devnum}:1 partuuid; fi

# Define kernel command-line arguments
setenv bootargs "root=${rootdev} rootfstype=${rootfstype} rootwait ${consoleargs} loglevel=${verbosity} consoleblank=0 coherent_pool=2M ubootpart=${partuuid} libata.force=noncq usb-storage.quirks=${usbstoragequirks} ${extraargs} ${extraboardargs}"

# Add bootargs for Docker
if test "${docker_optimizations}" = "on"; then setenv bootargs "${bootargs} cgroup_enable=memory swapaccount=1"; fi

# Load kernel, initramfs and device tree
load ${devtype} ${devnum} ${kernel_addr_r} ${prefix}Image
load ${devtype} ${devnum} ${ramdisk_addr_r} ${prefix}uInitrd
load ${devtype} ${devnum} ${fdt_addr_r} ${prefix}dtb/${fdtfile}
fdt addr ${fdt_addr_r}

# Apply DT overlays
if test -n "${overlays}" || test -n "${user_overlays}"; then
	fdt resize 65536
	for overlay_file in ${overlays}; do
		if load ${devtype} ${devnum} ${load_addr} ${prefix}dtb/${overlay_path}/overlay/${overlay_prefix}-${overlay_file}.dtbo; then
			echo "Applying kernel provided DT overlay ${overlay_prefix}-${overlay_file}.dtbo"
			fdt apply ${load_addr} || setenv overlay_error "true"
		fi
	done

	for overlay_file in ${user_overlays}; do
		if load ${devtype} ${devnum} ${load_addr} ${prefix}overlay-user/${overlay_file}.dtbo; then
			echo "Applying user provided DT overlay ${overlay_file}.dtbo"
			fdt apply ${load_addr} || setenv overlay_error "true"
		fi
	done

	if test "${overlay_error}" = "true"; then
		echo "Error applying DT overlays, restoring original DT"
		load ${devtype} ${devnum} ${fdt_addr_r} ${prefix}dtb/${fdtfile}
	else
		if load ${devtype} ${devnum} ${load_addr} ${prefix}dtb/${overlay_path}/overlay/${overlay_prefix}-fixup.scr; then
			echo "Applying kernel provided DT fixup script (${overlay_prefix}-fixup.scr)"
			source ${load_addr}
		fi
		if test -e ${devtype} ${devnum} ${prefix}fixup.scr; then
			load ${devtype} ${devnum} ${load_addr} ${prefix}fixup.scr
			echo "Applying user provided fixup script (fixup.scr)"
			source ${load_addr}
		fi
	fi
fi

# Boot
booti ${kernel_addr_r} ${ramdisk_addr_r} ${fdt_addr_r}
