# Ubuntu 22.10 VM Blueprint

The purpose of this Vagrantfile is to provide a ready to use Ubuntu 22.10 environment.

The provisioning shell script will install latest version of Ansible using pip. Then a sample Ansible playbook will be executed.

## How to provision this VM

The blueprint supports Microsoft Hyper-V, VMware Workstation and Oracle VirtualBox backends, simply provision and connect to this VM using Vagrant.

```bash
vagrant up && vagrant ssh
```
