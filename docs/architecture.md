# Architecture

> ***Please don't read this, it's mostly brain vomit***

**User Story:** I want any random Sam or Pat to be able to take a device out into the field, scan a piece of hardware information into a mobile application, plug in the system, and walk away with the provisioning process being fully automated without technical intervention.

1. Ops team deploys needed services on a server:
  - FDO AIO (ansible/setup-fdo-server.yml)
  - DHCP/FTP/NFS/TFTP/PXE (docs/pxe-server-setup.md)
  - Image Builder (ansible/setup-image-builder-server.yml)
2. Ops team deploy AAP2 Controller with needed post-bootstrap configuration (configure/start Microshift, configure NVIDIA Device Plugin, connect to Azure Arc)
3. Ops team configures network for PXE next-server booting or DHCP relay
4. Ops team deploys Job Code API+Web UI and FDO-Ansible Glue Service to PXE's HTTP Server
5. Ops team creates a RHEL Device Edge image with minimal packages, hosts assets on HTTP server
6. Ops team creates Job Code pointing a host configuration to a RHDE Image
7. Field tech goes out, scans the MAC Address of the device, waits for a Green Light, plugs in the device and powers it on then walks away.
8. Device boots via PXE/Redfish, RHDE Simple Installer images and connects to FDO Server
9. Device reboots, pulls basic configuration from FDO - config includes a Glue service that talks to the Glue Server on boot
10. One-shot Glue Service sends device MAC/IP/Interface to Server - Server maps MAC to the claimed Job Code ID, adds the host to AAP2 inventory, starts a Job Template to do further configuration of the device (configure/start Microshift, configure NVIDIA Device Plugin, connect to Azure Arc)
11. Ops team sees the device reporting in on the FDO server and Azure Arc
12. ??????
13. PROFIT!!!!!1

## "Micro" Services

- **Nginx** - A simple web server to provide access to assets such as the PXE/UEFI boot resources, ostree mirror, etc.
- **Image Registry Mirror** - In case this deployment is being done in a disconnected environment or redeployed where there may not be connectivity, it's handy to have an image registry that can mirror all the needed images.  Just a simple Docker Registry v2 with htpasswd authentication.
- **Job Code Web UI** - This is a web application that is used by an operations administrator to create Job Codes.  The Job Codes have details on the intended specification of the field deployed systems, and the generated Job Code ID is what is provided to the field technician.
- **Scanner App** - This application is what a field technician would use to scan the MAC address barcode of a device before plugging it in.  Works on mobile, supports a variety of bar/QR codes, prompts for a Job Code ID and has a big Submit button.
- **Unified API** - This service is what's used to create Job Codes, claim Job Codes, load information for the other services, and act as a glue between things like FDO and Ansible.

- **OCR Web App** - Not used any more really lol.  Loaded on a mobile device to scan text for MAC Addresses.  Simple HTML/JS app that talks to an external Tesseract service and takes the detected text and sends it with the Job Code to the Job Code API

## Helpful Links

- https://docs.nvidia.com/datacenter/cloud-native/edge/latest/nvidia-gpu-with-device-edge.html
- https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html
- https://github.com/NVIDIA/k8s-device-plugin?tab=readme-ov-file
- https://github.com/osbuild/rhel-for-edge-demo/
- https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/9/html/composing_installing_and_managing_rhel_for_edge_images/assembly_automatically-provisioning-and-onboarding-rhel-for-edge-devices_composing-installing-managing-rhel-for-edge-images
- https://docs.ansible.com/ansible-tower/3.2.6/html/towerapi/launch_jobtemplate.html
- https://docs.ansible.com/ansible-tower/3.8.4/html/towerapi/searching.html
- https://docs.ansible.com/ansible-tower/2.3.0/html/towerapi/host_list.html
- https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/9/html/performing_an_advanced_rhel_9_installation/kickstart-commands-and-options-reference_installing-rhel-as-an-experienced-user
- https://osbuild.org/docs/user-guide/blueprint-reference
- https://kenmoini.com/post/2021/03/disabling-nouveau-drivers-rhel-8/

## TODO

- [DONE] Setup PXE server (lol)
- [DONE] Automation to create a Blueprint/Image
- Automation to save image and copy to another location
- Automation to configure PXE server
- Full Instructions
- Slide Deck