# Configuring a Unifi Dream Machine

> TODO: Add more info about firewall bits and some pictures.

The Unifi Dream Machine is a cost-effective solution for deploying network services for this demo.  It has the ability to carve out VLANs, set DHCP Relay configuration, enough switch ports for an edge device or two, and built-in wifi for connecting your terminal to.

## Network Setup

Once the device is initially provisioned, you'll need to create some networks.  Assuming the default configuration as specified in this demo, you'll want to create/configure 4 networks:

- **Default**: The default network on VLAN 0, `192.169.98.0/24` with a DHCP Range of `192.168.98.100 - 192.168.98.254`.  Set the DNS Server to `192.168.99.2` once the DNS Server Pod is running.
- **Edge99**: This VLAN is for edge devices on VLAN 99, `192.168.99.0/24` with a DHCP Range of `192.168.99.100 - 192.168.99.254`.  Set the DHCP DNS Server to `192.168.99.2` once the DNS Server Pod is running.  Once the Edge Hub has been configured, come back here and set the DHCP Relay option to forward to the Edge Hub which is by default at `192.168.99.10`.
- **Wireless97**: This VLAN is for wifi devices on VLAN 97, `192.168.97.0/24` with a DHCP Range of `192.168.97.100 - 192.168.97.254`.  Set the DHCP DNS Server to `192.168.99.2` once the DNS Server Pod is running.
- **MGMT96**: This VLAN is for OOBM IPMI on VLAN 96, `192.168.96.0/24` with a DHCP Range of `192.168.96.100 - 192.168.96.254`.  Set the DHCP DNS Server to `192.168.99.2` once the DNS Server Pod is running.

- With those networks created, modify your Wireless network to use the `Wireless97` network.
- Configure the ports 1-3 on the UDM to have the `Edge99` network as the default network.  This is done via the Unifi Devices > UDM > Port Manager page.  This will make DHCP requests go through that VLAN 99 by default which will be sent to ISC DHCP, enabling PXE boot.
- You may also configure one of the ports for the `MGMT96` VLAN if you're using Redfish enabled BMCs.

## Firewall & Static Routes

Assuming you have the UDM connected to your home network's LAN and doing double NAT, you'll want to open some Firewall rules and set some static routes.

On your upstream router - eg I have my UDM connected to a UDM Pro so my upstream router is the UDM Pro - set some Static Routes that forward the subnets `192.168.96.0/24`, `192.168.97.0/24`, `192.168.98.0/24`, and `192.168.98.0/24` to the IP address associated with the UDM WAN port, which is an IP address on the UDM Pro LAN.

