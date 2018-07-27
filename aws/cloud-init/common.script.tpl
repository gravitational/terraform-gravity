#!/bin/sh
set -x

echo "bootstrap common"

# Set some curl options so that temporary failures get retried
# More info: https://ec.haxx.se/usingcurl-timeouts.html
CURL_OPTS="--retry 100 --retry-delay 0 --connect-timeout 10 --max-time 300"

#
# Setup OS modules
#
for module in iptable_nat iptable_filter overlay br_netfilter ebtable_filter bridge iptables
do
	echo "Loading kernel module: $${module}"
    modprobe $${module} || true
    echo "$${module}" >> /etc/modules-load.d/gravity.conf
done

#
# Set sysctl's 
#
cat > /etc/sysctl.d/50-telekube.conf <<EOF
net.ipv4.ip_forward=1
net.bridge.bridge-nf-call-iptables=1
EOF
if sysctl -q fs.may_detach_mounts >/dev/null 2>&1; then
  echo "fs.may_detach_mounts=1" >> /etc/sysctl.d/50-telekube.conf
fi
sysctl -p /etc/sysctl.d/50-telekube.conf

#
# Mount / Create gravity partition
#
umount /dev/xvdb || true
mkfs.ext4 /dev/xvdb
mkdir -p /var/lib/gravity
mount /var/lib/gravity

#
# Install Python/pip and awscli
#
curl $${CURL_OPTS} -O https://bootstrap.pypa.io/get-pip.py
python2.7 get-pip.py
pip install awscli

#
# Get tele/tsh
#
curl $${CURL_OPTS} https://get.gravitational.io/telekube/install/${gravity_version} | /bin/sh

