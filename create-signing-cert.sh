#!/bin/bash

# 创建 macOS 代码签名证书（自签名）
# 用于签名 NotchNoti，避免 macOS 安全警告

set -e

CERT_NAME="NotchNoti Developer"

echo "🔐 创建自签名证书: ${CERT_NAME}"
echo ""

# 检查证书是否已存在
if security find-identity -v -p codesigning | grep -q "${CERT_NAME}"; then
    echo "✅ 证书已存在"
    security find-identity -v -p codesigning | grep "${CERT_NAME}"
    echo ""
    read -p "是否删除并重新创建？(y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        # 查找并删除旧证书
        CERT_HASH=$(security find-identity -v -p codesigning | grep "${CERT_NAME}" | awk '{print $2}')
        if [ -n "$CERT_HASH" ]; then
            echo "🗑️  删除旧证书..."
            security delete-identity -Z "$CERT_HASH" ~/Library/Keychains/login.keychain-db || true
        fi
    else
        echo "使用现有证书。"
        exit 0
    fi
fi

echo ""
echo "📝 开始创建证书..."
echo ""
echo "⚠️  即将打开钥匙串访问应用"
echo ""
echo "请按照以下步骤操作："
echo "1. 在弹出的窗口中："
echo "   - 名称: NotchNoti Developer"
echo "   - 身份类型: 自签名根证书"
echo "   - 证书类型: 代码签名"
echo "   - 勾选 '让我覆盖这些默认值'"
echo ""
echo "2. 点击 '继续' 多次，直到完成"
echo ""
echo "3. 完成后，证书会出现在 '登录' 钥匙串中"
echo ""
read -p "准备好了吗？按回车键继续..."

# 打开钥匙串访问的证书创建向导
open "/System/Applications/Utilities/Keychain Access.app"
sleep 2

# 使用 AppleScript 自动化
osascript <<EOF
tell application "System Events"
    tell process "Keychain Access"
        -- 尝试激活窗口
        set frontmost to true
        delay 1

        -- 菜单: 钥匙串访问 > 证书助理 > 创建证书
        click menu item "创建证书..." of menu "证书助理" of menu item "证书助理" of menu "钥匙串访问" of menu bar 1
    end tell
end tell
EOF

echo ""
echo "⏳ 等待你完成证书创建..."
echo "（创建完成后，按任意键继续）"
read -n 1 -s

echo ""
echo "🔍 验证证书..."

if security find-identity -v -p codesigning | grep -q "${CERT_NAME}"; then
    echo ""
    echo "✅ 证书创建成功！"
    echo ""
    security find-identity -v -p codesigning | grep "${CERT_NAME}"
    echo ""
    echo "🎉 现在可以使用 './build-dmg-signed.sh' 构建签名版本了"
    echo ""
    echo "💡 提示: 如果证书在 '系统' 钥匙串中，请将其移动到 '登录' 钥匙串"
else
    echo ""
    echo "❌ 未找到证书，请手动创建："
    echo ""
    echo "1. 打开 '钥匙串访问'"
    echo "2. 菜单: 钥匙串访问 > 证书助理 > 创建证书"
    echo "3. 设置:"
    echo "   - 名称: ${CERT_NAME}"
    echo "   - 身份类型: 自签名根证书"
    echo "   - 证书类型: 代码签名"
    echo "   - 勾选 '让我覆盖这些默认值'"
    echo ""
    echo "4. 一直点击 '继续'，使用默认设置"
    echo ""
    echo "完成后再次运行此脚本验证。"
fi
