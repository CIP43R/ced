apt install git -y
mkdir -p /opt/setup-linux-server 2>&1
cd /opt/setup-linux-server
git clone https://github.com/CIP43R/setup-linux-server.git
/opt/setup-linux-server/init.sh