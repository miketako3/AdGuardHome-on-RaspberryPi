# AdGuard Home + Tailscale ゼロタッチプロビジョニング (Raspberry Pi)

[![CI](https://github.com/miketako3/AdGuardHome/actions/workflows/ci.yml/badge.svg)](https://github.com/miketako3/AdGuardHome/actions/workflows/ci.yml)

[English](README.md) | 日本語

このリポジトリは、Raspberry Pi 向け Ubuntu Server 24.04 LTS の最小・宣言的な構成を提供します。  
Raspberry Pi Imager で `hostname / admin user / SSH key` は設定済みである前提です。  
`cloud-init` はアプリ構築だけを担当します。

- パッケージ更新 (`apt update/upgrade`)
- Docker / Docker Compose の導入
- Tailscale の導入と非対話ログイン
- AdGuard Home の Docker Compose 起動

## 前提条件

1. Raspberry Pi Imager で Ubuntu Server 24.04 LTS (64-bit) を書き込み済みであること。
2. Imager 側でホスト名、管理ユーザー、SSH 公開鍵、パスワード認証無効化を設定済みであること。
3. 再利用可能な Tailscale Auth Key (`tskey-auth-...`) を用意済みであること。
4. SDカードのブートパーティションがローカルにマウントされていること。

## クイックスタート

1. `.env` を作成:

```bash
cp .env.example .env
```

2. `.env` を編集:

```dotenv
TAILSCALE_AUTH_KEY=tskey-auth-xxxxxxxxxxxx
BOOT_DIR=/Volumes/system-boot
```

3. Raspberry Pi Imager で書き込み完了後、SDカードを一度抜き差ししてください。  
環境によってはブートパーティションが自動再マウントされないため、`/Volumes` 配下の実際のマウント先を確認し、必要なら `BOOT_DIR` を更新します。

4. `user-data` を生成:

```bash
make render
```

5. ローカル検証テストを実行:

```bash
make test
```

6. SDカードのブートパーティションへコピー:

```bash
make install
```

7. Raspberry Pi に SD カードを挿して、電源と LAN を接続して起動。

## 起動後の確認

1. Tailscale 管理画面でノードが Online になっていること。
2. `http://<raspberry-pi-ip>:3000` にアクセスし、AdGuard Home の初期画面が開くこと。

## Make ターゲット

- `make render`: `templates/user-data.tmpl` から `build/user-data` を生成
- `make install`: `build/user-data` を `${BOOT_DIR}/user-data` にコピー
- `make test`: ローカル検証テスト（疑似ブート領域コピーを含む）
- `make clean`: 生成物を削除

## ファイル構成

- `templates/user-data.tmpl`: cloud-init テンプレート
- `Makefile`: render/install/test のエントリポイント
- `tests/test_setup.sh`: ローカルテスト
- `.env.example`: 秘密情報を含まない設定テンプレート
- `.github/workflows/ci.yml`: GitHub Actions CI

## セキュリティ

- 秘密情報は `.env` からのみ読み込みます。
- `.env` は `.gitignore` 対象でコミットしません。
- 生成物 (`build/`) もコミット対象外です。

## CI

GitHub Actions で `make test` を自動実行します。

- `main` への `push`
- すべての `pull_request`

## トラブルシュート

- `ERROR: TAILSCALE_AUTH_KEY is required`: `.env` に `TAILSCALE_AUTH_KEY` を設定してください。
- `ERROR: BOOT_DIR does not exist`: SDカードのブートパーティションのマウント先と `BOOT_DIR` を確認してください。
- 書き込み直後に `BOOT_DIR` エラーになる: SDカードを抜き差ししてから、`/Volumes` 配下のマウント先を再確認してください。
- AdGuard UI にアクセスできない: 初回起動時にネットワーク接続と Docker 起動が完了しているか確認してください。
