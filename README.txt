usage: AppJail.setup [options]

Description:

  AppJail.setup is a script for bootstrapping and configuring AppJail and
  all related projects, such as Overlord, Director, and Reproduce.
  The purpose of this script is to configure them with secure default
  settings that have proven effective over the years, as well as to
  enable the most frequently used features.

  This script attempts to works correctly on an dirty host, but this is
  merely a best-effort approach. It is preferable to use this script in
  conjunction with cloud-init/nuageinit in a fresh environment and then
  tailor the configurations to your needs.

  By default, when no arguments are provided, this script simply
  installs AppJail and enables its rc(8) script. In almost all cases,
  you’ll want to use the '--enable-common' option, which installs
  additional dependencies to enable more features and also includes
  Director for multi-jail deployments.

Options:

  --help
        Show this help message and exit.

  --appsdir <dir>
        Directory where application sources (git repositories) will be stored.
        Default: /root/applications

  --zpool <pool>
        ZFS pool name to use for AppJail datasets.
        Default: zroot

  --zrootfs <fs>
        ZFS filesystem name under the pool for AppJail.
        Default: appjail

  --ext-if <iface>
        External network interface used for external access (commonly, internet connection).
        If not specified, it will be auto-detected from the default route.

  --virtualnet-addr <addr>
        IP address range for the default virtual network (in CIDR notation).
        Default: 10.0.0.0/10

  --dns-iface <iface>
        Name of the cloned TAP interface used for DNS services.
        Default: ajdns

  --dns-addr <addr>
        IPv4 address assigned to the DNS interface.
        Default: 172.16.0.1

  --loopback-iface <iface>
        Name of the cloned loopback interface for jail networking.
        Default: appjail0

  --ssh-port <port>
        TCP port used for SSH access from the external network.
        Default: 22

  --memcached-max-item-size <size>
        Maximum item size for memcached (passed to -I option).
        Default: 6m

  --dry-run
        Print all commands that would be executed without actually running them.
        Useful for previewing the actions.

  --bleeding-edge
        Install AppJail, Director, Overlord, and Reproduce from Git (development
        versions) instead of using FreeBSD packages.

  --enable-dns
        Set up a DNS server (dnsmasq) and configure AppJail to use it.
        This also creates a tap(4) interface and updates resolv.conf(5).

  --with-director
        Install and configure Director for multi-jail orchestration.

  --with-overlord
        Install and configure Overlord along with its dependencies
        (supervisord, memcached, beanstalkd) for multi-host orchestration.

  --with-reproduce
        Install Reproduce for building AppJail images.

  --enable-healthcheckers
        Enable AppJail's health checker service.

  --enable-virtualnet
        Set up a virtual network infrastructure: enable IP forwarding, load
        bridge kernel modules, configure PF firewall, and create the default
        virtual network.

        If '--use-pf-minimal' is not specified, a set of rules will be
        installed along with the 'security-group' and 'security-table' hooks
        to restrict and control connections made by the jails by default.
        Note that, since the DNS server uses a private address, these cannot
        communicate by default; therefore, you need to add a jail to the
        'allow-dns' table. It is preferable to do so through the label used
        by the security table.

        See also: https://github.com/DtxdF/AppJail/wiki/filter

  --use-pf-minimal
        When combined with --enable-virtualnet, write only minimal PF rules
        (nat and rdr anchors) instead of the full rule set.

  --enable-loopback-iface
        Create and configure a cloned loopback interface for jail networking.
        Commonly used by LinuxJails.

  --enable-tmpfs
        Mount a tmpfs(4) filesystem on /usr/local/appjail/cache/tmp/.appjail for
        temporary files (adds entry to /etc/fstab and mounts it).

  --enable-debug
        Enable debug logging in AppJail's configuration file.

  --enable-racct
        Enable RACCT (resource accounting) by setting kern.racct.enable=1 in
        /boot/loader.conf. A reboot is required for this to take effect.

  --enable-trusted-users
        Configure trusted users: install doas, create the 'appjail' group, and
        add doas rules to allow members of that group to run appjail commands
        as root without a password.

  --enable-hooks
        Enable AppJail's hook system (creates the hook directories).

  --install-git
        Install a Git client (git-tiny, git-lite, or git) if not already present.

  --install-debootstrap
        Install debootstrap (used for creating debian-based jails).

  --install-oci-dependencies
        Install OCI dependencies: buildah and jq.

  --install-x11-dependencies
        Install x11-related packages (su-exec, xauth, xdotool, xephyr, xev,
        xseticon) for graphical applications in jails.

  --install-rage
        Install rage-encryption (used for Secrets).

  --enable-zfs
        Enable ZFS support in AppJail's configuration.

  --overwrite-pf-rules
        Overwrite existing PF rules file (/etc/pf.conf or the one defined in
        rc.conf).

  --overwrite-resolv-conf
        Overwrite /etc/resolv.conf with AppJail's DNS configuration, even if
        it already exists.

  --overwrite-director-ini
        Overwrite existing director.ini file (if present) instead of saving a
        fallback copy.

  --overwrite-overlord-yml
        Overwrite existing overlord.yml file (if present) instead of saving a
        fallback copy.

  --enable-common
        Enable a common set of options for typical AppJail usage. Equivalent to:
        --enable-dns --with-director --enable-healthcheckers --enable-virtualnet
        --enable-loopback-iface --enable-tmpfs --enable-racct --enable-trusted-users
        --enable-hooks --install-git --install-debootstrap --install-oci-dependencies
        --install-rage

Caveats:

  1. Keep in mind that, unlike director.ini, overlord.yml, pf.conf,
     resolv.conf, etc., the appjail.conf file is always overwritten. The
     first time, your appjail.conf file is renamed with the same name
     but with the .bak extension; however, the second time, the file
     with the .bak extension will not be overwritten. If you do not want
     this to happen, make a copy of your appjail.conf file.

  2. You should use nohup(1) if you are connected via an SSH connection,
     but it is recommended that you run this script using cloud-init/nuageinit,
     either physically or through the console of a virtual machine or
     via VNC. ALWAYS make sure you have a way to physically access the
     system to troubleshoot any issues.

  3. tap99 and lo99 should not be used, since this script assumes that they are
     always available for use.
