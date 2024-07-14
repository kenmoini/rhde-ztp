# DNS Setup

- SSH into a RHEL box
- Subscribe the host
- Make sure the host has a bridge device created

```bash
# Install Podman
dnf install podman cockpit-podman container-tools bind-utils net-tools bash-completion nano -y

# Start Podman
systemctl enable --now podman.socket
systemctl enable --now podman.service

# Start Cockpit
systemctl enable --now cockpit.socket

# Make Podman networking directory
mkdir -p /etc/containers/networks/

# Create a Podman network bridge
export BRIDGE_NAME="lanBridge"
export BRIDGE_SUBNET="192.168.99.0/24"
export BRIDGE_GATEWAY="192.168.99.1"
export BRIDGE_BASE_IFNAME="bridge99"

cat > /etc/containers/networks/${BRIDGE_NAME}.json << EOF
{
     "name": "${BRIDGE_NAME}",
     "driver": "bridge",
     "id": "$(tr -dc a-f0-9 </dev/urandom | head -c 64; echo)",
     "network_interface": "${BRIDGE_BASE_IFNAME}",
     "subnets": [
          {
               "subnet": "${BRIDGE_SUBNET}",
               "gateway": "${BRIDGE_GATEWAY}"
          }
     ],
     "ipv6_enabled": false,
     "internal": false,
     "dns_enabled": false,
     "ipam_options": {
          "driver": "host-local"
     }
}
EOF

# Create service container directory
mkdir -p /opt/service-containers/go-zones/{scripts,volumes/{etc-config,vendor-config}}

# Create service init script
export GZ_NAME="go-zones"
export GZ_NETWORK="lanBridge"
export GZ_IP_ADDRESS="192.168.99.2"
export GZ_CONTAINER_PORT="53"

cat > /opt/service-containers/go-zones/scripts/servicectl.sh << EOF
#!/bin/bash

set -x

###################################################################################
# VARIABLES
###################################################################################

CONTAINER_NAME="${GZ_NAME}"
NETWORK_NAME="${GZ_NETWORK}"
IP_ADDRESS="${GZ_IP_ADDRESS}"
CONTAINER_PORT="${GZ_CONTAINER_PORT}"

VOLUME_MOUNT_ONE="/opt/service-containers/go-zones/volumes/etc-config:/etc/go-zones/"
VOLUME_MOUNT_TWO="/opt/service-containers/go-zones/volumes/vendor-config:/opt/app-root/vendor/bind/"

CONTAINER_SOURCE="quay.io/kenmoini/go-zones:file-to-bind-latest"

RESOURCE_LIMITS="-m 500m"

###################################################################################
# EXECUTION PREFLIGHT
###################################################################################

## Ensure there is an action arguement
if [ -z "\$1" ]; then
  echo "Need action arguement of 'start', 'restart', or 'stop'!"
  echo "\${0} start|stop|restart"
  exit 1
fi


################################################################################### SERVICE ACTION SWITCH
case \$1 in

  ################################################################################# RESTART/STOP SERVICE
  "restart" | "stop" | "start")
    echo "Stopping container services if running..."

    echo "Killing \${CONTAINER_NAME} container..."
    /usr/bin/podman kill \${CONTAINER_NAME}

    echo "Removing \${CONTAINER_NAME} container..."
    /usr/bin/podman rm -f -i \${CONTAINER_NAME}
    ;;

esac

case \$1 in

  ################################################################################# RESTART/START SERVICE
  "restart" | "start")
    sleep 3

    echo "Checking for stale network lock file..."
    FILE_CHECK="/var/lib/cni/networks/\${NETWORK_NAME}/\${IP_ADDRESS}"
    if [[ -f "\$FILE_CHECK" ]]; then
        rm -f \$FILE_CHECK
    fi

    echo "Starting container services..."

    # Deploy \${CONTAINER_NAME} container
    echo -e "Deploying \${CONTAINER_NAME}...\n"

    /usr/bin/podman run -d --name "\${CONTAINER_NAME}" --privileged \\
      --network "\${NETWORK_NAME}" --ip "\${IP_ADDRESS}" -p "\${CONTAINER_PORT}" \\
      -v \${VOLUME_MOUNT_ONE} -v \${VOLUME_MOUNT_TWO} \\
      \${RESOURCE_LIMITS} \${CONTAINER_SOURCE}

    ;;

esac
EOF

# Create the systemd Service
cat > /etc/systemd/system/${GZ_NAME}.service <<EOF
[Unit]
Description=GoZones Container
After=network-online.target
Wants=network-online.target

[Service]
ExecStop=/opt/service-containers/${GZ_NAME}/scripts/servicectl.sh stop
ExecStart=/opt/service-containers/${GZ_NAME}/scripts/servicectl.sh start
ExecReload=/opt/service-containers/${GZ_NAME}/scripts/servicectl.sh restart

TimeoutStartSec=30
Type=forking
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

# Create the Server DNS Configuration file
cat > /opt/service-containers/${GZ_NAME}/volumes/etc-config/server.yml <<EOF
dns:
  ##########################################################################################
  # acls is a list of named network groups
  acls:
    # privatenets can respond to internal client queries with an internal IP
    - name: privatenets
      networks:
        - 10.0.0.0/8
        - 172.16.0.0/12
        - 192.168.0.0/16
        - localhost
        - localnets
    # externalwan would match any external network
    - name: externalwan
      networks:
        - any
        - "!10.0.0.0/8"
        - "!172.16.0.0/12"
        - "!192.168.0.0/16"
        - "!localhost"
        - "!localnets"

  ##########################################################################################
  # views is a list of named views that glue together acls and zones
  views:
    - name: internalNetworks
      # acls is a list of the named ACLs from above that this view will be applied to
      acls:
        - privatenets
      # recursion is a boolean that controls whether this view will allow recursive DNS queries
      recursion: true
      # if recursion is true, then you can provide forwarders to be used for recursive queries 
      #  such as a PiHole DNS server or just something like Cloudflare DNS at 1.0.0.1 and 1.1.1.1
      forwarders:
        - 1.1.1.1
        - 1.0.0.1
      # forwarded_zones is a list of zones and their authoritative nameservers to forward queries to
      forwarded_zones:
        - zone: kemo.labs
          forwarders:
            - 192.168.42.9
            - 192.168.42.10
        - zone: kemo.network
          forwarders:
            - 192.168.42.9
            - 192.168.42.10
      # zones is a list of named Zones to associate with this view
      zones:
        - kemo-edge


  ##########################################################################################
  ## Assumes two authoritative dns servers at dns-core-1.example.labs and dns-core-2.example.labs serving both zones
  zones:
    - name: kemo-edge
      zone: kemo.edge
      primary_dns_server: ns1.kemo.edge
      default_ttl: 3600
      records:
        NS:
          - name: ns1
            ttl: 86400
            domain: kemo.edge.
            anchor: '@'
        A:
          # a cidr suffix will generate PTR records
          - name: ns1
            value: ${GZ_IP_ADDRESS}/24
          - name: edge-router
            value: ${BRIDGE_GATEWAY}/24
          - name: edge-hub
            value: 192.168.99.10/24
          - name: pxe
            value: 192.168.99.10
          - name: image-builder
            value: 192.168.99.10
          - name: fdo-aio
            value: 192.168.99.10
          - name: aap2-controller
            value: 192.168.99.11/24
          - name: websrv
            value: 192.168.99.12/24
          - name: ocr-app
            value: 192.168.99.13/24
          - name: unified-api
            value: 192.168.99.14/24
          - name: scanner-app
            value: 192.168.99.15/24
          - name: "*.apps"
            value: 192.168.99.16
          - name: job-code-web
            value: 192.168.99.17/24
          - name: registry
            value: 192.168.99.18/24

EOF

# Create the named config
cat > /opt/service-containers/${GZ_NAME}/volumes/vendor-config/named.conf <<EOF
options {
  listen-on port 53 { any; };
  listen-on-v6 port 53 { any; };
  
  listen-on port 5353 { any; };
  listen-on-v6 port 5353 { any; };

  directory "/var/named";
  dump-file "/var/named/data/cache_dump.db";
  statistics-file "/var/named/data/named_stats.txt";
  memstatistics-file "/var/named/data/named_mem_stats.txt";
  secroots-file "/var/named/data/named.secroots";
  recursing-file "/var/named/data/named.recursing";

  version "not available";
  
  dnssec-validation no;

  recursion no;

  allow-transfer { none; };
  allow-query { any; };

  managed-keys-directory "/var/named/dynamic";
  geoip-directory "/usr/share/GeoIP";

  pid-file "/run/named/named.pid";
  session-keyfile "/run/named/session.key";

  include "/etc/crypto-policies/back-ends/bind.config";

  max-cache-size 100m; // maximum cache size of 100MB
};

logging {
  channel default_debug {
    file "data/named.run";
    severity dynamic;
  };
};

include "/opt/app-root/generated-conf/config/go-zones-bootstrap.conf";
EOF

# Reload systemd
systemctl daemon-reload

# Set the script to be executable
chmod a+x /opt/service-containers/${GZ_NAME}/scripts/servicectl.sh

# Prepull the image
podman pull quay.io/kenmoini/go-zones:file-to-bind-latest

# Enable and start the service
systemctl enable --now ${GZ_NAME}
```

