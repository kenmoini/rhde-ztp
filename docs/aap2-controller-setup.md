# Ansible Automation Platform 2 Controller Setup

> You can also just run the `ansible/controller-setup/configure-controller.yml` Playbook to do all this and more.  Once that Playbook runs, log in and create a Token as described on step 8 below.

1. Fork this repo
2. Install AAP2 Controller (??!!)
3. Create an **Inventory** called `RHDE` - observe the Inventory ID which is needed for the FDO-Ansible Glue Service.
4. Create a **Project** called `RHDE` *(why not)* - use your fork of this repo: https://github.com/kenmoini/rhde-ztp
5. Create a **Credential**, named `RHDEMachineKey` with a Machine type, add your private SSH Key - omit the Username. choose the `sudo` escalation method
6. Create ***another Credential***, named `RHDEVault` with an Ansible Vault password to be used for things such as a RH Pull Secret
7. Create an **Application**, named `RHDE`, `Resource owner password-based` grant type, `Public` client type
8. From **Users**, create/select a user, click on the Tokens tab, generate a Token with the `RHDE` Application - this token is used for the FDO-Ansible Glue Service
9. Create a **Template**, name it something like `RHDE FDO Post Bootstrap`.  Select the `RHDE` Inventory and Project, choose the `ansible/post-bootstrap-config.yml` Playbook, check `Prompt on Launch` for Variables and Limit, check Privilege Escalation, and in production you'd check Concurrent Jobs as well.  Add the `RHDEVault` and `RHDEMachineKey` Credentials.  Note the Job Template ID, this is needed for the FDO-Ansible Glue Service.
10. You may also create Templates for the `ansible/setup-fdo-server.yml` and `setup-image-builder-server.yml` Playbooks if you wish to run those tasks from AAPC.  Just make sure to create a separate Inventory and add your host/groups for those Playbooks.

## Copy Certificates to the AAP2 VM

Assuming you've run the PKI The Hard Way scripts, you can ship over the needed certs to AAP2 to get things all nicely validated:

```bash
ROOT_CA_CERT_PATH=./pki-the-hard-way/.pki/root-ca/certs/root.cert.pem

TOWER_CERT_PATH=./pki-the-hard-way/.pki/root-ca/intermediates/kemo-labs-intermediate-certificate-authority/signing/kemo-labs-edge-sca/certs/edge-hub.kemo.edge.cert.pem

TOWER_KEY_PATH=./pki-the-hard-way/.pki/root-ca/intermediates/kemo-labs-intermediate-certificate-authority/signing/kemo-labs-edge-sca/private/edge-hub.kemo.edge.key.pem

TOWER_BUNDLE_PATH=./pki-the-hard-way/.pki/root-ca/intermediates/kemo-labs-intermediate-certificate-authority/signing/kemo-labs-edge-sca/certs/full-ca-chain.cert.pem

ssh-copy-id root@aap2-controller.kemo.edge

scp ${ROOT_CA_CERT_PATH} root@aap2-controller.kemo.edge:/etc/pki/ca-trust/source/anchors/root.cert.pem
scp ${TOWER_CERT_PATH} root@aap2-controller.kemo.edge:/etc/tower/new-tower.cert
scp ${TOWER_KEY_PATH} root@aap2-controller.kemo.edge:/etc/tower/new-tower.key
scp ${TOWER_BUNDLE_PATH} root@aap2-controller.kemo.edge:/etc/tower/new-tower.bundle.cert

ssh root@aap2-controller.kemo.edge update-ca-trust
ssh root@aap2-controller.kemo.edge "mv /etc/tower/tower.cert /etc/tower/tower.cert.bak"
ssh root@aap2-controller.kemo.edge "mv /etc/tower/tower.key /etc/tower/tower.key.bak"
ssh root@aap2-controller.kemo.edge "cat /etc/tower/new-tower.cert /etc/tower/new-tower.bundle.cert > /etc/tower/tower.cert"
ssh root@aap2-controller.kemo.edge "mv /etc/tower/new-tower.key /etc/tower/tower.key"
ssh root@aap2-controller.kemo.edge "restorecon -v /etc/tower/tower.cert /etc/tower/tower.key"
ssh root@aap2-controller.kemo.edge "chown root:awx /etc/tower/tower.cert /etc/tower/tower.key"
ssh root@aap2-controller.kemo.edge "chmod 0600 /etc/tower/tower.cert /etc/tower/tower.key"
ssh root@aap2-controller.kemo.edge "nginx -t"

ssh root@aap2-controller.kemo.edge "systemctl reload nginx.service"
```