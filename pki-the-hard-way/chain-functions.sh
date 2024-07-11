#!/bin/bash

##################################################################################################################################
## createRootCA creates a new Root CA
# createRootCA $CA_PATH $CA_SLUG $CA_CN $CA_COUNTRY_CODE $CA_STATE $CA_CITY $CA_ORG $CA_ORG_UNIT $CA_EMAIL
# createRootCA $1       $2       $3     $4               $5        $6       $7      $8           $9
##################################################################################################################################
createRootCA() {
  ##############################################################
  ## Create Directory Structure
  echo -e "\n===== Creating Root CA (${2})..."
  echo -e " - Creating directories..."
  mkdir -p ${1}/{certs,crl,newcerts,private,intermediates}
  mkdir -p ${1}/public_bundles/{certs,crls}

  echo -e " - Setting permissions on directories..."
  chmod 700 ${1}/private
  chmod -R 777 ${1}/public_bundles

  ##############################################################
  ## Create basic files
  echo -e " - Touching basic files (index, serial, crlnumber)..."
  touch ${1}/index.txt
  [ ! -f ${1}/serial ] && echo 1000 > ${1}/serial
  [ ! -f ${1}/crlnumber ] && echo 1000 > ${1}/crlnumber

  ##############################################################
  ## Create OpenSSL Configuration files
  echo -e " - Creating OpenSSL configuration files..."
  #generateOpenSSLConfFile "${1}" root "$ROOT_CA_COUNTRY_CODE" "$ROOT_CA_STATE" "$ROOT_CA_CITY" "$ROOT_CA_ORG" "$ROOT_CA_ORG_UNIT" "$ROOT_CA_EMAIL" 7500 "https://pki.kemo.edge:443/crls/${ROOT_CA_SLUG}.crl"
  generateOpenSSLConfFile "${1}" root "${4}" "${5}" "${6}" "${7}" "${8}" "${9}" 7500 "https://pki.kemo.edge:443/crls/${2}.crl"

  ##############################################################
  ## Create OpenSSL Private Keys
  if [ ! -f ${1}/private/root.key.pem ]; then
    echo -e " -  Creating Private Key for Root CA..."
    openssl genrsa -aes256 -out ${1}/private/root.key.pem 4096
    chmod 400 ${1}/private/root.key.pem
  else
    echo " - Root CA Private Key Exists!"
  fi

  ################################################################
  ## Create CA Certificate
  if [ ! -f ${1}/certs/root.cert.pem ]; then
    echo -e " - Creating CA Self-Signed Certificate..."

    openssl req -config ${1}/openssl.cnf \
      -key ${1}/private/root.key.pem \
      -new -x509 -days 7500 -sha256 -extensions v3_root_ca \
      -out ${1}/certs/root.cert.pem \
      -subj "/emailAddress=${9}/C=${4}/ST=${5}/L=${6}/O=${7}/OU=${8}/CN=${3}"

    chmod 444 ${1}/certs/root.cert.pem
  else
    echo " - CA Certificate Exists!"
  fi

  ##############################################################
  ## Create CRL
  if [ ! -f ${1}/crl/root.crl.pem ]; then
    echo -e " - Creating Certificate Revocation List..."
    openssl ca -config ${1}/openssl.cnf -gencrl -out ${1}/crl/root.crl.pem
  else
    echo " - Root CA CRL Exists!"
  fi

  ##############################################################
  ## Copy the Root CA Certificate to the System Store
  # echo -e " - Copying Root CA Certificate to the System Store..."
  # cp ${1}/certs/root.cert.pem /usr/share/pki/ca-trust-source/anchors/${2}.cert.pem
  # update-ca-trust

}

##################################################################################################################################
## createIntermediateCA creates a new Intermediate CA signed by the Root CA
# createIntermediateCA $CA_PATH $CA_SLUG $CA_CN $CA_COUNTRY_CODE $CA_STATE $CA_CITY $CA_ORG $CA_ORG_UNIT $CA_EMAIL $ROOT_CA_PATH
# createIntermediateCA $1       $2       $3     $4               $5        $6       $7      $8           $9        $10
##################################################################################################################################
createIntermediateCA() {
  echo -e "\n===== Creating Intermediate CA (${2})..."

  ##############################################################
  ## Create Directory Structure
  echo -e " - Creating directories..."
  mkdir -p $1/{certs,crl,csr,newcerts,private,signing}

  echo -e " - Setting permissions on directories..."
  chmod 700 ${1}/private

  ##############################################################
  ## Create basic files
  echo -e " - Touching basic files (index, serial, crlnumber)..."
  touch ${1}/index.txt
  [ ! -f ${1}/serial ] && echo 1000 > ${1}/serial
  [ ! -f ${1}/crlnumber ] && echo 1000 > ${1}/crlnumber

  ##############################################################
  ## Create OpenSSL Configuration files
  echo -e " - Creating OpenSSL configuration files..."
  generateOpenSSLConfFile "${1}" intermediate "${4}" "${5}" "${6}" "${7}" "${8}" "${9}" 3750 "https://pki.kemo.edge:443/crls/${2}.crl"

  ##############################################################
  ## Create OpenSSL Private Keys
  if [ ! -f ${1}/private/intermediate.key.pem ]; then
    echo -e " -  Creating Private Key for Intermediate CA..."
    openssl genrsa -aes256 -out ${1}/private/intermediate.key.pem 4096
    chmod 400 ${1}/private/intermediate.key.pem
  else
    echo " - Intermediate CA Private Key Exists!"
  fi

  ##############################################################
  ## Create Intermediate CA CSR
  if [ ! -f ${1}/csr/intermediate.csr.pem ]; then
    echo -e " - Creating Intermediate CA CSR..."

    openssl req -new -sha256 \
      -config ${1}/openssl.cnf \
      -key ${1}/private/intermediate.key.pem \
      -out ${1}/csr/intermediate.csr.pem \
      -subj "/emailAddress=${9}/C=${4}/ST=${5}/L=${6}/O=${7}/OU=${8}/CN=${3}"
  else
    echo " - Intermediate CA CSR Exists!"
  fi

  ##############################################################
  ## Sign Intermediate CA CSR with Root CA
  if [ ! -f ${1}/certs/intermediate.cert.pem ]; then
    echo -e " - Signing Intermediate CA CSR with Root CA..."

    openssl ca -config ${10}/openssl.cnf -extensions v3_intermediate_ca \
      -days 3750 -notext -md sha256 \
      -in ${1}/csr/intermediate.csr.pem \
      -out ${1}/certs/intermediate.cert.pem

    chmod 444 ${1}/certs/intermediate.cert.pem
  else
    echo " - Intermediate CA Certificate Exists!"
  fi

  ##############################################################
  ## Create CRL
  if [ ! -f ${1}/crl/intermediate.crl.pem ]; then
    echo -e " - Creating Certificate Revocation List..."
    openssl ca -config ${1}/openssl.cnf -gencrl -out ${1}/crl/intermediate.crl.pem
  else
    echo " - Intermediate CA CRL Exists!"
  fi

}

#####################################################################################################################################
## createSigningCA creates a new Signing CA signed by the Intermediate CA
# createSigningCA $CA_PATH $CA_SLUG $CA_CN $CA_COUNTRY_CODE $CA_STATE $CA_CITY $CA_ORG $CA_ORG_UNIT $CA_EMAIL $INTERMEDIATE_CA_PATH
# createSigningCA $1       $2       $3     $4               $5        $6       $7      $8           $9        $10
#####################################################################################################################################
createSigningCA() {
  echo -e "\n===== Creating Signing CA (${2})..."

  ##############################################################
  ## Create Directory Structure
  echo -e " - Creating directories..."
  mkdir -p $1/{certs,crl,csr,newcerts,private}

  echo -e " - Setting permissions on directories..."
  chmod 700 ${1}/private

  ##############################################################
  ## Create basic files
  echo -e " - Touching basic files (index, serial, crlnumber)..."
  touch ${1}/index.txt
  [ ! -f ${1}/serial ] && echo 1000 > ${1}/serial
  [ ! -f ${1}/crlnumber ] && echo 1000 > ${1}/crlnumber

  ##############################################################
  ## Create OpenSSL Configuration files
  echo -e " - Creating OpenSSL configuration files..."
  generateOpenSSLConfFile "${1}" signing "${4}" "${5}" "${6}" "${7}" "${8}" "${9}" 1875 "https://pki.kemo.edge:443/crls/${2}.crl"

  ##############################################################
  ## Create OpenSSL Private Keys
  if [ ! -f ${1}/private/signing.key.pem ]; then
    echo -e " - Creating Private Keys..."
    openssl genrsa -aes256 -out ${1}/private/signing.key.pem 4096
    chmod 400 ${1}/private/signing.key.pem
  else
    echo " - Signing CA Private Key Exists!"
  fi

  ##############################################################
  ## Create Signing CA CSR
  if [ ! -f ${1}/csr/signing.csr.pem ]; then
    echo -e " - Creating Signing CA CSR..."

    openssl req -new -sha256 \
      -config ${1}/openssl.cnf \
      -key ${1}/private/signing.key.pem \
      -out ${1}/csr/signing.csr.pem \
      -subj "/emailAddress=${9}/C=${4}/ST=${5}/L=${6}/O=${7}/OU=${8}/CN=${3}"
  else
    echo " - Signing CA CSR Exists!"
  fi

  ##############################################################
  ## Sign Signing CA CSR with Intermediate CA
  if [ ! -f ${1}/certs/signing.cert.pem ]; then
    echo -e " - Signing Signing CA CSR with Intermediate CA..."

    openssl ca -config ${10}/openssl.cnf -extensions v3_signing_ca \
      -days 1875 -notext -md sha256 \
      -in ${1}/csr/signing.csr.pem \
      -out ${1}/certs/signing.cert.pem

    chmod 444 ${1}/certs/signing.cert.pem
  else
    echo " - Signing CA Certificate Exists!"
  fi

  ##############################################################
  ## Create CRL

  if [ ! -f ${1}/crl/signing.crl.pem ]; then
    echo -e " - Creating Signing Revocation List..."
    openssl ca -config ${1}/openssl.cnf -gencrl -out ${1}/crl/signing.crl.pem
  else
    echo " - Signing CA CRL Exists!"
  fi

}
#####################################################################################################################################
## generateOpenSSLConfFile generates an OpenSSL configuration file for different CA types
# generateOpenSSLConfFile $destPath $type $countryCode $state $city $org $orgUnit $email $expireDays $crlURL
#####################################################################################################################################
generateOpenSSLConfFile() {
cat << EOF > ${1}/openssl.cnf
# OpenSSL ${2} CA configuration file.
# Copy to ${1}/openssl.cnf.

[ ca ]
# 'man ca'
default_ca        = CA_default

[ CA_default ]
# Directory and file locations.
dir               = ${1}
certs             = \$dir/certs
crl_dir           = \$dir/crl
new_certs_dir     = \$dir/newcerts
database          = \$dir/index.txt
serial            = \$dir/serial
RANDFILE          = \$dir/private/.rand

# The root key and root certificate.
private_key       = \$dir/private/${2}.key.pem
certificate       = \$dir/certs/${2}.cert.pem

# For certificate revocation lists.
crlnumber         = \$dir/crlnumber
crl               = \$dir/crl/${2}.crl.pem
crl_extensions    = crl_ext
default_crl_days  = 30

# SHA-1 is deprecated, so use SHA-2 instead.
default_md        = sha256

name_opt          = ca_default
cert_opt          = ca_default
default_days      = ${9}
preserve          = no
copy_extensions   = copy
policy            = policy_${2}

[ policy_root ]
# The root CA should only sign intermediate certificates that match.
# See the POLICY FORMAT section of 'man ca'.
countryName             = supplied
stateOrProvinceName     = supplied
organizationName        = match
organizationalUnitName  = optional
commonName              = supplied
emailAddress            = supplied

[ policy_intermediate ]
# The intermediate CAs should only sign signing certificates that match.
# See the POLICY FORMAT section of 'man ca'.
countryName             = supplied
stateOrProvinceName     = supplied
organizationName        = supplied
organizationalUnitName  = optional
commonName              = supplied
emailAddress            = supplied

[ policy_signing ]
# Allow the signing CAs to sign a more diverse range of certificates.
# See the POLICY FORMAT section of 'man ca'.
countryName             = optional
stateOrProvinceName     = optional
localityName            = optional
organizationName        = optional
organizationalUnitName  = optional
commonName              = supplied
emailAddress            = optional

[ req ]
# Options for the 'req' tool ('man req').
default_bits        = 4096
distinguished_name  = req_distinguished_name
string_mask         = utf8only

# SHA-1 is deprecated, so use SHA-2 instead.
default_md          = sha256

# Extension to add when the -x509 option is used.
x509_extensions     = v3_${2}_ca

[ req_distinguished_name ]
# See <https://en.wikipedia.org/wiki/Certificate_signing_request>.
countryName                     = Country Name (2 letter code)
stateOrProvinceName             = State or Province Name
localityName                    = Locality Name
0.organizationName              = Organization Name
organizationalUnitName          = Organizational Unit Name
commonName                      = Common Name
emailAddress                    = Email Address

# Optionally, specify some defaults.
countryName_default             = ${3}
stateOrProvinceName_default     = ${4}
localityName_default            = ${5}
0.organizationName_default      = ${6}
organizationalUnitName_default  = ${7}
emailAddress_default            = ${8}

[ v3_root_ca ]
# Extensions for a Root CA ('man x509v3_config').
subjectKeyIdentifier    = hash
authorityKeyIdentifier  = keyid:always,issuer
basicConstraints        = critical, CA:true
keyUsage                = critical, digitalSignature, cRLSign, keyCertSign
crlDistributionPoints   = crl_dist

[ v3_intermediate_ca ]
# Extensions for an Intermediate CA ('man x509v3_config').
subjectKeyIdentifier    = hash
authorityKeyIdentifier  = keyid:always,issuer
basicConstraints        = critical, CA:true
keyUsage                = critical, digitalSignature, cRLSign, keyCertSign
crlDistributionPoints   = crl_dist

[ v3_signing_ca ]
# Extensions for a Signing CA ('man x509v3_config').
subjectKeyIdentifier    = hash
authorityKeyIdentifier  = keyid:always,issuer
basicConstraints        = critical, CA:true, pathlen:0
keyUsage                = critical, digitalSignature, cRLSign, keyCertSign
crlDistributionPoints   = crl_dist

[ v3_ldap_ca ]
# Extensions for a FreeIPA/RH IDM CA ('man x509v3_config').
subjectKeyIdentifier    = hash
authorityKeyIdentifier  = keyid:always,issuer
basicConstraints        = critical, CA:true
keyUsage                = critical, digitalSignature, nonRepudiation, cRLSign, keyCertSign, dataEncipherment, keyEncipherment
extendedKeyUsage        = clientAuth, emailProtection, serverAuth, codeSigning, OCSPSigning, ipsecIKE, timeStamping
crlDistributionPoints   = crl_dist

[ user_cert ]
# Extensions for client certificates ('man x509v3_config').
basicConstraints        = CA:FALSE
nsCertType              = client, email
nsComment               = "OpenSSL Generated Client Certificate"
subjectKeyIdentifier    = hash
authorityKeyIdentifier  = keyid,issuer
keyUsage                = critical, nonRepudiation, digitalSignature, keyEncipherment
issuerAltName           = issuer:copy
extendedKeyUsage        = clientAuth, emailProtection

[ server_cert ]
# Extensions for server certificates ('man x509v3_config').
basicConstraints        = CA:FALSE
nsCertType              = server
nsComment               = "OpenSSL Generated Server Certificate"
subjectKeyIdentifier    = hash
authorityKeyIdentifier  = keyid,issuer:always
keyUsage                = critical, digitalSignature, keyEncipherment
extendedKeyUsage        = serverAuth
issuerAltName           = issuer:copy
crlDistributionPoints   = crl_dist

[ openvpn_server_cert ]
# OpenVPN Server Certificate Extensions
basicConstraints        = CA:FALSE
keyUsage                = critical, digitalSignature, dataEncipherment, keyEncipherment
extendedKeyUsage        = critical, serverAuth
subjectKeyIdentifier    = hash
nsCertType              = server
nsComment               = "OpenSSL Generated OpenVPN Server Certificate"
authorityKeyIdentifier  = keyid,issuer:always
issuerAltName           = issuer:copy
crlDistributionPoints   = crl_dist

[ openvpn_client_cert ]
# Extensions for client certificates ('man x509v3_config').
basicConstraints        = CA:FALSE
nsCertType              = client
nsComment               = "OpenSSL Generated OpenVPN Client Certificate"
subjectKeyIdentifier    = hash
authorityKeyIdentifier  = keyid,issuer
keyUsage                = critical, nonRepudiation, digitalSignature, dataEncipherment, keyEncipherment
issuerAltName           = issuer:copy
extendedKeyUsage        = clientAuth
crlDistributionPoints   = crl_dist

[ crl_ext ]
# Extension for CRLs ('man x509v3_config').
authorityKeyIdentifier  = keyid:always
issuerAltName           = issuer:copy

[ ocsp ]
# Extension for OCSP signing certificates ('man ocsp').
basicConstraints        = CA:FALSE
subjectKeyIdentifier    = hash
authorityKeyIdentifier  = keyid,issuer
keyUsage                = critical, digitalSignature
extendedKeyUsage        = critical, OCSPSigning

[ crl_dist ]
# CRL Download address for the ${2} CA
fullname                = URI:${10}

EOF
}

#####################################################################################################################################
## checkForProgramAndExit checks for the existence of a program in the system PATH and exits if it is not found
# checkForProgramAndExit <program>
#####################################################################################################################################
function checkForProgramAndExit() {
    command -v $1 > /dev/null 2>&1
    if [[ $? -eq 0 ]]; then
        printf ' - %-72s %-7s\n' $1 "PASSED!";
    else
        printf ' - %-72s %-7s\n' $1 "FAILED!";
        exit 1
    fi
}

#####################################################################################################################################
## createCertificateChain creates the certificate chain bundles for Signing > Intermediate CA > Root CA
# createCertificateChain $SIGNING_CA_PATH $INTERMEDIATE_CA_PATH $ROOT_CA_PATH $SIGNING_CA_SLUG $INTERMEDIATE_CA_SLUG $ROOT_CA_SLUG
#####################################################################################################################################
function createCertificateChain() {
  echo -e "\n===== Creating Certificate Chain Bundles..."

  echo -e " - Creating full CA Chain (Signing CA -> Intermediate CA -> Root CA)\n    at ${1}/certs/full-ca-chain.cert.pem"
  cat ${1}/certs/signing.cert.pem \
    ${2}/certs/intermediate.cert.pem \
    ${3}/certs/root.cert.pem \
    > ${1}/certs/full-ca-chain.cert.pem

  echo -e " - Creating CA Chain Bundle (Signing CA -> Intermediate CA)\n    at ${1}/certs/ca-bundle.cert.pem"
  cat ${1}/certs/signing.cert.pem \
    ${2}/certs/intermediate.cert.pem \
    > ${1}/certs/ca-bundle.cert.pem

  ## Create Public Bundles
  echo " - Creating Public Bundles..."
  cp ${3}/certs/root.cert.pem ${3}/public_bundles/certs/${6}.cert.pem
  cp ${2}/certs/intermediate.cert.pem ${3}/public_bundles/certs/${5}.cert.pem
  cp ${1}/certs/signing.cert.pem ${3}/public_bundles/certs/${4}.cert.pem

  cp ${1}/certs/full-ca-chain.cert.pem ${3}/public_bundles/certs/${4}.full-ca-chain.cert.pem
  cp ${1}/certs/ca-bundle.cert.pem ${3}/public_bundles/certs/${4}.ca-bundle.cert.pem

  cp ${3}/crl/root.crl.pem ${3}/public_bundles/crls/${6}.crl.pem
  cp ${2}/crl/intermediate.crl.pem ${3}/public_bundles/crls/${5}.crl.pem
  cp ${1}/crl/signing.crl.pem ${3}/public_bundles/crls/${4}.crl.pem

  echo " - Setting permissions..."
  chmod 644 ${1}/certs/full-ca-chain.cert.pem
  chmod 644 ${1}/certs/ca-bundle.cert.pem

  chmod -R 775 ${3}/public_bundles/
}

#########################################################################################################################################
## createOpenVPNClientCertificate creates OpenVPN client certificates
# createOpenVPNClientCertificate "kemo" "ken@kenmoini.com" "US" "North Carolina" "Raleigh" "Kemo Networks" "Kemo Networks VPN Services" "/path/to/signing/ca"
#########################################################################################################################################
createOpenVPNClientCertificate() {
  echo -e "\n===== Creating OpenVPN Client Certificates..."
  local CLIENT_NAME=$1
  local CLIENT_EMAIL=$2
  local CLIENT_COUNTRY_CODE=$3
  local CLIENT_STATE=$4
  local CLIENT_CITY=$5
  local CLIENT_ORG=$6
  local CLIENT_ORG_UNIT=$7
  local CLIENT_CN=$CLIENT_NAME
  local CA_ROOT=$8
  
  echo -e " - Processing client: ${CLIENT_NAME}..."

  ## Generate the OpenVPN Client Certificate Private Key
  if [ ! -f ${CA_ROOT}/private/openvpn-client-${CLIENT_NAME}.key.pem ]; then
    echo -e " - Creating Private Key for a ${CLIENT_NAME} OpenVPN Client Certificate..."
    openssl genrsa -out ${CA_ROOT}/private/openvpn-client-${CLIENT_NAME}.key.pem 4096
    chmod 400 ${CA_ROOT}/private/openvpn-client-${CLIENT_NAME}.key.pem
  else
    echo " - ${CLIENT_NAME} OpenVPN Client Private Key Exists!"
  fi

  ## Generate the OpenVPN Client CSR
  if [ ! -f ${CA_ROOT}/csr/openvpn-client-${CLIENT_NAME}.csr.pem ]; then
    echo -e " - Creating ${CLIENT_NAME} OpenVPN Client CSR..."

    openssl req -new -sha256 \
      -config ${CA_ROOT}/openssl.cnf \
      -key ${CA_ROOT}/private/openvpn-client-${CLIENT_NAME}.key.pem \
      -out ${CA_ROOT}/csr/openvpn-client-${CLIENT_NAME}.csr.pem \
      -subj "/emailAddress=${CLIENT_EMAIL}/C=${CLIENT_COUNTRY_CODE}/ST=${CLIENT_STATE}/L=${CLIENT_CITY}/O=${CLIENT_ORG}/OU=${CLIENT_ORG_UNIT}/CN=${CLIENT_CN}"
  else
    echo " - ${CLIENT_NAME} OpenVPN Client CSR Exists!"
  fi

  ## Generate the OpenVPN Client Certificate
  if [ ! -f ${CA_ROOT}/certs/openvpn-client-${CLIENT_NAME}.cert.pem ]; then
    echo -e " - Signing ${CLIENT_NAME} OpenVPN Client CSR with Signing CA..."

    openssl ca -config ${CA_ROOT}/openssl.cnf -extensions openvpn_client_cert \
      -days 375 -notext -md sha256 \
      -in ${CA_ROOT}/csr/openvpn-client-${CLIENT_NAME}.csr.pem \
      -out ${CA_ROOT}/certs/openvpn-client-${CLIENT_NAME}.cert.pem

    chmod 444 ${CA_ROOT}/certs/openvpn-client-${CLIENT_NAME}.cert.pem
  else
    echo " - ${CLIENT_NAME} OpenVPN Client Certificate Exists!"
  fi
}

#########################################################################################################################################
## createOpenVPNServerCertificate creates OpenVPN Server certificates
# createOpenVPNServerCertificate "vpn.example.com" "ken@kenmoini.com" "US" "North Carolina" "Raleigh" "Kemo Networks" "Kemo Networks Canadian OpenVPN Server" "/path/to/signing/ca"
#########################################################################################################################################
createOpenVPNServerCertificate() {
  echo -e "\n===== Creating OpenVPN Server Certificate..."
  local SERVER_DOMAIN=$1
  local SERVER_EMAIL=$2
  local SERVER_COUNTRY_CODE=$3
  local SERVER_STATE=$4
  local SERVER_CITY=$5
  local SERVER_ORG=$6
  local SERVER_ORG_UNIT=$7
  local CA_ROOT=$8
  local SERVER_CN=$SERVER_DOMAIN

  ## Generate the OpenVPN Server Certificate Private Key
  if [ ! -f ${CA_ROOT}/private/${SERVER_DOMAIN}.key.pem ]; then
    echo -e " -  Creating Private Key for the OpenVPN Server Certificate..."
    openssl genrsa -out ${CA_ROOT}/private/${SERVER_DOMAIN}.key.pem 4096
    chmod 400 ${CA_ROOT}/private/${SERVER_DOMAIN}.key.pem
  else
    echo " - OpenVPN Server Private Key Exists!"
  fi

  ## Generate the OpenVPN Server CSR
  if [ ! -f ${CA_ROOT}/csr/${SERVER_DOMAIN}.csr.pem ]; then
    echo -e " - Creating the OpenVPN Server CSR..."

    openssl req -new -sha256 \
      -config ${CA_ROOT}/openssl.cnf \
      -key ${CA_ROOT}/private/${SERVER_DOMAIN}.key.pem \
      -out ${CA_ROOT}/csr/${SERVER_DOMAIN}.csr.pem \
      -addext 'subjectAltName = DNS:${SERVER_DOMAIN}' \
      -subj "/emailAddress=${SERVER_EMAIL}/C=${SERVER_COUNTRY_CODE}/ST=${SERVER_STATE}/L=${SERVER_CITY}/O=${SERVER_ORG}/OU=${SERVER_ORG_UNIT}/CN=${SERVER_CN}"
  else
    echo " - OpenVPN Server CSR Exists!"
  fi

  ## Generate the OpenVPN Server Certificate
  if [ ! -f ${CA_ROOT}/certs/${SERVER_DOMAIN}.cert.pem ]; then
    echo -e " - Signing OpenVPN Server CSR with Signing CA..."

    openssl ca -config ${CA_ROOT}/openssl.cnf -extensions openvpn_server_cert \
      -days 375 -notext -md sha256 \
      -in ${CA_ROOT}/csr/${SERVER_DOMAIN}.csr.pem \
      -out ${CA_ROOT}/certs/${SERVER_DOMAIN}.cert.pem

    chmod 444 ${CA_ROOT}/certs/${SERVER_DOMAIN}.cert.pem
  else
    echo " - OpenVPN Server Certificate Exists!"
  fi

  ## Generate Diffie-Hellman parameters
  if [ ! -f ${CA_ROOT}/private/${SERVER_DOMAIN}.dh.pem ]; then
    echo -e " - Generating Diffie-Hellman parameters for OpenVPN Server..."

    openssl dhparam -out ${CA_ROOT}/private/${SERVER_DOMAIN}.dh.pem 2048
  else
    echo " - OpenVPN Server Diffie-Hellman Parameters Exists!"
  fi

  ## Generate TLS Auth Secret
  if [ ! -f ${CA_ROOT}/private/${SERVER_DOMAIN}.tlsauth.key.pem ]; then
    echo -e " - Generating TLS Auth Secret for OpenVPN Server Certificate..."

    openvpn --genkey --secret ${CA_ROOT}/private/${SERVER_DOMAIN}.tlsauth.key.pem
    chmod 400 ${CA_ROOT}/private/${SERVER_DOMAIN}.tlsauth.key.pem
  else
    echo " - OpenVPN Server TLS Auth Secret Exists!"
  fi

}

#########################################################################################################################################
## createWebServerCertificate creates Web Server certificates
# createWebServerCertificate "example.com" "*.example.com;*.apps.example.com" "kemo@redhat.com" "US" "North Carolina" "Raleigh" "Kemo Networks" "Kemo Networks Web Servers" "/path/to/signing/ca"
#########################################################################################################################################
createWebServerCertificate() {
  echo -e "\n===== Generating Server Certificate..."
  local SERVER_DOMAIN=$1
  local SERVER_FILE_NAME=$(echo $1 | tr '*' 'wildcard')
  
  local SERVER_DNS_SANS=$2
  local SERVER_DNS_SANS_ARRAY=(${SERVER_DNS_SANS//;/ })
  local SERVER_DNS_SANS_FORMATTED="DNS:${SERVER_DOMAIN}"
  for i in "${SERVER_DNS_SANS_ARRAY[@]}"; do
    SERVER_DNS_SANS_FORMATTED="${SERVER_DNS_SANS_FORMATTED},DNS:${i}"
  done

  local SERVER_EMAIL=$3
  local SERVER_COUNTRY_CODE=$4
  local SERVER_STATE=$5
  local SERVER_CITY=$6
  local SERVER_ORG=$7
  local SERVER_ORG_UNIT=$8
  local CA_ROOT=$9
  local SERVER_CN=$SERVER_DOMAIN

  ## Generate the Server Certificate Private Key
  if [ ! -f ${CA_ROOT}/private/${SERVER_FILE_NAME}.key.pem ]; then
    echo -e " - Creating Private Key for a Server Certificate...\n=====\n"
    openssl genrsa -out ${CA_ROOT}/private/${SERVER_FILE_NAME}.key.pem 4096
    chmod 400 ${CA_ROOT}/private/${SERVER_FILE_NAME}.key.pem
  else
    echo " - Server Certificate Private Key Exists!"
  fi

  if [ ! -f ${CA_ROOT}/csr/${SERVER_FILE_NAME}.csr.pem ]; then
    echo -e " - Creating Server Certificate CSR..."

    openssl req -new -sha256 \
      -config ${CA_ROOT}/openssl.cnf \
      -key ${CA_ROOT}/private/${SERVER_FILE_NAME}.key.pem \
      -out ${CA_ROOT}/csr/${SERVER_FILE_NAME}.csr.pem \
      -addext 'subjectAltName = '${SERVER_DNS_SANS_FORMATTED}'' \
      -subj "/emailAddress=${SERVER_EMAIL}/C=${SERVER_COUNTRY_CODE}/ST=${SERVER_STATE}/L=${SERVER_CITY}/O=${SERVER_ORG}/OU=${SERVER_ORG_UNIT}/CN=${SERVER_CN}"
  else
    echo " - Server Certificate CSR Exists!"
  fi

  if [ ! -f ${CA_ROOT}/certs/${SERVER_FILE_NAME}.cert.pem ]; then
    echo -e " - Server Certificate CSR with Signing CA..."

    openssl ca -config ${CA_ROOT}/openssl.cnf -extensions server_cert \
      -days 375 -notext -md sha256 \
      -in ${CA_ROOT}/csr/${SERVER_FILE_NAME}.csr.pem \
      -out ${CA_ROOT}/certs/${SERVER_FILE_NAME}.cert.pem

    chmod 444 ${CA_ROOT}/certs/${SERVER_FILE_NAME}.cert.pem
  else
    echo " - Server Certificate Exists!"
  fi

  if [ ! -f ${CA_ROOT}/certs/bundle_haproxy-${SERVER_FILE_NAME}.cert.pem ]; then
    echo -e " - Creating HAProxy Certificate bundle for Server Certificate..."
    cat ${CA_ROOT}/private/${SERVER_FILE_NAME}.key.pem \
      ${CA_ROOT}/certs/${SERVER_FILE_NAME}.cert.pem \
      ${CA_ROOT}/certs/full-ca-chain.cert.pem \
      > ${CA_ROOT}/certs/bundle_haproxy-${SERVER_FILE_NAME}.cert.pem

    chmod 644 ${CA_ROOT}/certs/bundle_haproxy-${SERVER_FILE_NAME}.cert.pem
  else
    echo " - Server Certificate HAProxy bundle Exists!"
  fi
}