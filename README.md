# RTX830 Monitoring with Grafana Cloud

YAMAHA RTX830ルーターを**Prometheus + SNMP Exporter + Grafana Cloud**で監視するシステムです。

## 特徴

- **シンプル**: 2コンテナ（SNMP Exporter + Prometheus）で動作
- **クラウド管理**: データはGrafana Cloudに保存、ローカルストレージ不要
- **高い復旧性**: SDカード故障時も15分で復旧可能
- **包括的監視**: インターフェーストラフィック、システム情報など可視化
- **低コスト**: Grafana Cloud Free tier（10k series）で十分収まる
- **デバッグ容易**: Prometheus Web UI (localhost:9090) でPromQLテストやターゲット状態確認が可能

## アーキテクチャ

```
RTX830 (SNMP) → SNMP Exporter → Prometheus → Grafana Cloud
                                                ├── Metrics Storage
                                                └── Dashboard/Alerting
```

## クイックスタート

### 前提条件

- Raspberry Pi (Raspberry Pi OS)
- Docker & Docker Compose
- Grafana Cloudアカウント（Free tier）

### 1. リポジトリのクローン

```bash
git clone https://github.com/yutamoty/rtx830-monitoring.git
cd rtx830-monitoring
```

### 2. 環境変数の設定

```bash
cp .env.example .env
nano .env
```

以下を設定してください：

```bash
# RTX830のIPアドレス
RTX830_HOST=192.168.1.1

# Grafana Cloud設定（Grafana Cloudから取得）
GRAFANA_CLOUD_PROMETHEUS_URL=https://prometheus-prod-xx-xxx-xxx.grafana.net/api/prom/push
GRAFANA_CLOUD_PROMETHEUS_USER=123456
GRAFANA_CLOUD_API_KEY=glc_xxxxxxxxxxxxx
```

### 3. RTX830のSNMP設定

RTX830で以下を設定してください：

```bash
# 管理者モードに入る
administrator

# SNMPv2c設定
snmpv2c community read-only public
snmpv2c host <Raspberry_PiのIPアドレス>

# 設定を保存
save
```

### 4. コンテナの起動

```bash
docker-compose up -d
```

### 5. 動作確認

#### Prometheus UIで確認
```
http://<Raspberry_PiのIP>:9090
```

- **Targets** ページでSNMP Exporterへのスクレイプが成功しているか確認
- **Graph** ページでPromQLクエリをテスト

#### Grafana Cloudで確認
1. Grafana Cloudにログイン
2. Explore → Prometheusを選択
3. メトリクス（例: `ifHCInOctets`）を検索して表示されることを確認

## 監視項目

### システム情報
- システムアップタイム
- システム名・設置場所
- ファームウェア情報

### リソース
- CPU使用率
- メモリ使用量・空き容量

### インターフェース（各ポート毎）
- トラフィック（送受信バイト数）- 64bit対応
- パケット数（ユニキャスト/非ユニキャスト）
- エラー・廃棄パケット数
- リンク状態（Up/Down）
- 速度・Duplex設定

### プロトコル統計
- IP統計（受信/送信パケット数）
- TCP統計（接続数、セグメント数）
- UDP統計（データグラム数）
- ICMP統計（メッセージ数）

### ストレージ
- ストレージ使用量・空き容量

## トラブルシューティング

### SNMPデータが取得できない

```bash
# ログを確認
docker-compose logs prometheus

# Prometheus UIのTargetsページで状態確認
# http://<Raspberry_PiのIP>:9090/targets

# RTX830への接続確認
ping <RTX830のIP>

# SNMP接続テスト（snmptoolsがインストールされている場合）
snmpwalk -v2c -c <community> <RTX830のIP> system
```

### Grafana Cloudにデータが送信されない

```bash
# Prometheusのログでremote_writeエラーを確認
docker-compose logs prometheus | grep -i error

# .envファイルの設定を確認
cat .env
```

### コンテナが起動しない

```bash
# コンテナの状態を確認
docker-compose ps

# 詳細ログを確認
docker-compose logs
```

## 詳細ドキュメント

より詳しい手順や設定方法は、以下のドキュメントを参照してください：

- **[完全セットアップガイド](docs/setup-guide.md)** - ゼロから構築する詳細手順（所要時間: 50分）
- **[RTX830設定ガイド](docs/rtx830-config.md)** - SNMP設定の詳細
- **[Grafana Cloud設定ガイド](docs/grafana-cloud.md)** - クラウド側の詳細設定
- **[復旧手順書](docs/recovery.md)** - 障害時の復旧手順（復旧時間: 15分）

## ファイル構成

```
rtx830-monitoring/
├── CLAUDE.md              # プロジェクト詳細ドキュメント
├── README.md              # このファイル
├── docker-compose.yml     # Docker Compose設定
├── .env.example           # 環境変数サンプル
├── .env                   # 環境変数（要作成、Git管理外）
├── prometheus/
│   ├── prometheus.yml     # Prometheus設定（scrape + Remote Write）
│   └── entrypoint.sh      # 環境変数展開 + 起動スクリプト
└── docs/
    ├── setup-guide.md     # 完全セットアップガイド
    ├── rtx830-config.md   # RTX830設定詳細
    ├── grafana-cloud.md   # Grafana Cloud設定詳細
    └── recovery.md        # 復旧手順書
```

## 復旧手順

SDカード故障時の復旧：

1. 新しいRaspberry Pi OS環境を準備
2. Docker & Docker Composeをインストール
3. リポジトリをクローン: `git clone https://github.com/yutamoty/rtx830-monitoring.git`
4. `.env`ファイルを作成（Grafana Cloud設定を入力）
5. コンテナを起動: `docker-compose up -d`

**復旧時間**: 約15分（データは失われません）

## ダッシュボード作成

Grafana Cloudでダッシュボードを作成する際の参考：

- [Generic SNMP Dashboard (ID: 12366)](https://grafana.com/grafana/dashboards/12366)をベースに使用
- RTX830特有のメトリクス用にパネルを追加・カスタマイズ

## コスト

**Grafana Cloud Free tier**: 10,000 series まで無料
**RTX830の推定使用量**: 約300 series（Free tierの3%）

## ライセンス

MIT License

## サポート

問題や質問は[GitHub Issues](https://github.com/yutamoty/rtx830-monitoring/issues)で報告してください。

## 参考リンク

- [YAMAHA RTX830 コマンドリファレンス](http://www.rtpro.yamaha.co.jp/RT/manual/rt-common/index.html)
- [Prometheus Documentation](https://prometheus.io/docs/)
- [SNMP Exporter](https://github.com/prometheus/snmp_exporter)
- [Grafana Cloud](https://grafana.com/products/cloud/)
