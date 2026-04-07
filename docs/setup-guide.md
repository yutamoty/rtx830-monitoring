# RTX830モニタリング完全セットアップガイド

このガイドでは、ゼロからRTX830の監視環境を構築する手順を説明します。

## 全体の流れ

```
1. Grafana Cloudの準備（15分）
2. RTX830のSNMP設定（5分）
3. Raspberry Piのセットアップ（10分）
4. 動作確認（5分）
5. ダッシュボード作成（15分）
```

**所要時間**: 約50分

---

## ステップ1: Grafana Cloudの準備

### 1.1 アカウント作成

1. https://grafana.com/auth/sign-up/create-user にアクセス
2. メールアドレスで登録（または GitHub/Google アカウントで登録）
3. アカウント情報を入力して作成

### 1.2 Grafana Cloudスタックの作成

1. ログイン後、**"Launch"** または **"Create a stack"** をクリック
2. スタック名を入力（例: `rtx830-monitoring`）
3. リージョンを選択（日本の場合は `ap-northeast-1` または `ap-southeast-1` 推奨）
4. **"Create stack"** をクリック

### 1.3 Prometheus接続情報の取得

#### Remote Write URLとユーザー名の取得

1. 左サイドバー → **"Connections"** → **"Add new connection"**
2. **"Hosted Prometheus metrics"** を検索して選択
3. 表示される情報をメモ：
   ```
   Remote Write Endpoint: https://prometheus-prod-XX-XXXX.grafana.net/api/prom/push
   Username / Instance ID: 123456
   ```

#### APIキーの生成

1. 左サイドバー → **"Security"** → **"API Keys"**
2. **"Create API key"** をクリック
3. 設定：
   - **Key name**: `rtx830-alloy`
   - **Role**: `MetricsPublisher` または `Admin`
   - **Time to live**: 無期限（または必要に応じて設定）
4. **"Add"** をクリック
5. 表示されるAPIキー（`glc_xxxxx...`）をコピーして保存
   - ⚠️ **重要**: このキーは二度と表示されないので必ず保存してください

### 1.4 取得した情報の整理

以下の3つの情報をメモ帳などに保存してください：

```
GRAFANA_CLOUD_PROMETHEUS_URL=https://prometheus-prod-XX-XXXX.grafana.net/api/prom/push
GRAFANA_CLOUD_PROMETHEUS_USER=123456
GRAFANA_CLOUD_API_KEY=glc_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

---

## ステップ2: RTX830のSNMP設定

### 2.1 RTX830への接続

Web GUI または Telnet/SSH で RTX830 に接続します。

### 2.2 SNMP設定の投入

#### 基本設定（SNMPv2c）

```
# 管理者モードに入る
administrator

# SNMP Community String の設定（"public"から変更することを推奨）
snmp community read-only your_secret_community_string

# アクセス許可（Raspberry PiのIPアドレスを指定）
snmp host 192.168.1.100

# システム情報の設定（オプション）
snmp sysname "RTX830"
snmp syscontact "admin@example.com"
snmp syslocation "Home/Office"

# 設定の保存
save
```

**セキュリティTips:**
- `your_secret_community_string` は推測困難な文字列に変更してください
- 本番環境では SNMPv3 の使用を推奨します

#### より安全なSNMPv3設定（推奨）

```
# SNMPv3ユーザーの作成
snmp user myuser auth-protocol sha auth-password MyAuthPass123 priv-protocol aes priv-password MyPrivPass123

# SNMPv3アクセスグループの設定
snmp group mygroup user myuser security-level auth-priv

# アクセス許可
snmp host 192.168.1.100
```

SNMPv3を使う場合は、後で `.env` ファイルの設定も変更します。

### 2.3 設定の確認

```
show config | grep snmp
```

以下のような出力が表示されればOK：
```
snmp community read-only your_secret_community_string
snmp host 192.168.1.100
```

---

## ステップ3: Raspberry Piのセットアップ

### 3.1 前提条件の確認

Raspberry Piで以下がインストールされているか確認：

```bash
# Dockerのバージョン確認
docker --version
# 出力例: Docker version 24.0.0, build xxx

# Docker Composeのバージョン確認
docker-compose --version
# 出力例: docker-compose version 1.29.2, build xxx
```

インストールされていない場合は以下を実行：

```bash
# Dockerのインストール
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# 現在のユーザーをdockerグループに追加（再ログイン必要）
sudo usermod -aG docker $USER

# Docker Composeのインストール
sudo apt-get update
sudo apt-get install -y docker-compose
```

### 3.2 リポジトリのクローン

```bash
# ホームディレクトリに移動
cd ~

# リポジトリをクローン
git clone https://github.com/yutamoty/rtx830-monitoring.git

# ディレクトリに移動
cd rtx830-monitoring

# 内容を確認
ls -la
```

### 3.3 環境変数の設定

```bash
# .env.exampleをコピー
cp .env.example .env

# .envファイルを編集
nano .env
```

以下の内容を入力（ステップ1と2で取得した情報を使用）：

```bash
# RTX830 SNMP設定
RTX830_HOST=192.168.1.1  # RTX830の実際のIPアドレス
SNMP_COMMUNITY=your_secret_community_string  # ステップ2で設定したCommunity String
SNMP_VERSION=2c

# Grafana Cloud設定（ステップ1で取得した情報）
GRAFANA_CLOUD_PROMETHEUS_URL=https://prometheus-prod-XX-XXXX.grafana.net/api/prom/push
GRAFANA_CLOUD_PROMETHEUS_USER=123456
GRAFANA_CLOUD_API_KEY=glc_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

# Grafana Alloy設定
ALLOY_PORT=12345

# タイムゾーン設定
TZ=Asia/Tokyo
```

**保存方法（nano エディタ）:**
- `Ctrl + O` → Enter（保存）
- `Ctrl + X`（終了）

### 3.4 設定の確認

```bash
# .envファイルの内容を確認（機密情報が表示されるので注意）
cat .env
```

### 3.5 ネットワーク確認

Raspberry Pi から RTX830 に接続できるか確認：

```bash
# RTX830へのping確認
ping -c 4 192.168.1.1

# SNMP接続確認（snmp-utilsがインストールされている場合）
# インストール: sudo apt-get install snmp
snmpwalk -v2c -c your_secret_community_string 192.168.1.1 system
```

---

## ステップ4: コンテナの起動と動作確認

### 4.1 コンテナの起動

```bash
# バックグラウンドでコンテナを起動
docker-compose up -d

# 出力例:
# Creating network "rtx830-monitoring_default" with the default driver
# Creating alloy ... done
```

### 4.2 コンテナの状態確認

```bash
# コンテナの起動状態を確認
docker-compose ps

# 期待される出力:
# NAME    STATE    PORTS
# alloy   running  0.0.0.0:12345->12345/tcp
```

### 4.3 ログの確認

```bash
# Alloyのログをリアルタイム表示
docker-compose logs -f alloy

# 正常な場合の出力例:
# alloy | level=info msg="starting Alloy"
# alloy | level=info msg="SNMP exporter started"
# alloy | level=info msg="remote write client started"
```

エラーがないか確認してください。

**Ctrl + C** でログ表示を終了できます。

### 4.4 Alloy UI での確認

Webブラウザで以下にアクセス：

```
http://<Raspberry_PiのIPアドレス>:12345
```

Alloy の管理画面が表示され、以下が確認できます：
- コンポーネントのステータス
- 収集中のメトリクス
- Remote Writeの状態

### 4.5 Grafana Cloudでの確認

1. Grafana Cloud にログイン
2. 左サイドバー → **"Explore"**
3. データソースで **"Prometheus"** を選択
4. メトリクスブラウザまたはクエリで以下を入力：
   ```
   ifHCInOctets
   ```
5. **"Run query"** をクリック

**成功の確認:**
- RTX830のインターフェース毎にメトリクスが表示される
- `device="rtx830"` というラベルが付いている

---

## ステップ5: ダッシュボードの作成

### 5.1 汎用SNMPダッシュボードのインポート

1. Grafana Cloud → 左サイドバー → **"Dashboards"**
2. **"New"** → **"Import"**
3. Dashboard ID に `12366` を入力（Generic SNMP Dashboard）
4. **"Load"** をクリック
5. データソースで **"Prometheus"** を選択
6. **"Import"** をクリック

### 5.2 RTX830用のカスタマイズ

インポートしたダッシュボードを編集して、RTX830特有のパネルを追加：

#### インターフェーストラフィックパネル

1. **"Add"** → **"Visualization"**
2. クエリ：
   ```promql
   # 受信トラフィック（bps）
   rate(ifHCInOctets{device="rtx830"}[5m]) * 8
   
   # 送信トラフィック（bps）
   rate(ifHCOutOctets{device="rtx830"}[5m]) * 8
   ```
3. 設定：
   - Panel type: **Time series**
   - Unit: **bits/sec**
   - Legend: `{{ifDescr}}`

#### CPU使用率パネル

1. **"Add"** → **"Visualization"**
2. クエリ：
   ```promql
   hrProcessorLoad{device="rtx830"}
   ```
3. 設定：
   - Panel type: **Gauge** または **Time series**
   - Unit: **Percent (0-100)**

#### メモリ使用率パネル

1. **"Add"** → **"Visualization"**
2. クエリ：
   ```promql
   (hrStorageUsed{device="rtx830"} / hrStorageSize{device="rtx830"}) * 100
   ```
3. 設定：
   - Panel type: **Gauge**
   - Unit: **Percent (0-100)**

#### TCP接続数パネル

1. **"Add"** → **"Visualization"**
2. クエリ：
   ```promql
   tcpCurrEstab{device="rtx830"}
   ```
3. 設定：
   - Panel type: **Stat** または **Time series**

### 5.3 ダッシュボードの保存

1. 右上の **"Save dashboard"** アイコンをクリック
2. 名前を入力（例: `RTX830 Monitoring`）
3. **"Save"** をクリック

---

## ステップ6: アラート設定（オプション）

### 6.1 アラートルールの作成

1. Grafana Cloud → 左サイドバー → **"Alerting"** → **"Alert rules"**
2. **"Create alert rule"** をクリック

#### 例: CPU使用率が80%を超えた場合のアラート

1. **Rule name**: `RTX830 High CPU Usage`
2. **Query**:
   ```promql
   hrProcessorLoad{device="rtx830"} > 80
   ```
3. **Condition**: `WHEN last() OF query(A) IS ABOVE 80`
4. **For**: `5m`（5分間継続した場合）
5. **Annotations**:
   - Summary: `RTX830 CPU usage is above 80%`
6. **"Save and exit"** をクリック

### 6.2 通知チャネルの設定

1. **"Contact points"** → **"New contact point"**
2. 名前を入力（例: `Email Notifications`）
3. Integration: **Email** を選択
4. Addresses: 通知先メールアドレスを入力
5. **"Save contact point"** をクリック

---

## トラブルシューティング

### 問題: コンテナが起動しない

```bash
# ログを詳しく確認
docker-compose logs alloy

# 設定ファイルの構文エラーをチェック
docker run --rm -v $(pwd)/alloy:/etc/alloy grafana/alloy:latest \
  run --dry-run /etc/alloy/config.alloy
```

### 問題: SNMPデータが取得できない

```bash
# RTX830への接続確認
ping -c 4 192.168.1.1

# SNMP接続確認
snmpwalk -v2c -c your_secret_community_string 192.168.1.1 system

# Alloyログでエラー確認
docker-compose logs alloy | grep -i error
```

### 問題: Grafana Cloudにデータが送信されない

```bash
# Remote Writeのエラーを確認
docker-compose logs alloy | grep -i "remote_write"

# .envファイルの設定を再確認
cat .env

# APIキーとエンドポイントURLが正しいか確認
```

### 問題: メトリクスは届くがグラフに表示されない

1. Grafana Cloud → **"Explore"**
2. メトリクスブラウザで `ifHCInOctets` を検索
3. ラベルフィルターで `device="rtx830"` を確認
4. 時間範囲を調整（Last 5 minutes → Last 1 hour）

---

## メンテナンス

### コンテナの再起動

```bash
# コンテナを再起動
docker-compose restart

# コンテナを停止
docker-compose stop

# コンテナを停止して削除
docker-compose down
```

### 設定変更後の反映

```bash
# config.alloy または snmp.yml を編集後
nano alloy/config.alloy

# コンテナを再起動
docker-compose restart alloy
```

### ログの確認

```bash
# 最新100行のログを表示
docker-compose logs --tail=100 alloy

# リアルタイムでログを表示
docker-compose logs -f alloy

# エラーのみをフィルター
docker-compose logs alloy | grep -i error
```

### Dockerイメージの更新

```bash
# 最新イメージをプル
docker-compose pull

# コンテナを再作成
docker-compose up -d
```

---

## まとめ

これで RTX830 の監視環境が完成しました！

### 確認ポイント

- ✅ Grafana Cloud にメトリクスが届いている
- ✅ ダッシュボードでRTX830の状態が可視化できている
- ✅ Alloyコンテナが正常に動作している

### 次のステップ

1. ダッシュボードをカスタマイズして見やすくする
2. アラートルールを追加して異常を検知できるようにする
3. 他のデバイス（スイッチ、AP等）の監視を追加する

### サポート

問題や質問がある場合：
- GitHub Issues: https://github.com/yutamoty/rtx830-monitoring/issues
- ドキュメント: プロジェクトの `CLAUDE.md` と `README.md` を参照
