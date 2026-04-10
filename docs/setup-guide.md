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
   - **Key name**: `rtx830-prometheus`
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

### 2.1 事前準備: Raspberry Pi のIPアドレス固定

RTX830 側でアクセス元IPを絞るため、Raspberry Pi のIPアドレスは**固定**しておく必要があります。DHCPで変動すると `snmpv2c host` 制限に引っかかって SNMP が取れなくなります。

以下のいずれかで固定してください:
- Raspberry Pi 側で static IP を設定する
- RTX830 の DHCP スコープで MAC アドレスに対する固定割当を設定する（`dhcp scope bind` コマンド）

以降の手順では Raspberry Pi の固定IPを `192.168.1.100` として記載します。環境に合わせて読み替えてください。

### 2.2 RTX830への接続

Web GUI または Telnet/SSH で RTX830 に接続します。

```bash
# SSH で接続する例
ssh admin@192.168.1.1
```

### 2.3 SNMP設定の投入

#### 基本設定（SNMPv2c）

```
# 管理者モードに入る
administrator

# SNMPv2c コミュニティ文字列を設定（read-only）
# ⚠️ 本リポジトリ同梱の snmp/snmp.yml は community: public がデフォルトなので、
#    ここを変更する場合は snmp/snmp.yml の community も同じ値に揃えてください。
snmpv2c community read-only public

# アクセスを許可するホスト（Raspberry Pi の固定IP）
snmpv2c host 192.168.1.100

# システム情報（オプション: Grafana でホスト名等を表示したい場合）
snmp sysname "RTX830"
snmp syscontact "admin@example.com"
snmp syslocation "Home/Office"

# 設定の保存
save
```

**セキュリティTips:**
- `public` はデフォルトのコミュニティ文字列で推測されやすいため、本番では推測困難な文字列への変更を推奨します
- その場合は `snmp/snmp.yml` 側の `community:` も同じ値に書き換え、`docker-compose restart snmp-exporter` で反映させてください
- より強固にしたい場合は後述の SNMPv3 を検討してください

#### より安全なSNMPv3設定（推奨）

```
# SNMPv3ユーザーの作成
snmpv3 usm user 1 monitoruser sha MyAuthPass123 aes MyPrivPass123

# アクセスを許可するホスト
snmpv3 host 192.168.1.100

# 設定の保存
save
```

SNMPv3 を使う場合は `snmp/snmp.yml` の `auths:` 節に SNMPv3 用の認証情報を追加し、`prometheus/prometheus.yml` の `params.auth` をそれを参照するよう切り替える必要があります。詳しくは [rtx830-config.md](rtx830-config.md) を参照してください。

### 2.4 フィルタ（パケットフィルタ）の確認

RTX830 側で `ip lan1 filter in` などに厳しめのフィルタが設定されている場合、SNMP (UDP/161) が塞がれていることがあります。その場合は監視元からの SNMP を明示的に許可してください。

```
# 既存のフィルタ番号と被らない番号を選ぶ
ip filter 2000 pass 192.168.1.100 192.168.1.1 udp * 161

# LAN側インターフェースの in フィルタ列に 2000 を追加
#（既存の filter in 列がある場合は、その先頭に追加する）
ip lan1 filter in 2000

save
```

フィルタを弄らずにそのまま SNMP が取れるならこのステップはスキップして構いません。

### 2.5 設定の確認（RTX830 側）

```
show config | grep -i snmp
```

以下のような出力が表示されればOK：
```
snmpv2c community read-only public
snmpv2c host 192.168.1.100
snmp sysname "RTX830"
snmp syscontact "admin@example.com"
snmp syslocation "Home/Office"
```

### 2.6 監視ホストから疎通確認

Raspberry Pi 側から実際に SNMP クエリが通るかを確認しておくと、後段のコンテナ起動後の切り分けが楽になります。

```bash
# snmp-utils のインストール（未インストールの場合）
sudo apt-get install -y snmp

# システム情報を問い合わせ
snmpwalk -v2c -c public 192.168.1.1 system
```

以下のような応答が返ってくれば RTX830 側の設定は OK です。

```
SNMPv2-MIB::sysDescr.0 = STRING: RTX830 Rev.15.02.xx (...)
SNMPv2-MIB::sysUpTime.0 = Timeticks: (...)
SNMPv2-MIB::sysName.0 = STRING: RTX830
...
```

タイムアウトする場合は次を順に確認してください:

| 症状 | 確認するもの |
|---|---|
| `Timeout: No Response` | `snmpv2c host` に Raspberry Pi の固定IPが入っているか |
| `Timeout: No Response` | フィルタで UDP/161 が塞がれていないか（2.4 参照） |
| `Unknown host` | RTX830 へ `ping` が通るか、IP が正しいか |
| community mismatch | `snmp.yml` と RTX830 の community が同一か |

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

# Prometheus設定
PROMETHEUS_PORT=9090

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
# Creating prometheus ... done
```

### 4.2 コンテナの状態確認

```bash
# コンテナの起動状態を確認
docker-compose ps

# 期待される出力:
# NAME    STATE    PORTS
# prometheus   running  (host network mode)
```

### 4.3 ログの確認

```bash
# Prometheusのログをリアルタイム表示
docker-compose logs -f prometheus

# 正常な場合の出力例:
# prometheus | level=info msg="Server is ready to receive web requests."
# prometheus | level=info msg="Starting TSDB"
# prometheus | level=info msg="remote storage has been configured for remote_write"
```

エラーがないか確認してください。

**Ctrl + C** でログ表示を終了できます。

### 4.4 Prometheus UI での確認

Webブラウザで以下にアクセス：

```
http://<Raspberry_PiのIPアドレス>:9090
```

Prometheus の管理画面で以下が確認できます：
- **Status → Targets**: SNMP Exporterへのスクレイプ状態
- **Graph**: PromQLクエリのテスト
- **Status → Runtime & Build Information**: 設定の確認

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
docker-compose logs prometheus

# Prometheus UIのTargetsページで確認
# http://<Raspberry_PiのIP>:9090/targets
```

### 問題: SNMPデータが取得できない

```bash
# RTX830への接続確認
ping -c 4 192.168.1.1

# SNMP接続確認
snmpwalk -v2c -c your_secret_community_string 192.168.1.1 system

# Prometheusログでエラー確認
docker-compose logs prometheus | grep -i error
```

### 問題: Grafana Cloudにデータが送信されない

```bash
# Remote Writeのエラーを確認
docker-compose logs prometheus | grep -i "remote_write"

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
# prometheus.yml を編集後
nano prometheus/prometheus.yml

# コンテナを再起動
docker-compose restart prometheus
```

### ログの確認

```bash
# 最新100行のログを表示
docker-compose logs --tail=100 prometheus

# リアルタイムでログを表示
docker-compose logs -f prometheus

# エラーのみをフィルター
docker-compose logs prometheus | grep -i error
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
- ✅ Prometheusコンテナが正常に動作している

### 次のステップ

1. ダッシュボードをカスタマイズして見やすくする
2. アラートルールを追加して異常を検知できるようにする
3. 他のデバイス（スイッチ、AP等）の監視を追加する

### サポート

問題や質問がある場合：
- GitHub Issues: https://github.com/yutamoty/rtx830-monitoring/issues
- ドキュメント: プロジェクトの `CLAUDE.md` と `README.md` を参照
