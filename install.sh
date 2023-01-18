#!/bin/bash
echo "[INFO] Starting installation process..."
sudo apt install git -y &>
cd /opt
git clone https://github.com/CIP43R/setup-linux-server.git &>
cd setup-linux-server
sudo bash ./init.sh