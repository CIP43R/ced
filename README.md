# How to use
Run one of the following commands (curl or wget) to install the setup script
```
curl -o- https://raw.githubusercontent.com/CIP43R/setup-linux-server/master/install.sh | bash
```
```
wget -qO- https://raw.githubusercontent.com/CIP43R/setup-linux-server/master/install.sh | bash
```

# What is this?
This is just a small personal thing I created. I like experimenting with servers, so I often end up destroying mine in incredibly interesting ways.
Sometimes it's easier to reinstall it, and since my snapshots are getting deleted after a while, I wanted to have a quick way of bootstrapping everything I need.

It's basically a small script that lets you pick some very basic but useful tools and configs for a nice and safe admin UX.

# What can it do?
The focus lies on the security aspect.

- It will prompt whether you want to create a central sudo user that replaces root. If you skip this step, everything the script does related to the users (i.e. authentication) will be applied to the user that is running the script.
- It will install ufw, a very handy and simple firewall tool, and configure it for only ssh 
- Then it will ask you for an RSA key, since in the next step, it will change the ssh config so that only pubkey authentication is allowed
- Optionally, you can then enable MFA (2FA+). It will install google authenticator and prompt you to create a key.
- As a safety measure, it will only allow the one user to use ssh, if desired this can be changed later. Same goes for crontab usage.
- It will then install fail2ban and preconfigure it to permanently ban attackers. Standard jails for nginx and ssh will be enabled
- Optionally, you can install SELinux. Please read how it works, before installing it
- After that, you can pick to install one or more third party applications: nginx, docker and webmin

# TODO / Plans
- Make the script more generic, allowing to add and remove certain features
- Refactor the script and make it more efficient and readable
- Make the script usable for multi-user purposes
- More options for the security measures (such as fail2ban)
- Cronjob to regularly update everything
- Certbot