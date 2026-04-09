#!/bin/sh
# 環境変数をprometheus.ymlテンプレートに展開してPrometheusを起動する

TEMPLATE="/etc/prometheus/prometheus.yml"
CONFIG="/tmp/prometheus.yml"

# 必須環境変数のチェック
for var in GRAFANA_CLOUD_PROMETHEUS_URL GRAFANA_CLOUD_PROMETHEUS_USER GRAFANA_CLOUD_API_KEY RTX830_HOST; do
  eval val=\$$var
  if [ -z "$val" ]; then
    echo "ERROR: $var is not set"
    exit 1
  fi
done

# テンプレートから設定ファイルを生成（sed で環境変数を展開）
sed \
  -e "s|\${GRAFANA_CLOUD_PROMETHEUS_URL}|${GRAFANA_CLOUD_PROMETHEUS_URL}|g" \
  -e "s|\${GRAFANA_CLOUD_PROMETHEUS_USER}|${GRAFANA_CLOUD_PROMETHEUS_USER}|g" \
  -e "s|\${GRAFANA_CLOUD_API_KEY}|${GRAFANA_CLOUD_API_KEY}|g" \
  -e "s|\${RTX830_HOST}|${RTX830_HOST}|g" \
  "$TEMPLATE" > "$CONFIG"

echo "Prometheus config generated from template."

# Prometheus を起動
exec /bin/prometheus \
  --config.file="$CONFIG" \
  --storage.tsdb.path=/prometheus \
  --storage.tsdb.retention.time=2h \
  --web.console.libraries=/usr/share/prometheus/console_libraries \
  --web.console.templates=/usr/share/prometheus/consoles \
  --web.enable-lifecycle
