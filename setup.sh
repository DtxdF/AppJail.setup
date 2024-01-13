#!/bin/sh
#
# BSD 3-Clause License
#
# Copyright (c) 2023, Jesús Daniel Colmenares Oviedo <DtxdF@disroot.org>
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# 1. Redistributions of source code must retain the above copyright notice, this
#    list of conditions and the following disclaimer.
#
# 2. Redistributions in binary form must reproduce the above copyright notice,
#    this list of conditions and the following disclaimer in the documentation
#    and/or other materials provided with the distribution.
#
# 3. Neither the name of the copyright holder nor the names of its
#    contributors may be used to endorse or promote products derived from
#    this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
# CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
# OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

APPSDIR="${APPSDIR:-/root/applications}"

PREFIX="/usr/local"
SHAREDIR="${PREFIX}/share/appjail"
FILESDIR="${SHAREDIR}/files"
ETCDIR="${PREFIX}/etc/appjail"
CONF="${ETCDIR}/appjail.conf"
DNSCONF="${FILESDIR}/dnsmasq.conf"
RESOLVCONF="${ETCDIR}/resolv.conf"
BOOTFS="/boot"
LOADERCONF="${BOOTFS}/loader.conf"

main()
{
    if ! check_superuser; then
        err "You need to be the superuser to use this script."
        exit 1
    fi

    if ! check_appjail; then
        if ! askyesno "Do you want to install AppJail?"; then
            err "You need AppJail to continue."
            exit 1
        fi

        info

        askchoice "Choose a method to install AppJail" \
            "Bleeding-Edge - Development version from git(1) repository" \
            "sysutils/appjail - Stable version from pkg(8) repository" \
            "sysutils/appjail-devel - Development version from pkg(8) repository"

        local install_method=$?

        if [ ${install_method} -eq 1 ]; then
            if ! check_git; then
                info "Installing devel/git"

                if ! pkg install -y devel/git; then
                    err "Error installing devel/git"
                    exit 1
                fi
            fi

            if ! mkdir -p "${APPSDIR}"; then
                err "Error creating ${APPSDIR}"
                exit 1
            fi

            if [ ! -d "${APPSDIR}/AppJail" ]; then
                info "Cloning AppJail repository"

                if ! git -C "${APPSDIR}" clone "https://github.com/DtxdF/AppJail.git"; then
                    err "Error cloning the repository 'github.com/DtxdF/AppJail'"
                    exit 1
                fi
            fi

            (cd "${APPSDIR}/AppJail"; make APPJAIL_VERSION=`make -V APPJAIL_VERSION`+`git rev-parse HEAD` install)
        elif [ ${install_method} -eq 2 ]; then
            info "Installing sysutils/appjail"
            pkg install -y sysutils/appjail
        else
            info "Installing sysutils/appjail-devel"
            pkg install -y sysutils/appjail-devel
        fi
    fi

    if [ -f "${CONF}" ]; then
        warn
        warn "Your AppJail configuration file will be overwritten."
        warn

        if ! askyesno "Do you want to overwrite your AppJail configuration file?"; then
            exit 0
        fi
    fi

    create_conf

    if ! check_git; then
        info
        info "devel/git is required to clone repositories containing Makejails and files used"
        info "to get and update images."
        info

        if askyesno "Do you want to install git?"; then
            pkg install -y devel/git
        fi
    fi

    local default_interface
    default_interface=`get_default_interface`

    info
    info "The external interface represents the interface that provides connection to the"
    info "outside, usually representing Internet."
    info

    local ext_if=`ask "Which interface do you want to use?" "${default_interface}"`

    if check_empty "${ext_if}"; then
        err "You must define an external interface to continue."
        exit 1
    fi

    echo "EXT_IF=${ext_if}" >> "${CONF}"
    echo "ON_IF=${ext_if}" >> "${CONF}"

    local appjail_enable appjail_enabled=false
    appjail_enable=`getsysrc appjail_enable`

    if [ -z "${appjail_enable}" ] || ! checkyesno appjail_enable "${appjail_enable}"; then
        info
        info "This rc script is responsible for starting the jails at system startup. If you"
        info "want to start your jails at startup, enable this service."
        info

        if askyesno "Do you want to enable AppJail rc script?"; then
            info "Enabling AppJail rc script"
            sysrc appjail_enable=YES

            appjail_enabled=true
        fi
    else
        appjail_enabled=true
    fi

    if ${appjail_enabled}; then
        local appjail_health_enable
        appjail_health_enable=`getsysrc appjail_health_enable`

        info
        info "If you want to supervise your jails and their services, you need to enable the healthcheckers."
        info
        info "Remember: if you have not defined a healthchecker in at least one of your jails,"
        info "          this rc script will not start."
        info

        if askyesno "Do you want to enable supervisor/healthcheckers?"; then
            info "Enabling AppJail Healthcheckers"
            sysrc appjail_health_enable=YES
        fi
    fi

    local appjail_natnet_enable
    appjail_natnet_enable=`getsysrc appjail_natnet_enable`

    if [ -z "${appjail_natnet_enable}" ] || ! checkyesno appjail_natnet_enable "${appjail_natnet_enable}"; then
        info
        info "You can enable NAT per network instead of per jail, but you need to enable this"
        info "rc script."
        info

        if askyesno "Do you want to enable NAT per network?"; then
            sysrc appjail_natnet_enable=YES
        fi
    fi

    local appjail_dns_enable
    appjail_dns_enable=`getsysrc appjail_dns_enable`

    if [ -z "${appjail_dns_enable}" ] || ! checkyesno appjail_dns_enable "${appjail_dns_enable}"; then
        info
        info "DNS in AppJail is very useful when you don't want to deal with IP addresses,"
        info "instead, you will use a handy name that also identifies the jail."
        info

        if askyesno "Do you want to use DNS in AppJail?"; then
            if ! check_dnsmasq; then
                info "Installing dns/dnsmassq"
                pkg install -y dns/dnsmasq
            fi

            info "Enabling dnsmasq"
            sysrc dnsmasq_enable=YES

            info "Enabling appjail-dns"
            sysrc appjail_dns_enable=YES

            local dnsmasq_conf
            dnsmasq_conf=`getsysrc dnsmasq_conf`

            if check_empty "${dnsmasq_conf}"; then
                if askyesno "Do you want to use a DNSMasq configuration file intended for use with AppJail?"; then
                    sysrc dnsmasq_conf=${DNSCONF}
                else
                    warn "Make sure to use a valid configuration file for DNSMasq that works well with AppJail."
                fi
            fi

            local dns_iface
            dns_iface=`ask "What do you want to name your DNS interface?" "ajdns"`
            dns_iface=`printf "%s" "${dns_iface}" | tr -d '[:space:]' | cut -b-15`

            local dns_ip
            dns_ip=`ask "Which IPv4 address do you want to use for this interface?" "172.0.0.1"`

            local shorten_domain_names

            if askyesno "Do you want to shorten domain names?"; then
                shorten_domain_names=true
            else
                shorten_domain_names=false
            fi

            local ajdns
            ajdns=`ifconfig tap create`

            if [ $? -ne 0 ]; then
                err "Error creating interface ${dns_iface}"
                exit 1
            fi

            if ! ifconfig "${ajdns}" name "${dns_iface}"; then
                err "Error renaming ${ajdns} -> ${dns_iface}"
                exit 1
            fi

            if ! ifconfig "${dns_iface}" inet "${dns_ip}/32"; then
                err "Error configuring IPv4 address '${dns_ip}/32' in '${dns_iface}'"
                exit 1
            fi

            info "Configuring interface for use with DNS"
            sysrc cloned_interfaces+="${ajdns}"
            sysrc ifconfig_${ajdns}_name="${dns_iface}"
            sysrc ifconfig_${dns_iface}="inet ${dns_ip}/32"

            echo "nameserver ${dns_ip}" > "${RESOLVCONF}"
            echo "DEFAULT_RESOLV_CONF=${RESOLVCONF}" >> "${CONF}"

            if ${shorten_domain_names}; then
                echo "SHORTEN_DOMAIN_NAMES=1" >> "${CONF}"
            else
                echo "SHORTEN_DOMAIN_NAMES=0" >> "${CONF}"
            fi

            if ! touch /var/tmp/appjail-hosts; then
                err "Error creating /var/tmp/appjail-hosts"
                exit 1
            fi

            info "Restarting dnsmasq"
            service dnsmasq restart

            info "Starting appjail-dns"
            service appjail-dns start
        fi
    fi

    if askyesno "Do you want to create a loopback interface for LinuxJails?"; then
        local lin_iface
        lin_iface=`ask "What do you want to name your LinuxJails interface?" "appjail0"`
        lin_iface=`printf "%s" "${lin_iface}" | tr -d '[:space:]' | cut -b-15`

        local loopiface
        loopiface=`ifconfig lo create`

        if [ $? -ne 0 ]; then
            err "Error creating interface ${lin_iface}"
            exit 1
        fi

        if ! ifconfig "${loopiface}" name "${lin_iface}"; then
            err "Error renaming ${loopiface} -> ${lin_iface}"
            exit 1
        fi

        info "Configuring interface for use with LinuxJails"
        sysrc cloned_interfaces+="${loopiface}"
        sysrc ifconfig_${loopiface}_name="${lin_iface}"
    fi

    if ! check_debootstrap; then
        info
        info "If you want to create LinuxJails, you need to install sysutils/debootstrap."
        info

        if askyesno "Do you want to install Debootstrap?"; then
            pkg install -y sysutils/debootstrap
        fi
    fi

    local pf_enable write_pf_rules=false
    pf_enable=`getsysrc pf_enable`

    if [ -z "${pf_enable}" ] || ! checkyesno pf_enable "${pf_enable}"; then
        info
        info "Packet filtering must be enabled to use features such as port forwarding and NAT."
        info

        if askyesno "Do you want to enable pf?"; then
            local pf_rules
            pf_rules=`getsysrc pf_rules` || exit $?
            pf_rules="${pf_rules:-/etc/pf.conf}"

            info "Enabling pf"

            sysrc pf_enable=YES
            sysrc pflog_enable=YES

            write_pf_rules=true
        fi
    else
        write_pf_rules=true
    fi

    if ${write_pf_rules}; then
        write_pf_rules "${pf_rules}"

        info "Configuring IP forwarding"
        sysrc gateway_enable=YES
        sysctl net.inet.ip.forwarding=1
    fi

    info
    info "If you are using ZFS on this system, you can enable it in AppJail to take advantage of"
    info "this advanced file system."
    info
    info "Remember: If you have already been using AppJail with ZFS disabled, you need to remove"
    info "          or migrate your installation."
    info
    info "          1. Stop all your jails."
    info "          2. chflags -R 0 /usr/local/appjail"
    info "          3. rm -rf /usr/local/appjail"
    info

    if askyesno "Do you want to enable ZFS?" "NO"; then
        local zpool
        zpool=`ask "Which zpool do you want to use?" "zroot"`

        echo "ZPOOL=${zpool}" >> "${CONF}"
        echo "ENABLE_ZFS=1" >> "${CONF}"
    else
        echo "ENABLE_ZFS=0" >> "${CONF}"
    fi

    info
    info "AppJail uses a temporary directory for some volatile operations. To avoid preserving"
    info "this garbage in case of a power failure, you can use the tmpfs file system."
    info

    if askyesno "Do you wan to use tmpfs?"; then
        if [ ! -f /etc/fstab ] || ! grep -qEe '^[[:space:]]*tmpfs[[:space:]]*/usr/local/appjail/cache/tmp/.appjail[[:space:]]tmpfs[[:space:]]' /etc/fstab; then
            echo "tmpfs /usr/local/appjail/cache/tmp/.appjail tmpfs rw,late 0 0" >> /etc/fstab
        fi
        mount /usr/local/appjail/cache/tmp/.appjail
    fi

    info
    info "Enabling the debug level is useful for diagnosing problems, but it is very verbose."
    info

    if askyesno "Do you want to enable the debug level?" "NO"; then
        echo "ENABLE_DEBUG=1" >> "${CONF}"
    else
        echo "ENABLE_DEBUG=0" >> "${CONF}"
    fi

    if ! grep -qEe "^[[:space:]]*kern\.racct\.enable=1$" "${LOADERCONF}"; then
        info
        info "RACCT subsystem need to be enabled to limit resources."
        info
        info "Remember: Reboot your system to take effect."

        if askyesno "Do you want to enable the RACCT subsystem?"; then
            echo "kern.racct.enable=1" >> "${LOADERCONF}"
        fi
    fi

    local freebsd_version=`freebsd-version | grep -Eo '[0-9]+\.[0-9]+-[a-zA-Z0-9]+'`
    local freebsd_arch=`uname -m`
    local image_arch=`uname -p`

    info "Configuring FREEBSD_ARCH"
    echo "FREEBSD_ARCH=${freebsd_arch}" >> "${CONF}"

    info "Configuring FREEBSD_VERSION"
    echo "FREEBSD_VERSION=${freebsd_version}" >> "${CONF}"

    info "Configuring IMAGE_ARCH"
    echo "IMAGE_ARCH=${image_arch}" >> "${CONF}"

    info "Configuring TAR_XZ_ARGS"
    echo "TAR_XZ_ARGS=\"--xz --options xz:threads=0\"" >> "${CONF}"

    info "Configuring TAR_ZSTD_ARGS"
    echo "TAR_ZSTD_ARGS=\"--zstd --options zstd:threads=0\"" >> "${CONF}"
}

write_pf_rules()
{
    local pf_rules="$1"

    info "Configuring pf"

    if [ -f "${pf_rules}" ]; then
        info "Creating a backup of your ${pf_rules}"
            
        if ! cp -v "${pf_rules}" "${pf_rules}.bak-appjail"; then
            err "Error creating the backup of your ${pf_rules}"
            exit 1
        fi

        grep -Ev \
            -e "^[[:space:]]*nat-anchor[[:space:]]+['\"]appjail-nat/(network|jail)/\*['\"][[:space:]]*$" \
            -e "^[[:space:]]*rdr-anchor[[:space:]]+['\"]appjail-rdr/\*['\"][[:space:]]*$" "${pf_rules}.bak-appjail" > "${pf_rules}"
    fi

    cat << EOF >> "${pf_rules}"
nat-anchor 'appjail-nat/jail/*'
nat-anchor "appjail-nat/network/*"
rdr-anchor "appjail-rdr/*"
EOF
    if [ $? -ne 0 ]; then
        err "Error configuring ${pf_rules}"
        exit 1
    fi

    restart_pf
}

restart_pf()
{
    info "Restarting pf"

    if ! service pf restart; then
        err "Error restarting pf"
        exit 1
    fi

    info "Restarting pflog"

    if ! service pflog restart; then
        err "Error restarting pflog"
    fi
}

check_superuser()
{
    if [ `id -u` -eq 0 ]; then
        return 0
    else
        return 1
    fi
}

check_debootstrap()
{
    which -s debootstrap
}

check_dnsmasq()
{
    which -s dnsmasq
}

check_git()
{
    which -s git
}

create_conf()
{
    if [ ! -d "${ETCDIR}" ]; then
        info "Creating ${ETCDIR}"

        if ! mkdir -p "${ETCDIR}"; then
            err "Error creating ${ETCDIR}"
            exit 1
        fi
    fi

    info "Creating ${CONF}"

    if ! echo -n > "${CONF}"; then
        err "Error creating ${CONF}"
        exit 1
    fi
}

check_appjail()
{
    which -s appjail
}

getsysrc()
{
    sysrc -in "$1"
}

get_default_interface()
{
    local ext_if
    ext_if=`route -4 get default 2> /dev/null | grep 'interface:' | cut -d' ' -f4-`

    if check_empty "${ext_if}"; then
        ext_if=`route -6 get default 2> /dev/null | grep 'interface:' | cut -d' ' -f4-`
    fi

    printf "%s\n" "${ext_if}"
}

ask()
{
    local question="$1" default="$2"

    while :; do
        local _a

        if [ -n "${default}" ]; then
            read -p "${question} [${default}]: " _a

            if check_empty "${_a}"; then
                _a="${default}"
            fi
        else
            read -p "${question}: " _a
        fi

        printf "%s" "${_a}"
        break
    done
}

check_empty()
{
	if [ -z "$1" ] || printf "%s" "$1" | grep -Eq '^[[:space:]]+$'; then
        return 0
    else
        return 1
    fi
}

askchoice()
{
    local question="$1"; shift
    local _q length=0

    for _q in "$@"; do
        length=$((length+1))

        echo -e "[${length}] - ${_q}"
    done

    echo -e "[0] - Exit"
    echo

    local _a

    while :; do
        read -p "${question}: " _a

        if ! checknumber "${_a}"; then
            warn "Invalid option: ${_a}"
            continue
        fi

        if [ "${_a}" -gt "${length}" ]; then
            warn "Invalid option: ${_a}"
            continue
        fi

        if [ "${_a}" -eq 0 ]; then
            exit 0
        fi

        return ${_a}
    done
}

checknumber()
{
    local number="$1"

    if printf "${number}" | grep -qEe '^[0-9]+$'; then
        return 0
    else
        return 1
    fi
}

askyesno()
{
    local question="$1" yes_default="${2:-YES}"
    local def yes no

    if checkyesno "askyesno" "${yes_default}"; then
        yes="Y"
        no="n"
        def="y"
    else
        yes="y"
        no="N"
        def="n"
    fi

    while :; do
        local _a

        read -p "${question} [${yes}/${no}]: " _a

        _a=`printf "%s" "${_a}" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]'`

        if check_empty "${_a}"; then
            _a="${def}"
        fi

        if [ "${_a}" = "y" ]; then
            return 0
        elif [ "${_a}" = "n" ]; then
            return 1
        else
            warn "Invalid option: ${_a}"
        fi
    done
}

checkyesno()
{
    case "$2" in
        [Tt][Rr][Uu][Ee]|[Yy][Ee][Ss]|[Oo][Nn]|1) return 0 ;;
        [Ff][Aa][Ll][Ss][Ee]|[Nn][Oo]|[Oo][Ff][Ff]|0) return 1 ;;
        *) warn "$1 is not set properly."; return 2 ;;
    esac
}

info()
{
    stderr "> $*"
}

err()
{
    stderr "/> $*"
}

warn()
{
    stderr "!> $*"
}

stderr()
{
    print "$*" >&2
}

print()
{
    echo -e "$*"
}

main "$@"
