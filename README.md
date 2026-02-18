# BIKES

## Prepare Data


After cloning this repository, download the media (audio and video files) and place them in a directory ``media/`` in the root directory of this repository.

Current home of the media is only accessible with GaTech credentials:
https://gtvault.sharepoint.com/:f:/s/L42II-CIC_Asia/IgCdoEeOcv1BTbRsNfRwcvLZAYwcsakacRHTjUhNamec9Gs?e=gvjCoL


## Getting Started with Ansible

To run the first steps without SSH key:

    $ sudo apt install sshpass


### Check

    $ ansible-playbook -k -i pis.ini ping.yml

### Copy ssh key

    $ ansible-playbook -k -i pis.ini copy_ssh_key.yml -e "key=PATH_TO_PUBLIC_KEY"


After this, all playbooks can be run without the -k flag - and without password prompt.

## Customize


## Install Software

    
    $ ansible-playbook -i pis.ini install_supercollider.yml


Processing: needs to be from tarball (github releases) NOT from snap - that one is missing the processing-java

----

## Syncing Media

- Run the ``sync_mesh.yml`` playbook to get all media to the remote nodes.

----

## 