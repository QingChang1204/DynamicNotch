#!/bin/bash

# NotchDrop 通知 Hook for Claude Code (正确版本)
# 从 stdin 读取 Claude Code 传递的 JSON 数据

NOTCH_SERVER="http://localhost:9876/notify"

# 读取 stdin 中的 JSON 数据
INPUT_JSON=$(cat)

# 使用系统自带的工具解析 JSON（macOS 有 python）
TOOL_NAME=$(echo "$INPUT_JSON" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('tool_name', 'unknown'))" 2>/dev/null)
HOOK_EVENT=$(echo "$INPUT_JSON" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('hook_event_name', 'unknown'))" 2>/dev/null)
TOOL_INPUT=$(echo "$INPUT_JSON" | python3 -c "import sys, json; data=json.load(sys.stdin); print(json.dumps(data.get('tool_input', {})))" 2>/dev/null)

# 从 tool_input 中提取具体信息
if [ "$TOOL_NAME" = "Edit" ] || [ "$TOOL_NAME" = "Write" ] || [ "$TOOL_NAME" = "MultiEdit" ]; then
    FILE_PATH=$(echo "$TOOL_INPUT" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('file_path', 'unknown'))" 2>/dev/null)
elif [ "$TOOL_NAME" = "Bash" ]; then
    COMMAND=$(echo "$TOOL_INPUT" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('command', 'unknown'))" 2>/dev/null)
fi

# 辅助函数：发送通知
send_notification() {
    local title="$1"
    local message="$2"
    local type="${3:-info}"
    local priority="${4:-1}"
    
    curl -X POST "$NOTCH_SERVER" \
        -H "Content-Type: application/json" \
        -d "{
            \"title\": \"$title\",
            \"message\": \"$message\",
            \"type\": \"$type\",
            \"priority\": $priority,
            \"metadata\": {
                \"source\": \"claude-code\",
                \"tool\": \"$TOOL_NAME\",
                \"event\": \"$HOOK_EVENT\"
            }
        }" 2>/dev/null &
}

# 调试日志（可选）
echo "[DEBUG] Hook Event: $HOOK_EVENT, Tool: $TOOL_NAME" >> /tmp/claude-hook.log
echo "[DEBUG] Full JSON: $INPUT_JSON" >> /tmp/claude-hook.log

# 根据 hook 事件类型处理
case "$HOOK_EVENT" in
    "PreToolUse")
        # 工具使用前的通知 - 只通知重要操作
        case "$TOOL_NAME" in
            "Write"|"Edit"|"MultiEdit")
                send_notification "✏️ 准备修改文件" "$FILE_PATH" "warning" 2
                ;;
            "Bash")
                # 过滤掉一些不重要的命令
                if echo "$COMMAND" | grep -qE "^(echo|sleep|curl.*localhost:9876|tail|head|grep|ls|pwd|date)"; then
                    # 这些命令静默
                    :
                else
                    # 只有重要命令才通知
                    COMMAND_PREVIEW=$(echo "$COMMAND" | head -c 50)
                    send_notification "⚠️ 即将执行命令" "$COMMAND_PREVIEW..." "warning" 2
                fi
                ;;
            "Task")
                send_notification "🤖 启动 Agent" "AI 任务处理中" "info" 1
                ;;
            *)
                # 其他工具都静默
                ;;
        esac
        ;;
        
    "PostToolUse")
        # 工具使用后的通知 - 大幅减少
        case "$TOOL_NAME" in
            "Write"|"Edit"|"MultiEdit")
                # 文件修改完成，低优先级简短通知
                send_notification "✅ 文件已修改" "$FILE_PATH" "success" 0
                ;;
            "Task")
                send_notification "🤖 Agent 完成" "任务处理完毕" "success" 1
                ;;
            *)
                # 其他操作完成都静默，包括 Bash 命令
                ;;
        esac
        ;;
        
    "UserPromptSubmit")
        # 用户提交新提示时 - 静默，避免干扰
        # 用户已经知道自己提交了什么，不需要通知
        ;;
        
    "Stop")
        # Claude 完成响应时 - 改为低优先级
        send_notification "✨ 任务完成" "Claude 已完成处理" "success" 1
        ;;
        
    "SessionStart")
        # 会话开始时 - 静默，避免每次都通知
        ;;
        
    "Notification")
        # Claude 等待用户确认时 - 紧急通知，最高优先级
        send_notification "🔔 需要你的确认" "Claude 正在等待你的选择" "warning" 3
        ;;
        
    *)
        # 未知事件
        send_notification "📌 Claude 事件" "$HOOK_EVENT" "info" 0
        ;;
esac

exit 0