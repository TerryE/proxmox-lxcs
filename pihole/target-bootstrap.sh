#! /bin/bash

# In-target initial provisioning of the Debian Pihole + Unbound  LXC
# Note that Pihole isn't yet supported on Alpine, hence the use of Debian

# This script rebuilds the local DNS server, so we need to use a public DNS
# here, and fix up locale so that Perl scripts don't throw errors
sed -i '3s/ .*/ 8.8.8.8/; 4d' /etc/resolv.conf
sed -i '/en_US.UTF-8/s/^# //' /etc/locale.gen; locale-gen

# Install Precusor packages for the Pihole LXC

package common
package add unbound
package install

addAccount PIHOLE

# Configure and start up Unbound

mv /etc/unbound/unbound.conf.d/{,05-}root-auto-trust-anchor-file.conf
cp -r /usr/local/conf/unbound /etc
service unbound restart
service sshd stop
rm -R /etc/ssh
ln -s /usr/local/data/{pihole,.pihole,ssh} /etc

sleep 2
SUBNET=$(ip a| perl -ne '/inet (\d+\.\d+\.\d+).*eth0/ && print $1;')
echo "
    PIHOLE_INTERFACE=eth0
    DNSMASQ_LISTENING=single
    IPV4_ADDRESS=
    QUERY_LOGGING=true
    DNSSEC=true
    BLOCKING_ENABLED=true
    API_QUERY_LOG_SHOW=all
    API_PRIVACY_MODE=false
    TEMPERATUREUNIT=C
    DNS_FQDN_REQUIRED=true
    DNS_BOGUS_PRIV=true
    MAXDBDAYS=31
    PIHOLE_DNS_1=127.0.0.1#5053
    PIHOLE_DNS_2=127.0.0.1#5053
    REV_SERVER=true
    REV_SERVER_CIDR=$SUBNET.0/24
    REV_SERVER_TARGET=$SUBNET.1
    REV_SERVER_DOMAIN=home
    WEBUIBOXEDLAYOUT=traditional
    INSTALL_WEB_SERVER=true
    INSTALL_WEB_INTERFACE=true
    LIGHTTPD_ENABLED=true
    CACHE_SIZE=10000
    WEBPASSWORD='$WEBPASSWD'" \
| sed 's/^ *//' > /etc/pihole/setupVars.conf
cp /etc/pihole/setupVars.conf /home/pihole

# Download the pihole installation script and do unattended install

wget -qO - https://install.pi-hole.net | bash -ls - --unattended

# Stop pihole to reconnect to persistent version, and restart

bash -lc "pihole disable"
pkill pihole-FTL

# Configure and start up pihole.  Note that /etc/pihole is preserved
# except setupVars.conf is reinitialised

cp {/home,/etc}/pihole/setupVars.conf
bash -lc "pihole enable restartdns"

enableService