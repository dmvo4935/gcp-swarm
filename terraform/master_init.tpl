#cloud-config
package_update: true

packages:
 - docker.io
 - python-pip

runcmd:
 - pip install --upgrade pip bottle
