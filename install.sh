#!/bin/bash
sudo apt install git -y
sudo git clone https://github.com/CIP43R/ced.git /opt/ced
echo export PATH="$PATH:/opt/ced" >> ~/.bashrc
source ~/.bashrc
sudo chmod +x /opt/ced/ced
rm /opt/ced/install.sh

printf "Installed successfully! You can now type in 'ced' into your terminal to try it!"