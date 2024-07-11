#!/bin/bash

## Exit on errors
set -e
## Uncomment the following flag during debugging
## set -x

## Adapted from:
## - https://jamielinux.com/docs/openssl-certificate-authority/index.html
## - https://roll.urown.net/ca/index.html
## - https://github.com/kenmoini/ansible-openvpn-server/blob/main/tasks/setup_openvpn.yaml
## - https://www.phildev.net/ssl/opensslconf.html
## - https://www.golinuxcloud.com/add-x509-extensions-to-certificate-openssl/
##
## Needs OpenSSL 1.1.1 or later & OpenVPN 2.4.6 or later
##
## Tools:
## - Check Cert+CA Chains: https://tools.keycdn.com/ssl
##
## To use this PKI Chain, you will need to:
##   As a system admin/user:
##   - Add the Root CA Certificate to your System Trusted Root Certificate Authorities
##   - Depending on your browser, you may need to add the Root CA Certificate to your browser's Trusted Root Certificates
##   With a web server:
##   - Take the full-chain and provide it to your web server along with the private key and signed certificate of the server
##   With HAProxy:
##   - Concatenate the private key, signed certificate, and full-chain into a single file - in that order
##   With OpenVPN:
##   - You will need to supply the full-chain, TLS Auth key, Diffe-Helleman parameters key, and Server certificate and private key to your OpenVPN server and in some places your clients
##
## When chaining certificate authorities, you will need to add the last chain first so the order would be:
## - Signing CA Certificate (Signed by Intermediate CA)
## - Intermediate CA Certificate (Signed by Root CA)
## - Root CA Certificate (Self-Signed by Root CA)

##############################################################
## Set vars
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
PKI_PATH="${SCRIPT_DIR}/.pki"

source ${SCRIPT_DIR}/chain-vars.sh

##############################################################
## Include Functions
source "${SCRIPT_DIR}/chain-functions.sh"

##############################################################
## Start bootstrapping
echo -e "\n=========================="
echo -e "===== Bootstrapping PKI..."
echo -e "=========================="

##############################################################
## Check for needed programs
echo -e "\n===== Checking for needed programs..."
checkForProgramAndExit openssl
#checkForProgramAndExit openvpn

##############################################################
## Create the Root CA
##############################################################
createRootCA "${ROOT_CA_PATH}" "${ROOT_CA_SLUG}" "${ROOT_CA_CN}" "${ROOT_CA_COUNTRY_CODE}" "${ROOT_CA_STATE}" "${ROOT_CA_CITY}" "${ROOT_CA_ORG}" "${ROOT_CA_ORG_UNIT}" "${ROOT_CA_EMAIL}"

##############################################################
## Create the Intermediate CAs
##############################################################
## - Kemo Labs Intermediate CA
createIntermediateCA "${KL_ICA_PATH}" "${KL_ICA_SLUG}" "${KL_ICA_CN}" "${KL_ICA_COUNTRY_CODE}" "${KL_ICA_STATE}" "${KL_ICA_CITY}" "${KL_ICA_ORG}" "${KL_ICA_ORG_UNIT}" "${KL_ICA_EMAIL}" "${ROOT_CA_PATH}"

##############################################################
## Create the Signing CAs
##############################################################
## - Kemo Labs Signing CA - Edge Services
createSigningCA "${KL_EDGE_SCA_PATH}" "${KL_EDGE_SCA_SLUG}" "${KL_EDGE_SCA_CN}" "${KL_EDGE_SCA_COUNTRY_CODE}" "${KL_EDGE_SCA_STATE}" "${KL_EDGE_SCA_CITY}" "${KL_EDGE_SCA_ORG}" "${KL_EDGE_SCA_ORG_UNIT}" "${KL_EDGE_SCA_EMAIL}" "${KL_ICA_PATH}"

##############################################################
## Create the Certificate Chain Bundles
##############################################################
createCertificateChain "${KL_EDGE_SCA_PATH}" "${KL_ICA_PATH}" "${ROOT_CA_PATH}" "${KL_EDGE_SCA_SLUG}" "${KL_ICA_SLUG}" "${ROOT_CA_SLUG}"

##############################################################
## Create the Client/Service/User Certificates
##############################################################
createWebServerCertificate "edge-hub.kemo.edge" "*.apps.kemo.edge;edge-hub.kemo.edge;*.kemo.edge" "ken@kenmoini.com" "US" "North Carolina" "Raleigh" "Kemo Labs" "Kemo Labs Edge Services" "${KL_EDGE_SCA_PATH}"
