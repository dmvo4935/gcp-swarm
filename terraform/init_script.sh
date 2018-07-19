#!/bin/bash

apt-get -y update && apt-get -y install python-pip docker.io
pip install --upgrade pip ansible

ansible-pull -U https://github.com/dmvo4935/gcp-swarm.git -C ${branch} -e 'manager_address=${master_address}' ansible1/local_main.yml
#echo ${master_address} > /master_address
