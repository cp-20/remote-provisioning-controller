#!/bin/bash

if [ -z "${SERVER_ID}" ]; then
  echo -e "$error SERVER_ID is required."
  exit 1
fi
IS_MASTER=false
if [ ${SERVER_ID} == "s1" ]; then
  IS_MASTER=true
fi

if [ -z "${SERVER_ADDRESS}" ]; then
  echo -e "$error SERVER_ADDRESS is required."
  exit 1
fi

if [ -z "${SSH_USERS}" ]; then
  echo -e "$error SSH_USERS is required."
  exit 1
fi

if [ -z "${GITHUB_TOKEN}" ]; then
  echo -e "$error GITHUB_TOKEN is required."
  exit 1
fi

if [ -z "${DISCORD_WEBHOOK_URL}" ]; then
  echo -e "$error DISCORD_WEBHOOK_URL is required."
  exit 1
fi

if [ -z "${LOKI_URL}" ]; then
  echo -e "$error LOKI_URL is required."
  exit 1
fi

export RPC_SERVER_ID=${SERVER_ID}
export RPC_IS_MASTER=${IS_MASTER}
export RPC_SSH_USERS=${SSH_USERS}
export RPC_PROJECT_ROOT="${PROJECT_ROOT:-/home/isucon/isucon14}"
export RPC_DEPLOY_BRANCH="${DEPLOY_BRANCH:-main}"
export RPC_DISCORD_WEBHOOK_URL=${DISCORD_WEBHOOK_URL}
export RPC_LOKI_URL=${LOKI_URL}

export RPC_GITHUB_REPO_OWNER=${GITHUB_REPO_OWNER:-"cp-20"}
export RPC_GITHUB_REPO_NAME=${GITHUB_REPO_NAME:-"isucon14"}
export RPC_GITHUB_TOKEN=${GITHUB_TOKEN}

export RPC_NGINX_CONF_DIR_ORIGINAL="/etc/nginx"
export RPC_NGINX_CONF_DIR_REPO="${PROJECT_ROOT}/${SERVER_ID}/etc/nginx"
export RPC_NGINX_ACCESS_LOG_PATH="/var/log/nginx/access.log"

export RPC_DB_CONF_DIR_ORIGINAL="/etc/mysql"
export RPC_DB_CONF_DIR_REPO="${PROJECT_ROOT}/${SERVER_ID}/etc/mysql"
export RPC_DB_SLOW_LOG_PATH="/var/log/mysql/mysql-slow.log"

export RPC_SYSTEMD_CONF_DIR_ORIGINAL="/etc/systemd/system"
export RPC_SYSTEMD_CONF_DIR_REPO="${PROJECT_ROOT}/${SERVER_ID}/etc/systemd/system"

export RPC_APP_DIR_ORIGINAL="/home/isucon/webapp/go"
export RPC_APP_DIR_REPO="${PROJECT_ROOT}/webapp/go"

export RPC_ENV_FILE_ORIGINAL="/home/isucon/env.sh"
export RPC_ENV_FILE_REPO="${PROJECT_ROOT}/${SERVER_ID}/env.sh"

export RPC_DB_USER="isucon"      # アプリから接続するユーザ
export RPC_DB_ADMIN_USER="admin" # Adminerから接続するユーザ
export RPC_DB_ADMIN_PASSWORD="password"
