#!/bin/bash

# 使用 Apple Development 证书构建（自己用）
# 这样可以避免 Gatekeeper 警告，但只能在注册的设备上运行

set -e

echo "🚀 使用 Development 证书构建 NotchNoti..."

# 配置
APP_NAME="NotchNoti"
DMG_NAME="NotchNoti-Dev"
VERSION="1.0.0"
BUNDLE_ID="com.qingchang.notchnoti"

# 使用你现有的有效证书
SIGN_IDENTITY="Apple Development: QingChang Liu (GW23U73S4V)"

# 路径
PROJECT_DIR="$(pwd)"
BUILD_DIR="${PROJECT_DIR}/build"
RELEASE_DIR="${BUILD_DIR}/Release"
DMG_DIR="${BUILD_DIR}/dmg"
DMG_CONTENTS="${DMG_DIR}/${DMG_NAME}"
FINAL_DMG="${BUILD_DIR}/${DMG_NAME}-${VERSION}.dmg"

echo "📝 使用证书: ${SIGN_IDENTITY}"

# 清理旧文件
echo "📦 清理旧文件..."
rm -rf "${BUILD_DIR}"
mkdir -p "${RELEASE_DIR}"
mkdir -p "${DMG_CONTENTS}"

# 构建 Release 版本（带签名）
echo "🔨 构建 Release 版本..."
xcodebuild -scheme NotchNoti \
    -configuration Release \
    -derivedDataPath "${BUILD_DIR}/DerivedData" \
    PRODUCT_BUNDLE_IDENTIFIER="${BUNDLE_ID}" \
    CODE_SIGN_IDENTITY="${SIGN_IDENTITY}" \
    CODE_SIGN_STYLE=Manual \
    DEVELOPMENT_TEAM="4U5Y6C3TP5" \
    CODE_SIGNING_REQUIRED=YES \
    CODE_SIGNING_ALLOWED=YES \
    build

# 查找构建的 app
APP_PATH=$(find "${BUILD_DIR}/DerivedData" -name "${APP_NAME}.app" -type d | head -n 1)

if [ -z "$APP_PATH" ]; then
    echo "❌ 找不到构建的应用"
    exit 1
fi

echo "✅ 找到应用: $APP_PATH"

# 对 app bundle 进行签名
echo "✍️  对应用进行代码签名..."

# 先签名 notch-hook 二进制
if [ -f "${APP_PATH}/Contents/MacOS/notch-hook" ]; then
    echo "  - 签名 notch-hook..."
    codesign --force --sign "${SIGN_IDENTITY}" \
        --options runtime \
        "${APP_PATH}/Contents/MacOS/notch-hook" || true
fi

# 然后签名整个 app bundle
echo "  - 签名 app bundle..."
codesign --force --deep --sign "${SIGN_IDENTITY}" \
    --options runtime \
    --entitlements "${PROJECT_DIR}/NotchNoti/NotchNoti.entitlements" \
    "${APP_PATH}"

# 验证签名
echo "🔍 验证代码签名..."
codesign --verify --verbose=4 "${APP_PATH}"
if [ $? -eq 0 ]; then
    echo "✅ 代码签名验证成功"
else
    echo "⚠️  签名可能有问题，但继续..."
fi

# 复制应用到 DMG 目录
echo "📋 复制应用..."
cp -R "$APP_PATH" "${DMG_CONTENTS}/"

# 移除隔离属性
xattr -cr "${DMG_CONTENTS}/${APP_NAME}.app"

# 创建应用程序文件夹的符号链接
ln -s /Applications "${DMG_CONTENTS}/Applications"

# 创建 README
cat > "${DMG_CONTENTS}/README.txt" << EOF
NotchNoti - Development Build
==============================

此版本使用 Apple Development 证书签名。

安装说明:
1. 将 ${APP_NAME}.app 拖拽到 Applications 文件夹
2. 双击运行 ${APP_NAME}
3. 如果提示无法验证开发者，运行:
   sudo xattr -cr /Applications/NotchNoti.app

代码签名: ${SIGN_IDENTITY}
构建时间: $(date)
版本: ${VERSION}
EOF

# 创建 DMG
echo "💿 创建 DMG..."
hdiutil create -volname "${DMG_NAME}" \
    -srcfolder "${DMG_CONTENTS}" \
    -ov \
    -format UDZO \
    "${FINAL_DMG}"

# 清理临时文件
echo "🧹 清理临时文件..."
rm -rf "${DMG_DIR}"
rm -rf "${BUILD_DIR}/DerivedData"

# 计算文件大小
DMG_SIZE=$(du -h "${FINAL_DMG}" | cut -f1)

echo ""
echo "✅ 打包完成!"
echo "📦 DMG 文件: ${FINAL_DMG}"
echo "📏 文件大小: ${DMG_SIZE}"
echo "🔐 代码签名: ${SIGN_IDENTITY}"
echo ""
echo "💡 如果安装后有警告，运行:"
echo "   ./fix-gatekeeper.sh"
