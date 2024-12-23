#!/bin/bash

set -e

# DB設定ファイルのコピー
sudo cp -r "${RPC_DB_CONF_DIR_REPO}"/* "${RPC_DB_CONF_DIR_ORIGINAL}"
sudo chmod -R 755 "${RPC_DB_CONF_DIR_ORIGINAL}"

# DBサービスの再起動
sudo systemctl restart mysql

# スローログのチェックと操作
if [ -f "${RPC_DB_SLOW_LOG_FILE}" ]; then
  sudo truncate -s 0 "${RPC_DB_SLOW_LOG_FILE}"
  sudo chmod 777 "${RPC_DB_SLOW_LOG_FILE}"
fi

sudo cp -r "${RPC_SQL_DIR_REPO}"/* "${RPC_SQL_DIR_ORIGINAL}"
# sudo cp -r "${RPC_SQL_DIR_REPO}"/5_user_presents_not_receive_data.tsv "/var/lib/mysql-files/5_user_presents_not_receive_data.tsv"
