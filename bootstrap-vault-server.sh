#!/bin/bash
echo "Setting up DNS"
sudo bash -c 'echo "DNS1=127.0.0.1" >> /etc/sysconfig/network-scripts/ifcfg-eth0'
sudo bash -c 'echo "DNS2=172.25.0.2" >> /etc/sysconfig/network-scripts/ifcfg-eth0'
sudo service network restart
echo "Installing Vault..."
VAULT_VERSION=1.5.5
curl -sSL https://releases.hashicorp.com/vault/${VAULT_VERSION}/vault_${VAULT_VERSION}_linux_amd64.zip> vault.zip
unzip vault.zip
sudo install vault /usr/bin/vault
sudo mkdir -p /etc/vault
sudo chmod a+w /etc/vault
HOSTNAME=`hostname`
LOCAL_IP=`curl http://169.254.169.254/latest/meta-data/local-ipv4`
cat > /etc/vault/config.hcl <<EOF
disable_mlock = true
ui            = true

listener "tcp" {
  address          = "0.0.0.0:8200"
  cluster_address  = "$LOCAL_IP:8201"
  tls_disable      = "true"
}
storage "consul" {
  address = "127.0.0.1:8500"
  path    = "vault/"
}
api_addr = "http://$LOCAL_IP:8200"
cluster_addr = "https://$LOCAL_IP:8201"
EOF
sudo bash -c 'cat > /etc/systemd/system/vault.service <<EOF
[Unit]
Description=Vault
Requires=network-online.target
After=network-online.target
[Service]
Restart=on-failure
ExecStart=/usr/bin/vault server -config /etc/vault
ExecReload=/bin/kill -HUP $MAINPID
KillSignal=SIGTERM
RestartSec=30
StartLimitBurst=5
[Install]
WantedBy=multi-user.target
EOF'
sudo systemctl enable vault
sudo systemctl start vault
echo "Installing Consul..."
CONSUL_VERSION=1.8.4
curl -sSL https://releases.hashicorp.com/consul/${CONSUL_VERSION}/consul_${CONSUL_VERSION}_linux_amd64.zip > consul.zip
unzip consul.zip
sudo install consul /usr/bin/consul
sudo mkdir -p /etc/consul
sudo chmod a+w /etc/consul
sudo mkdir -p /etc/consul/data
sudo chmod a+w /etc/consul/data
sudo mkdir -p /etc/consul/config
sudo chmod a+w /etc/consul/config
HOSTNAME=`hostname`
LOCAL_IP=`curl http://169.254.169.254/latest/meta-data/local-ipv4`
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
