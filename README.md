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

## External Dependencies

- [Technically Optional, but suggested] SMTP Server or Twilio/TextBelt for sending Job Code messages via Email/Text
- [Optional] Azure Arc or Red Hat Advanced Cluster Management

## Workflow

- Operations Admin creates an Image Builder Blueprint/edge-commit/edge-simplified-installer image via AAP2.  Components are extracted appropriately.