#!/bin/bash

set -e

# systemd設定ファイルのコピー
cp -r "${RPC_SYSTEMD_CONF_DIR_REPO}"/* "${RPC_SYSTEMD_CONF_DIR_ORIGINAL}"
chmod -R 755 "${RPC_SYSTEMD_CONF_DIR_ORIGINAL}"

# systemdのデーモンをリロード
systemctl daemon-reload
