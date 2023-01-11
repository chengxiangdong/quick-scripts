#!/bin/bash
# https://raw.githubusercontent.com/chengxiangdong/quick-scripts/main/scripts/install-go.sh

yum install -y wget
wget https://dl.google.com/go/go1.19.4.linux-amd64.tar.gz
rm -rf /usr/local/go && tar -C /usr/local -xzf go1.19.4.linux-amd64.tar.gz

echo "export PATH=$PATH:/usr/local/go/bin" >> ~/.bash_profile
source ~/.bash_profile
