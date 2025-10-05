#!/bin/bash

# NotchNoti DMG 打包脚本（带代码签名）
# 用于创建可分发的 DMG 安装包，解决 macOS 安全警告问题

set -e

echo "🚀 开始打包 NotchNoti（带代码签名）..."

# 配置
APP_NAME="NotchNoti"
DMG_NAME="NotchNoti"
VERSION="1.0.0"
BUILD_DATE=$(date +"%Y%m%d-%H%M%S")  # 格式: 20251004-081830
BUNDLE_ID="com.qingchang.notchnoti"

# 代码签名配置
# 自动检测 Developer ID Application 证书
SIGN_IDENTITY=$(security find-identity -v -p codesigning | grep "Developer ID Application" | grep -v "REVOKED" | head -1 | awk -F'"' '{print $2}')

# 如果没有 Developer ID，尝试使用 Apple Distribution
if [ -z "$SIGN_IDENTITY" ]; then
    SIGN_IDENTITY=$(security find-identity -v -p codesigning | grep "Apple Distribution" | grep -v "REVOKED" | head -1 | awk -F'"' '{print $2}')
fi

# 如果还是没有，使用 Apple Development
if [ -z "$SIGN_IDENTITY" ]; then
    SIGN_IDENTITY=$(security find-identity -v -p codesigning | grep "Apple Development" | grep -v "REVOKED" | head -1 | awk -F'"' '{print $2}')
fi

# 路径
PROJECT_DIR="$(pwd)"
BUILD_DIR="${PROJECT_DIR}/build"
RELEASE_DIR="${BUILD_DIR}/Release"
DMG_DIR="${BUILD_DIR}/dmg"
DMG_CONTENTS="${DMG_DIR}/${DMG_NAME}"
FINAL_DMG="${BUILD_DIR}/${DMG_NAME}-${VERSION}-${BUILD_DATE}.dmg"

echo "📝 签名配置: ${SIGN_IDENTITY}"

# 检查证书是否存在
if ! security find-identity -v -p codesigning | grep -q "${SIGN_IDENTITY}"; then
    echo "⚠️  警告: 未找到证书 '${SIGN_IDENTITY}'"
    echo ""
    echo "创建自签名证书的方法："
    echo "1. 打开 '钥匙串访问'"
    echo "2. 菜单: 钥匙串访问 > 证书助理 > 创建证书"
    echo "3. 名称: NotchNoti Developer"
    echo "4. 身份类型: 自签名根证书"
    echo "5. 证书类型: 代码签名"
    echo ""
    read -p "是否继续不签名的构建？(y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
    SIGN_IDENTITY=""
fi

# 清理旧文件（保留之前的 DMG）
echo "📦 清理构建缓存..."
rm -rf "${BUILD_DIR}/DerivedData"
rm -rf "${BUILD_DIR}/Release"
rm -rf "${BUILD_DIR}/dmg"
mkdir -p "${BUILD_DIR}"
mkdir -p "${RELEASE_DIR}"
mkdir -p "${DMG_CONTENTS}"

# 构建 Release 版本
echo "🔨 构建 Release 版本..."
if [ -n "${SIGN_IDENTITY}" ]; then
    # 带签名构建 - 使用自动签名 + Team ID
    xcodebuild -scheme NotchNoti \
        -configuration Release \
        -derivedDataPath "${BUILD_DIR}/DerivedData" \
        PRODUCT_BUNDLE_IDENTIFIER="${BUNDLE_ID}" \
        CODE_SIGN_STYLE=Automatic \
        DEVELOPMENT_TEAM="5AMV7L9P34" \
        CODE_SIGNING_REQUIRED=YES \
        CODE_SIGNING_ALLOWED=YES \
        build
else
    # 不签名构建
    xcodebuild -scheme NotchNoti \
        -configuration Release \
        -derivedDataPath "${BUILD_DIR}/DerivedData" \
        PRODUCT_BUNDLE_IDENTIFIER="${BUNDLE_ID}" \
        CODE_SIGN_IDENTITY="" \
        CODE_SIGNING_REQUIRED=NO \
        CODE_SIGNING_ALLOWED=NO \
        build
fi

# 查找构建的 app
APP_PATH=$(find "${BUILD_DIR}/DerivedData" -name "${APP_NAME}.app" -type d | head -n 1)

if [ -z "$APP_PATH" ]; then
    echo "❌ 找不到构建的应用"
    exit 1
fi

echo "✅ 找到应用: $APP_PATH"

# 检查 app 是否已经被 Xcode 签名
if [ -n "${SIGN_IDENTITY}" ]; then
    echo "🔍 检查代码签名..."

    # 检查签名状态
    if /usr/bin/codesign --verify --verbose "${APP_PATH}" 2>&1 | grep -q "valid on disk"; then
        echo "✅ 应用已由 Xcode 自动签名"
        EXISTING_IDENTITY=$(/usr/bin/codesign -dvvv "${APP_PATH}" 2>&1 | grep "Authority=" | head -1 | cut -d'=' -f2)
        echo "   签名者: ${EXISTING_IDENTITY}"

        # 验证 entitlements 是否正确
        echo "🔍 验证 entitlements..."
        /usr/bin/codesign -d --entitlements - "${APP_PATH}" 2>&1 | head -20
    else
        echo "⚠️  应用未签名或签名无效，尝试手动签名..."

        # 先签名 notch-hook 二进制
        if [ -f "${APP_PATH}/Contents/MacOS/notch-hook" ]; then
            echo "  - 签名 notch-hook 二进制..."
            /usr/bin/codesign --force --sign "${SIGN_IDENTITY}" \
                --options runtime \
                "${APP_PATH}/Contents/MacOS/notch-hook" 2>&1 || echo "    (notch-hook 签名失败)"
        fi

        # 然后签名整个 app bundle（不使用 --deep，避免破坏功能）
        echo "  - 签名 app bundle..."
        /usr/bin/codesign --force --sign "${SIGN_IDENTITY}" \
            --entitlements "${PROJECT_DIR}/NotchNoti/NotchNoti.entitlements" \
            --options runtime \
            "${APP_PATH}" 2>&1

        if [ $? -eq 0 ]; then
            echo "✅ 手动签名成功"
        else
            echo "⚠️  手动签名失败，但继续打包..."
        fi
    fi
fi

# 复制 notch-hook 二进制到 app bundle（如果存在）
if [ -f "${PROJECT_DIR}/notch-hook" ]; then
    echo "📎 复制 notch-hook 二进制..."
    cp "${PROJECT_DIR}/notch-hook" "${APP_PATH}/Contents/MacOS/notch-hook"
    chmod +x "${APP_PATH}/Contents/MacOS/notch-hook"

    # 签名 notch-hook
    if [ -n "${SIGN_IDENTITY}" ]; then
        /usr/bin/codesign --force --sign "${SIGN_IDENTITY}" \
            --options runtime \
            "${APP_PATH}/Contents/MacOS/notch-hook" 2>&1 || echo "  (notch-hook 签名失败)"
    fi
else
    echo "⚠️  警告: notch-hook 二进制不存在，请先构建 Rust hook"
fi

# 复制应用到 DMG 目录
echo "📋 复制应用..."
cp -R "$APP_PATH" "${DMG_CONTENTS}/"

# 移除隔离属性（quarantine）
echo "🧹 移除隔离属性..."
xattr -cr "${DMG_CONTENTS}/${APP_NAME}.app"

# 创建应用程序文件夹的符号链接
ln -s /Applications "${DMG_CONTENTS}/Applications"

# 创建 README 文件
cat > "${DMG_CONTENTS}/README.txt" << EOF
NotchNoti - Dynamic Notch Notification System
=============================================

安装说明:
1. 将 ${APP_NAME}.app 拖拽到 Applications 文件夹
2. 双击运行 ${APP_NAME}
EOF

if [ -n "${SIGN_IDENTITY}" ]; then
    cat >> "${DMG_CONTENTS}/README.txt" << EOF
3. 应用已签名，可以直接运行（无需右键打开）

代码签名信息:
- 签名者: ${SIGN_IDENTITY}
- 签名时间: $(date)
EOF
else
    cat >> "${DMG_CONTENTS}/README.txt" << EOF
3. 首次运行需要右键点击选择'打开'（绕过 Gatekeeper）
4. 可能需要在'系统偏好设置 > 隐私与安全性'中允许运行

⚠️  注意: 此应用未经代码签名
EOF
fi

cat >> "${DMG_CONTENTS}/README.txt" << EOF

功能特性:
- 利用 MacBook 刘海区域显示通知
- 支持通知优先级和队列管理
- 可与 Claude Code 集成
- 深色/浅色模式自适应

通知服务器:
- Unix Socket: ~/.notch.sock
- HTTP 端口: 9876
- API: POST http://localhost:9876/notify

Claude Code 集成:
1. 打开 NotchNoti 设置
2. 点击 "配置 Claude Code Hooks"
3. 选择项目目录
4. 自动配置完成！

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

# 如果有签名，也签名 DMG
if [ -n "${SIGN_IDENTITY}" ]; then
    echo "✍️  签名 DMG..."
    /usr/bin/codesign --force --sign "${SIGN_IDENTITY}" \
        "${FINAL_DMG}" 2>&1 || echo "⚠️  DMG 签名失败（不影响使用）"
fi

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

if [ -n "${SIGN_IDENTITY}" ]; then
    echo "🔐 代码签名: ${SIGN_IDENTITY}"
    echo ""
    echo "🎉 你的应用已签名！不会再有安全警告了。"
else
    echo ""
    echo "⚠️  此构建未签名，可能会触发安全警告。"
    echo ""
    echo "💡 要解决此问题："
    echo "1. 创建自签名证书（见上面的说明）"
    echo "2. 使用 './build-dmg-signed.sh' 重新构建"
fi

echo ""
echo "📝 安装后运行："
echo "   sudo xattr -cr /Applications/NotchNoti.app  # 移除隔离属性"
