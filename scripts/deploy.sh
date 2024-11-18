#!/bin/bash

set -e

script_dir=$(cd $(dirname $0) && pwd)

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
blue='\033[0;34m'
gray='\033[2;29m'
nc='\033[0m'

error="${red}[ERROR]${nc}"
success="${green}[SUCCESS]${nc}"
info="${blue}[INFO]${nc}"

source "${script_dir}/setup-common-variables.sh"

variables=$(env | grep "^RPC_" | awk -F= '{print "$" $1}')

active_servers=$(jq -r '.servers[] | select(.enabled == true) | .name' "${script_dir}/../config.json")
inactive_servers=$(jq -r '.servers[] | select(.enabled == false) | .name' "${script_dir}/../config.json")

active_servers_print=$(echo $active_servers | tr '\n' ',')
inactive_servers_print=$(echo $inactive_servers | tr '\n' ',')
echo -e "$info Deploying to ${yellow}${active_servers_print%,}${nc} (inactive: ${yellow}${inactive_servers_print%,}${nc})"

echo -e "\n$info Git Pull (all)"
for server in $active_servers; do
  address=$(jq -r ".servers[] | select(.name == \"${server}\") | .address" "${script_dir}/../config.json")
  # cat "${script_dir}/deploy-remote/git.sh" | envsubst "${variables}" | ssh "isucon@${address}" bash
  echo -e "$success $server ${gray}(${address})${nc}"
done

echo -e "\n$info Propagate systemd config (all)"
for server in $active_servers; do
  address=$(jq -r ".servers[] | select(.name == \"${server}\") | .address" "${script_dir}/../config.json")
  # cat "${script_dir}/deploy-remote/systemd.sh" | envsubst "${variables}" | ssh "isucon@${address}" bash
  echo -e "$success $server ${gray}(${address})${nc}"
done

echo -e "\n$info Propagate database config (db)"
db_servers=$(jq -r '.servers[] | select(.enabled == true) | select(.deploy[]? == "db") | .name' "${script_dir}/../config.json")
for server in $db_servers; do
  address=$(jq -r ".servers[] | select(.name == \"${server}\") | .address" "${script_dir}/../config.json")
  # cat "${script_dir}/deploy-remote/db.sh" | envsubst "${variables}" | ssh "isucon@${address}" bash
  echo -e "$success $server ${gray}(${address})${nc}"
done

echo -e "\n$info Propagate nginx config (proxy)"
proxy_servers=$(jq -r '.servers[] | select(.enabled == true) | select(.deploy[]? == "proxy") | .name' "${script_dir}/../config.json")
for server in $proxy_servers; do
  address=$(jq -r ".servers[] | select(.name == \"${server}\") | .address" "${script_dir}/../config.json")
  # cat "${script_dir}/deploy-remote/proxy.sh" | envsubst "${variables}" | ssh "isucon@${address}" bash
  echo -e "$success $server ${gray}(${address})${nc}"
done

echo -e "\n$info Build and deploy app (app)"
app_servers=$(jq -r '.servers[] | select(.enabled == true) | select(.deploy[]? == "app") | .name' "${script_dir}/../config.json")
for server in $app_servers; do
  address=$(jq -r ".servers[] | select(.name == \"${server}\") | .address" "${script_dir}/../config.json")
  # cat "${script_dir}/deploy-remote/app.sh" | envsubst "${variables}" | ssh "isucon@${address}" bash
  echo -e "$success $server ${gray}(${address})${nc}"
done
