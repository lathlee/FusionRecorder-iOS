#!/usr/bin/env bash
set -euo pipefail

# 生成 SideStore / AltStore 源 source.json
# 用法: gen_sources.sh <VERSION> <BASE_URL> <IDENTIFIER> <OUT_FILE>
# 环境变量 IPA_SIZE 可选，写入 apps[].size。

VER="$1"
BASE="$2"
IDENT="$3"
OUTFILE="$4"
IPA_SIZE="${IPA_SIZE:-0}"
DATE=$(date -u '+%Y-%m-%d')

mkdir -p "$(dirname "$OUTFILE")"

cat > "$OUTFILE" <<JSON
{
  "name": "FusionRecorder",
  "identifier": "$IDENT",
  "sourceURL": "$BASE/source.json",
  "apps": [
    {
      "name": "融合录屏",
      "bundleIdentifier": "com.lath.fusionrecorder",
      "version": "$VER",
      "versionDate": "$DATE",
      "downloadURL": "$BASE/FusionRecorder-$VER-unsigned.ipa",
      "localizedDescription": "融合录屏 iPhone 端：无线 ADB 启动采集，双路 H264 裸 TCP 接收，VideoToolbox + Metal 实时合成，成片写入相册。",
      "iconURL": "$BASE/icon.png",
      "tintColor": "0A84FF",
      "size": $IPA_SIZE,
      "permissions": []
    }
  ],
  "news": [
    {
      "title": "FusionRecorder $VER",
      "date": "$DATE",
      "caption": "独立仓库云端编译产物，添加源后可用 SideStore 侧载安装。"
    }
  ]
}
JSON

echo "已生成 $OUTFILE"
