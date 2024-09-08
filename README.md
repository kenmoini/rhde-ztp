# Zero Touch Provisioning for Red Hat Device Edge

> **User Story**: I need to deploy edge devices in the field without having trained technicians manually provision them. I should be able to get my 15 year old nephew to scan a code with his phone, plug a system in, and walk away.

This repository houses the content needed to easily and quickly deploy Red Hat Device Edge systems with Zero Touch Provisioning principles.

## Solution Components

- Red Hat Enterprise Linux
- Red Hat Enterprise Linux for Device Edge (ostree-based)
- Red Hat Image Builder
- Red Hat Microshift
- Ansible Automation Platform 2
- FIDO Device Onboarding (FDO)
- Misc technologies involved:
  - Cockpit Web UI
  - DNS via GoZones
  - FTP
  - Nginx
  - ISC DHCPD
  - Libvirt/KVM
  - NFS
  - PXE
  - TFTP
  - Podman
- A few different API/Web services
  - Job Code Manager - Web UI to build Job Code definitions
  - Scanner App - A Web UI to scan barcodes and QR codes to claim Job Codes
  - Unified API - An API that handles the integration of the various components

## Architecture

In this demo architecture, most services are colocated on a single physical host, the **Edge Hub**.  As currently configured the Edge Hub runs the following:

- Unified API via Podman
- Scanner App via Podman
- GoZones DNS via Podman
- Job Code Manager via Podman
- HAProxy reverse proxy via Podman
- NGINX HTTP Server via Podman
- Docker Registry v2 via Podman
- PXE Services (ISC DHCP, TFTP, NFS) configured as services on the host
- FDO AIO configured as services on the host
- Ansible Automation Platform 2 Controller in a VM

In a production environment you'd want to separate some of those systems.  The example `ansible/inventory` file shows the different groups that can be configured for the different system concerns - the configuration in `ansible/controller-setup` would need to be modified to add different hosts to those different groups when configuring the AAP2 Controller.

Otherwise all that is needed is a router that can provide DHCP Relay services that point to the Edge Hub, and enough switch ports to connect different edge devices.  In this demo example a [Unifi Dream Machine](./docs/configure-udm.md) is used.

With that you can bring your own edge devices or even emulate them with Libvirt/KVM VMs.  What is needed are devices that can PXE boot or have a Redfish endpoint.  UEFI boot is technically available, however it only works with an HTTPS server that has a certificate signed in the BIOS trusted store - and Secure Boot may not work since the PXE Boot EFI files are not signed by Microsoft.  Getting an EFI boot file signed by Microsoft is a long and arduous process so it's easier to stick to PXE/Redfish.

In this demo lab I've used a Beelink SER5 Max, OnLogic CL250, Minisforum MS-01, and a set of Dell and Supermicro servers.  Each system needs a boot disk as well as an additional hard disk for Microshift LVM.  Target the installation disk when creating the RHDE Images and the post-configuration automation will detect and target the other disk automatically for Microshift LVM.

## Prerequisites & External Dependencies

- Red Hat Pull Secret: https://console.redhat.com/openshift/downloads/
- A system to act as the Edge Hub
- [Technically Optional, but suggested] SMTP Server or Twilio/TextBelt for sending Job Code messages via Email/Text
- [Optional] If booting via Redfish to BMCs you will need the IPMI credentials - these are stored as Ansible Vault encrypted variables in `site-configs/redfish-systems`
- [Optional] Azure Arc or Red Hat Advanced Cluster Management.  If using with Azure Arc, you'll need a Service Principal with the role to onboard Kubernetes clusters.

## Workflow

- Operations Admin creates an Image Builder Blueprint/edge-commit/edge-simplified-installer image via AAP2.  Components are extracted appropriately.