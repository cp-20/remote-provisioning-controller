#!/bin/bash

set -e

# アプリケーションのビルド
cd "${RPC_APP_DIR_REPO}"
go build -o "${RPC_APP_BIN_ORIGINAL}"

# アプリケーションサービスの再起動
systemctl restart "${RPC_APP_SERVICE_NAME}"
