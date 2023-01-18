#!/bin/bash
cwd=$(pwd)
logloc=$cwd/logs/install.log # Custom logs produced in this file
aptlogloc=$cwd/logs/apt.log  # Logs produced by apt 
cmdlogloc=$cwd/logs/cmd.log  # Logs produced by applications run in here

printf "[INFO] Starting installation process\\n" | tee -a $logloc
sudo apt install git -y &> $aptlogloc
cd /opt
git clone https://github.com/CIP43R/setup-linux-server.git &> $cmdlogloc
cd setup-linux-server
sudo bash ./init.sh