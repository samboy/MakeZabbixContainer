# MakeZabbixContainer

For an assignment I did for a possible position, I have made a shell script
that makes a Docker container running Zazzle (no, I am not making a 
Dockerfile because this script, in theory, can more easily be ported
to other virtualization platforms).

I also have, in the Ansible folder, a shell script which makes a Docker
container we can SSH in to (Please do *not* use the SSH host key in 
that script for anything but examples!); it then sets up and runs
Ansible to install and set up NGinx in that Docker virtual server.
