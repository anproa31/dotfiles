# Arch Linux + Windows dual boot  - command-by-command install

Distilled from `arch_wiki.md`, `ytb_video.md`, `dualboot - git_tutor.md`, aligned with this dotfiles repo
(bspwm + SDDM + polybar, bootstrapped by `./install.sh`).

**Assumptions**

| Thing | Value |
|---|---|
| Firmware | UEFI + GPT (Secure Boot off) |
| Disk | `/dev/nvme0n1`  - replace everywhere if yours differs (`/dev/sda`, ...) |
| Windows ESP | `/dev/nvme0n1p1`  - **already exists, never format it** |
| ESP mount point | `/efi` (Linux `/boot` stays on the root partition) |
| Boot loader | GRUB + os-prober |
| Desktop | bspwm + SDDM, from this repo  - **do not install GNOME/gdm** |

Why ESP at `/efi` and not `/boot`: the Windows ESP is usually 100 MiB. Kernels + initramfs do not
fit there, and a full ESP is one of the classic ways to end up at a `grub rescue>` prompt. Keeping
`/boot` on the ext4 root means Windows Update can never touch your kernels.

---

## Step 0  - Windows side, before you touch Linux

Do all of this from Windows. It is the single biggest anti-`grub rescue` measure.

1. **BitLocker**: Settings → Privacy & Security → Device encryption / BitLocker → **turn off**
   (or suspend it and save the recovery key somewhere off the machine). A boot-order change on an
   encrypted disk triggers a BitLocker recovery prompt.
2. **Fast Startup off**  - it leaves NTFS dirty, which breaks `os-prober` and NTFS mounts.
   Control Panel → Power Options → "Choose what the power buttons do" → uncheck *Turn on fast startup*.
3. **Hibernation off**, admin `cmd`:
   ```
   powercfg /h off
   ```
4. **Clock in UTC** so Windows and Linux agree (admin `cmd`):
   ```
   reg add "HKLM\SYSTEM\CurrentControlSet\Control\TimeZoneInformation" /v RealTimeIsUniversal /t REG_DWORD /d 1 /f
   ```
5. **Shrink the Windows partition** in Disk Management (`diskmgmt.msc`)  - right-click the Windows
   volume → Shrink Volume. Leave **at least 60 GiB** unallocated (40 GiB absolute minimum).
   Shrink from Windows, never from a Linux tool.
6. **Fully update Windows now**, and reboot into Windows once more. A pending feature update applied
   *after* GRUB is installed is exactly the event that rewrites the ESP / boot order.
7. Write down the ESP: Disk Management shows it as a ~100 MiB "EFI System Partition" on disk 0.

Also in firmware setup (BIOS): **Secure Boot = disabled**, and SATA/NVMe mode = **AHCI**, not RAID/Intel RST
(a disk in RAID mode does not show up in the installer at all).

---

## Step 1  - Boot the live ISO

- Write the ISO with Rufus: partition scheme **GPT**, target **UEFI**, defaults otherwise.
- Boot menu (F12 / Esc / F9 depending on vendor) → pick the USB → *Arch Linux install medium*.

Confirm you are in UEFI mode  - this must print `64`:

```bash
cat /sys/firmware/efi/fw_platform_size
```

Optional, bigger console font on a HiDPI screen:

```bash
setfont ter-132b
```

---

## Step 2  - Network + clock + keyring

```bash
iwctl
```

Inside `iwctl`:

```
device list
station wlan0 get-networks
station wlan0 connect <WiFi-Name>
exit
```

Ethernet: just plug the cable in, nothing to do.

Verify and sync:

```bash
ping -c 3 ping.archlinux.org
timedatectl
pacman -Sy archlinux-keyring
```

`archlinux-keyring` first: a stale live-ISO keyring makes `pacstrap` fail with signature errors.

---

## Step 3  - Partition

Look first:

```bash
lsblk -f
```

You should see `nvme0n1p1` (vfat, ~100M  - the ESP), the Windows NTFS partitions, and free space.

> **Destructive step. Read before pressing anything.**
> In `cfdisk` you create partitions **only in the free space you made in Step 0**.
> Do not touch, resize, or delete `nvme0n1p1` (EFI), the Microsoft reserved partition,
> the Windows NTFS partition, or the WinRE recovery partition. Deleting any of them kills Windows.

```bash
cfdisk /dev/nvme0n1
```

Create in the free space:

| # | Size | Type |
|---|---|---|
| swap | = your RAM (8–16 GiB typical) | `Linux swap` |
| root | all remaining free space | `Linux filesystem` |

Then `Write` → type `yes` → `Quit`.

```bash
lsblk
```

Note the new device names. Below they are called `nvme0n1p5` (swap) and `nvme0n1p6` (root)  -
**substitute your real numbers in every command that follows.**

---

## Step 4  - Format

> **Never run `mkfs.fat` on `/dev/nvme0n1p1`.** That is the shared Windows ESP; formatting it
> destroys the Windows Boot Manager and is the fastest route to an unbootable dual boot.
> You only format the two partitions you just created.

```bash
mkswap /dev/nvme0n1p5
mkfs.ext4 /dev/nvme0n1p6
```

---

## Step 5  - Mount

```bash
mount /dev/nvme0n1p6 /mnt
mount --mkdir /dev/nvme0n1p1 /mnt/efi
swapon /dev/nvme0n1p5
lsblk
```

`/mnt/efi` must show the existing Windows ESP with `EFI/Microsoft/` inside it:

```bash
ls /mnt/efi/EFI
```

If that directory is missing, you mounted the wrong partition  - stop and re-check.

---

## Step 6  - Base system

CPU microcode: `intel-ucode` for Intel, `amd-ucode` for AMD. Pick one.

```bash
pacstrap -K /mnt base base-devel linux linux-headers linux-firmware intel-ucode \
  linux-lts linux-lts-headers \
  grub efibootmgr os-prober ntfs-3g \
  networkmanager sudo git vim nano stow zsh man-db man-pages
```

`linux-lts` is a deliberate second kernel: if a `linux` upgrade ever produces an unbootable initramfs,
the LTS entry in the GRUB menu still boots.

```bash
genfstab -U /mnt >> /mnt/etc/fstab
cat /mnt/etc/fstab
```

Check `/efi` and swap appear there before continuing.

---

## Step 7  - Chroot and configure the system

```bash
arch-chroot /mnt
```

Everything until Step 11 runs **inside** the chroot.

Time (example is Vietnam  - match the `ibus-bamboo` in `pkg_lists.txt`):

```bash
ln -sf /usr/share/zoneinfo/Asia/Ho_Chi_Minh /etc/localtime
hwclock --systohc
```

Locale:

```bash
nano /etc/locale.gen        # uncomment: en_US.UTF-8 UTF-8
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf
```

Hostname + hosts:

```bash
echo "archbox" > /etc/hostname
cat > /etc/hosts <<'EOF'
127.0.0.1   localhost
::1         localhost
127.0.1.1   archbox.localdomain archbox
EOF
```

Root password, user, sudo:

```bash
passwd
useradd -m -G wheel -s /bin/bash <username>
passwd <username>
EDITOR=nano visudo          # uncomment: %wheel ALL=(ALL:ALL) ALL
```

Shell stays `/bin/bash` here on purpose  - this repo's `install.sh` switches you to `zsh` later,
once `zsh` and `~/.zshenv` actually exist.

---

## Step 8  - GRUB, installed so it survives Windows

Enable OS detection:

```bash
nano /etc/default/grub
```

Set / uncomment:

```
GRUB_DISABLE_OS_PROBER=false
GRUB_TIMEOUT=5
```

Install GRUB **twice**  - once as a normal NVRAM entry, once into the firmware fallback path:

```bash
grub-install --target=x86_64-efi --efi-directory=/efi --bootloader-id=GRUB --recheck
grub-install --target=x86_64-efi --efi-directory=/efi --removable --recheck
grub-mkconfig -o /boot/grub/grub.cfg
```

What the two do:

- first → `/efi/EFI/GRUB/grubx64.efi` + an `efibootmgr` entry named GRUB.
- second → `/efi/EFI/BOOT/BOOTX64.EFI`, the path firmware boots when NVRAM has no valid entry.
  **This is the single line that saves you when a Windows update wipes the boot order.**

`grub-mkconfig` output must contain a line like
`Found Windows Boot Manager on /dev/nvme0n1p1@/efi/Microsoft/Boot/bootmgfw.efi`.
If it does not, see Step 12.

Check and fix the boot order:

```bash
efibootmgr -v
```

Put GRUB first (use your real entry numbers from the output above):

```bash
efibootmgr -o 0000,0001
```

---

## Step 9  - Anti-`grub rescue` hardening

Three separate failure modes, three fixes. All of this is done once, inside the chroot.

**(a) GRUB package upgraded but not reinstalled** → `error: symbol 'grub_calloc' not found` →
rescue prompt. Fix with a pacman hook that reinstalls GRUB every time the package updates:

```bash
mkdir -p /etc/pacman.d/hooks
cat > /etc/pacman.d/hooks/99-grub-install.hook <<'EOF'
[Trigger]
Type = Package
Operation = Upgrade
Target = grub

[Action]
Description = Reinstalling GRUB to the ESP and regenerating grub.cfg...
When = PostTransaction
Exec = /bin/sh -c "grub-install --target=x86_64-efi --efi-directory=/efi --bootloader-id=GRUB --recheck && grub-install --target=x86_64-efi --efi-directory=/efi --removable --recheck && grub-mkconfig -o /boot/grub/grub.cfg"
EOF
```

**(b) Windows Update overwrites/reshuffles the ESP.** Keep a copy you can restore from:

```bash
cp -a /efi/EFI/GRUB /root/EFI-GRUB.backup
cp -a /efi/EFI/BOOT /root/EFI-BOOT.backup
cp /boot/grub/grub.cfg /root/grub.cfg.backup
```

**(c) Kernel upgrade fills a small ESP.** Already handled: `/boot` lives on the ext4 root, not on the
ESP. Keep it that way  - do not "helpfully" move `/boot` onto `/efi` later.

Optional but recommended, keeps `pacman -Syu` from silently outrunning your free space:

```bash
sed -i 's/^#ParallelDownloads/ParallelDownloads/' /etc/pacman.conf
```

---

## Step 10  - Services, then first reboot

```bash
systemctl enable NetworkManager
exit
umount -R /mnt
reboot
```

Pull the USB while it reboots. You should land on the GRUB menu with **Arch Linux** and
**Windows Boot Manager** entries. Boot Arch, log in as your user.

Do **not** install GNOME/gdm here  - the desktop comes from this repo in the next step.

---

## Step 11  - This dotfiles repo

Connect to Wi-Fi in the installed system:

```bash
nmcli device wifi connect <WiFi-Name> password "<Password>"
ping -c 3 ping.archlinux.org
```

Clone and bootstrap. Run as your **normal user**, not with `sudo`:

```bash
git clone --recurse-submodules https://github.com/<you>/dotfiles.git ~/dotfiles
cd ~/dotfiles
./install.sh
```

`install.sh` does, in order: yay → every package in `pkg_lists.txt` → default shell `zsh` →
enable `sddm` / `NetworkManager` / `bluetooth` → touchpad rules → yotsugi SDDM theme →
minegrub GRUB theme → `manas140/fetch` → backup clashing configs → `stow` into `$HOME` →
polybar battery/adapter detection → pywal yotsugi theme + wallpaper.

The GRUB-theme step runs `grub-mkconfig` again, so re-verify Windows is still in the menu:

```bash
grep -i 'menuentry' /boot/grub/grub.cfg | grep -i windows
```

Reboot into SDDM and pick the **bspwm** session:

```bash
reboot
```

---

## Step 12  - Recovery cookbook

### Windows entry missing from the GRUB menu

```bash
sudo pacman -S --needed os-prober ntfs-3g
sudo mount /dev/nvme0n1p1 /mnt          # the ESP
sudo grub-mkconfig -o /boot/grub/grub.cfg
sudo umount /mnt
```

If it is still missing, Fast Startup is on again in Windows (Step 0.2)  - turn it off, reboot into
Windows once, shut down fully, then re-run `grub-mkconfig`.

### Machine boots straight into Windows after an update

The NVRAM boot order was reset. From the firmware boot menu pick *GRUB* (or *UEFI OS*  - the fallback
copy from Step 8), boot Arch, then make it permanent:

```bash
sudo efibootmgr -v
sudo efibootmgr -o <grub_entry>,<windows_entry>
```

If no GRUB entry exists at all any more, recreate both:

```bash
sudo grub-install --target=x86_64-efi --efi-directory=/efi --bootloader-id=GRUB --recheck
sudo grub-install --target=x86_64-efi --efi-directory=/efi --removable --recheck
sudo grub-mkconfig -o /boot/grub/grub.cfg
```

### You are sitting at a `grub rescue>` prompt

Find the root partition, then hand control back to the full GRUB:

```
grub rescue> ls
grub rescue> ls (hd0,gpt6)/          # try each until you see /boot /etc /usr
grub rescue> set root=(hd0,gpt6)
grub rescue> set prefix=(hd0,gpt6)/boot/grub
grub rescue> insmod normal
grub rescue> normal
```

That gets you one boot only. Once inside Arch, make it permanent with the two `grub-install`
commands above.

### Nothing boots  - repair from the live USB

```bash
mount /dev/nvme0n1p6 /mnt
mount --mkdir /dev/nvme0n1p1 /mnt/efi
arch-chroot /mnt
grub-install --target=x86_64-efi --efi-directory=/efi --bootloader-id=GRUB --recheck
grub-install --target=x86_64-efi --efi-directory=/efi --removable --recheck
grub-mkconfig -o /boot/grub/grub.cfg
exit
umount -R /mnt
reboot
```

---

## Step 13  - Removing Arch later (from Windows)

> **Destructive and irreversible.** `delete partition override` erases that partition immediately,
> with no confirmation and no undo. Verify the partition number twice before running it.

Admin Command Prompt in Windows:

```
diskpart
list disk
select disk 0
list partition
select partition <arch_root_number>
delete partition override
```

Repeat `select` + `delete` for the swap partition. Do **not** delete partition 1 (the ESP).
Then remove the leftover GRUB entry  - from Windows, `bcdedit` cannot do it; use an admin cmd:

```
mountvol S: /s
rmdir /s /q S:\EFI\GRUB
mountvol S: /d
```

Finally extend the Windows volume back over the freed space in Disk Management.
