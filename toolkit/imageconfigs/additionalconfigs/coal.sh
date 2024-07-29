#!/bin/bash
# Setup the data partition
mkdir /data/overlays
mkdir -p /data/overlays/etc/upper
mkdir -p /data/overlays/etc/work
mkdir -p /data/overlays/home/upper
mkdir -p /data/overlays/home/work
mkdir -p /data/overlays/var/upper
mkdir -p /data/overlays/var/work
mkdir -p /data/overlays/root/upper
mkdir -p /data/overlays/root/work

# Make rootfs mount as read-only
sed -i "s/\/ ext4 defaults/\/ ext4 defaults,ro/" /etc/fstab

# Ensure data partition is mounted in initrd along with overlay
sed -i "s/data ext4 defaults/data ext4 defaults,x-initrd.mount/" /etc/fstab
echo "overlay /etc overlay x-initrd.mount,x-systemd.requires-mounts-for=/sysroot/data,lowerdir=/sysroot/etc,upperdir=/sysroot/data/overlays/etc/upper,workdir=/sysroot/data/overlays/etc/work 0 0" >> /etc/fstab
echo "overlay /home overlay x-initrd.mount,x-systemd.requires-mounts-for=/sysroot/data,lowerdir=/sysroot/home,upperdir=/sysroot/data/overlays/home/upper,workdir=/sysroot/data/overlays/home/work 0 0" >> /etc/fstab
echo "overlay /var overlay x-initrd.mount,x-systemd.requires-mounts-for=/sysroot/data,lowerdir=/sysroot/var,upperdir=/sysroot/data/overlays/var/upper,workdir=/sysroot/data/overlays/var/work 0 0" >> /etc/fstab
echo "overlay /root overlay x-initrd.mount,x-systemd.requires-mounts-for=/sysroot/data,lowerdir=/sysroot/root,upperdir=/sysroot/data/overlays/root/upper,workdir=/sysroot/data/overlays/root/work 0 0" >> /etc/fstab

# Enable initrd to break into a shell
#sed -i "s/rd.shell=0 rd.emergency=reboot/rd.shell=1 rd.break=pre-pivot/" /boot/grub2/grub.cfg

# UKI logic
EFIDIR="BOOT"
KERNEL_VERSION=""

# Image generation is done in a chroot environment, so running `uname -r`
# will return the version of the host running kernel. This function works
# under the assumption that exactly one kernel is installed in the end image.
get_kernel_version() {
    kernel_modules_dir="/usr/lib/modules"
    KERNEL_VERSION="$(ls $kernel_modules_dir)"
}

# symlink /boot/efi to ../efi
cp -a /boot/efi/. /efi
rm -rf /boot/efi
ln -s ../efi /boot/efi

# The shim has its default boot-loader filename built in as grubx64.efi.
# To switch to systemd-boot, we overwrite that file location with the
# sd-boot EFI binary as a workaround.
cp /lib/systemd/boot/efi/systemd-bootx64.efi /efi/EFI/$EFIDIR/grubx64.efi

# empty /etc/fstab file
echo > /etc/fstab

# copy UKI into the ESP
mkdir -p /efi/EFI/Linux
get_kernel_version
echo "Kernel version = $KERNEL_VERSION"
cp /lib/modules/$KERNEL_VERSION/vmlinuz-uki.efi /efi/EFI/Linux/vmlinuz-uki-$KERNEL_VERSION.efi

# END UKI Logic

# Added to `kernel-uki-dracut.conf` used by kernel-uki.spec
# Ensure overlay driver is available in initrd
# echo "add_drivers+=\" overlay \"" >> /etc/dracut.conf.d/01-coal.conf

# Added to `kernel-uki-dracut.conf` used by kernel-uki.spec
# Enable systemd-repart in the initrd
# echo "add_dracutmodules+=\" systemd-repart \"" >> /etc/dracut.conf.d/01-coal.conf

# No longer needed now that we generate kernel-uki
# Regenerate initrd with locale in it
# dracut --force --regenerate-all --include /usr/lib/locale /usr/lib/locale

# bootctl install --esp-path --boot-path --root