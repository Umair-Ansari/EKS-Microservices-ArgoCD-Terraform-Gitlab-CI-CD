#!/bin/bash

# Add Docker's official GPG key:
sudo apt-get update
sudo apt-get install ca-certificates curl gnupg
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

# Add the repository to Apt sources:
echo \
  "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update && apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y

# By default, Docker requires root privileges to run commands. However, you can add your user to the Docker group to grant them permission to run Docker commands without using
sudo usermod -aG docker ubuntu
sudo newgrp docker
sudo systemctl enable docker
sudo systemctl start docker

# Change SSH port to 26
# Modify /etc/ssh/sshd_config
sudo sed -i 's/#Port 22/Port 26/' /etc/ssh/sshd_config

# Restart SSH service
sudo service ssh restart


# Pull the latest GitLab CE Docker image
sudo docker pull gitlab/gitlab-ce:latest

# Create directories for GitLab data
sudo mkdir -p /srv/gitlab/config /srv/gitlab/logs /srv/gitlab/data

# Run the GitLab CE Docker container
sudo docker run --detach \
  --hostname gitlab-ci.sac-stg.org \
  --publish 443:443 --publish 80:80 --publish 22:22 \
  --restart always \
  --volume /srv/gitlab/config:/etc/gitlab \
  --volume /srv/gitlab/logs:/var/log/gitlab \
  --volume /srv/gitlab/data:/var/opt/gitlab \
  gitlab/gitlab-ce:latest

## after above command you need to go inside docker and set password for root suer
# sudo docker exec -it e82a266410d0 /bin/bash
# gitlab-rake "gitlab:password:reset"
# root
# your password
# your password again