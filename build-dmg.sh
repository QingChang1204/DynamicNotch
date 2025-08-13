#!/bin/bash

# NotchNoti DMG 打包脚本
# 用于创建可分发的 DMG 安装包

set -e

echo "🚀 开始打包 NotchNoti..."

# 配置
APP_NAME="NotchNoti"
DMG_NAME="NotchNoti"
VERSION="1.0.0"
BUNDLE_ID="com.qingchang.notchnoti"

# 路径
PROJECT_DIR="$(pwd)"
BUILD_DIR="${PROJECT_DIR}/build"
RELEASE_DIR="${BUILD_DIR}/Release"
DMG_DIR="${BUILD_DIR}/dmg"
DMG_CONTENTS="${DMG_DIR}/${DMG_NAME}"
FINAL_DMG="${BUILD_DIR}/${DMG_NAME}-${VERSION}.dmg"

# 清理旧文件
echo "📦 清理旧文件..."
rm -rf "${BUILD_DIR}"
mkdir -p "${RELEASE_DIR}"
mkdir -p "${DMG_CONTENTS}"

# 构建 Release 版本
echo "🔨 构建 Release 版本..."
xcodebuild -scheme NotchNoti \
    -configuration Release \
    -derivedDataPath "${BUILD_DIR}/DerivedData" \
    PRODUCT_BUNDLE_IDENTIFIER="${BUNDLE_ID}" \
    CODE_SIGN_IDENTITY="" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO \
    build

# 查找构建的 app
APP_PATH=$(find "${BUILD_DIR}/DerivedData" -name "${APP_NAME}.app" -type d | head -n 1)

if [ -z "$APP_PATH" ]; then
    echo "❌ 找不到构建的应用"
    exit 1
fi

echo "✅ 找到应用: $APP_PATH"

# 复制应用到 DMG 目录
echo "📋 复制应用..."
cp -R "$APP_PATH" "${DMG_CONTENTS}/"

# 创建应用程序文件夹的符号链接
ln -s /Applications "${DMG_CONTENTS}/Applications"

# 创建 README 文件
cat > "${DMG_CONTENTS}/README.txt" << EOF
NotchNoti - Dynamic Notch Notification System
=============================================

安装说明:
1. 将 ${APP_NAME}.app 拖拽到 Applications 文件夹
2. 双击运行 ${APP_NAME}
3. 首次运行可能需要在系统偏好设置中允许

功能特性:
- 利用 MacBook 刘海区域显示通知
- 支持通知优先级和队列管理
- 可与 Claude Code 集成
- 深色/浅色模式自适应

通知服务器:
- 端口: 9876
- API: POST http://localhost:9876/notify

更多信息请访问:
https://github.com/QingChang1204/DynamicNotch

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
echo ""
echo "可以将此文件分享给其他人使用了！"
echo ""
echo "⚠️  提醒用户："
echo "1. macOS 13.0+ (Ventura 或更高版本)"
echo "2. 首次运行需要右键点击选择'打开'（绕过 Gatekeeper）"
echo "3. 可能需要在'系统偏好设置 > 隐私与安全性'中允许运行"