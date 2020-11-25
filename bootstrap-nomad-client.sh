#!/bin/bash
echo "Setting up DNS"
sudo bash -c 'echo "DNS1=127.0.0.1" >> /etc/sysconfig/network-scripts/ifcfg-eth0'
sudo bash -c 'echo "DNS2=172.25.0.2" >> /etc/sysconfig/network-scripts/ifcfg-eth0'
sudo service network restart
yes | sudo amazon-linux-extras install docker
sudo amazon-linux-extras enable docker
sudo service docker start
sudo usermod -a -G docker ec2-user
echo "Installing Nomad..."
NOMAD_VERSION=0.12.5
cd /tmp/
curl -sSL https://releases.hashicorp.com/nomad/${NOMAD_VERSION}/nomad_${NOMAD_VERSION}_linux_amd64.zip -o nomad.zip
unzip nomad.zip
sudo install nomad /usr/bin/nomad
sudo mkdir -p /etc/nomad/config
sudo chmod -R a+w /etc/nomad
echo "Installing Consul..."
CONSUL_VERSION=1.8.4
curl -sSL https://releases.hashicorp.com/consul/${CONSUL_VERSION}/consul_${CONSUL_VERSION}_linux_amd64.zip > /tmp/consul.zip
unzip /tmp/consul.zip
sudo install consul /usr/bin/consul
sudo mkdir -p /etc/consul
sudo chmod a+w /etc/consul
sudo mkdir -p /etc/consul/data
sudo chmod a+w /etc/consul/data
sudo mkdir -p /etc/consul/config
sudo chmod a+w /etc/consul/config
HOSTNAME=`hostname`
LOCAL_IP=`curl http://169.254.169.254/latest/meta-data/local-ipv4`
cat > /etc/nomad/config/client.hcl <<EOF
bind_addr = "0.0.0.0"
log_level = "DEBUG"
data_dir = "/etc/nomad"
name = "$HOSTNAME"
client {
  enabled = true
  server_join {
	retry_join = ["provider=aws tag_key=tipeserver tag_value=nomad"]
  }
}
addresses {
  rpc  = "$LOCAL_IP"
  serf = "$LOCAL_IP"
}
advertise {
  http = "$LOCAL_IP:4646"
}

EOF
sudo bash -c 'cat > /etc/systemd/system/nomad.service <<EOF
[Unit]
Description=Nomad
Requires=network-online.target
After=network-online.target

[Service]
Restart=on-failure
ExecStart=/usr/bin/nomad agent -config=/etc/nomad/config
ExecReload=/bin/kill -HUP $MAINPID
KillSignal=SIGTERM

[Install]
WantedBy=multi-user.target
EOF'
sudo yum -y install amazon-ecr-credential-helper
mkdir -p /home/ec2-user/.docker
cat > /home/ec2-user/.docker/config.json <<EOF
{
	"credsStore": "ecr-login"
}
EOF
sudo chown -R ec2-user:ec2-user /home/ec2-user/.docker
sudo systemctl enable nomad
sudo systemctl start nomad
echo "Installing Dnsmasq..."
sudo yum -y install dnsmasq dnsmasq-utils
echo "Configuring Dnsmasq..."
sudo bash -c 'echo "server=/consul/127.0.0.1#8600" >> /etc/dnsmasq.d/consul'
sudo bash -c 'echo "listen-address=127.0.0.1" >> /etc/dnsmasq.d/consul'
sudo bash -c 'echo "bind-interfaces" >> /etc/dnsmasq.d/consul'
echo "Restarting dnsmasq..."
sudo systemctl enable dnsmasq
sudo service dnsmasq restart
cat > /etc/consul/config/client.json <<EOF
{
  "server": false,
  "ui": true,
  "data_dir": "/etc/consul/data",
  "client_addr": "0.0.0.0",
  "advertise_addr": "$LOCAL_IP",
  "retry_join": ["provider=aws tag_key=tipeserver tag_value=nomad"]
}
EOF
sudo bash -c 'cat > /etc/systemd/system/consul.service <<EOF
[Unit]
Description=Consul
Requires=network-online.target
After=network-online.target

[Service]
Restart=on-failure
ExecStart=/usr/bin/consul agent -config-dir=/etc/consul/config
ExecReload=/bin/kill -HUP $MAINPID
KillSignal=SIGTERM
RestartSec=30
StartLimitBurst=5

[Install]
WantedBy=multi-user.target
EOF'
sudo systemctl enable consul
sudo systemctl start consul
curl -L -o cni-plugins.tgz https://github.com/containernetworking/plugins/releases/download/v0.8.7/cni-plugins-linux-amd64-v0.8.7.tgz
sudo mkdir -p /opt/cni/bin
sudo tar -C /opt/cni/bin -xzf cni-plugins.tgz
