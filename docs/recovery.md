# RTX830監視システム 復旧手順書

SDカード故障やシステム障害時の迅速な復旧手順を説明します。

**目標復旧時間**: 15分

---

## 前提条件

復旧に必要な情報とリソース：

### 必須情報

1. **GitHub アクセス**
   - リポジトリURL: `https://github.com/yutamoty/rtx830-monitoring.git`
   - アクセス権限

2. **Grafana Cloud情報**（事前にバックアップしておく）
   ```
   GRAFANA_CLOUD_PROMETHEUS_URL=https://prometheus-prod-XX-XXXX.grafana.net/api/prom/push
   GRAFANA_CLOUD_PROMETHEUS_USER=123456
   GRAFANA_CLOUD_API_KEY=glc_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
   ```

3. **RTX830情報**
   ```
   RTX830_HOST=192.168.1.1
   SNMP_COMMUNITY=your_secret_community_string
   ```

### 必須リソース

- 新しいRaspberry Pi または交換用SDカード
- インターネット接続
- RTX830（SNMP設定済み）

---

## 復旧シナリオ別手順

### シナリオ1: SDカード故障

**症状**: Raspberry Piが起動しない、ファイルシステムエラー

#### ステップ1: 新しいSDカードの準備

1. 新しいSDカード（16GB以上推奨）を用意
2. Raspberry Pi Imager で Raspberry Pi OS をインストール
   - OS: Raspberry Pi OS (64-bit) 推奨
   - 設定: SSH有効化、ユーザー名・パスワード設定
3. SDカードをRaspberry Piに挿入して起動
4. SSH接続を確認

#### ステップ2: 基本環境のセットアップ（5分）

```bash
# システムアップデート
sudo apt-get update
sudo apt-get upgrade -y

# Gitのインストール
sudo apt-get install -y git

# Dockerのインストール
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# 現在のユーザーをdockerグループに追加
sudo usermod -aG docker $USER

# Docker Composeのインストール
sudo apt-get install -y docker-compose

# 再ログイン（dockerグループ反映のため）
exit
# → 再度SSHでログイン
```

#### ステップ3: 監視システムのデプロイ（5分）

```bash
# ホームディレクトリに移動
cd ~

# リポジトリをクローン
git clone https://github.com/yutamoty/rtx830-monitoring.git

# ディレクトリに移動
cd rtx830-monitoring

# 環境変数ファイルの作成
cp .env.example .env

# .envファイルを編集（バックアップした情報を使用）
nano .env
```

`.env`に以下を設定：
```bash
# RTX830設定
RTX830_HOST=192.168.1.1
SNMP_COMMUNITY=your_secret_community_string
SNMP_VERSION=2c

# Grafana Cloud設定（バックアップから復元）
GRAFANA_CLOUD_PROMETHEUS_URL=https://prometheus-prod-XX-XXXX.grafana.net/api/prom/push
GRAFANA_CLOUD_PROMETHEUS_USER=123456
GRAFANA_CLOUD_API_KEY=glc_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

# その他
ALLOY_PORT=12345
TZ=Asia/Tokyo
```

#### ステップ4: コンテナ起動（1分）

```bash
# コンテナを起動
docker-compose up -d

# 起動確認
docker-compose ps
```

#### ステップ5: 動作確認（3分）

```bash
# ログを確認
docker-compose logs alloy | tail -50

# Grafana Cloudで確認
# → Explore → ifHCInOctets を検索
```

---

### シナリオ2: コンテナが停止・削除された

**症状**: コンテナが動いていない、誤って削除した

#### 復旧手順（2分）

```bash
# プロジェクトディレクトリに移動
cd ~/rtx830-monitoring

# 最新のコードを取得
git pull

# コンテナを再起動
docker-compose up -d

# 確認
docker-compose ps
docker-compose logs alloy
```

---

### シナリオ3: 設定ファイルの破損

**症状**: コンテナが起動するがエラーが出る

#### 復旧手順（3分）

```bash
# プロジェクトディレクトリに移動
cd ~/rtx830-monitoring

# 最新のコードを取得（設定ファイルも更新）
git fetch origin
git reset --hard origin/main

# .envファイルは保持される（.gitignore対象）
# 必要に応じて.envを再設定
nano .env

# コンテナを再起動
docker-compose down
docker-compose up -d

# 確認
docker-compose logs alloy
```

---

### シナリオ4: Raspberry Pi本体の故障

**症状**: Raspberry Piが起動しない、ハードウェア故障

#### 復旧手順（15分）

新しいRaspberry Piで「シナリオ1: SDカード故障」の手順を実施。

**追加確認事項**:
1. 新しいRaspberry PiのIPアドレスを確認
2. RTX830の `snmp host` 設定を更新（必要に応じて）
   ```
   snmp host <新しいRaspberry_PiのIP>
   ```

---

## データの復旧

### メトリクスデータ

- **保存場所**: Grafana Cloud
- **復旧**: 不要（クラウドに保存されているため、自動的にアクセス可能）
- **確認**: Grafana Cloud → Explore でクエリ実行

### ダッシュボード

- **保存場所**: Grafana Cloud
- **復旧**: 不要（クラウドに保存されている）
- **確認**: Grafana Cloud → Dashboards で確認

### 設定ファイル

- **保存場所**: GitHub
- **復旧**: `git clone` で自動的に取得
- **例外**: `.env`ファイルは手動で再作成が必要

---

## 復旧チェックリスト

復旧が完了したら、以下をチェックしてください。

### システムレベル

- [ ] Raspberry Piが起動している
- [ ] SSH接続ができる
- [ ] Dockerがインストールされている
- [ ] Docker Composeがインストールされている

### アプリケーションレベル

- [ ] リポジトリがクローンされている
- [ ] `.env`ファイルが正しく設定されている
- [ ] コンテナが起動している（`docker-compose ps`）
- [ ] コンテナのログにエラーがない（`docker-compose logs`）

### 監視レベル

- [ ] Alloy UIにアクセスできる（http://192.168.1.100:12345）
- [ ] Grafana Cloudでメトリクスが表示される
- [ ] ダッシュボードにデータが表示される
- [ ] アラートが動作している

### ネットワークレベル

- [ ] Raspberry PiからRTX830にpingが通る
- [ ] SNMP接続ができる（`snmpwalk`コマンド）

---

## トラブルシューティング

### 問題: Dockerのインストールに失敗する

```bash
# 既存のDockerパッケージを削除
sudo apt-get remove docker docker-engine docker.io containerd runc

# 再度インストール
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
```

### 問題: コンテナが起動しない

```bash
# 詳細なログを確認
docker-compose logs alloy

# 設定ファイルの構文チェック
docker run --rm -v $(pwd)/alloy:/etc/alloy grafana/alloy:latest \
  run --dry-run /etc/alloy/config.alloy

# ポート競合の確認
sudo netstat -tlnp | grep 12345

# コンテナを完全削除して再作成
docker-compose down -v
docker-compose up -d
```

### 問題: Grafana Cloudにデータが送信されない

```bash
# .envファイルの確認
cat .env | grep GRAFANA_CLOUD

# ネットワーク接続の確認
curl -I https://prometheus-prod-XX-XXXX.grafana.net

# Alloyログでエラー確認
docker-compose logs alloy | grep -i error
docker-compose logs alloy | grep -i "remote_write"
```

### 問題: SNMPデータが取得できない

```bash
# RTX830への接続確認
ping -c 4 192.168.1.1

# SNMP接続テスト
sudo apt-get install snmp
snmpwalk -v2c -c your_secret_community_string 192.168.1.1 system

# RTX830のSNMP設定確認
# RTX830にログインして: show config | grep snmp
```

---

## 予防措置

復旧を迅速化するための予防措置：

### 1. 定期的なバックアップ

**週次バックアップ**:
```bash
# .envファイルのバックアップ（別の安全な場所に保存）
cp ~/rtx830-monitoring/.env ~/rtx830-monitoring-backup.env

# ダッシュボードのエクスポート
# Grafana Cloud → Dashboards → RTX830 Monitoring → Share → Export → Save to file
```

### 2. ドキュメントの準備

以下の情報を紙やパスワード管理ツールに記録：
- Grafana Cloud URL、ユーザー名、パスワード
- Grafana Cloud APIキー
- RTX830 IPアドレス、SNMP Community String
- Raspberry Pi ユーザー名、パスワード

### 3. 予備SDカードの準備

- 予備のSDカードを用意
- 可能であれば、定期的にSDカードのイメージバックアップを作成
  ```bash
  # MacOS/Linuxでの例
  sudo dd if=/dev/sdX of=~/raspberrypi-backup.img bs=4M status=progress
  ```

### 4. 監視の監視

- Grafana Cloudでアラートを設定
- メトリクスが一定時間届かない場合に通知

### 5. 定期的な動作確認

月次で以下を確認：
- [ ] コンテナが正常に動作している
- [ ] Grafana Cloudでメトリクスが表示される
- [ ] ダッシュボードが正常に表示される
- [ ] アラートが動作している

---

## 復旧時間の短縮

### 自動化スクリプトの作成

`scripts/setup.sh` を使用して復旧を自動化：

```bash
#!/bin/bash
# RTX830監視システム 自動セットアップスクリプト

set -e

echo "=== RTX830監視システム 復旧開始 ==="

# Dockerのインストール
if ! command -v docker &> /dev/null; then
    echo "Dockerをインストール中..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    sudo usermod -aG docker $USER
fi

# Docker Composeのインストール
if ! command -v docker-compose &> /dev/null; then
    echo "Docker Composeをインストール中..."
    sudo apt-get install -y docker-compose
fi

# リポジトリのクローン
if [ ! -d "rtx830-monitoring" ]; then
    echo "リポジトリをクローン中..."
    git clone https://github.com/yutamoty/rtx830-monitoring.git
fi

cd rtx830-monitoring

# .envファイルの確認
if [ ! -f ".env" ]; then
    echo "エラー: .envファイルが存在しません"
    echo ".env.exampleをコピーして.envを作成してください"
    exit 1
fi

# コンテナの起動
echo "コンテナを起動中..."
docker-compose up -d

echo "=== 復旧完了 ==="
echo "動作確認: docker-compose ps"
echo "ログ確認: docker-compose logs alloy"
```

---

## 緊急連絡先

復旧に困った場合の連絡先：

- **GitHub Issues**: https://github.com/yutamoty/rtx830-monitoring/issues
- **Grafana Cloud Support**: https://grafana.com/support/
- **YAMAHA サポート**: http://www.rtpro.yamaha.co.jp/RT/FAQ/

---

## 復旧記録テンプレート

復旧作業の記録用：

```
=== 復旧記録 ===

【発生日時】: YYYY/MM/DD HH:MM
【発見者】: 
【症状】: 

【原因】: 

【復旧手順】:
1. 
2. 
3. 

【復旧完了時刻】: YYYY/MM/DD HH:MM
【所要時間】: XX分

【データ損失】: あり / なし
【今後の対策】: 

【作業者】: 
```

---

## まとめ

- **データは安全**: メトリクス・ダッシュボードはGrafana Cloudに保存
- **迅速な復旧**: 15分以内に復旧可能
- **予防が重要**: 定期的なバックアップと動作確認を実施

このドキュメントを印刷または安全な場所に保存しておくことを推奨します。
