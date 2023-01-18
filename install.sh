#!/bin/bash
sudo apt install git -y
cd /opt
sudo git clone https://github.com/CIP43R/setup-linux-server.git
cd setup-linux-server
sudo bash ./init.sh