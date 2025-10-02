#!/bin/bash

# 清理被撤销的证书
# 避免混淆和钥匙串臃肿

echo "🧹 清理被撤销的证书..."
echo ""

# 查找所有被撤销的证书
REVOKED_CERTS=$(security find-identity -v -p codesigning 2>&1 | grep "REVOKED" | awk '{print $2}')

if [ -z "$REVOKED_CERTS" ]; then
    echo "✅ 没有发现被撤销的证书"
    exit 0
fi

echo "发现以下被撤销的证书:"
echo ""
security find-identity -v -p codesigning 2>&1 | grep "REVOKED"
echo ""

read -p "是否删除这些证书？(y/N) " -n 1 -r
echo

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "取消操作"
    exit 0
fi

echo ""
echo "开始删除..."

# 逐个删除
COUNT=0
for HASH in $REVOKED_CERTS; do
    echo "  删除: $HASH"
    security delete-identity -Z "$HASH" ~/Library/Keychains/login.keychain-db 2>/dev/null || true
    ((COUNT++))
done

echo ""
echo "✅ 已删除 $COUNT 个被撤销的证书"
echo ""
echo "当前有效证书:"
security find-identity -v -p codesigning 2>&1 | grep -v "REVOKED"
