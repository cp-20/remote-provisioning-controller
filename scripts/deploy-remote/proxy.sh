#!/bin/bash

set -e

# Nginx設定ファイルのコピー
sudo cp -r "${RPC_NGINX_CONF_DIR_REPO}"/* "${RPC_NGINX_CONF_DIR_ORIGINAL}"
sudo chmod -R 755 "${RPC_NGINX_CONF_DIR_ORIGINAL}"

# プロキシサービスの再起動
sudo systemctl restart nginx

# アクセスログの操作
if [ -f "${RPC_NGINX_ACCESS_LOG_FILE}" ]; then
  sudo truncate -s 0 "${RPC_NGINX_ACCESS_LOG_FILE}"
  sudo chmod 777 "${RPC_NGINX_ACCESS_LOG_FILE}"
fi
