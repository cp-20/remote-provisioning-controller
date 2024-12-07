#!/bin/bash

set -e

# systemd設定ファイルのコピー
sudo cp -r "${RPC_SYSTEMD_CONF_DIR_REPO}"/* "${RPC_SYSTEMD_CONF_DIR_ORIGINAL}"
sudo chmod -R 755 "${RPC_SYSTEMD_CONF_DIR_ORIGINAL}"

# systemdのデーモンをリロード
sudo systemctl daemon-reload
