#!/bin/bash
sudo apt install git -y
sudo git clone https://github.com/CIP43R/ced.git /opt/ced
echo export PATH="$PATH:/opt/ced" >> ~/.bashrc
sudo chmod -R 777 /opt/ced
sudo chmod +x /opt/ced/ced
sudo rm /opt/ced/install.sh
source ~/.bashrc

printf "Installed successfully! You can now type in 'ced' into your terminal to try it!"