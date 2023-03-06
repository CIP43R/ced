#!/bin/bash
sudo apt install git -y
sudo git clone https://github.com/CIP43R/setup-linux-server.git /opt/ced
sudo cp /opt/ced/config.template /opt/ced/config.conf 
echo export PATH="$PATH:~/shared/setup-linux-server" >> ~/.bashrc
source ~/.bashrc

printf "Installed successfully! You can now type in 'ced' into your terminal to try it!"