#!/bin/bash

apt-get -y update && apt-get -y install python-pip docker.io
pip install --upgrade pip ansible

ansible-pull -U https://github.com/dmvo4935/ansible.git -C ${branch} -e 'manager_address=${master_address}' local_main.yml
#echo ${master_address} > /master_address
