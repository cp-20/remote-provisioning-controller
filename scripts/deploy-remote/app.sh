#!/bin/bash

set -e

export PATH=/home/isucon/local/go/bin:/home/isucon/go/bin:$PATH

# アプリケーションのビルド
cd "${RPC_APP_DIR_REPO}"
go build -o "${RPC_APP_BIN_ORIGINAL}"

# アプリケーションサービスの再起動
sudo systemctl restart "${RPC_APP_SERVICE_NAME}"
