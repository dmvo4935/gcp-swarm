#!/bin/bash

apt-get -y update && apt-get -y install python-pip docker.io
pip install --upgrade pip ansible

#echo "ansible-pull -U https://github.com/dmvo4935/ansible.git -e \"manager_address=${master_address}\" local_main.yml"
ansible-pull -U https://github.com/dmvo4935/ansible.git -e 'manager_address=${master_address}' local_main.yml
#echo ${master_address} > /master_address
