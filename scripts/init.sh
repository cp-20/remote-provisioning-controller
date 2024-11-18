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

DRY_RUN=false
if [ "$1" == "--dry-run" ]; then
  DRY_RUN=true
  shift
fi

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

source "${script_dir}/setup-common-variables.sh"
export RPC_SERVER_ID=${SERVER_ID}
export RPC_IS_MASTER=${IS_MASTER}

# 変数を表示
echo -e "$info Variables:"
echo -e "  RPC_SERVER_ID = ${yellow}\"${RPC_SERVER_ID}${nc}\""
echo -e "  RPC_PROJECT_ROOT = ${yellow}\"${RPC_PROJECT_ROOT}${nc}\""
echo -e "  RPC_DEPLOY_BRANCH = ${yellow}\"${RPC_DEPLOY_BRANCH}${nc}\""
echo -e "  RPC_DISCORD_WEBHOOK_URL = ${yellow}\"${RPC_DISCORD_WEBHOOK_URL}${nc}\""
echo -e "  RPC_LOKI_URL = ${yellow}\"${RPC_LOKI_URL}${nc}\""
echo -e "  RPC_GITHUB_REPO_OWNER = ${yellow}\"${RPC_GITHUB_REPO_OWNER}${nc}\""
echo -e "  RPC_GITHUB_REPO_NAME = ${yellow}\"${RPC_GITHUB_REPO_NAME}${nc}\""
echo -e "  RPC_GITHUB_TOKEN = ${yellow}\"${RPC_GITHUB_TOKEN:0:10}...${nc}\""
echo -e "  RPC_NGINX_CONF_DIR_ORIGINAL = ${yellow}\"${RPC_NGINX_CONF_DIR_ORIGINAL}${nc}\""
echo -e "  RPC_NGINX_CONF_DIR_REPO = ${yellow}\"${RPC_NGINX_CONF_DIR_REPO}${nc}\""
echo -e "  RPC_NGINX_ACCESS_LOG_PATH = ${yellow}\"${RPC_NGINX_ACCESS_LOG_PATH}${nc}\""
echo -e "  RPC_DB_CONF_DIR_ORIGINAL = ${yellow}\"${RPC_DB_CONF_DIR_ORIGINAL}${nc}\""
echo -e "  RPC_DB_CONF_DIR_REPO = ${yellow}\"${RPC_DB_CONF_DIR_REPO}${nc}\""
echo -e "  RPC_DB_SLOW_LOG_PATH = ${yellow}\"${RPC_DB_SLOW_LOG_PATH}${nc}\""
echo -e "  RPC_SYSTEMD_CONF_DIR_ORIGINAL = ${yellow}\"${RPC_SYSTEMD_CONF_DIR_ORIGINAL}${nc}\""
echo -e "  RPC_SYSTEMD_CONF_DIR_REPO = ${yellow}\"${RPC_SYSTEMD_CONF_DIR_REPO}${nc}\""
echo -e "  RPC_APP_DIR_ORIGINAL = ${yellow}\"${RPC_APP_DIR_ORIGINAL}${nc}\""
echo -e "  RPC_APP_DIR_REPO = ${yellow}\"${RPC_APP_DIR_REPO}${nc}\""
echo -e "  RPC_ENV_FILE_ORIGINAL = ${yellow}\"${RPC_ENV_FILE_ORIGINAL}${nc}\""
echo -e "  RPC_ENV_FILE_REPO = ${yellow}\"${RPC_ENV_FILE_REPO}${nc}\""
echo -e "  RPC_DB_USER = ${yellow}\"${RPC_DB_USER}${nc}\""
echo -e "  RPC_DB_ADMIN_USER = ${yellow}\"${RPC_DB_ADMIN_USER}${nc}\""
echo -e "  RPC_DB_ADMIN_PASSWORD = ${yellow}\"${RPC_DB_ADMIN_PASSWORD}${nc}\""

variables=$(env | grep "^RPC_" | awk -F= '{print "$" $1}')

if [ $DRY_RUN == true ]; then
  echo -e "\n----------------------------------------\n"
  echo -ne "${gray}"
  echo "$(cat "${script_dir}/init-remote.sh" | envsubst "${variables}")"
  echo -ne "${nc}"
else
  cat "${script_dir}/init-remote.sh" | envsubst "${variables}" | ssh "isucon@${SERVER_ADDRESS}" bash
fi