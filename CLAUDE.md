# YAMAHA RTX830 Monitoring System

## プロジェクト概要

このプロジェクトは、YAMAHA RTX830ルーターの包括的な監視システムを構築するためのものです。
Prometheus + SNMP Exporter + Grafana Cloud スタックを使用し、SNMP経由でRTX830から全ての監視可能なメトリクスを収集・可視化します。

### 設計目標

- **完全なコード管理**: すべての設定をGitで管理し、Infrastructure as Codeを実現
- **高い復旧性**: SDカード故障時でも、このリポジトリから迅速に環境を再構築可能
- **包括的な監視**: トラフィック、CPU、メモリ、セッション数、インターフェース状態など、取得可能な全ての情報を可視化
- **クラウド管理**: Grafana Cloudでデータを保存し、ローカルストレージの障害リスクを最小化

## アーキテクチャ

```
RTX830 (SNMP) ← [SNMP Exporter] ← Raspberry Pi (Prometheus) → Grafana Cloud
                                                                  ├── Metrics Storage
                                                                  └── Dashboard/Alerting
```

### なぜ Prometheus + Grafana Cloud なのか？

- **エコシステム**: Prometheusのコミュニティダッシュボードやツールがそのまま使える
- **デバッグしやすい**: Prometheus Web UI (localhost:9090) で PromQL のテストやターゲット状態確認が可能
- **復旧が簡単**: データはクラウドに保存されるため、ラズパイ故障時も履歴データは安全
- **コスト**: Grafana Cloud Free tier（10k series）で十分収まる
- **スケーラブル**: 将来的に他のデバイスを追加しても同じ構成で対応可能

## 環境構成

- **監視対象**: YAMAHA RTX830
- **監視プロトコル**: SNMPv2c/v3
- **実行環境**: Raspberry Pi (Raspberry Pi OS)
- **コンテナ**: Docker + Docker Compose
- **監視スタック**:
  - SNMP Exporter: RTX830からSNMPデータを取得
  - Prometheus: メトリクス収集 + Grafana Cloudへの Remote Write
  - Grafana Cloud: メトリクス保存・ダッシュボード・アラート
- **バージョン管理**: Git/GitHub

## ディレクトリ構造

```
rtx830-monitoring/
├── CLAUDE.md                    # このファイル（プロジェクトドキュメント）
├── README.md                    # プロジェクト説明
├── docker-compose.yml           # Docker Compose設定
├── .env.example                 # 環境変数のサンプル
├── prometheus/
│   ├── prometheus.yml          # Prometheus設定（スクレイプ + Remote Write）
│   └── entrypoint.sh           # 環境変数展開 + Prometheus起動スクリプト
├── scripts/
│   ├── setup.sh               # 初回セットアップスクリプト
│   ├── backup.sh              # 設定バックアップスクリプト
│   └── restore.sh             # リストアスクリプト
└── docs/
    ├── setup-guide.md         # セットアップガイド
    ├── rtx830-config.md       # RTX830側の設定手順
    ├── grafana-cloud.md       # Grafana Cloud設定手順
    └── recovery.md            # 復旧手順書
```

## RTX830で取得可能なメトリクス

### 基本情報
- システムアップタイム
- ファームウェアバージョン
- システム名、設置場所

### CPU/メモリ
- CPU使用率（hrProcessorLoad）
- メモリ使用量
- メモリ空き容量

### インターフェース
- LAN/WANポート毎の情報
  - トラフィック（送受信バイト/パケット数）- 64bit対応
  - エラー/廃棄パケット数
  - リンク状態（Up/Down）
  - 速度/Duplex設定
  - インターフェース名とエイリアス

### プロトコル統計
- IP統計（受信/送信パケット数）
- TCP統計（接続数、アクティブ/パッシブオープン）
- UDP統計（受信/送信データグラム数）
- ICMP統計（受信/送信メッセージ数）

### ストレージ
- ストレージ使用量
- ストレージタイプと容量

### 制限事項
- **NATセッション数**: SNMP非対応（Lua連携が必要）

## セットアップの流れ

### 1. Grafana Cloud の準備
- Grafana Cloud アカウント作成（Free tier）
- APIキーの発行
- Remote Write エンドポイントURLの取得

### 2. RTX830側の準備
- SNMP設定の有効化
- Community String / SNMPv3ユーザーの設定
- アクセス制御の設定

### 3. Raspberry Pi側の準備
- Docker / Docker Composeのインストール
- このリポジトリのクローン
- 環境変数の設定（`.env`ファイル作成）

### 4. 監視スタックのデプロイ
- `docker-compose up -d`でコンテナ起動
- Grafana Cloudでメトリクス受信確認

### 5. ダッシュボード作成
- Grafana Cloudでダッシュボード作成
- 汎用SNMPダッシュボード（ID: 12366）をベースに調整

## 復旧手順

SDカード故障やシステム障害時の復旧手順：

### 前提条件
- 新しいRaspberry Pi OS環境
- インターネット接続
- GitHubへのアクセス権
- Grafana Cloud アカウントとAPIキー

### 復旧ステップ
1. 基本パッケージのインストール（Git, Docker, Docker Compose）
2. リポジトリのクローン: `git clone https://github.com/yutamoty/rtx830-monitoring.git`
3. 環境変数の設定（`.env`ファイルを作成）
   - Grafana Cloud APIキーとエンドポイントを設定
   - RTX830のIPアドレスとSNMP設定
4. コンテナ起動: `docker-compose up -d`
5. Grafana Cloudでメトリクス受信確認

**目標復旧時間**: 15分以内（基本OS環境が整っている前提）
**データ**: Grafana Cloudに保存されているため、履歴データは失われない

## 環境変数

以下の環境変数が必要です（`.env`ファイルで管理）：

```bash
# RTX830 SNMP設定
RTX830_HOST=192.168.1.1
SNMP_COMMUNITY=public
SNMP_VERSION=2c

# Grafana Cloud設定
GRAFANA_CLOUD_PROMETHEUS_URL=https://prometheus-xxx.grafana.net/api/prom/push
GRAFANA_CLOUD_PROMETHEUS_USER=123456
GRAFANA_CLOUD_API_KEY=glc_xxxxxxxxxxxxxxxxxxxxx

# Prometheus設定（Web UI: http://<IP>:9090）
PROMETHEUS_PORT=9090
```

## セキュリティ考慮事項

- `.env`ファイルは`.gitignore`に含め、Gitにコミットしない
- SNMP Community Stringは強力なものを使用
- 可能であればSNMPv3の使用を推奨
- Grafana Cloud APIキーは厳重に管理
- Raspberry PiのファイアウォールでPrometheus Web UIポート(9090)へのアクセスを制限

## メンテナンス

### バックアップ
- Prometheus設定: Git管理されているため自動的にバックアップ
- メトリクスデータ: Grafana Cloudに保存（手動バックアップ不要）
- ダッシュボード: Grafana CloudからJSON exportで定期バックアップ推奨

### アップデート
- Dockerイメージ: `docker-compose pull && docker-compose up -d`
- 設定変更: `prometheus/prometheus.yml`編集後に`docker-compose restart prometheus`

## トラブルシューティング

### SNMPデータが取得できない
- RTX830側のSNMP設定を確認
- ネットワーク接続を確認（pingテスト）
- Prometheus Web UI (localhost:9090) の Targets ページでスクレイプ状態を確認
- ログを確認: `docker-compose logs prometheus`

### Grafana Cloudにメトリクスが届かない
- APIキーとエンドポイントURLを確認
- Prometheusのログでremote_writeエラーを確認: `docker-compose logs prometheus`
- Prometheus Web UI の Status → Runtime & Build Information で設定を確認
- Grafana CloudのData Sourcesページで接続状態を確認

### コンテナが起動しない
- ポートの競合を確認
- 設定ファイルの構文エラーを確認
- ログを確認: `docker-compose logs`

## Grafana Cloudのコスト管理

### Free Tierの制限
- メトリクスシリーズ: 10,000 series
- ログ: 50GB/月
- トレース: 50GB/月

### RTX830監視での推定使用量
- システムメトリクス: ~20 series
- インターフェースメトリクス: ~200 series（インターフェース数×メトリクス数）
- プロトコル統計: ~50 series
- **合計**: 約300 series程度（Free tierの3%）

## Claude Codeでの開発

このプロジェクトはClaude Codeを使用して開発・メンテナンスされています。

### よくあるタスク

- **新しいメトリクスの追加**: `prometheus/prometheus.yml`を更新
- **スクレイプ間隔の変更**: `prometheus/prometheus.yml`のscrape_intervalを調整
- **ダッシュボードの追加**: Grafana CloudでJSON exportしてリポジトリに追加

### Claude Codeへの依頼例

```
「RTX830のインターフェーストラフィックを5秒間隔で収集するように変更してください」
「SNMP ExporterにSNMPv3認証を追加してください」
「新しいスクレイプジョブをPrometheus設定に追加してください」
```

## 参考リンク

- [YAMAHA RTX830 コマンドリファレンス](http://www.rtpro.yamaha.co.jp/RT/manual/rt-common/index.html)
- [Prometheus Documentation](https://prometheus.io/docs/)
- [SNMP Exporter](https://github.com/prometheus/snmp_exporter)
- [Grafana Cloud Documentation](https://grafana.com/docs/grafana-cloud/)
- [SNMP MIBs Reference](https://www.cisco.com/c/en/us/support/docs/ip/simple-network-management-protocol-snmp/7244-snmp-mibs.html)

## ライセンス

MIT License

## 連絡先・サポート

問題や質問がある場合は、GitHubのIssuesを使用してください。
