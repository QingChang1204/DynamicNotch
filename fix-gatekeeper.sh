#!/bin/bash

# 快速修复 macOS Gatekeeper 警告
# 用于开发测试时移除隔离属性

echo "🔧 修复 NotchNoti 的 Gatekeeper 警告..."

APP_PATH="/Applications/NotchNoti.app"

if [ ! -d "$APP_PATH" ]; then
    echo "❌ 未找到应用: $APP_PATH"
    echo "请先安装应用到 /Applications"
    exit 1
fi

echo "📦 应用路径: $APP_PATH"

# 移除隔离属性（quarantine）
echo "🧹 移除隔离属性..."
sudo xattr -cr "$APP_PATH"

echo "✅ 完成！现在不会再有安全警告了。"
echo ""
echo "💡 如果以后重新安装，再次运行此脚本即可。"
