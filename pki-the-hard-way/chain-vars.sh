#!/bin/bash

##############################################################
## Root CA
ROOT_CA_PATH="${PKI_PATH}/root-ca"
ROOT_CA_SLUG="kemo-labs-certificate-authority"
ROOT_CA_CN="Kemo Labs Certificate Authority"
ROOT_CA_COUNTRY_CODE="US"
ROOT_CA_STATE="North Carolina"
ROOT_CA_CITY="Raleigh"
ROOT_CA_ORG="Kemo Labs"
ROOT_CA_ORG_UNIT="Kemo Labs InfoSec"
ROOT_CA_EMAIL="ken@kemo.labs"

##############################################################
## Intermediate CAs
##############################################################

## Intermediate CAs - Kemo Labs ICA
KL_ICA_SLUG="kemo-labs-intermediate-certificate-authority"
KL_ICA_PATH="${ROOT_CA_PATH}/intermediates/${KL_ICA_SLUG}"
KL_ICA_CN="Kemo Labs Intermediate Certificate Authority"
KL_ICA_COUNTRY_CODE="US"
KL_ICA_STATE="North Carolina"
KL_ICA_CITY="Raleigh"
KL_ICA_ORG="Kemo Labs"
KL_ICA_ORG_UNIT="Kemo Labs InfoSec"
KL_ICA_EMAIL="ken@kemo.labs"

##############################################################
## Signing CAs
##############################################################

## Signing CAs - Kemo Labs Edge SCA
KL_EDGE_SCA_SLUG="kemo-labs-edge-sca"
KL_EDGE_SCA_PATH="${KL_ICA_PATH}/signing/${KL_EDGE_SCA_SLUG}"
KL_EDGE_SCA_CN="Kemo Labs Edge Signing Certificate Authority"
KL_EDGE_SCA_COUNTRY_CODE="US"
KL_EDGE_SCA_STATE="North Carolina"
KL_EDGE_SCA_CITY="Raleigh"
KL_EDGE_SCA_ORG="Kemo Labs"
KL_EDGE_SCA_ORG_UNIT="Kemo Labs InfoSec"
KL_EDGE_SCA_EMAIL="ken@kemo.labs"
