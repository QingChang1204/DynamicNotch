#!/bin/bash

# NotchNoti DMG 打包脚本 - Developer ID Application 签名
# 用于分发给其他人，完全无警告

set -e

echo "🚀 开始打包 NotchNoti（分发版本 - Developer ID）..."

# 配置
APP_NAME="NotchNoti"
DMG_NAME="NotchNoti"
VERSION="1.0.0"
BUNDLE_ID="com.qingchang.notchnoti"
TEAM_ID="5AMV7L9P34"

# Developer ID Application 证书
DEVELOPER_ID_CERT="Developer ID Application: QingChang Liu (5AMV7L9P34)"

# 路径
PROJECT_DIR="$(pwd)"
BUILD_DIR="${PROJECT_DIR}/build"
RELEASE_DIR="${BUILD_DIR}/Release"
DMG_DIR="${BUILD_DIR}/dmg"
DMG_CONTENTS="${DMG_DIR}/${DMG_NAME}"
FINAL_DMG="${BUILD_DIR}/${DMG_NAME}-${VERSION}-Signed.dmg"

echo "📝 签名配置: ${DEVELOPER_ID_CERT}"

# 检查证书是否存在
if ! security find-identity -v -p codesigning | grep -q "${DEVELOPER_ID_CERT}"; then
    echo "❌ 未找到 Developer ID Application 证书"
    echo ""
    echo "当前可用证书:"
    security find-identity -v -p codesigning | grep -v "REVOKED"
    exit 1
fi

# 清理旧文件
echo "📦 清理旧文件..."
rm -rf "${BUILD_DIR}"
mkdir -p "${RELEASE_DIR}"
mkdir -p "${DMG_CONTENTS}"

# 第一步：构建未签名版本（因为 Developer ID 不能用 Automatic）
echo "🔨 构建 Release 版本（步骤1：编译）..."
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

# 第二步：手动签名
echo ""
echo "✍️  步骤2：使用 Developer ID 签名..."

# 先签名所有二进制文件（深度遍历）
echo "  - 签名内嵌二进制文件..."

# 签名 notch-hook
if [ -f "${APP_PATH}/Contents/MacOS/notch-hook" ]; then
    echo "    • notch-hook"
    /usr/bin/codesign --force --sign "${DEVELOPER_ID_CERT}" \
        --options runtime \
        "${APP_PATH}/Contents/MacOS/notch-hook" || echo "      (签名失败)"
fi

# 签名所有 Frameworks
if [ -d "${APP_PATH}/Contents/Frameworks" ]; then
    echo "    • Frameworks"
    find "${APP_PATH}/Contents/Frameworks" -type f \( -name "*.dylib" -o -name "*.framework" \) | while read file; do
        /usr/bin/codesign --force --sign "${DEVELOPER_ID_CERT}" \
            --options runtime \
            "$file" 2>/dev/null || true
    done
fi

# 最后签名整个 app bundle
echo "  - 签名主应用..."
/usr/bin/codesign --force --deep --sign "${DEVELOPER_ID_CERT}" \
    --options runtime \
    --entitlements "${PROJECT_DIR}/NotchNoti/NotchNoti.entitlements" \
    "${APP_PATH}"

if [ $? -ne 0 ]; then
    echo "❌ 签名失败"
    exit 1
fi

# 验证签名
echo ""
echo "🔍 验证代码签名..."
/usr/bin/codesign --verify --verbose=2 "${APP_PATH}" 2>&1

if [ $? -eq 0 ]; then
    echo "✅ 签名验证成功"
    echo ""
    # 显示签名信息
    echo "📋 签名详情:"
    /usr/bin/codesign -dvvv "${APP_PATH}" 2>&1 | grep -E "(Authority|Identifier|TeamIdentifier)" | head -5
else
    echo "❌ 签名验证失败"
    exit 1
fi

# 检查 Gatekeeper 评估
echo ""
echo "🔒 检查 Gatekeeper 评估..."
if spctl -a -vv "${APP_PATH}" 2>&1 | grep -q "accepted"; then
    echo "✅ Gatekeeper 评估通过（可分发）"
else
    echo "⚠️  Gatekeeper 评估失败"
    echo "   这是正常的，因为应用未公证（notarization）"
    echo "   但签名有效，用户右键打开即可"
fi

# 复制应用到 DMG 目录
echo ""
echo "📋 复制应用..."
cp -R "$APP_PATH" "${DMG_CONTENTS}/"

# 移除隔离属性
echo "🧹 移除隔离属性..."
xattr -cr "${DMG_CONTENTS}/${APP_NAME}.app"

# 创建应用程序文件夹的符号链接
ln -s /Applications "${DMG_CONTENTS}/Applications"

# 创建 README
cat > "${DMG_CONTENTS}/README.txt" << EOF
NotchNoti - Developer ID Signed Release
========================================

此版本使用 Apple Developer ID Application 证书签名。
可以分发给其他 Mac 用户使用。

安装说明:
1. 将 ${APP_NAME}.app 拖拽到 Applications 文件夹
2. 首次运行：右键点击选择"打开"（或双击后在设置中允许）
3. 之后可以正常双击打开

代码签名:
- 证书: ${DEVELOPER_ID_CERT}
- Team ID: ${TEAM_ID}
- 构建时间: $(date)
- 版本: ${VERSION}

功能特性:
- 利用 MacBook 刘海区域显示通知
- 支持通知优先级和队列管理
- 可与 Claude Code 集成
- Unix Socket: ~/.notch.sock
- HTTP 端口: 9876

更多信息:
https://github.com/QingChang1204/DynamicNotch

版本: ${VERSION}
EOF

# 创建 DMG
echo ""
echo "💿 创建 DMG..."
hdiutil create -volname "${DMG_NAME}" \
    -srcfolder "${DMG_CONTENTS}" \
    -ov \
    -format UDZO \
    "${FINAL_DMG}"

if [ $? -ne 0 ]; then
    echo "❌ DMG 创建失败"
    exit 1
fi

# 签名 DMG
echo ""
echo "✍️  签名 DMG..."
/usr/bin/codesign --force --sign "${DEVELOPER_ID_CERT}" \
    "${FINAL_DMG}"

if [ $? -eq 0 ]; then
    echo "✅ DMG 签名成功"
else
    echo "⚠️  DMG 签名失败（不影响使用）"
fi

# 清理临时文件
echo ""
echo "🧹 清理临时文件..."
rm -rf "${DMG_DIR}"
rm -rf "${BUILD_DIR}/DerivedData"

# 计算文件大小
DMG_SIZE=$(du -h "${FINAL_DMG}" | cut -f1)

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ 打包完成!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📦 DMG 文件: ${FINAL_DMG}"
echo "📏 文件大小: ${DMG_SIZE}"
echo "🔐 代码签名: ${DEVELOPER_ID_CERT}"
echo ""
echo "🎉 此版本可以分发给其他人使用！"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📝 分发说明:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "✅ 用户首次运行需要："
echo "   1. 右键点击 NotchNoti.app"
echo "   2. 选择 '打开'"
echo "   3. 点击 '打开' 确认"
echo ""
echo "✅ 之后可以正常双击运行"
echo ""
echo "💡 要完全消除警告（可选）："
echo "   - 需要公证（notarization）"
echo "   - 命令: xcrun notarytool submit ${FINAL_DMG}"
echo "   - 公证后用户可以直接双击打开，无任何警告"
echo ""
