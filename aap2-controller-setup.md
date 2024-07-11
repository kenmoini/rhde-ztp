# Ansible Automation Platform 2 Controller Setup

- Fork this repo
- Install AAP2 Controller (??!!)
- Create an **Inventory** called `RHDE` - observe the Inventory ID which is needed for the FDO-Ansible Glue Service.
- Create a **Project** called `RHDE` *(why not)* - use your fork of this repo: https://github.com/kenmoini/rhde-ztp
- Create a **Credential**, named `RHDEMachineKey` with a Machine type, add your private SSH Key - omit the Username. choose the `sudo` escalation method
- Create ***another Credential***, named `RHDEVault` with an Ansible Vault password to be used for things such as a RH Pull Secret
- Create an **Application**, named `RHDE`, `Resource owner password-based` grant type, `Public` client type
- From **Users**, create/select a user, click on the Tokens tab, generate a Token with the `RHDE` Application - this token is used for the FDO-Ansible Glue Service
- Create a **Template**, name it something like `RHDE FDO Post Bootstrap`.  Select the `RHDE` Inventory and Project, choose the `ansible/post-bootstrap-config.yml` Playbook, check `Prompt on Launch` for Variables and Limit, check Privilege Escalation, and in production you'd check Concurrent Jobs as well.  Add the `RHDEVault` and `RHDEMachineKey` Credentials.  Note the Job Template ID, this is needed for the FDO-Ansible Glue Service.
- You may also create Templates for the `ansible/setup-fdo-server.yml` and `setup-image-builder-server.yml` Playbooks if you wish to run those tasks from AAPC.  Just make sure to create a separate Inventory and add your host/groups for those Playbooks.

