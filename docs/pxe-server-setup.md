# PXE Server Setup

```bash
# Install needed packages
dnf install git nano ansible-core -y

# Clone the automation repo
git clone https://github.com/kenmoini/ansible-pxe-server

cd ansible-pxe-server

cat > inventory <<EOF
all:
  hosts:
    pxe.kemo.edge:
      ansible_host: 192.168.99.10
      ansible_connection: local
EOF

cat > setup.vars <<EOF
# Disabling HTTP since that's handled by the nginx container
enable_http: false

pxe_server_name: pxe.kemo.edge
pxe_server_ip: 192.168.99.10
httpd_server_ip: 192.168.99.12

domain_name: kemo.edge
domain_name_servers: "192.168.99.2"
gateway_router_ip: 192.168.99.1
ntp_server_ip: 192.168.99.10
dhcp_subnet: 192.168.99.0
dhcp_netmask: 255.255.255.0
dhcp_range_start: 192.168.99.100
dhcp_range_end: 192.168.99.250

distros:
# Pathing: /var/ftp/pub/pxe/install/{{ arch }}/{{ group }}/{ext,iso}/{{ isoURL | basename }}
# Pathing: /var/ftp/pub/pxe/tftpboot/{{ boot_method }}/{{ arch }}/( boot loader files )
# Pathing: /var/ftp/pub/pxe/tftpboot/{{ boot_method }}/{{ arch }}/{{ group }}/{{ name }}/boot
  - name: rhel94x8664
    displayName: Red Hat Enterprise Linux 9.4
    group: rhel94
    bios_kernel: images/pxeboot/vmlinuz
    bios_initrd: images/pxeboot/initrd.img
    efi_kernel: images/pxeboot/vmlinuz
    efi_initrd: images/pxeboot/initrd.img
    arch: x86_64
    efi_loader_seed: true
    efi_loader_path: EFI/BOOT/ # trailing slash is important!
    family: rhel
    # Either isoURL or isoSrcPath need to be provided
    isoSrcPath: /opt/isos/rhel-9.4.iso
    protocol: http
    boot_methods:
      - BIOS
      - EFI
    efi_options:
      - gui-install
      - text-install
      - linux-rescue

EOF

# Make a seed dir
mkdir -p /var/ftp/pub/pxe/install/x86_64/rhel94/ext/rhel-9.4/EFI/BOOT/

# Run the playbook
ansible-playbook -i inventory -e "@setup.vars" deploy.yml

# Run the playbook again cause I'm a lazy idiot...
ansible-playbook -i inventory -e "@setup.vars" deploy.yml
```

- Disable the firewall... `systemctl stop firewalld && systemctl disable firewalld`
- Set your router to relay DHCP to the edge-hub