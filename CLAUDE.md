# YAMAHA RTX830 Monitoring System

## プロジェクト概要

このプロジェクトは、YAMAHA RTX830ルーターの包括的な監視システムを構築するためのものです。
Prometheus + Grafana スタックを使用し、SNMP経由でRTX830から全ての監視可能なメトリクスを収集・可視化します。

### 設計目標

- **完全なコード管理**: すべての設定をGitで管理し、Infrastructure as Codeを実現
- **高い復旧性**: SDカード故障時でも、このリポジトリから迅速に環境を再構築可能
- **包括的な監視**: トラフィック、CPU、メモリ、セッション数、インターフェース状態など、取得可能な全ての情報を可視化

## アーキテクチャ

```
RTX830 (SNMP) ← [監視] ← Raspberry Pi
                          ├── SNMP Exporter (Prometheus exporter)
                          ├── Prometheus (メトリクス収集・保存)
                          └── Grafana (可視化)
```

## 環境構成

- **監視対象**: YAMAHA RTX830
- **監視プロトコル**: SNMPv2c/v3
- **実行環境**: Raspberry Pi (Raspberry Pi OS)
- **コンテナ**: Docker + Docker Compose
- **監視スタック**:
  - Prometheus: メトリクス収集・保存
  - SNMP Exporter: SNMP → Prometheusメトリクス変換
  - Grafana: ダッシュボード・可視化
- **バージョン管理**: Git/GitHub

## ディレクトリ構造

```
rtx830-monitoring/
├── CLAUDE.md                    # このファイル（プロジェクトドキュメント）
├── README.md                    # プロジェクト説明
├── docker-compose.yml           # Docker Compose設定
├── .env.example                 # 環境変数のサンプル
├── prometheus/
│   ├── prometheus.yml          # Prometheus設定
│   └── rules/                  # アラートルール
├── snmp-exporter/
│   ├── snmp.yml               # SNMP Exporter設定（RTX830用）
│   └── generator/             # snmp.yml生成用設定
├── grafana/
│   ├── provisioning/
│   │   ├── datasources/       # データソース自動設定
│   │   └── dashboards/        # ダッシュボード自動設定
│   └── dashboards/
│       └── rtx830.json        # RTX830監視ダッシュボード
├── scripts/
│   ├── setup.sh               # 初回セットアップスクリプト
│   ├── backup.sh              # バックアップスクリプト
│   └── restore.sh             # リストアスクリプト
└── docs/
    ├── setup-guide.md         # セットアップガイド
    ├── rtx830-config.md       # RTX830側の設定手順
    └── recovery.md            # 復旧手順書
```

## RTX830で取得可能なメトリクス

### 基本情報
- システムアップタイム
- ファームウェアバージョン
- シリアル番号

### CPU/メモリ
- CPU使用率
- メモリ使用量
- メモリ空き容量

### インターフェース
- LAN/WANポート毎の情報
  - トラフィック（送受信バイト/パケット数）
  - エラー/廃棄パケット数
  - リンク状態（Up/Down）
  - 速度/Duplex設定

### セッション/接続
- セッション数（現在/最大）
- NAT/NAPTセッション情報
- VPNトンネル状態

### PPP/WAN接続
- PPP接続状態
- 接続時間
- 送受信データ量

### 温度・ハードウェア
- 筐体温度
- ファン状態（該当する場合）

## セットアップの流れ

### 1. RTX830側の準備
- SNMP設定の有効化
- Community String / SNMPv3ユーザーの設定
- アクセス制御の設定

### 2. Raspberry Pi側の準備
- Docker / Docker Composeのインストール
- このリポジトリのクローン
- 環境変数の設定（`.env`ファイル作成）

### 3. 監視スタックのデプロイ
- `docker-compose up -d`でコンテナ起動
- Grafanaへアクセスしてダッシュボード確認

### 4. 動作確認
- Prometheusでメトリクス取得確認
- Grafanaでグラフ表示確認

## 復旧手順

SDカード故障やシステム障害時の復旧手順：

### 前提条件
- 新しいRaspberry Pi OS環境
- インターネット接続
- GitHubへのアクセス権

### 復旧ステップ
1. 基本パッケージのインストール（Git, Docker, Docker Compose）
2. リポジトリのクローン: `git clone https://github.com/yutamoty/rtx830-monitoring.git`
3. 環境変数の設定（`.env`ファイルを作成）
4. セットアップスクリプト実行: `./scripts/setup.sh`
5. コンテナ起動: `docker-compose up -d`

**目標復旧時間**: 30分以内（基本OS環境が整っている前提）

## 環境変数

以下の環境変数が必要です（`.env`ファイルで管理）：

```bash
# RTX830 SNMP設定
RTX830_HOST=192.168.1.1
SNMP_COMMUNITY=public
SNMP_VERSION=2c

# Grafana設定
GRAFANA_ADMIN_PASSWORD=<strong-password>
GRAFANA_PORT=3000

# Prometheus設定
PROMETHEUS_PORT=9090
PROMETHEUS_RETENTION=15d

# SNMP Exporter設定
SNMP_EXPORTER_PORT=9116
```

## セキュリティ考慮事項

- `.env`ファイルは`.gitignore`に含め、Gitにコミットしない
- SNMP Community Stringは強力なものを使用
- 可能であればSNMPv3の使用を推奨
- Grafana管理者パスワードは強力なものを設定
- Raspberry PiのファイアウォールでPrometheus/Grafanaへのアクセスを制限

## メンテナンス

### バックアップ
- Prometheusデータ: `./scripts/backup.sh prometheus`
- Grafanaダッシュボード: Git管理されているため自動的にバックアップ
- 設定ファイル: すべてGit管理

### アップデート
- Dockerイメージ: `docker-compose pull && docker-compose up -d`
- 設定変更: ファイル編集後に`docker-compose restart <service>`

## トラブルシューティング

### SNMPデータが取得できない
- RTX830側のSNMP設定を確認
- ネットワーク接続を確認（pingテスト）
- SNMP Exporterのログを確認: `docker-compose logs snmp-exporter`

### Grafanaにアクセスできない
- コンテナの起動状態を確認: `docker-compose ps`
- ポートの競合を確認
- ファイアウォール設定を確認

### ディスク容量不足
- Prometheusの保持期間を調整（`PROMETHEUS_RETENTION`）
- 古いデータの削除を検討

## Claude Codeでの開発

このプロジェクトはClaude Codeを使用して開発・メンテナンスされています。

### よくあるタスク

- **新しいメトリクスの追加**: `snmp-exporter/snmp.yml`を更新
- **ダッシュボードの改善**: `grafana/dashboards/rtx830.json`を編集
- **アラートルールの追加**: `prometheus/rules/`に新しいファイルを追加
- **セットアップの自動化**: `scripts/`ディレクトリのスクリプトを改善

### Claude Codeへの依頼例

```
「RTX830のVPNトンネル状態を監視するアラートを追加してください」
「CPU使用率が80%を超えた時の通知を設定してください」
「ダッシュボードに新しいパネルを追加してください」
```

## 参考リンク

- [YAMAHA RTX830 コマンドリファレンス](http://www.rtpro.yamaha.co.jp/RT/manual/rt-common/index.html)
- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)
- [SNMP Exporter Documentation](https://github.com/prometheus/snmp_exporter)

## ライセンス

MIT License

## 連絡先・サポート

問題や質問がある場合は、GitHubのIssuesを使用してください。
