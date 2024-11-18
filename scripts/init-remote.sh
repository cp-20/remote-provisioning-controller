#!/bin/bash

set -e

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
blue='\033[0;34m'
nc='\033[0m'

error="${red}[ERROR]${nc}"
info="${blue}[INFO]${nc}"

# セットアップ
sudo apt update && sudo apt upgrade -y
sudo apt install -y git unzip dstat tree make wget

# スペックを確認
cpu_info=$(lscpu | grep -e Architecture -e '^CPU(s)' | grep '^[^N]' | tr -s ' ' '`' | tr '\n' '#' | sed -e 's/#/`, /g')
memory_info=$(cat /proc/meminfo | grep MemTotal)
curl -X POST -H "Content-Type: application/json" -d "{\"content\": \"**${RPC_SERVER_ID}**\n- **CPU** ${cpu_info}\n- **Mem** ${memory_info}\"}" ${RPC_DISCORD_WEBHOOK_URL}

# GitHub CLIのインストール
(type -p wget >/dev/null || (sudo apt update && sudo apt-get install wget -y)) &&
  sudo mkdir -p -m 755 /etc/apt/keyrings &&
  wget -qO- https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg >/dev/null &&
  sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg &&
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null &&
  sudo apt update &&
  sudo apt install gh -y

# Goのインストール
wget -O /tmp/go.linux-amd64.tar.gz https://go.dev/dl/go1.23.3.linux-amd64.tar.gz
sudo tar -C /usr/local -xzf /tmp/go.linux-amd64.tar.gz
echo 'export PATH=$PATH:/usr/local/go/bin' >>/home/isucon/.bashrc

# SSH鍵の生成
ssh-keygen -t ed25519 -f /home/isucon/.ssh/id_ed25519 -N ""
ssh_pubkey=$(cat /home/isucon/.ssh/id_ed25519.pub)

# git config
git config --global user.name "isucon_${RPC_SERVER_ID}"
git config --global user.email "isucon@example.com"

# デプロイキーの追加
GH_TOKEN="${RPC_GITHUB_TOKEN}" gh repo deploy-key add /home/isucon/.ssh/id_ed25519.pub --repo "${GITHUB_REPO_OWNER}/${GITHUB_REPO_NAME}" --title "Deploy Key ${SERVER_ID}" --read-write

# Gitリポジトリの初期化
mkdir -p ${RPC_PROJECT_ROOT}
cd ${RPC_PROJECT_ROOT}
git init
git remote add origin "https://github.com/${RPC_GITHUB_REPO_OWNER}/${RPC_GITHUB_REPO_NAME}"

# 設定ファイルをコピー (masterのみ)
if [ $RPC_IS_MASTER = "true" ]; then
  mkdir -p ${RPC_NGINX_CONF_DIR_REPO}
  mkdir -p ${RPC_DB_CONF_DIR_REPO}
  mkdir -p ${RPC_SYSTEMD_CONF_DIR_REPO}
  sudo cp -r ${RPC_NGINX_CONF_DIR_ORIGINAL}/ ${RPC_NGINX_CONF_DIR_REPO}
  sudo cp -r ${RPC_DB_CONF_DIR_ORIGINAL}/ ${RPC_DB_CONF_DIR_REPO}
  sudo cp -r ${RPC_SYSTEMD_CONF_DIR_ORIGINAL}/ ${RPC_SYSTEMD_CONF_DIR_REPO}
  sudo chmod -R 777 ${RPC_NGINX_CONF_DIR_REPO}
  sudo chmod -R 777 ${RPC_DB_CONF_DIR_REPO}
  sudo chmod -R 777 ${RPC_SYSTEMD_CONF_DIR_REPO}
fi

# webappをコピー (masterのみ)
if [ $RPC_IS_MASTER = "true" ]; then
  mkdir -p ${RPC_APP_DIR_REPO}
  sudo cp -r ${RPC_APP_DIR_ORIGINAL}/ ${RPC_APP_DIR_REPO}
  sudo chmod -R 777 ${RPC_APP_DIR_REPO}
fi

# env.shをコピー
sudo mv ${RPC_ENV_FILE_ORIGINAL} ${RPC_ENV_FILE_REPO}
sudo ln -s ${RPC_ENV_FILE_REPO} ${RPC_ENV_FILE_ORIGINAL}

# MySQLの設定
sudo mysql -u root -e "UPDATE mysql.user SET Host = '%' WHERE User = '${RPC_DB_USER}' AND Host = 'localhost';"
sudo mysql -u root -e "CREATE USER IF NOT EXISTS '${RPC_DB_ADMIN_USER}'@'localhost' IDENTIFIED BY '${RPC_DB_ADMIN_PASSWORD}' WITH MAX_USER_CONNECTIONS 3; GRANT ALL PRIVILEGES ON *.* TO '${RPC_DB_ADMIN_USER}'@'localhost' WITH GRANT OPTION;"

# SSH公開鍵の登録
IFS=',' read -r -a users <<<"${RPC_SSH_USERS}"
for user in "${users[@]}"; do
  wget -qO- https://github.com/${user}.keys >>/home/isucon/.ssh/authorized_keys
done
sudo systemctl restart sshd

# ログファイルの作成
sudo touch ${RPC_NGINX_ACCESS_LOG_PATH}
sudo touch ${RPC_DB_SLOW_LOG_PATH}
sudo chmod -R 777 /var/log/nginx
sudo chmod -R 777 /var/log/mysql

# GitHubにpush (masterのみ)
if [ $RPC_IS_MASTER = "true" ]; then
  cd ${RPC_PROJECT_ROOT}
  git add .
  git commit -m 'deploy'
  git branch -M main
  git push -u origin ${RPC_DEPLOY_BRANCH}
fi

# node_exporterのインストール
cd /tmp
wget https://github.com/prometheus/node_exporter/releases/download/v1.8.2/node_exporter-1.8.2.linux-amd64.tar.gz
tar xvfz node_exporter-*.*-amd64.tar.gz
cd node_exporter-*.*-amd64
sudo mv node_exporter /usr/local/bin/
sudo useradd -s /sbin/nologin node_exporter
sudo chown node_exporter:node_exporter /usr/local/bin/node_exporter
sudo cat <<EOF >/etc/systemd/system/node_exporter.service
[Unit]
Description=Node Exporter

[Service]
User=node_exporter
ExecStart=/usr/local/bin/node_exporter

[Install]
WantedBy=multi-user.target
EOF
sudo systemctl daemon-reload
sudo systemctl enable node_exporter
sudo systemctl start node_exporter

# systemd_exporterのインストール
cd /tmp
wget https://github.com/prometheus-community/systemd_exporter/releases/download/v0.6.0/systemd_exporter-0.6.0.linux-amd64.tar.gz
tar xvfz systemd_exporter-*.*-amd64.tar.gz
cd systemd_exporter-*.*-amd64
sudo mv systemd_exporter /usr/local/bin/
sudo useradd -s /sbin/nologin systemd_exporter
sudo chown systemd_exporter:systemd_exporter /usr/local/bin/systemd_exporter
sudo cat <<EOF >/etc/systemd/system/systemd_exporter.service
[Unit]
Description=Systemd Exporter

[Service]
User=systemd_exporter
ExecStart=/usr/local/bin/systemd_exporter

[Install]
WantedBy=multi-user.target
EOF
sudo systemctl daemon-reload
sudo systemctl enable systemd_exporter
sudo systemctl start systemd_exporter

# Loki Promtailのインストール
cd /tmp
wget https://github.com/grafana/loki/releases/download/v3.2.1/promtail-linux-amd64.zip
unzip promtail-linux-amd64.zip
sudo mv promtail-linux-amd64 /usr/local/bin/promtail
sudo cat <<EOF >/etc/promtail-local-config.yaml
server:
  http_listen_port: 9080
  http_listen_address: 0.0.0.0

positions:
  filename: /var/lib/promtail/positions.yaml

clients:
  - url: ${RPC_LOKI_URL}
scrape_configs:
  - job_name: journal
    journal:
      max_age: 8h
      labels:
        job: systemd-journal
        host: ${RPC_SERVER_ID}
    relabel_configs:
      - source_labels: ['__journal__systemd_unit']
        target_label: 'unit'
      - source_labels: ['__journal__hostname']
        target_label: 'hostname'
EOF
sudo useradd -s /sbin/nologin promtail
sudo chown promtail:promtail /usr/local/bin/promtail /etc/promtail-local-config.yaml
sudo cat <<EOF >/etc/systemd/system/promtail.service
[Unit]
Description=Loki

[Service]
User=promtail
ExecStart=/usr/local/bin/promtail -config.file /etc/promtail-local-config.yaml

[Install]
WantedBy=multi-user.target
EOF

# Discordに通知
curl -X POST -H "Content-Type: application/json" -d "{\"content\": \"**${RPC_SERVER_ID}**のプロビジョニングが終わりました\"}" ${RPC_DISCORD_WEBHOOK_URL}
