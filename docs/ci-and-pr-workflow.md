# CI / PR 運用ガイド

このリポジトリは、**main直push禁止 + 軽量CI + auto-merge** で、速さと安全性を両立します。

## 1. 開発フロー
- `main` へ直接pushしない
- 作業ブランチを作る: `codex/<topic>`
- `main` 向けにPRを作成
- CIが通ったらauto-mergeで自動マージ

## 2. 必須CI
- Workflow: `.github/workflows/ios-ci.yml`
- Required check: `Unit Tests (iOS)`

## 3. GitHub設定（初回のみ）
GitHub UIで以下を設定してください。

1. `Settings` -> `Rules` -> `Rulesets` -> `New branch ruleset`
2. 対象ブランチ: `main`
3. 有効化する項目:
   - `Require a pull request before merging`
   - `Require status checks to pass before merging`
     - Required checks: `Unit Tests (iOS)`
   - `Block force pushes`
4. 1人開発なら、承認者必須はオフ（0 approvals）でOK

## 4. Auto-merge設定
- `Settings` -> `General` で `Allow auto-merge` を有効化
- 各PRで `Enable auto-merge` をON
- これで「PRは必須、待ち時間は最小」にできる

## 5. ローカル検証コマンド
CIと同じコマンドです。

```bash
xcodebuild \
  -project NaniYaru.xcodeproj \
  -scheme NaniYaru \
  -destination "platform=iOS Simulator,name=iPhone 16" \
  CODE_SIGN_ALLOW_ENTITLEMENTS_MODIFICATION=YES \
  test
```
