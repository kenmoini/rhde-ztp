# KVM Host Setup

```bash
# Install needed packages
dnf install -y virt-install virt-viewer virt-top cockpit-machines libvirt libguestfs-tools

# Just disable SELinux...
setenforce 0
cp /etc/sysconfig/selinux /etc/sysconfig/selinux.bak
cat /etc/sysconfig/selinux.bak | sed s/SELINUX=enforcing/SELINUX=disabled/g > /etc/sysconfig/selinux

# Enable unsafe interrupts
echo "options vfio_iommu_type1 allow_unsafe_interrupts=1" > /etc/modprobe.d/unsafe-interrupts.conf

# Set bridge udev rules
echo 'ACTION=="add", SUBSYSTEM=="module", KERNEL=="br_netfilter", RUN+="/sbin/sysctl -p /etc/sysctl.d/bridge.conf"' > /etc/udev/rules.d/99-bridge.rules

# Set nf bridge config
cat > /etc/sysctl.d/libvirt-nf-bridge.conf <<EOF
net.bridge.bridge-nf-call-ip6tables=0
net.bridge.bridge-nf-call-iptables=0
net.bridge.bridge-nf-call-arptables=0
EOF

# Start libvirt
systemctl enable --now libvirtd
systemctl enable --now libvirtd-tcp.socket

# Create a libvirt bridge network
export BRIDGE_IFACE_NAME="bridge99"
cat > /tmp/libvirt-bridge-${BRIDGE_IFACE_NAME}.xml <<EOF
<network>
  <name>${BRIDGE_IFACE_NAME}</name>
  <forward mode="bridge"/>
  <bridge name="${BRIDGE_IFACE_NAME}"/>
</network>
EOF

virsh net-define /tmp/libvirt-bridge-${BRIDGE_IFACE_NAME}.xml
virsh net-start ${BRIDGE_IFACE_NAME}
virsh net-autostart ${BRIDGE_IFACE_NAME}

# Delete the default network
virsh net-destroy default
virsh net-undefine default

# Would also be good to restart the host
```