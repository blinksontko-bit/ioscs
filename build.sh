#!/bin/bash
# 在任意 macOS 上执行：bash build.sh
set -e
cd "$(dirname "$0")"

command -v xcodegen >/dev/null 2>&1 || brew install xcodegen

xcodegen generate
xcodebuild \
  -project ios-harness.xcodeproj \
  -scheme ios-harness \
  -configuration Release \
  -sdk iphoneos \
  -derivedDataPath build \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  ENABLE_BITCODE=NO \
  build

APP=$(find build/Build/Products/Release-iphoneos -maxdepth 1 -name '*.app' | head -1)
rm -rf Payload ios-harness-unsigned.ipa
mkdir -p Payload
cp -R "$APP" Payload/
zip -qry ios-harness-unsigned.ipa Payload
shasum -a 256 ios-harness-unsigned.ipa | tee ios-harness-unsigned.ipa.sha256
echo "OK: $(pwd)/ios-harness-unsigned.ipa"
