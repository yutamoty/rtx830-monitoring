# YAMAHA RTX830 SNMP設定ガイド

RTX830でSNMPを有効化し、外部から監視できるようにする設定手順です。

## 基本設定（SNMPv2c）

### Web GUI での設定

1. RTX830のWeb管理画面にログイン（通常 http://192.168.1.1）
2. **詳細設定** → **管理** → **SNMP** へ移動
3. 以下を設定：
   - **SNMPエージェント**: 有効
   - **Community名**: `your_secret_community_string`（推測困難な文字列に変更）
   - **アクセス権限**: `読み込みのみ`
   - **許可ホスト**: Raspberry PiのIPアドレス（例: `192.168.1.100`）
4. **設定の確定** をクリック

### コマンドライン（CLI）での設定

Telnet/SSHで接続後、以下のコマンドを実行：

```bash
# 管理者モードに入る
administrator

# SNMP Community String の設定
snmp community read-only your_secret_community_string

# アクセス許可するホストの指定
snmp host 192.168.1.100

# システム情報の設定（オプション）
snmp sysname "RTX830"
snmp syscontact "admin@example.com"
snmp syslocation "Home/Office"

# 設定の保存
save
```

### 設定の確認

```bash
show config | grep snmp
```

期待される出力：
```
snmp community read-only your_secret_community_string
snmp host 192.168.1.100
snmp sysname "RTX830"
snmp syscontact "admin@example.com"
snmp syslocation "Home/Office"
```

---

## 高度な設定（SNMPv3）

より安全な SNMPv3 を使用する場合の設定です。

### SNMPv3 ユーザーの作成

```bash
# 管理者モードに入る
administrator

# SNMPv3ユーザーの作成
# 形式: snmp user <ユーザー名> auth-protocol <認証プロトコル> auth-password <認証パスワード> priv-protocol <暗号化プロトコル> priv-password <暗号化パスワード>

snmp user monitoruser auth-protocol sha auth-password MyAuthPassword123 priv-protocol aes priv-password MyPrivPassword123

# アクセスグループの設定
snmp group monitorgroup user monitoruser security-level auth-priv

# アクセス許可
snmp host 192.168.1.100

# 設定の保存
save
```

### パラメータ説明

- **auth-protocol**: 認証プロトコル
  - `md5`: MD5（非推奨）
  - `sha`: SHA-1（推奨）
  
- **priv-protocol**: 暗号化プロトコル
  - `des`: DES（非推奨）
  - `aes`: AES（推奨）
  
- **security-level**:
  - `no-auth-no-priv`: 認証なし・暗号化なし（非推奨）
  - `auth-no-priv`: 認証あり・暗号化なし
  - `auth-priv`: 認証あり・暗号化あり（推奨）

### SNMP Exporter側の設定変更（SNMPv3使用時）

SNMP Exporterのカスタム設定ファイル（`snmp.yml`）を以下のように編集：

```yaml
rtx830:
  walk:
    # ... (既存の設定)
  
  version: 3  # v2 から v3 に変更
  auth:
    security_level: authPriv
    username: monitoruser
    auth_protocol: SHA
    auth_password: MyAuthPassword123
    priv_protocol: AES
    priv_password: MyPrivPassword123
```

---

## ファイアウォール設定

RTX830のフィルタ設定でSNMPアクセスを制限する場合：

```bash
# 管理者モードに入る
administrator

# SNMP（UDP 161）を許可するフィルタを作成
ip filter 100 pass 192.168.1.100 * udp * 161

# LANインターフェースにフィルタを適用
ip lan1 filter in 100

# 設定の保存
save
```

---

## 取得可能なMIB情報

RTX830で取得可能な主なSNMP情報：

### システム情報
- `sysDescr` (1.3.6.1.2.1.1.1.0): システム説明
- `sysUpTime` (1.3.6.1.2.1.1.3.0): 稼働時間
- `sysName` (1.3.6.1.2.1.1.5.0): システム名
- `sysLocation` (1.3.6.1.2.1.1.6.0): 設置場所

### インターフェース情報（IF-MIB）
- `ifDescr`: インターフェース名
- `ifOperStatus`: インターフェース状態
- `ifHCInOctets`: 受信バイト数（64bit）
- `ifHCOutOctets`: 送信バイト数（64bit）
- `ifInErrors`: 受信エラー数
- `ifOutErrors`: 送信エラー数

### ホストリソース（HOST-RESOURCES-MIB）
- `hrProcessorLoad`: CPU使用率
- `hrStorageSize`: ストレージサイズ
- `hrStorageUsed`: ストレージ使用量

### プロトコル統計
- `tcpCurrEstab`: TCP接続数
- `udpInDatagrams`: UDP受信数
- `icmpInMsgs`: ICMP受信数

---

## 動作確認

### snmpwalkコマンドでの確認

Raspberry Pi から以下のコマンドで確認：

```bash
# snmp-utilsのインストール（未インストールの場合）
sudo apt-get install snmp snmp-mibs-downloader

# システム情報の取得（SNMPv2c）
snmpwalk -v2c -c your_secret_community_string 192.168.1.1 system

# インターフェース情報の取得
snmpwalk -v2c -c your_secret_community_string 192.168.1.1 ifDescr

# CPU使用率の取得
snmpwalk -v2c -c your_secret_community_string 192.168.1.1 1.3.6.1.2.1.25.3.3.1.2
```

### SNMPv3での確認

```bash
snmpwalk -v3 -u monitoruser -l authPriv \
  -a SHA -A MyAuthPassword123 \
  -x AES -X MyPrivPassword123 \
  192.168.1.1 system
```

### 期待される出力例

```
SNMPv2-MIB::sysDescr.0 = STRING: YAMAHA RTX830 Rev.15.02.16 (Thu Dec 21 15:30:00 2023)
SNMPv2-MIB::sysUpTime.0 = Timeticks: (123456789) 14 days, 6:56:07.89
SNMPv2-MIB::sysName.0 = STRING: RTX830
SNMPv2-MIB::sysLocation.0 = STRING: Home/Office
```

---

## トラブルシューティング

### 問題: SNMPが応答しない

#### 確認1: SNMP設定が有効になっているか

```bash
show config | grep snmp
```

#### 確認2: ファイアウォールで遮断されていないか

```bash
show ip filter
```

#### 確認3: ネットワーク接続

```bash
# Raspberry Pi から RTX830 へ ping
ping 192.168.1.1
```

### 問題: "Timeout: No Response from..."

- Community String が正しいか確認
- RTX830の `snmp host` 設定に監視元IPアドレスが含まれているか確認
- ファイアウォールで UDP 161 番ポートが許可されているか確認

### 問題: 一部のMIBが取得できない

RTX830は標準的なMIB-II、IF-MIB、HOST-RESOURCES-MIBに対応していますが、一部のベンダー固有MIBには非対応です。

**非対応の例**:
- NATセッション数（YAMAHA独自MIB、Lua連携が必要）
- VPN詳細統計

---

## セキュリティのベストプラクティス

1. **強力なCommunity Stringを使用**
   - デフォルトの `public` は使用しない
   - 推測困難な文字列（20文字以上）を使用

2. **SNMPv3の使用**
   - 可能な限りSNMPv3を使用
   - 認証と暗号化を有効化（`auth-priv`）

3. **アクセス制限**
   - `snmp host` で監視元IPアドレスを明示的に指定
   - read-only（読み込み専用）を使用

4. **ファイアウォールの設定**
   - 必要なIPアドレスからのみSNMP（UDP 161）を許可

5. **定期的なパスワード変更**
   - SNMPv3のパスワードは定期的に変更

---

## 参考リンク

- [YAMAHA RTX830 コマンドリファレンス](http://www.rtpro.yamaha.co.jp/RT/manual/rt-common/index.html)
- [SNMP設定（ヤマハネットワーク製品）](http://www.rtpro.yamaha.co.jp/RT/docs/snmp/)
- [RFC 3411-3418 (SNMPv3)](https://www.rfc-editor.org/rfc/rfc3411.html)
