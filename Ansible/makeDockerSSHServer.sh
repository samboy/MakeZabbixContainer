#!/bin/sh

######################## MAKE DOCKER EXAMPLE SERVER ########################
# Just in case
docker stop $(docker ps -q) ; docker rm $(docker ps -a -q)

# Observe: This is a *BASE* CentOS 7 system.  Factory default.
DOCKERID=$( docker run -p 8080:80 -p 2222:22 -dit centos:7 bash )

# First things first: Security updates (usually Docker is up to date
# with these, but if we run a local repo, we may not be)
docker exec -it $DOCKERID \
yum -y update
docker exec -it $DOCKERID \
yum -y install net-tools
docker exec -it $DOCKERID \
yum -y install less

# Add sshd so Ansible can log in
docker exec -it $DOCKERID \
yum -y install openssh-server

# Make sure we have SSH RSA key for server
#ssh-keygen -f /etc/ssh/ssh_host_rsa_key -N '' -t rsa -b 2048
# Use use a fixed key so known_hosts does not need to be updated every time
# we make a new container
cat > ssh_host_rsa_key << EOF
-----BEGIN RSA PRIVATE KEY-----
MIIEogIBAAKCAQEA1NvJvPOV/kgqLNzYXUwRHZzY7qmKb+b6ceOVNgxZTh8/hQsd
M5wCNjAPMsyMveSLC5UQxZD/jCzIRDBFCc7XKe3VLgAHeR/LNTxvod1d2QKltutT
oCRSfMGvinQfM01Sp0BRgRZG+9dzSUAZhE4Pe5hurckiPI4xmj4pBvztFjm4pBH5
YkryDyiCN+gVRciAk+5xTipvjmZwSkm6SYkIsZONQuCQ4WqenvNVMB7yW+HSJ2EF
EDUGtYvez7lEgp4gDOx3rmhIntesUXFFtPOYZfoqCROXt4LAWMTNncpyW7092/E/
BP8SIc4xoP4dfzQhuqVgtK070TWZC9nGwbqlNwIDAQABAoIBAFPt6cjQPxdJex+/
YKzA3orPmpXYUda3u46GjwIFsnzkQ1aBQF1mKVUWdBeyodgKMm05tKhB+RFbYwfI
BKDOZvaIaaM+rbOrvqNaFiY7s9Jqgc7zUUD2sXOxpzavfNHsrid2a+y7TPfmRvXe
CXGqmd5BB3sMsKwx4QsRcXno5s748VDhPAgTYYEKyntGUZy5E69a0ZBkyh5rLynt
kXG6kK/i44V7ixp8lwsFZYLkDfi7r18zHCBSFUzrw4l5MRxmXle6K/JFjg9x/2MU
yvjtoNYtBJIVe9CWjF+GZDylyHlePM6c2v4cIJFRJxHbDxfsRaaakY63uXp9NVbF
X33kTZkCgYEA8MfjuN9EoHKReYva9c+J5Oe9EK9IBp3iG7W+iOL85mjVfbTeSH+L
qD0bxP67xUturj0fdokN85QMLvnTyLaKSjGY4IcBfHxvNybG+U7Vu2YwzhkR6+Aq
qGQNqxVtZTnkWAAhyslLBDjzGDkGAtPo+BDP93pYDyeO0oAqWWirvbMCgYEA4lAV
hAh235dB2b5DBs25YNUNnWqLKoZnISSzBjbTmNVnCTNpQem0i+N8tpQkXmHRNCdB
ypGDVHxNpLU6CCPbOI5+o3GbovtYXuzdfvSrLOEOq08uFYudCPJM6s6P+wp/+7HP
JBQBf51eibqH126pJvXJUr8jv3BVjUt4/zZJoG0CgYAI0yqzgetf/hL643dY/wxM
yXmSfPok0/CPl2+uULN4Nmtsug5Tlekmd2bnJ3b2WjdqR285xvgt70UrC5kJiDc1
VPAHeqtBRsZEvTUZuhv3TF2JkD2p6YNmvJQLqzNhPGf0Gb0jU5FeTEAMqTphLCcj
wGn+5gsIMyj26h+jO0TgJQKBgEHSUv+syo4rWv6uhKYU7YbJUIVpOIKsxo/wMZVs
GszHvIkDh+igxV8uUdZ0bcN5pbQKeuskuVK4OIjgILm/XAIuB40X/NFBUymAsMc8
+BA8gNy4Ucn4ajrw5ggg/eVg32pgA8QVgX4RUi6yrtGsoMvxDpXfe9ExJeDLg6yO
qIldAoGAVbvirKD4ZEePv9DhNpRKe9mwW9b+HAUxHZmnj7Jo3SCi+jQz0W2NOU4I
xplUUNqnpIEKUsiLvYUXQFT6TeMVzoZaECxG5E9gIW/SYd/+vFRwq70DILQcewdy
dOct+RhwcCvL8EvvUXDrQxrrmxi/JzX2mxf+arxsDxHyByyHhGs=
-----END RSA PRIVATE KEY-----
EOF
docker cp ssh_host_rsa_key $DOCKERID:/etc/ssh/
# Start SSH server; note that putting -it here will make server die
docker exec $DOCKERID /usr/sbin/sshd

# Give user sudo permission
docker exec $DOCKERID yum -y install sudo
cat > add_sudoer.sh << EOF
#!/bin/sh
echo user ALL=\(ALL\) ALL >> /etc/sudoers
EOF
docker cp add_sudoer.sh $DOCKERID:/
docker exec $DOCKERID sh /add_sudoer.sh

# Add user with name "user" in container
docker exec -it $DOCKERID \
useradd user
docker exec -it $DOCKERID \
mkdir /home/user/.ssh
cat > set_pw.sh <<EOF
#!/bin/sh
echo user:password | chpasswd
EOF
docker cp set_pw.sh $DOCKERID:/
docker exec -it $DOCKERID sh /set_pw.sh

# SSH in is dog slow because of DNS weirdness
cat > zap.resolv.conf << EOF
echo nameserver 127.0.0.1 > /etc/resolv.conf
EOF
docker cp zap.resolv.conf $DOCKERID:/
docker exec -it $DOCKERID sh /zap.resolv.conf

# Add SSH key to docker
docker cp $HOME/.ssh/id_rsa.pub $DOCKERID:/home/user/.ssh/authorized_keys
docker exec -it $DOCKERID \
chmod 600 /home/user/.ssh/authorized_keys
docker exec -it $DOCKERID \
chmod 700 /home/user/.ssh/
docker exec -it $DOCKERID \
chown -R user:user /home/user

#yum -y install epel-release
#yum -y install nginx

