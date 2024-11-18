#!/bin/bash

set -e

# DB設定ファイルのコピー
cp -r "${RPC_DB_CONF_DIR_REPO}"/* "${RPC_DB_CONF_DIR_ORIGINAL}"
chmod -R 755 "${RPC_DB_CONF_DIR_ORIGINAL}"

# DBサービスの再起動
systemctl restart mysql

# スローログのチェックと操作
if [ -f "${RPC_DB_SLOW_LOG_FILE}" ]; then
  truncate -s 0 "${RPC_DB_SLOW_LOG_FILE}"
  chmod 777 "${RPC_DB_SLOW_LOG_FILE}"
fi
