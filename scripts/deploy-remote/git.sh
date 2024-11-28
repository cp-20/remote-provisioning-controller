#!/bin/bash

set -e

# リポジトリのPull
# RPC_DEPLOY_BRANCHのブランチにreset hard
git -C "${RPC_PROJECT_ROOT}" fetch origin
git -C "${RPC_PROJECT_ROOT}" reset --hard origin/${RPC_DEPLOY_BRANCH}

# 最新コミットの取得
last_commit=$(git -C "${RPC_PROJECT_ROOT}" log --pretty=oneline -n 1)

# 通知の送信
curl -s -X POST -H "Content-Type: application/json" -d "{\"content\": \"**Deploying...**:\n- server: \`$RPC_SERVER_ID\`\n- branch: \`$RPC_DEPLOY_BRANCH\`\n- commit: \`$last_commit\`\"}" ${RPC_DISCORD_WEBHOOK_URL}
