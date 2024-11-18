#!/bin/bash

set -e

# リポジトリのPull
git -C "${RPC_PROJECT_ROOT}" pull origin "${RPCDEPLOY_BRANCH}"

# 最新コミットの取得
last_commit=$(git -C "${RPC_PROJECT_ROOT}" log --pretty=oneline -n 1)

# 通知の送信
curl -X POST -H "Content-Type: application/json" -d "{\"content\": \"**Deploying...**:\n- branch: \`$DEPLOY_BRANCH\`\n- commit: \`$last_commit\`\"}" "$RPC_WEBHOOK_URL"
