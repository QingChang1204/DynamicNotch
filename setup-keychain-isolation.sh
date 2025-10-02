#!/bin/bash

# 为不同的 Xcode 环境创建独立的钥匙串
# 避免证书冲突和频繁 revoke

echo "🔐 设置 Xcode 证书隔离环境"
echo ""

PERSONAL_KEYCHAIN="$HOME/Library/Keychains/NotchNoti-Personal.keychain-db"
WORK_KEYCHAIN="$HOME/Library/Keychains/NotchNoti-Work.keychain-db"

echo "选择你要设置的环境："
echo "1) 个人环境 (Personal)"
echo "2) 工作环境 (Work)"
read -p "请选择 (1/2): " choice

case $choice in
    1)
        KEYCHAIN_NAME="NotchNoti-Personal"
        KEYCHAIN_PATH="$PERSONAL_KEYCHAIN"
        ;;
    2)
        KEYCHAIN_NAME="NotchNoti-Work"
        KEYCHAIN_PATH="$WORK_KEYCHAIN"
        ;;
    *)
        echo "❌ 无效选择"
        exit 1
        ;;
esac

echo ""
echo "📝 钥匙串名称: $KEYCHAIN_NAME"
echo "📁 钥匙串路径: $KEYCHAIN_PATH"

# 检查钥匙串是否已存在
if [ -f "$KEYCHAIN_PATH" ]; then
    echo "⚠️  钥匙串已存在"
    read -p "是否删除并重新创建？(y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        security delete-keychain "$KEYCHAIN_PATH" || true
    else
        echo "使用现有钥匙串"
        exit 0
    fi
fi

# 创建新钥匙串
echo ""
read -s -p "设置钥匙串密码: " PASSWORD
echo ""

security create-keychain -p "$PASSWORD" "$KEYCHAIN_PATH"

# 解锁钥匙串
security unlock-keychain -p "$PASSWORD" "$KEYCHAIN_PATH"

# 设置钥匙串为默认搜索路径的一部分
security list-keychains -d user -s "$KEYCHAIN_PATH" $(security list-keychains -d user | sed 's/"//g')

# 设置钥匙串永不锁定（可选）
security set-keychain-settings "$KEYCHAIN_PATH"

echo ""
echo "✅ 钥匙串创建成功！"
echo ""
echo "📝 下一步："
echo ""
echo "1. 打开 Xcode"
echo "2. Preferences > Accounts > 选择你的 Apple ID"
echo "3. Manage Certificates > 下载/创建证书"
echo "4. 证书会自动安装到这个钥匙串"
echo ""
echo "🔧 构建时使用特定钥匙串："
echo ""
echo "   xcodebuild ... OTHER_CODE_SIGN_FLAGS=\"--keychain $KEYCHAIN_PATH\""
echo ""
echo "或者在构建脚本中设置："
echo ""
echo "   security default-keychain -s \"$KEYCHAIN_PATH\""
echo "   # ... 执行构建 ..."
echo "   security default-keychain -s ~/Library/Keychains/login.keychain-db  # 恢复"
echo ""

# 创建快捷切换脚本
cat > "$HOME/.switch-keychain-$KEYCHAIN_NAME.sh" << 'SCRIPT'
#!/bin/bash
KEYCHAIN_PATH="__KEYCHAIN_PATH__"
echo "🔄 切换到 __KEYCHAIN_NAME__ 钥匙串"
security default-keychain -s "$KEYCHAIN_PATH"
security unlock-keychain "$KEYCHAIN_PATH"
echo "✅ 已切换"
SCRIPT

sed -i '' "s|__KEYCHAIN_PATH__|$KEYCHAIN_PATH|g" "$HOME/.switch-keychain-$KEYCHAIN_NAME.sh"
sed -i '' "s|__KEYCHAIN_NAME__|$KEYCHAIN_NAME|g" "$HOME/.switch-keychain-$KEYCHAIN_NAME.sh"
chmod +x "$HOME/.switch-keychain-$KEYCHAIN_NAME.sh"

echo "💡 快捷切换脚本已创建:"
echo "   $HOME/.switch-keychain-$KEYCHAIN_NAME.sh"
