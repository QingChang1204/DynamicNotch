#!/bin/bash

# NotchNoti Rust Hook Wrapper
# 调用编译好的Rust二进制文件

# HOOK_BINARY="$HOME/.claude/hooks/notch-hook"
HOOK_BINARY="$CLAUDE_PROJECT_DIR/.claude/hooks/notch-hook"

# 检查二进制文件是否存在
if [ ! -f "$HOOK_BINARY" ]; then
    echo "Error: Rust hook binary not found at $HOOK_BINARY" >&2
    echo "Please build it first: cd .claude/hooks/rust-hook && cargo build --release" >&2
    exit 1
fi

# 直接执行Rust程序，它会使用 CLAUDE_PROJECT_DIR 环境变量
exec "$HOOK_BINARY"