#!/bin/bash

cols=$(tput cols)
lines=$(tput lines)

main_menu(){
    selected_menu=$(whiptail --title "Main Menu" --menu "Choose a progcess" $lines $cols 16 \
    "Keymap Chooser" "Set keyboard" \
    "Hostname" "Set host name" \
    "Mirror Country" "Set local mirror repository" \
    "Disk Manager" "Set disk configuration" \
    "Boot Manager" "install Uefi or GRUB" \
    "Create User" "Create a user" \
    "Select Drivers" "Install drivers and hardware support" \
    "Select Desktop" "Install desktop manager" \
    "Select Programs" "Select programs" \
    "Start Install" "Start Installation" 3>&1 1>&2 2>&3)
    exitstatus=$?
    if [ $exitstatus = 0 ]; then
        case $selected_menu in
        "Keymap Chooser" )
            keymap_manager ;;
        "Hostname" )
            hostname_manager ;;
        "Mirror Country" )
            mirrorlist_manager ;;
        "Disk Manager" )
            disk_manager ;;
        "Boot Manager" )
            boot_manager ;;
        "Create User" )
            user_manager ;;
        "Select Drivers" )
            driver_manager ;;
        "Select Desktop" )
            desktop_manager ;;
        "Select Programs" )
            program_manager ;;
        "Start Install" )
            check_install ;;
        esac
    else
        umount -R /mnt
        swapoff -a
        exit
    fi
}

keymap_manager(){
title="Keymap Manager"
message="Select a keymap:\n"
    selected_keymap=$(whiptail --title "$title" --radiolist "$message"  $lines $cols 15 \
        "us" "" off \
        "trq" "" on 3>&1 1>&2 2>&3)
    exitstatus=$?
    if [[ $exitstatus = 0 ]]; then
        loadkeys "$selected_keymap"
    fi
    main_menu
}

select_mirrorlist(){
    selected_countries=($(whiptail --title "$title" --checklist --separate-output "$message" $lines $cols 15 \
    "TR" "Turkey" on \
    "FR" "France" off 3>&1 1>&2 2>&3))

}


mirrorlist_manager(){
    title="Mirror Menager"
    message="Select a mirrorlist method"
    selected_mirrorlist_method=$(whiptail --title "$title" --radiolist "$message" $lines $cols 16 \
    "Rankmirrors" "List by speed" on \
    "Specificmirrors" "Legacy boot method" off 3>&1 1>&2 2>&3)
    exitstatus=$?

    if [ $exitstatus = 0 ]; then
        Rankmirrors="false" Specificmirrors="false"
        case $selected_mirrorlist_method in
        "Rankmirrors" )
            Rankmirrors="true"
            selected_countries="ranked"
            #selected_countries filled for installation check.
            ;;
        "Specificmirrors" )
            Specificmirrors="true"
            message="Select mirrors:"
            if [[ -z ${selected_countries[@]} ]]; then
                select_mirrorlist
            else
                message="Selected mirrors:\n ${selected_countries[@]} \n\nif you want to change say yes."
                if (whiptail --title "$title" --yesno "$message" $lines $cols) then
                    select_mirrorlist
                fi
            fi
            ;;
        esac
	fi
    main_menu
}

set_mirrorlist(){
	pacman -Sy
    pacman -S --noconfirm pacman-mirrorlist

	if [ -f "/etc/pacman.d/mirrorlist.pacnew" ]; then
        mv "/etc/pacman.d/mirrorlist.pacnew" "/etc/pacman.d/mirrorlist.backup"
    else
        mv "/etc/pacman.d/mirrorlist" "/etc/pacman.d/mirrorlist.backup"
    fi

    sed -i 's/^#Server/Server/' "/etc/pacman.d/mirrorlist.backup"

    if [[ $Rankmirrors = "true" ]]; then
    	rankmirrors "/etc/pacman.d/mirrorlist.backup" > "/etc/pacman.d/mirrorlist.new"
    fi

    if [[ $Specificmirrors = "true" ]]; then
        for selected_country in "${selected_countries[@]}"; do

            mirror_gen_url="https://www.archlinux.org/mirrorlist/?country=$selected_country&use_mirror_status=on"

            if [ ! -f "/etc/pacman.d/mirrorlist.countries" ]; then
                curl $mirror_gen_url > "/etc/pacman.d/mirrorlist.countries"
            else
                curl $mirror_gen_url | sed -n '5,$p' >> "/etc/pacman.d/mirrorlist.countries"
            fi
        done
    
        rankmirrors "/etc/pacman.d/mirrorlist.countries" > "/etc/pacman.d/mirrorlist.new"
    fi
    
    rm "/etc/pacman.d/mirrorlist"
    mv "/etc/pacman.d/mirrorlist.new" "/etc/pacman.d/mirrorlist"
}


disk_manager(){
    title="Disk Manager"
    message="Select a disk or partition for configuration:\n"
    
    unset disk_list
    i=0
    disks=($(lsblk -io KNAME | grep 'sd[a-z]'))
    for disk in ${disks[@]} ;do
        disk_list[i]="/dev/"$disk
        type="$(lsblk --noheadings -d -o TYPE,FSTYPE,SIZE,LABEL,MODEL,MOUNTPOINT "${disk_list[i]}")"
        i=$((i+1))
        disk_list[i]=$type
        i=$((i+1))
    done
    
    selected_disk=$(whiptail --title "$title" --menu "$message" $lines $cols 16 "${disk_list[@]}" 3>&1 1>&2 2>&3)
    exitstatus=$?
    if [ $exitstatus = 0 ]; then
        selected_disk_type="$(lsblk --noheadings -d -o TYPE "$selected_disk")"
        if [ $selected_disk_type = "disk" ]; then
            partition_manager
        else
            format_manager
        fi
    fi
    main_menu
}

partition_manager(){
    title="Disk Menager"
    message="Choose a partition Manager for configuration the $selected_disk"
    selected_disk_manager=$(whiptail --title "$title" --menu "$message" $lines $cols 16 \
    "cfdisk" "for MBR and GPT partitions" \
    "cgdisk" "for GPT partitions" 3>&1 1>&2 2>&3)
    exitstatus=$?
    
    if [ $exitstatus = 0 ]; then
        case $selected_disk_manager in
        "cfdisk" )
            cfdisk $selected_disk;;
        "cgdisk" )
            cgdisk $selected_disk;;
        esac
    fi
    disk_manager
}

format_manager(){
    title="Disk Menager"
    message="Format the $selected_disk partition"
    selected_format=$(whiptail --title "$title" --menu "$message" $lines $cols 16 \
    "none" "Do not format" \
    "fat32" "efi boot partition" \
    "ext4" "fourth extended filesystem" \
    "swap" "swap partition" 3>&1 1>&2 2>&3)
    exitstatus=$?
    
    if [ $exitstatus = 0 ]; then
        case $selected_format in
        "none" )
            ;;
        "fat32" )
            mkfs.fat -F32 $selected_disk;;
        "ext4" )
            mkfs.ext4 -F $selected_disk;;
        "swap" )
            mkswap -f $selected_disk;;
        esac
        mount_manager
    fi
    disk_manager
}

check_mounted_fs(){
echo $(lsblk -l | grep "$1$" | awk '{print "/dev/" $1}')
}

mount_manager(){
    title="Disk Manager"

    RootDisk=$(check_mounted_fs "/mnt")
    mounted_dir="$(lsblk --noheadings -d -o MOUNTPOINT "$selected_disk")"
    
    if [[ -z $RootDisk ]]; then
        if [[ $mounted_dir = "[SWAP]" ]]; then
            swapoff $selected_disk
        else
            message="First you must mount /mnt. \nWould you mount /dev/sda1 to /mnt \n\n If you want another partition mount to /mnt please select No"
            if (whiptail --title "$title" --yesno "$message" $lines $cols) then
            mount $selected_disk /mnt
            fi
        fi
    else
        message="mount the $selected_disk"
        selected_dir=$(whiptail --title "$title" --menu "$message" $lines $cols 16 \
        "none" "Do not mount" \
        "/mnt/boot" "for efi or grub boot partition" \
        "/mnt/home" "for user home directory" \
        "[SWAP]" "for swap" 3>&1 1>&2 2>&3)
        exitstatus=$?
        
        if [ $exitstatus = 0 ]; then
            if [[ ! -z $mounted_dir ]] && [[ $mounted_dir != $selected_dir ]]; then
            case $mounted_dir in
                "[SWAP]" )
                    swapoff $selected_disk
                    ;;
                * )
                    umount -R $mounted_dir
                    ;;
            esac
            fi
            case $selected_dir in
            "none" )
                ;;
            "[SWAP]" )
                swapon $selected_disk ;;
            * )
                mkdir -p $selected_dir
                mount $selected_disk $selected_dir ;;
            esac
        fi
    fi
}

boot_manager(){
    title="Boot Manager"

    RootDisk=$(check_mounted_fs "/mnt")
    BootDisk=$(check_mounted_fs "/mnt/boot")
    if [[ -z $BootDisk ]]; then
        BootDisk=$RootDisk
    fi
    
    if [[ ! -z $selected_boot ]]; then
        message="Selected Boot:\n $selected_boot \n\n if you want to change say yes."
        if (whiptail --title "$title" --yesno "$message" $lines $cols) then
        select_boot
        fi
    else
    select_boot
    fi
main_menu
}

select_boot(){
    message="Select a boot method"
    selected_boot=$(whiptail --title "$title" --radiolist "$message" $lines $cols 16 \
    "Uefi" "The motherboard should be uefi supported." off \
    "Grub" "Legacy boot method" on 3>&1 1>&2 2>&3)
    exitstatus=$?
    
    if [ $exitstatus = 0 ]; then
        boot_uefi="false" boot_grub="false"
        case $selected_boot in
        "Uefi" )
            boot_uefi="true"
            ;;
        "Grub" )
            boot_grub="true"
            ;;
        esac
    fi
}

set_boot(){
    if [[ $boot_uefi = "true" ]]; then
        rm /mnt/boot/loader/loader.conf
        arch-chroot /mnt bootctl install
        RootDiskUUID=$(blkid -s PARTUUID -o value $RootDisk)
        echo "title Arch Linux" > /mnt/boot/loader/entries/arch.conf
        echo "linux /vmlinuz-linux" >> /mnt/boot/loader/entries/arch.conf
        echo "initrd /initramfs-linux.img" >> /mnt/boot/loader/entries/arch.conf
        echo "options root=PARTUUID=$RootDiskUUID rw" >> /mnt/boot/loader/entries/arch.conf
    fi
            
    if [[ $boot_grub = "true" ]]; then
        arch-chroot /mnt pacman -S --noconfirm grub
        BootDisk=$(echo $BootDisk | sed s'/.$//')
        arch-chroot /mnt grub-install --recheck $BootDisk
        arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg
    fi
}

user_manager(){
title="User Manager"
root_check
user_check
main_menu
}

root_check(){
    if [[ ! -z $root_password ]]; then
        message="Already root password was entered \nif you want to change say yes."
        if (whiptail --title "$title" --yesno "$message" $lines $cols) then
            root_password=
            root_password_check=
            ask_root_password
            while [[ $root_password != $root_password_check ]] && [[ ! -z $root_password ]]; do
                ask_root_password
            done
        fi
    else    
    root_password=
    root_password_check=
    ask_root_password
    while [[ $root_password != $root_password_check ]] && [[ ! -z $root_password ]]; do
        ask_root_password
    done
    fi
}

user_check(){
    title="User Manager"
    if [[ ! -z $username ]]; then
            message="User Name is: $username \n\n if you want to change say yes."
        if (whiptail --title "$title" --yesno "$message" $lines $cols) then
            get_userinfo
        fi
    else
    get_userinfo
    fi    
}

get_userinfo(){
message="Enter a user name:"
username=$(whiptail --title "$title" --inputbox "$message" $lines $cols  3>&1 1>&2 2>&3)
exitstatus=$?
if [ $exitstatus = 0 ]; then
    user_password=
    user_password_check=

    ask_user_password
    while [[ $user_password != $user_password_check ]] && [[ ! -z $user_password ]]; do
    ask_user_password
    done

    message="Would you like to make it a manager."
    if (whiptail --title "$title" --yesno "$message" $lines $cols) then
        wheel_user="true"
    else
        wheel_user="false"
    fi
fi
}

ask_user_password(){
        message="please enter a password for $username:"
        user_password=$(password_menu "$message" )
        
        message="please enter again the password for check:"
        user_password_check=$(password_menu "$message" )
}

ask_root_password(){
        message="please enter a password for root:"
        root_password=$(password_menu "$message" )
        
        message="please enter again the password for check:"
        root_password_check=$(password_menu "$message" )
}

password_menu(){
message=$1
password=$(whiptail --title "$title" --passwordbox "$message" $lines $cols  3>&1 1>&2 2>&3)
echo "$password"
}

set_user(){
    if [[ $wheel_user = "true" ]]; then
        arch-chroot /mnt useradd -m -g users -G wheel -s /bin/bash $username
    else
        arch-chroot /mnt useradd -m -g users -s /bin/bash $username
    fi
    echo -e "$user_password\n$user_password" | arch-chroot /mnt passwd $username
    echo -e "$root_password\n$root_password" | arch-chroot /mnt passwd root
}

driver_manager(){
    title="Driver Manager"
    message="Selected drivers: ${selected_drivers[@]} \n\n if you want to change say yes."
    if [[ ! -z ${selected_drivers[@]} ]]; then
        if (whiptail --title "$title" --yesno "$message" $lines $cols) then
            unset selected_drivers
            select_drivers
        fi
    else
        select_drivers
    fi
    main_menu
}

select_drivers(){
    message="Select your drivers:"
    selected_drivers=($(whiptail --title "$title" --checklist --separate-output "$message" $lines $cols 16 \
    "pulseaudio" "With alsa audio" on \
    "networkmanager" "Netowk Manager" on \
    "amdgpu" "amd gpu driver" off \
    "intel" "intel gpu driver" off \
    "nouveau" "nvidia open driver" off \
    "nvidia" "nvidia proprietary driver" off \
    "cups" "printer support" on \
    "hplip" "hp printer support" on \
    "trim" "trim harddisk support" on \
    "vboxguest" "if this computer is a virtualbox guest" off 3>&1 1>&2 2>&3))
}

install_drivers(){
    for driver in "${selected_drivers[@]}"; do
        case "$driver" in
        "pulseaudio")
            arch-chroot /mnt pacman -S --noconfirm alsa-utils pulseaudio-alsa
            ;;
        "networkmanager")
            arch-chroot /mnt pacman -S --noconfirm networkmanager
            arch-chroot /mnt systemctl enable NetworkManager.service
            ;;
        "amdgpu")
            arch-chroot /mnt pacman -S --noconfirm xf86-video-amdgpu vulkan-radeon mesa-libgl lib32-mesa-libgl mesa-vdpau libva-mesa-driver
            ;;
        "intel")
            arch-chroot /mnt pacman -S --noconfirm xf86-video-intel vulkan-intel mesa-libgl lib32-mesa-libgl libva-intel-driver libvdpau-va-gl
            ;;
        "nouveau")
            arch-chroot /mnt pacman -S --noconfirm xf86-video-nouvea mesa-libgl lib32-mesa-libgl mesa-vdpau libva-vdpau-driver
            ;;
        "nvidia")
            arch-chroot /mnt pacman -S --noconfirm nvidia nvidia-libgl lib32-nvidia-libgl libva-vdpau-driver
            ;;
        "cups")
            arch-chroot /mnt pacman -S --noconfirm cups
            arch-chroot /mnt systemctl enable org.cups.cupsd.service
            ;;
        "hplip")
            arch-chroot /mnt pacman -S --noconfirm hplip python-gobject python-pyqt5 wget
            ;;
        "trim")
            arch-chroot /mnt systemctl enable fstrim.timer
            ;;
        "vboxguest")
            arch-chroot /mnt pacman -S --noconfirm virtualbox-guest-modules-arch
            ;;
        esac
    done
}

program_manager(){
    title="Program Manager"
    message="Selected programs: ${selected_programs[@]} \n\n if you want to change say yes."
    if [[ ! -z ${selected_programs[@]} ]]; then
        if (whiptail --title "$title" --yesno "$message" $lines $cols) then
            unset selected_programs
            select_programs
        fi
    else
        select_programs
    fi
    main_menu
}

select_programs(){
    message="Select your programs"
    selected_programs=($(whiptail --title "$title" --checklist --separate-output "$message" $lines $cols 16 \
    "Blender" "3d modelling" off \
    "Digikam" "Photo archive manager" off \
    "Firefox" "Internet Browser" off \
    "Libreoffice" "Office program" off \
    "Steam" "steam game platform" off \
    "Cantata" "Music player" off \
    "Virtualbox" "Virtual pc" off 3>&1 1>&2 2>&3))
}

install_programs(){
    for driver in "${selected_programs[@]}"; do
        case "$driver" in
        "Blender")
            arch-chroot /mnt pacman -S --noconfirm blender
            ;;
        "Digikam")
            arch-chroot /mnt pacman -S --noconfirm digikam
            ;;
        "Firefox")
            arch-chroot /mnt pacman -S --noconfirm firefox
            ;;
        "Libreoffice")
            arch-chroot /mnt pacman -S --noconfirm libreoffice-fresh
            ;;
        "Steam")
            arch-chroot /mnt pacman -S --noconfirm steam

            ;;
        "Cantata")
            arch-chroot /mnt pacman -S --noconfirm cantata perl-uri mpd

            mv /mnt/etc/mpd.conf /mnt/etc/mpd.conf.default

            mkdir /mnt/home/mpd
            chown mpd:audio /mnt/home/mpd

            mkdir /mnt/home/mpd/music
            chown  -R $username:audio /mnt/home/mpd/music

            mkdir /mnt/home/mpd/playlist
            chown mpd:audio /mnt/home/mpd/playlist

            touch /mnt/home/mpd/sticker.sql
            chown mpd:audio /mnt/home/mpd/sticker.sql

            touch /mnt/home/mpd/database
            chown mpd:audio /mnt/home/mpd/database

            echo '# See: /usr/share/doc/mpd/mpdconf.example

music_directory "/home/mpd/music"
playlist_directory "/home/mpd/playlist"
db_file "/home/mpd/database"
log_file "/home/mpd/log"
pid_file "/home/mpd/pid"
state_file "/home/mpd/state"
sticker_file "/home/mpd/sticker.sql"

audio_output {
type        "pulse"
name        "MPD Pulse Output"
server      "127.0.0.1"
}' > /mnt/etc/mpd.conf

            LineNum=$(grep -n "load-module module-native-protocol-tcp" /mnt/etc/pulse/default.pa | head -1 | cut -f1 -d:)
            LineNum=$(( $LineNum + 1 ))
            sed -i "$LineNum i \load-module module-native-protocol-tcp auth-ip-acl=127.0.0.1" /mnt/etc/pulse/default.pa

            arch-chroot /mnt systemctl enable mpd.service
            ;;
        "Virtualbox")
            arch-chroot /mnt pacman -S --noconfirm virtualbox-host-modules-arch
            arch-chroot /mnt pacman -S --noconfirm virtualbox
            arch-chroot /mnt gpasswd -a $username vboxusers
            arch-chroot /mnt for module in `ls /lib/modules/$(uname -r)/kernel/misc/{vboxdrv.ko,vboxnetadp.ko,vboxnetflt.ko,vboxpci.ko}` do ./scripts/sign-file sha1 certs/signing_key.pem certs/signing_key.x509 $module done
            ;;
        esac
    done
}

desktop_manager(){
    title="Desktop Manager"
    message="Selected desktops: ${selected_desktops[@]} \n\n if you want to change say yes."
    if [[ ! -z ${selected_desktops[@]} ]]; then
        if (whiptail --title "$title" --yesno "$message" $lines $cols) then
            unset selected_desktops
            select_desktops
        fi
    else
    select_desktops
    fi
    main_menu
}

select_desktops(){
    message="Select your desktop:"
    selected_desktops=($(whiptail --title "Desktop Manager" --checklist --separate-output "Choose and install desktop managers:" $lines $cols 15 \
    "Gnome" "Gnome desktop" off \
    "Plasma" "plasma5 desktop" on \
    "XFCE" "xfce4 desktop" off 3>&1 1>&2 2>&3))
}

install_desktops(){
    for desktop in "${selected_desktops[@]}"; do
        case $desktop in
        "Gnome")
            arch-chroot /mnt pacman -S --noconfirm gnome gnome-extra flatpak-builder

            arch-chroot /mnt pacman -S --noconfirm gnome-boxes gnome-games gnome-recipes gnome-software

            arch-chroot /mnt systemctl enable gdm.service
            ;;

        "Plasma")
            arch-chroot /mnt pacman -S --noconfirm phonon-qt5-vlc libx264

            arch-chroot /mnt pacman -S --noconfirm plasma packagekit-qt5

            arch-chroot /mnt systemctl enable sddm.service

            echo "[Autologin]
Relogin=false
Session=
User=

[General]
HaltCommand=
RebootCommand=

[Theme]
Current=breeze
CursorTheme=Breeze_Snow

[Users]
MaximumUid=65000
MinimumUid=1000" > /mnt/etc/sddm.conf

            # base
            arch-chroot /mnt pacman -S --noconfirm dolphin kate konsole
            arch-chroot /mnt pacman -S --noconfirm xdg-user-dirs
            arch-chroot /mnt pacman -S --noconfirm ttf-dejavu ttf-liberation

            # admin
            arch-chroot /mnt pacman -S --noconfirm kcron cronie ksystemlog systemd-kcm
            arch-chroot /mnt pacman -S --noconfirm partitionmanager

            # graphics
            arch-chroot /mnt pacman -S --noconfirm gwenview kolourpaint okular spectacle krita
            arch-chroot /mnt pacman -S --noconfirm kimageformats kipi-plugins qt5-imageformats kdegraphics-mobipocket kdegraphics-thumbnailers

            # multimedia
            arch-chroot /mnt pacman -S --noconfirm dragon ffmpegthumbs elisa kdenlive recordmydesktop

            # network
            arch-chroot /mnt pacman -S --noconfirm falkon kdenetwork-filesharing smb4k krdc krfb ktorrent 

            # pim
            arch-chroot /mnt pacman -S --noconfirm \
                akonadi-calendar-tools \
                akonadiconsole \
                akregator \
                grantlee-editor \
                kaddressbook \
                kalarm \
                kdepim-addons \
                kleopatra \
                kmail \
                knotes \
                kontact \
                korganizer \
                pim-data-exporter


            # utils
            arch-chroot /mnt pacman -S --noconfirm ark filelight kcalc kcharselect kgpg kwalletmanager print-manager
            arch-chroot /mnt pacman -S --noconfirm p7zip unrar unzip zip

            # office
            arch-chroot /mnt pacman -S --noconfirm calligra
        
            # Develop
            arch-chroot /mnt pacman -S --noconfirm kdevelop cmake git
            arch-chroot /mnt pacman -S --noconfirm kdevelop-python python-pyqt5
            
            # Accessories
            arch-chroot /mnt pacman -S --noconfirm plasma5-applets-redshift-control
            ;;

        "XFCE")
            arch-chroot /mnt pacman -S --noconfirm xfce4 xfce4-goodies
            
            arch-chroot /mnt pacman -S --noconfirm lightdm lightdm-gtk-greeter
            arch-chroot /mnt systemctl enable lightdm.service
            ;;
        esac
    done
    
    echo "/* Allow members of the wheel group to execute any actions
 * without password authentication, similar to "sudo NOPASSWD:"
 */
polkit.addRule(function(action, subject) {
    if (subject.isInGroup("wheel")) {
        return polkit.Result.YES;
    }
});" > /mnt/etc/polkit-1/rules.d/49-nopasswd_global.rules
}

install_base(){
	pacstrap /mnt base base-devel
	genfstab -U /mnt >> /mnt/etc/fstab

	cp "/etc/pacman.d/mirrorlist.backup" "/mnt/etc/pacman.d/mirrorlist.backup"
}

hostname_manager(){
    title="Hostname Manager"
    hostname=$(whiptail --title "$title" --inputbox "$message" $lines $cols  3>&1 1>&2 2>&3)
    main_menu
}

set_hostname(){
    echo $hostname > /mnt/etc/hostname
}


set_sudo(){
    Wheel=$(grep -n "%wheel ALL=(ALL) ALL" /mnt/etc/sudoers | cut -f1 -d:)
    sed -i "$Wheel s/^# //g" /mnt/etc/sudoers
}

set_multilib(){
    LineNum=$(grep -n "\[multilib\]" /mnt/etc/pacman.conf | cut -f1 -d:)
    sed -i "$LineNum s/^#//g" /mnt/etc/pacman.conf
    LineNum=$(( $LineNum + 1 ))
    sed -i "$LineNum s/^#//g" /mnt/etc/pacman.conf
    arch-chroot /mnt pacman -Sy
}

set_locale(){
    #Burasi icin menu olusturulacak.
    encoding="#en_US.UTF-8 UTF-8"
    LineNum=$(grep -n "$encoding" /mnt/etc/locale.gen | cut -f1 -d:)
    sed -i "$LineNum s/^#//g" /mnt/etc/locale.gen
    
    encoding="#tr_TR.UTF-8 UTF-8"
    LineNum=$(grep -n "$encoding" /mnt/etc/locale.gen | cut -f1 -d:)
    sed -i "$LineNum s/^#//g" /mnt/etc/locale.gen

    arch-chroot /mnt locale-gen

    echo 'LANG=en_US.UTF-8' > /mnt/etc/locale.conf
    ln -s -f /mnt/usr/share/zoneinfo/Turkey /mnt/etc/localtime
    arch-chroot /mnt systemctl enable systemd-timesyncd.service
    arch-chroot /mnt hwclock --systohc --utc
}

set_headphone(){
    file="/mnt/usr/share/pulseaudio/alsa-mixer/paths/analog-output-lineout.conf"
    LineNum=$(grep -n "Jack Front Headphone" $file | head -1 | cut -f1 -d:)
    LineNum=$(( $LineNum + 1 ))
    sed -i "${LineNum}s/.*/state.plugged = yes/" $file

    file="/mnt/usr/share/pulseaudio/alsa-mixer/paths/analog-output-headphones.conf"
    LineNum=$(grep -n "Element Front" $file | head -1 | cut -f1 -d:)
    LineNum=$(( $LineNum + 1 ))
    sed -i "${LineNum}s/.*/switch = off/" $file
    LineNum=$(( $LineNum + 1 ))
    sed -i "${LineNum}s/.*/volume = off/" $file

    file="/mnt/etc/pulse/default.pa"
    LineNum=$(grep -n "load-module module-udev-detect" $file | head -1 | cut -f1 -d:)
    sed -i "${LineNum}s/.*/#load-module module-udev-detect\nload-module module-udev-detect tsched=0/" $file
    
    echo "[Unit]
Description=Create alsa state file and disable automute
After=sound.target

[Service]
Type=simple
ExecStart=/usr/bin/myalsa.sh

[Install]
WantedBy=multi-user.target" > /mnt/etc/systemd/system/myalsa.service
    
    arch-chroot /mnt systemctl daemon-reload
    arch-chroot /mnt systemctl enable myalsa.service
    
    echo "#!/bin/bash

echo 0 > /sys/module/snd_hda_intel/parameters/power_save

amixer -c 0 sset 'Auto-Mute Mode' Disabled
alsactl store

sleep 2 

systemctl start alsa-restore.service

systemctl disable myalsa.service
rm /etc/systemd/system/myalsa.service
systemctl daemon-reload
rm /usr/bin/myalsa.sh" > /mnt/usr/bin/myalsa.sh

    chmod +x /mnt/usr/bin/myalsa.sh
}

set_samba(){
    arch-chroot /mnt pacman -S --noconfirm samba
    mkdir -p /mnt/var/lib/samba/usershares
    arch-chroot /mnt groupadd -r sambashare
    arch-chroot /mnt chown root:sambashare /var/lib/samba/usershares
    arch-chroot /mnt chmod 1770 /var/lib/samba/usershares

    sambaconf="/mnt/etc/samba/smb.conf"
    curl "https://git.samba.org/samba.git/?p=samba.git;a=blob_plain;f=examples/smb.conf.default;hb=HEAD" > $sambaconf
    LineNum=$(grep -n "\[global\]" $sambaconf | cut -f1 -d:)
    LineNum=$(( $LineNum + 1 ))
    sed -i "$LineNum i \   usershare owner only = yes" $sambaconf
    sed -i "$LineNum i \   usershare allow guests = yes" $sambaconf
    sed -i "$LineNum i \   usershare max shares = 100" $sambaconf
    sed -i "$LineNum i \   usershare path = /var/lib/samba/usershares" $sambaconf
    sed -i 's/^   workgroup = MYGROUP/   workgroup = WORKGROUP/' $sambaconf

    arch-chroot /mnt systemctl enable smb.service nmb.service
    
    arch-chroot /mnt gpasswd sambashare -a $username
    echo -e "$user_password\n$user_password" | arch-chroot /mnt smbpasswd -a $username
}

check_install(){
title="Check Manager"
check_status="true"

if [[ -z ${selected_countries[@]} ]]; then
    message="Mirror list not configurated"
    whiptail --title "$title" --msgbox "$message" $lines $cols
    check_status="false"
fi

if [[ -z $RootDisk ]]; then
    message="/mnt not mounted"
    whiptail --title "$title" --msgbox "$message" $lines $cols
    check_status="false"
fi

if [[ -z $selected_boot ]]; then
    message="Boot manager not selected"
    whiptail --title "$title" --msgbox "$message" $lines $cols
    check_status="false"
fi

if [[ -z $username ]]; then
    message="User not created pls create a user"
    whiptail --title "$title" --msgbox "$message" $lines $cols
    check_status="false"
fi

if [[ -z $user_password ]]; then
    message="User Password not created pls create a user password"
    whiptail --title "$title" --msgbox "$message" $lines $cols
    check_status="false"
fi

if [[ -z $root_password ]]; then
    message="Root Password not created pls create a root password"
    whiptail --title "$title" --msgbox "$message" $lines $cols
    check_status="false"
fi

if [[ "$check_status" = "true" ]]; then
    start_install
fi
main_menu
}

start_install(){
    message="drivers:\n ${selected_drivers[@]} \n\n programs:\n ${selected_programs[@]} \n\n $pulseaudio $networkmanager $amdgpu $cups $trim $vboxguest"
    if (whiptail --title "$title" --yesno "$message" $lines $cols) then
    set_mirrorlist
    install_base
    set_boot
    set_locale
    set_hostname
    set_user
    set_sudo
    set_multilib
    install_drivers
    install_desktops
    install_programs
    set_headphone
    set_samba
    else
        main_menu
    fi
}
main_menu
