#!/bin/sh
# 実行後、libvirtdへのアクセス権限を有効にするためホストマシンを再起動してください
python3 -m pip install --upgrade pip
pip3 install \
    grpcio grpcio-tools \
    flask flask-sqlalchemy flask-migrate \
    flask-wtf email-validator flask-login PyMySQL \
    ipget docker kubernetes

sudo apt install \
    libvirt-clients virtinst qemu-system libvirt-daemon-system \
    mysql-server mysql-client python3-mysqldb