#!/bin/bash

set -e

script_dir=$(cd "$(dirname "$0")" && pwd)

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
blue='\033[0;34m'
gray='\033[2;29m'
nc='\033[0m'

error="${red}[ERROR]${nc}"
info="${blue}[INFO]${nc}"

active_servers=$(jq -r '.servers[] | select(.enabled == true) | .name' "${script_dir}/../config.json")
inactive_servers=$(jq -r '.servers[] | select(.enabled == false) | .name' "${script_dir}/../config.json")

active_servers_print=$(echo "$active_servers" | tr '\n' ',')
inactive_servers_print=$(echo "$inactive_servers" | tr '\n' ',')
echo -e "$info Initializing ${yellow}${active_servers_print%,}${nc} (inactive: ${yellow}${inactive_servers_print%,}${nc})"

for server in $active_servers; do
  SERVER_ADDRESS=$(jq -r ".servers[] | select(.name == \"${server}\") | .address" "${script_dir}/../config.json")
  export SERVER_ID=${server}

  echo -e "$info Initializing ${yellow}${server}${nc} ${gray}(${SERVER_ADDRESS})${nc}"

  export RPC_SERVER_ID=${server}
  is_master=false
  if [ "$server" == "s2" ]; then
    is_master=true
  fi
  export RPC_IS_MASTER=${is_master}
  source "${script_dir}/setup-common-variables.sh"

  # 変数を表示
  echo -e "$info Variables:"
  echo -e "  RPC_SERVER_ID = \"${yellow}${RPC_SERVER_ID}${nc}\""
  echo -e "  RPC_IS_MASTER = \"${yellow}${RPC_IS_MASTER}${nc}\""
  echo -e "  RPC_SSH_USERS = \"${yellow}${RPC_SSH_USERS}${nc}\""
  echo -e "  RPC_PROJECT_ROOT = \"${yellow}${RPC_PROJECT_ROOT}${nc}\""
  echo -e "  RPC_DEPLOY_BRANCH = \"${yellow}${RPC_DEPLOY_BRANCH}${nc}\""
  echo -e "  RPC_DISCORD_WEBHOOK_URL = \"${yellow}${RPC_DISCORD_WEBHOOK_URL}${nc}\""
  echo -e "  RPC_LOKI_URL = \"${yellow}${RPC_LOKI_URL}${nc}\""
  echo -e "  RPC_GITHUB_REPO_OWNER = \"${yellow}${RPC_GITHUB_REPO_OWNER}${nc}\""
  echo -e "  RPC_GITHUB_REPO_NAME = \"${yellow}${RPC_GITHUB_REPO_NAME}${nc}\""
  echo -e "  RPC_GITHUB_TOKEN = \"${yellow}${RPC_GITHUB_TOKEN:0:20}...${nc}\""
  echo -e "  RPC_NGINX_CONF_DIR_ORIGINAL = \"${yellow}${RPC_NGINX_CONF_DIR_ORIGINAL}${nc}\""
  echo -e "  RPC_NGINX_CONF_DIR_REPO = \"${yellow}${RPC_NGINX_CONF_DIR_REPO}${nc}\""
  echo -e "  RPC_NGINX_ACCESS_LOG_PATH = \"${yellow}${RPC_NGINX_ACCESS_LOG_PATH}${nc}\""
  echo -e "  RPC_DB_CONF_DIR_ORIGINAL = \"${yellow}${RPC_DB_CONF_DIR_ORIGINAL}${nc}\""
  echo -e "  RPC_DB_CONF_DIR_REPO = \"${yellow}${RPC_DB_CONF_DIR_REPO}${nc}\""
  echo -e "  RPC_DB_SLOW_LOG_PATH = \"${yellow}${RPC_DB_SLOW_LOG_PATH}${nc}\""
  echo -e "  RPC_SYSTEMD_CONF_DIR_ORIGINAL = \"${yellow}${RPC_SYSTEMD_CONF_DIR_ORIGINAL}${nc}\""
  echo -e "  RPC_SYSTEMD_CONF_DIR_REPO = \"${yellow}${RPC_SYSTEMD_CONF_DIR_REPO}${nc}\""
  echo -e "  RPC_APP_DIR_ORIGINAL = \"${yellow}${RPC_APP_DIR_ORIGINAL}${nc}\""
  echo -e "  RPC_APP_DIR_REPO = \"${yellow}${RPC_APP_DIR_REPO}${nc}\""
  echo -e "  RPC_ENV_FILE_ORIGINAL = \"${yellow}${RPC_ENV_FILE_ORIGINAL}${nc}\""
  echo -e "  RPC_ENV_FILE_REPO = \"${yellow}${RPC_ENV_FILE_REPO}${nc}\""
  echo -e "  RPC_DB_USER = \"${yellow}${RPC_DB_USER}${nc}\""
  echo -e "  RPC_DB_ADMIN_USER = \"${yellow}${RPC_DB_ADMIN_USER}${nc}\""
  echo -e "  RPC_DB_ADMIN_PASSWORD = \"${yellow}${RPC_DB_ADMIN_PASSWORD}${nc}\""

  # y/n 確認
  echo -ne "\n$info Continue? [y/n] "
  read -r answer
  if [ "$answer" != "y" ]; then
    echo -e "$error Aborted."
    exit 1
  fi

  variables=$(env | grep "^RPC_" | awk -F= '{print "$" $1}')
  cat "${script_dir}/init-remote.sh" | envsubst "${variables}" | ssh "isucon@${SERVER_ADDRESS}" bash
done
