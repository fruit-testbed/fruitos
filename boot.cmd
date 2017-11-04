if test "${board_revision}" = "0xA02082";
then
	setenv fdtfile bcm2710-rpi-3-b.dtb;
elif test "${board_revision}" = "0xA22082";
then
	setenv fdtfile bcm2710-rpi-3-b.dtb;
elif test "${board_revision}" = "0xA32082";
then
	setenv fdtfile bcm2710-rpi-3-b.dtb;
elif test "${board_revision}" = "0xA020A0";
then
	setenv fdtfile bcm2710-rpi-cm3.dtb;
else
	setenv fdtfile bcm2709-rpi-2-b.dtb;
fi;
setenv kernel vmlinuz;
setenv ramdisk initramfs;
setenv boot_prefix /boot;
if fatload mmc 0:1 200000 uboot-root_dev.env;
then
	env import -t 200000;
	if test "${root_dev}" = "/dev/mmcblk0p2";
	then
		setenv root_dev /dev/mmcblk0p3;
		setenv root_part "0:3";
	else
		setenv root_dev /dev/mmcblk0p2;
		setenv root_part "0:2";
	fi;
else
	setenv root_dev /dev/mmcblk0p2;
	setenv root_part "0:2";
fi;
env export -t 200000 root_dev;
fatwrite mmc 0:1 200000 uboot-root_dev.env;
setenv bootargs 8250.nr_uarts=1 console=ttyAMA0,115200 console=tty1 noquite loglevel=7 dwc_otg.lpm_enable=0 root=${root_dev} rootfstype=ext4;
fatload mmc 0:1 0x2000000 ${fdtfile};
ext4load mmc ${root_part} ${kernel_addr_r} ${boot_prefix}/${kernel};
ext4load mmc ${root_part} ${ramdisk_addr_r} ${boot_prefix}/${ramdisk};
bootz ${kernel_addr_r} ${ramdisk_addr_r} 0x2000000;