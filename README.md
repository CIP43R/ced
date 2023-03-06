# How to use
Run one of the following commands (curl or wget) to install the setup script
```
curl https://raw.githubusercontent.com/CIP43R/setup-linux-server/master/install.sh -o install.sh && bash install.sh
```
```
wget -qO- https://raw.githubusercontent.com/CIP43R/setup-linux-server/master/install.sh && bash install.sh
```

# What is this?
This is just a small personal thing I created. I like experimenting with servers, so I often end up destroying mine in incredibly interesting ways.
Sometimes it's easier to reinstall it, and since my snapshots are getting deleted after a while, I wanted to have a quick way of bootstrapping everything I need.

It's basically a small script that lets you pick some very basic but useful tools and configs for a nice and safe admin UX.

This repo is mostly just for my personal educational purposes! I'm experimenting with linux and am not an expert with either bash scripting or security measures. Please keep that in mind in case you want to use this for anything.

# What can it do?
It can make your life easier if you i.e. just want to create a small server for testing, development, gaming whatever.
The focus lies on the security aspect and easy configuration. I provided the (in my opinion) most useful and important things to have on a server, as well as the most crucial basic configurations for these.

The script interactively guides you through several steps:
- It will prompt whether you want to create a central sudo user that replaces root. If you skip this step, everything the script does related to the users (i.e. authentication) will be applied to the user that is running the script.
- It will install ufw, a very handy and simple firewall tool, and configure it for ssh 
- Then it will ask you for an RSA key, since in the next step, it will change the ssh config so that only pubkey authentication is allowed
- Optionally, you can then enable MFA (2FA+). It will install google authenticator and prompt you to create a key.
- As a safety measure, it will only allow the one user (either the created or the current) to use ssh, if desired this can be changed later. Same goes for crontab usage.
- It will then install fail2ban and preconfigure it to permanently ban attackers. Standard jails for nginx and ssh will be enabled, others will be enabled automatically if the apps are desired to be installed (i.e. vsftpd)
- Optionally, you can install SELinux. Please read how it works, before installing it
- After that, you can pick to install one or more third party applications: nginx, docker, webmin, etc. (full list below)

As of now, it is meant to be executed **once**. There could be unexpected behavior when running it multiple times.

# Expand / Edit
You can just clone this repo to your server and adjust all the configs you'd like to.
The original configs will be saved in /backup 

# Full list of mandatory and optional packages
| Package | Purpose |
| ------- | ------- |
| fail2ban | Detect and ban intruders |

This is a list of currently supported and maintained (=auto updating package and configs) third party apps that can be installed

| Package | Purpose |
| ------- | ------- |
| vsftpd | Secure FTP server |
| nginx | Webserver, easy configurable |
| webmin | Rather ugly, but useful server management / admin GUI, good for beginners |
| certbot | Handy tool to get and maintain SSL certificates from Let's Encrypt |
| docker | If you don't know what this is, you probably don't need it. |
| portainer | Docker management UI |


# TODO / Plans
- Make the script usable for multi-user purposes
- More options for the security measures (such as fail2ban)
- Cronjob to regularly update everything
- Security checks (suspicious networt traffic, rootkits etc.)
- Time or condition limited service (vsftpd, custom servers)
- Allow apache and certbot with apache, too
- Add more comments

# Things to keep in mind regarding security
- Fail2ban basically detects intruders by checking the logs of certain applications. Each application will have a jail, which basically is a configuration to help fail2ban detect odd behavior. Whenever system authentication is being used (i.e. webmin), you technically don't have to add an extra jail, unless you want to filter it separately and have more distinct logs for your bans. Webmin however uses the same logs as SSH.
- VSFTPD is (here) configured to allow all local linux users to use ftp, but restricts them to only get access to their home dir. You should probably keep it this way. If you want to be extra safe you can specify a custom folder in the home folders to only give users access to a minimal portion.

# Useful locations to keep in sight

Important logs are in `/var/log`

# Useful commands to keep in mind

### List all IPs banned by fail2ban:
`sudo zgrep 'Ban' /var/log/fail2ban.log*`

### List all system groups pretty:
`cut -d: -f1 /etc/group`

### Get error logs if a service didn't start

`sudo journalctl | grep -i <SERVICE NAME>`
