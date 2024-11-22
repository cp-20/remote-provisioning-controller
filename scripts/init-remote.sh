#!/bin/bash

set -e

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
blue='\033[0;34m'
nc='\033[0m'

error="${red}[ERROR]${nc}"
info="${blue}[INFO]${nc}"
success="${green}[SUCCESS]${nc}"

# セットアップ
sudo apt-get update && sudo apt-get upgrade -y
sudo apt-get install -y git unzip dstat tree make wget
echo -e "$success セットアップ"

# スペックを確認
cpu_info=$(lscpu | grep -e Architecture -e '^CPU(s)' | grep '^[^N]' | tr -s ' ' '`' | tr '\n' '#' | sed -e 's/#/`, /g')
memory_info=$(cat /proc/meminfo | grep MemTotal)
curl -s -X POST -H "Content-Type: application/json" -d "{\"content\": \"**${RPC_SERVER_ID}**\n- **CPU** ${cpu_info}\n- **Mem** ${memory_info}\"}" ${RPC_DISCORD_WEBHOOK_URL}
echo -e "$success スペックを確認"

# SSH公開鍵の登録
IFS=',' read -r -a users <<<"${RPC_SSH_USERS}"
for user in "${users[@]}"; do
  mkdir -p /home/isucon/.ssh
  wget -qO- https://github.com/${user}.keys >>/home/isucon/.ssh/authorized_keys
done
sudo systemctl restart sshd
echo -e "$success SSH公開鍵の登録"

# GitHub CLIのインストール
if ! command -v gh &>/dev/null; then
  sudo mkdir -p -m 755 /etc/apt/keyrings &&
    wget -qO- https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg >/dev/null &&
    sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg &&
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null &&
    sudo apt update &&
    sudo apt install gh -y
  echo -e "$success GitHub CLIのインストール"
else
  echo -e "$info skipped GitHub CLIのインストール"
fi

export PATH=/home/isucon/local/go/bin:/home/isucon/go/bin:$PATH
if ! command -v go &>/dev/null || [ "$(go version | awk '{print $3}')" != "go1.23.3" ]; then
  if [ -d "/home/isucon/local/go" ]; then
    sudo rm -rf "/home/isucon/local/go"
  fi
  wget -qO /tmp/go.linux-amd64.tar.gz https://go.dev/dl/go1.23.3.linux-amd64.tar.gz
  sudo tar -C /home/isucon/local -xzf /tmp/go.linux-amd64.tar.gz
else
  echo -e "$info skipped Goのインストール"
fi
echo -e "$success Goのインストール"

# SSH鍵の生成
if [ ! -f /home/isucon/.ssh/id_ed25519 ]; then
  ssh-keygen -t ed25519 -f /home/isucon/.ssh/id_ed25519 -N ""
  echo -e "$success SSH鍵の生成"
else
  echo -e "$info skipped SSH鍵の生成"
fi
ssh_pubkey=$(cat /home/isucon/.ssh/id_ed25519.pub)

# git config
git config --global user.name "isucon_${RPC_SERVER_ID}"
git config --global user.email "isucon@example.com"
echo -e "$success git config"

# デプロイキーの追加
repo="${RPC_GITHUB_REPO_OWNER}/${RPC_GITHUB_REPO_NAME}"
registered_keys=$(GH_TOKEN="${RPC_GITHUB_TOKEN}" gh repo deploy-key list --repo "${repo}" --json "key" --jq ".[].key")
pubkey_main="$(echo $ssh_pubkey | awk '{print $1 " " $2}')"
if ! echo "${registered_keys}" | grep "${pubkey_main}"; then
  GH_TOKEN="${RPC_GITHUB_TOKEN}" gh repo deploy-key add /home/isucon/.ssh/id_ed25519.pub --repo "${repo}" --title "Deploy Key ${RPC_SERVER_ID}" --allow-write
  echo -e "$success デプロイキーの追加"
else
  echo -e "$info skipped デプロイキーの追加"
fi

# Gitリポジトリの初期化
if [ -d "${RPC_PROJECT_ROOT}" ]; then
  sudo rm -rf "${RPC_PROJECT_ROOT}"
fi
mkdir -p ${RPC_PROJECT_ROOT}
cd ${RPC_PROJECT_ROOT}
git init
git remote add origin "git@github.com:${RPC_GITHUB_REPO_OWNER}/${RPC_GITHUB_REPO_NAME}.git"
echo -e "$success Gitリポジトリの初期化"

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
  echo -e "$success 設定ファイルをコピー"
fi

# webappをコピー (masterのみ)
if [ $RPC_IS_MASTER = "true" ]; then
  mkdir -p ${RPC_APP_DIR_REPO}
  sudo cp -r ${RPC_APP_DIR_ORIGINAL}/ ${RPC_APP_DIR_REPO}
  sudo chmod -R 777 ${RPC_APP_DIR_REPO}
  echo -e "$success webappをコピー"
fi

# env.shをコピー
echo "env = ${RPC_ENV_FILE_REPO}"
if [ ! -f "${RPC_ENV_FILE_REPO}" ]; then
  mkdir -p $(dirname ${RPC_ENV_FILE_REPO})
  sudo mv ${RPC_ENV_FILE_ORIGINAL} ${RPC_ENV_FILE_REPO}
  sudo ln -s ${RPC_ENV_FILE_REPO} ${RPC_ENV_FILE_ORIGINAL}
  sudo chmod 777 ${RPC_ENV_FILE_REPO}
  echo -e "$success env.shをコピー"
else
  echo -e "$info skipped env.shをコピー"
fi

# MySQLの設定
sudo mysql -u root -e "UPDATE mysql.user SET Host = '%' WHERE User = '${RPC_DB_USER}' AND Host = 'localhost';"
sudo mysql -u root -e "CREATE USER IF NOT EXISTS '${RPC_DB_ADMIN_USER}'@'localhost' IDENTIFIED BY '${RPC_DB_ADMIN_PASSWORD}' WITH MAX_USER_CONNECTIONS 3; GRANT ALL PRIVILEGES ON *.* TO '${RPC_DB_ADMIN_USER}'@'localhost' WITH GRANT OPTION;"
echo -e "$success MySQLの設定"

# ログファイルの作成
sudo touch ${RPC_NGINX_ACCESS_LOG_PATH}
sudo touch ${RPC_DB_SLOW_LOG_PATH}
sudo chmod -R 777 /var/log/nginx
sudo chmod -R 777 /var/log/mysql
echo -e "$success ログファイルの作成"

# GitHubにpush (masterのみ)
if [ $RPC_IS_MASTER = "true" ]; then
  cd ${RPC_PROJECT_ROOT}
  git add .
  git commit -m 'deploy'
  git branch -M main
  ssh-keyscan -H github.com >>~/.ssh/known_hosts
  git push -u origin ${RPC_DEPLOY_BRANCH}
  echo -e "$success GitHubにpush"
fi

# node_exporterのインストール
if ! command -v node_exporter &>/dev/null; then
  cd /tmp
  wget -q https://github.com/prometheus/node_exporter/releases/download/v1.8.2/node_exporter-1.8.2.linux-amd64.tar.gz
  tar xvfz node_exporter-*.*-amd64.tar.gz
  cd node_exporter-*.*-amd64
  sudo mv node_exporter /usr/local/bin/
  echo -e "$success node_exporterのインストール"
else
  echo -e "$info skipped node_exporterのインストール"
fi
if ! systemctl is-active --quiet node_exporter; then
  sudo useradd -s /sbin/nologin node_exporter
  sudo chown node_exporter:node_exporter /usr/local/bin/node_exporter
  sudo tee /etc/systemd/system/node_exporter.service >/dev/null <<EOF
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
  echo -e "$success node_exporterのサービス登録"
else
  echo -e "$info skipped node_exporterのサービス登録"
fi

# systemd_exporterのインストール
if ! command -v systemd_exporter &>/dev/null; then
  cd /tmp
  wget -q https://github.com/prometheus-community/systemd_exporter/releases/download/v0.6.0/systemd_exporter-0.6.0.linux-amd64.tar.gz
  tar xvfz systemd_exporter-*.*-amd64.tar.gz
  cd systemd_exporter-*.*-amd64
  sudo mv systemd_exporter /usr/local/bin/
  echo -e "$success systemd_exporterのインストール"
else
  echo -e "$info skipped systemd_exporterのインストール"
fi
if ! systemctl is-active --quiet systemd_exporter; then
  sudo useradd -s /sbin/nologin systemd_exporter
  sudo chown systemd_exporter:systemd_exporter /usr/local/bin/systemd_exporter
  sudo tee /etc/systemd/system/systemd_exporter.service >/dev/null <<EOF
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
  echo -e "$success systemd_exporterのサービス登録"
else
  echo -e "$info skipped systemd_exporterのサービス登録"
fi

# Loki Promtailのインストール
if ! command -v promtail &>/dev/null; then
  cd /tmp
  wget -q https://github.com/grafana/loki/releases/download/v3.2.1/promtail-linux-amd64.zip
  unzip promtail-linux-amd64.zip
  sudo mv promtail-linux-amd64 /usr/local/bin/promtail
  echo -e "$success Loki Promtailのインストール"
else
  echo -e "$info skipped Loki Promtailのインストール"
fi
if ! systemctl is-active --quiet promtail; then
  sudo tee /etc/promtail-local-config.yaml >/dev/null <<EOF
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
  sudo tee /etc/systemd/system/promtail.service >/dev/null <<EOF
[Unit]
Description=Loki

[Service]
User=promtail
ExecStart=/usr/local/bin/promtail -config.file /etc/promtail-local-config.yaml

[Install]
WantedBy=multi-user.target
EOF
  sudo systemctl daemon-reload
  sudo systemctl enable promtail
  sudo systemctl start promtail
  echo -e "$success Loki Promtailのサービス登録"
else
  echo -e "$info skipped Loki Promtailのサービス登録"
fi

# pprotein-agent のインストール
if ! command -v pprotein-agent &>/dev/null; then
  wget -qO /tmp/pprotein_1.2.3_linux_amd64.tar.gz https://github.com/kaz/pprotein/releases/download/v1.2.3/pprotein_1.2.3_linux_amd64.tar.gz
  tar xvfz /tmp/pprotein_1.2.3_linux_amd64.tar.gz -C /tmp
  sudo mv /tmp/pprotein-agent /usr/local/bin/
  echo -e "$success pprotein-agent のインストール"
else
  echo -e "$info skipped pprotein-agent のインストール"
fi
if ! systemctl is-active --quiet pprotein-agent; then
  sudo tee /etc/default/pprotein-agent.env >/dev/null <<EOF
PPROTEIN_HTTPLOG=${RPC_NGINX_ACCESS_LOG_PATH}
PPROTEIN_SLOWLOG=${RPC_DB_SLOW_LOG_PATH}
PPROTEIN_GIT_REPOSITORY=${RPC_PROJECT_ROOT}
PORT=10008
EOF
  sudo useradd -s /sbin/nologin pprotein-agent
  sudo chown pprotein-agent:pprotein-agent /usr/local/bin/pprotein-agent /etc/default/pprotein-agent.env
  sudo tee /etc/systemd/system/pprotein-agent.service >/dev/null <<EOF
[Unit]
Description=pprotein-agent
After=network.target

[Service]
User=pprotein-agent
ExecStart=/usr/local/bin/pprotein-agent
EnvironmentFile=/etc/default/pprotein-agent.env
Restart=always

[Install]
WantedBy=multi-user.target
EOF
  sudo systemctl daemon-reload
  sudo systemctl enable pprotein-agent
  sudo systemctl start pprotein-agent
  echo -e "$success pprotein-agent のサービス登録"
else
  echo -e "$info skipped pprotein-agent のサービス登録"
fi

# Discordに通知
curl -s -X POST -H "Content-Type: application/json" -d "{\"content\": \"**${RPC_SERVER_ID}**のプロビジョニングが終わりました\"}" ${RPC_DISCORD_WEBHOOK_URL}
echo -e "$success Discordに通知"

echo -e "$success プロビジョニングが正常に完了しました"
