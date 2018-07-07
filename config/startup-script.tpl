
cat << EOF > /tmp/docker.conf
[Service]
ExecStart=
ExecStart=/usr/bin/dockerd -H fd:// \
  -H tcp://${docker_api_ip}:2375 \
  --storage-driver=overlay2 \
  --dns 8.8.4.4 --dns 8.8.8.8 \
  --log-driver json-file \
  --log-opt max-size=50m --log-opt max-file=10 \
  --experimental=true \
  --metrics-addr ${docker_api_ip}:9323
EOF

cat << EOF > /tmp/install-docker-ce.sh
#!/usr/bin/env bash

# setup Docker repository

echo ">>> installing Docker ${docker_version}"

apt-get -qq update
apt-get -qq install \
    apt-transport-https \
    ca-certificates \
    curl \
    software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
add-apt-repository \
   "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
   $(lsb_release -cs) \
   stable"

# install Docker CE
apt-get -q update -y
apt-get -q install -y docker-ce=${docker_version}
EOF

sudo sysctl -w vm.max_map_count=262144
sudo echo 'vm.max_map_count=262144' >> /etc/sysctl.conf
sudo mkdir -p /etc/systemd/system/docker.service.d
sudo mv /tmp/docker.conf /etc/systemd/system/docker.service.d/docker.conf
sudo chmod +x /tmp/install-docker-ce.sh
sudo /tmp/install-docker-ce.sh
curl -sSO https://dl.google.com/cloudagents/install-logging-agent.sh
sudo bash install-logging-agent.sh
sudo docker swarm join --token ${worker_token} ${manager_name}:2377
