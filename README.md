# RPC (Remote Provisioning Controller)

ISUCON 用のプロビジョニングツール

## 使い方

### 下準備

- 空のリポジトリを用意する
- GitHub の トークン (Fine-grained tokens / Tokens (classic)) を発行しておく
  - 該当のリポジトリへのアクセス権を与えておく
- Discord の適当なサーバーの適当なチャンネルに Webhook を作成して、URLを保管しておく

### observer のセットアップ

基本の使い方は `docker compose up -f observer/compose.yaml --build --watch` するだけ

次のサービスが起動される

- Grafana (`:43000`)
  - 各種メトリクスの可視化、ログの閲覧など
- Adminer (`:48080`)
  - DBの閲覧、書き換えなど
- pprotein (`:49000`)
  - pprof、alp、mysqldumpの結果の閲覧
- Prometheus (`:49090`)
  - 各種メトリクスの取得
- Loki (`:43100`)
  - ログの取得

### 環境変数の設定

次のような環境変数を設定する。`.env` ファイルに書き込むと良い (`.env.sample` をコピーして作成するとよい)

```shell
export SSH_USERS="SSHするユーザーのGitHub ID (カンマ区切り)"
export GITHUB_TOKEN="GitHubのトークン"
export DISCORD_WEBHOOK_URL="DiscordのWebhook URL"
export LOKI_URL="LokiのURL"

export PROJECT_ROOT="プロジェクトのルートパス"
export GITHUB_REPO_OWNER="リポジトリのオーナー (organization)"
export GITHUB_REPO_NAME="リポジトリの名前"
export APP_BIN_ORIGINAL="アプリの実行ファイルのパス"
export APP_SERVICE_NAME="サービス名"
```
