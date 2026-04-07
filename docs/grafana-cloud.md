# Grafana Cloud セットアップガイド

Grafana Cloudの初期設定からダッシュボード作成までの手順を説明します。

## Grafana Cloudとは

- Grafanaの公式クラウドサービス
- メトリクス、ログ、トレースを一元管理
- Free tier: 10,000 series、50GB logs/月で無料
- RTX830監視では約300 series使用（Free tierの3%）

---

## ステップ1: アカウント作成

### 1.1 サインアップ

1. https://grafana.com にアクセス
2. 右上の **"Sign up"** をクリック
3. 登録方法を選択：
   - メールアドレス
   - GitHub アカウント
   - Google アカウント
   - Microsoft アカウント

### 1.2 アカウント情報の入力

メールアドレスで登録する場合：
1. Email、Password を入力
2. 利用規約に同意
3. **"Create account"** をクリック
4. 確認メールが届くので、リンクをクリックして認証

---

## ステップ2: スタックの作成

### 2.1 スタック作成

1. ログイン後、**"Launch a free stack"** をクリック
2. スタック設定を入力：

   **Stack name**: `rtx830-monitoring`（任意の名前）
   
   **Stack URL**: `rtx830-monitoring`（自動生成、変更可能）
   
   **Region**: 地域を選択
   - `ap-northeast-1` (東京) - 推奨
   - `ap-southeast-1` (シンガポール)
   - `us-east-1` (バージニア)

3. **"Create stack"** をクリック

### 2.2 スタック情報の確認

作成されたスタックの情報をメモ：
```
Stack URL: https://rtx830-monitoring.grafana.net
Username: <your-email>
```

---

## ステップ3: Prometheus設定情報の取得

### 3.1 Hosted Prometheus Metricsの設定

1. 左サイドバー → **"Connections"**
2. **"Add new connection"** をクリック
3. 検索ボックスに `prometheus` と入力
4. **"Hosted Prometheus metrics"** を選択
5. 表示される情報をコピー：

```
Remote Write Endpoint:
https://prometheus-prod-XX-XXXX.grafana.net/api/prom/push

Username / Instance ID:
123456
```

この情報を `.env` ファイルで使用します：
```bash
GRAFANA_CLOUD_PROMETHEUS_URL=https://prometheus-prod-XX-XXXX.grafana.net/api/prom/push
GRAFANA_CLOUD_PROMETHEUS_USER=123456
```

---

## ステップ4: APIキーの生成

### 4.1 APIキーの作成

1. 左サイドバー → **"Security"** → **"API Keys"**
2. **"Create API key"** をクリック
3. APIキー設定：

   **Key name**: `rtx830-alloy`
   
   **Role**: `MetricsPublisher`（または `Admin`）
   
   **Time to live**: `No expiration`（無期限）

4. **"Add"** をクリック
5. 表示されるAPIキーをコピー：
   ```
   glc_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
   ```

⚠️ **重要**: このキーは一度しか表示されません。必ず保存してください。

### 4.2 .envファイルへの追加

```bash
GRAFANA_CLOUD_API_KEY=glc_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

---

## ステップ5: データソースの確認

### 5.1 Prometheusデータソースの確認

1. 左サイドバー → **"Connections"** → **"Data sources"**
2. **"Prometheus"** が存在することを確認
3. クリックして詳細を表示：
   - **URL**: `https://prometheus-prod-XX-XXXX.grafana.net/api/prom`
   - **Access**: `Server (default)`
   - **Status**: 緑のチェックマーク

### 5.2 データソーステスト

1. データソース詳細画面の下部
2. **"Save & test"** をクリック
3. 緑のチェックマークと "Data source is working" が表示されればOK

---

## ステップ6: メトリクスの確認

Raspberry Piでコンテナを起動後、Grafana Cloudでメトリクスを確認します。

### 6.1 Exploreでの確認

1. 左サイドバー → **"Explore"**
2. データソースで **"Prometheus"** を選択
3. **"Metrics browser"** をクリック
4. `ifHCInOctets` を検索
5. **"Run query"** をクリック

**成功の確認**:
- RTX830のインターフェース毎にメトリクスが表示
- ラベルに `device="rtx830"` が含まれる

### 6.2 利用可能なメトリクス

主要なメトリクス：
```
# インターフェーストラフィック
ifHCInOctets{device="rtx830", ifDescr="LAN1"}
ifHCOutOctets{device="rtx830", ifDescr="LAN1"}

# CPU使用率
hrProcessorLoad{device="rtx830"}

# メモリ使用量
hrStorageUsed{device="rtx830"}
hrStorageSize{device="rtx830"}

# TCP接続数
tcpCurrEstab{device="rtx830"}
```

---

## ステップ7: ダッシュボードの作成

### 7.1 汎用SNMPダッシュボードのインポート

1. 左サイドバー → **"Dashboards"**
2. **"New"** → **"Import"**
3. **Dashboard ID**: `12366` を入力
4. **"Load"** をクリック
5. 設定：
   - **Name**: `Generic SNMP`
   - **Prometheus**: 使用するPrometheusデータソースを選択
6. **"Import"** をクリック

### 7.2 RTX830専用ダッシュボードの作成

#### 新規ダッシュボード作成

1. **"Dashboards"** → **"New"** → **"New Dashboard"**
2. **"Add visualization"** をクリック

#### インターフェーストラフィックパネル

**パネル1: インターフェーストラフィック（bps）**

1. **Query**:
   ```promql
   # 受信トラフィック
   rate(ifHCInOctets{device="rtx830"}[5m]) * 8
   
   # 送信トラフィック
   rate(ifHCOutOctets{device="rtx830"}[5m]) * 8
   ```

2. **Transform**: なし

3. **パネル設定**:
   - **Title**: `Interface Traffic`
   - **Panel type**: `Time series`
   - **Unit**: `bits/sec` (Data rate → bits/sec)
   - **Legend**: `{{ifDescr}} {{__name__}}`
   - **Graph style**: `Lines`

4. **"Apply"** をクリック

#### CPU使用率パネル

**パネル2: CPU使用率**

1. **Query**:
   ```promql
   hrProcessorLoad{device="rtx830"}
   ```

2. **パネル設定**:
   - **Title**: `CPU Usage`
   - **Panel type**: `Gauge`
   - **Unit**: `Percent (0-100)`
   - **Thresholds**:
     - Green: 0-70
     - Yellow: 70-85
     - Red: 85-100

3. **"Apply"** をクリック

#### メモリ使用率パネル

**パネル3: メモリ使用率**

1. **Query**:
   ```promql
   (hrStorageUsed{device="rtx830", hrStorageDescr=~".*Memory.*"} / hrStorageSize{device="rtx830", hrStorageDescr=~".*Memory.*"}) * 100
   ```

2. **パネル設定**:
   - **Title**: `Memory Usage`
   - **Panel type**: `Gauge`
   - **Unit**: `Percent (0-100)`
   - **Thresholds**:
     - Green: 0-70
     - Yellow: 70-85
     - Red: 85-100

3. **"Apply"** をクリック

#### TCP接続数パネル

**パネル4: TCP接続数**

1. **Query**:
   ```promql
   tcpCurrEstab{device="rtx830"}
   ```

2. **パネル設定**:
   - **Title**: `TCP Connections`
   - **Panel type**: `Stat`
   - **Unit**: `none`
   - **Graph mode**: `Area`

3. **"Apply"** をクリック

#### システムアップタイムパネル

**パネル5: システムアップタイム**

1. **Query**:
   ```promql
   sysUpTime{device="rtx830"} / 100
   ```

2. **パネル設定**:
   - **Title**: `System Uptime`
   - **Panel type**: `Stat`
   - **Unit**: `Seconds (s)`
   - **Display**: `From now`

3. **"Apply"** をクリック

### 7.3 ダッシュボードの保存

1. 右上の **"Save dashboard"** アイコンをクリック
2. 名前を入力: `RTX830 Monitoring`
3. フォルダを選択（オプション）
4. **"Save"** をクリック

### 7.4 ダッシュボード変数の追加（高度）

複数のデバイスを監視する場合、変数を使用すると便利です。

1. ダッシュボード右上の **"Settings"** → **"Variables"**
2. **"Add variable"** をクリック
3. 設定：
   - **Name**: `device`
   - **Type**: `Query`
   - **Query**: `label_values(ifHCInOctets, device)`
4. **"Apply"** → **"Save dashboard"**

パネルのクエリを変更：
```promql
rate(ifHCInOctets{device="$device"}[5m]) * 8
```

---

## ステップ8: アラートの設定

### 8.1 アラートルールの作成

1. 左サイドバー → **"Alerting"** → **"Alert rules"**
2. **"Create alert rule"** をクリック

#### CPU使用率アラート

**ルール設定**:
- **Rule name**: `RTX830 High CPU Usage`
- **Query A**:
  ```promql
  hrProcessorLoad{device="rtx830"}
  ```
- **Condition**: `WHEN last() OF query(A) IS ABOVE 80`
- **For**: `5m`
- **Annotations**:
  - **Summary**: `RTX830 CPU usage is above 80%`
  - **Description**: `Current CPU usage: {{ $values.A }}%`

**"Save and exit"** をクリック

#### インターフェースダウンアラート

**ルール設定**:
- **Rule name**: `RTX830 Interface Down`
- **Query A**:
  ```promql
  ifOperStatus{device="rtx830"}
  ```
- **Condition**: `WHEN last() OF query(A) IS BELOW 1`
- **For**: `1m`
- **Annotations**:
  - **Summary**: `RTX830 interface {{$labels.ifDescr}} is down`

### 8.2 通知チャネルの設定

#### Email通知

1. **"Contact points"** → **"New contact point"**
2. 設定：
   - **Name**: `Email Notifications`
   - **Integration**: `Email`
   - **Addresses**: `your-email@example.com`
3. **"Save contact point"** をクリック

#### Slack通知（オプション）

1. **"New contact point"**
2. 設定：
   - **Name**: `Slack Notifications`
   - **Integration**: `Slack`
   - **Webhook URL**: Slack Incoming Webhook URL
3. **"Save contact point"** をクリック

### 8.3 通知ポリシーの設定

1. **"Notification policies"** → **"Edit"**
2. **Default contact point**: 作成した通知チャネルを選択
3. **"Save"** をクリック

---

## ステップ9: 使用量の確認

### 9.1 メトリクス使用量の確認

1. 左サイドバー → **"Administration"** → **"Cloud"** → **"Usage insights"**
2. **"Metrics"** タブを選択
3. 現在の使用量を確認：
   - **Active series**: RTX830で約300 series
   - **Limit**: 10,000 series (Free tier)

### 9.2 コスト管理

Free tierの制限：
- **Metrics**: 10,000 active series
- **Logs**: 50 GB/月
- **Traces**: 50 GB/月
- **Data retention**: 14 days

RTX830監視での推定使用量：
- システムメトリクス: ~20 series
- インターフェース: ~200 series
- プロトコル統計: ~50 series
- その他: ~30 series
- **合計**: 約300 series（制限の3%）

---

## トラブルシューティング

### 問題: メトリクスがGrafana Cloudに届かない

#### 確認1: Remote Write URL

```bash
# Raspberry Piで.envファイルを確認
cat .env | grep GRAFANA_CLOUD_PROMETHEUS_URL
```

#### 確認2: APIキー

```bash
# APIキーが正しいか確認
cat .env | grep GRAFANA_CLOUD_API_KEY
```

#### 確認3: Alloyログ

```bash
# Remote Writeエラーを確認
docker-compose logs alloy | grep -i "remote_write"
```

### 問題: ダッシュボードにデータが表示されない

1. **"Explore"** で直接クエリを実行してメトリクスが存在するか確認
2. 時間範囲を変更（Last 5 minutes → Last 1 hour）
3. クエリの構文エラーをチェック

### 問題: アラートが発火しない

1. **"Alerting"** → **"Alert rules"** でルールの状態を確認
2. **"State history"** でアラート履歴を確認
3. 通知チャネルが正しく設定されているか確認

---

## ベストプラクティス

### ダッシュボード管理

1. **バージョン管理**
   - 重要なダッシュボードはJSON exportしてGitで管理
   - 定期的にバックアップ

2. **組織化**
   - フォルダを使ってダッシュボードを整理
   - タグを活用

3. **共有**
   - 必要に応じてダッシュボードをPublicリンクで共有

### アラート管理

1. **適切な閾値設定**
   - 誤検知を避けるため、適切な閾値と待機時間を設定

2. **アラート疲れの防止**
   - 重要度に応じてアラートを分類
   - 通知頻度を調整

3. **定期的な見直し**
   - アラートルールを定期的に見直し、最適化

---

## 参考リンク

- [Grafana Cloud Documentation](https://grafana.com/docs/grafana-cloud/)
- [Prometheus Query Examples](https://prometheus.io/docs/prometheus/latest/querying/examples/)
- [Grafana Alerting](https://grafana.com/docs/grafana/latest/alerting/)
- [PromQL Cheat Sheet](https://promlabs.com/promql-cheat-sheet/)
