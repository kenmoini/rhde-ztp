#!/bin/bash

# - FDO Provisions device-side one-shot service
# - Device-side One-shot service runs script
# - Device-side Glue script gets system MAC Address, and sends it to a Glue Service
# - Hosted Glue Service looks up Job Code data and MAC Address submitted by field tech
# - Hosted Glue Service configures Ansible Inventory with host info from Job Code data
# - Hosted Glue Service runs Ansible playbook to configure system

export GLUE_SERVICE="https://unified-api.apps.kemo.edge"

export DEFAULT_ROUTE_DEVICE=$(ip route show default | awk '/default/ {print $5}')

export DEFAULT_MAC_ADDRESS=$(cat /sys/class/net/${DEFAULT_ROUTE_DEVICE}/address)

export DEFAULT_IP_ADDRESS=$(ip addr show ${DEFAULT_ROUTE_DEVICE} | awk '/inet / {print $2}' | cut -d/ -f1)

# Post the MAC address to the Glue API
curl -k -X POST -H "Content-Type: application/json" -d "{\"mac_address\": \"$DEFAULT_MAC_ADDRESS\", \"provisioned_ip_address\": \"$DEFAULT_IP_ADDRESS\", \"default_device\": \"$DEFAULT_ROUTE_DEVICE\"}" $GLUE_SERVICE/api/v1/system-up