# iPXE Setup

```bash
dnf install "@Development Tools"

cd /opt

git clone https://github.com/ipxe/ipxe.git

cd ipxe/src

cat > embed.ipxe <<EOF
#!ipxe

dhcp
chain tftp://192.168.99.10/main.ipxe
EOF

make bin-x86_64-efi/ipxe.efi EMBED=embed.ipxe # EFI
make bin/undionly.kpxe EMBED=embed.ipxe #BIOS

mkdir /pxe-boot
cp bin-x86_64-efi/ipxe.efi /var/ftp/pub/pxe/tftpboot/
cp bin-x86_64-efi/ipxe.efi /pxe-boot
cp bin/undionly.kpxe /var/ftp/pub/pxe/tftpboot/

```