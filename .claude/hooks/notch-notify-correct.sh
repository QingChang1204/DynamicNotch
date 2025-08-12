#!/bin/bash

# NotchDrop 通知 Hook for Claude Code (纯 Bash 版本)
# 使用 bash 字符串处理解析 JSON

NOTCH_SERVER="http://localhost:9876/notify"

# 读取 stdin 中的 JSON 数据
INPUT_JSON=$(cat)

# 获取项目名称和路径
PROJECT_NAME=$(basename "$(pwd)")
PROJECT_PATH=$(pwd)

# 纯 bash 提取 JSON 值的函数
extract_json_value() {
    local json="$1"
    local key="$2"

    # 查找 "key": "value" 或 "key": value 模式
    local pattern="\"${key}\"[[:space:]]*:[[:space:]]*"

    # 提取值
    if [[ $json =~ $pattern\"([^\"]*)\"] ]]; then
        echo "${BASH_REMATCH[1]}"
    elif [[ $json =~ $pattern([^,\}]+) ]]; then
        # 去掉可能的引号
        local value="${BASH_REMATCH[1]}"
        value="${value#\"}"
        value="${value%\"}"
        echo "$value"
    else
        echo ""
    fi
}

# 提取嵌套 JSON 值（tool_input 内的值）
extract_nested_value() {
    local json="$1"
    local key="$2"
    
    # 使用更宽松的模式，直接在整个 JSON 中查找 tool_input.key
    # 查找模式："tool_input":{..."key":"value"...}
    local pattern="\"tool_input\"[[:space:]]*:[[:space:]]*\{[^\}]*\"${key}\"[[:space:]]*:[[:space:]]*"
    
    if [[ $json =~ $pattern\"([^\"]*)\"] ]]; then
        echo "${BASH_REMATCH[1]}"
    elif [[ $json =~ $pattern([^,\}]+) ]]; then
        local value="${BASH_REMATCH[1]}"
        value="${value#\"}"
        value="${value%\"}"
        echo "$value"
    else
        echo ""
    fi
}

# 提取基本信息
TOOL_NAME=$(extract_json_value "$INPUT_JSON" "tool_name")
HOOK_EVENT=$(extract_json_value "$INPUT_JSON" "hook_event_name")

# 默认值
[ -z "$TOOL_NAME" ] && TOOL_NAME="unknown"
[ -z "$HOOK_EVENT" ] && HOOK_EVENT="unknown"

# 从 tool_input 中提取具体信息
FILE_PATH=""
OLD_STRING=""
NEW_STRING=""
COMMAND=""

case "$TOOL_NAME" in
    Edit|Write|MultiEdit)
        FILE_PATH=$(extract_nested_value "$INPUT_JSON" "file_path")
        if [ "$TOOL_NAME" = "Edit" ]; then
            OLD_STRING=$(extract_nested_value "$INPUT_JSON" "old_string")
            NEW_STRING=$(extract_nested_value "$INPUT_JSON" "new_string")
        elif [ "$TOOL_NAME" = "Write" ]; then
            NEW_STRING=$(extract_nested_value "$INPUT_JSON" "content")
        fi
        ;;
    mcp__jetbrains__replace_text_in_file|mcp__jetbrains__create_new_file)
        RELATIVE_PATH=$(extract_nested_value "$INPUT_JSON" "pathInProject")
        if [ "$TOOL_NAME" = "mcp__jetbrains__replace_text_in_file" ]; then
            OLD_STRING=$(extract_nested_value "$INPUT_JSON" "oldText")
            NEW_STRING=$(extract_nested_value "$INPUT_JSON" "newText")
        elif [ "$TOOL_NAME" = "mcp__jetbrains__create_new_file" ]; then
            NEW_STRING=$(extract_nested_value "$INPUT_JSON" "text")
        fi

        # 处理相对路径
        if [ -n "$RELATIVE_PATH" ]; then
            FILE_NAME=$(basename "$RELATIVE_PATH")
            FOUND_PATH=$(mdfind -name "$FILE_NAME" 2>/dev/null | grep "$RELATIVE_PATH$" | head -1)

            if [ -n "$FOUND_PATH" ] && [ -f "$FOUND_PATH" ]; then
                FILE_PATH="$FOUND_PATH"
                PROJECT_PATH="${FOUND_PATH%/"$RELATIVE_PATH"}"
                PROJECT_NAME=$(basename "$PROJECT_PATH")
            else
                FILE_PATH="$PROJECT_PATH/$RELATIVE_PATH"
            fi
        fi
        ;;
    Bash|mcp__jetbrains__execute_terminal_command)
        COMMAND=$(extract_nested_value "$INPUT_JSON" "command")
        # 截取前50个字符
        COMMAND="${COMMAND:0:50}"
        ;;
esac

# Diff 处理脚本路径
DIFF_HANDLER="$(dirname "$0")/diff-handler.sh"

# 辅助函数：发送通知
send_notification() {
    local title="$1"
    local message="$2"
    local type="${3:-info}"
    local priority="${4:-1}"

    # 在标题中加入项目名称
    local full_title="[$PROJECT_NAME] $title"

    # 转义消息中的特殊字符
    message="${message//\"/\\\"}"
    message="${message//$'\n'/ }"

    curl -X POST "$NOTCH_SERVER" \
        -H "Content-Type: application/json" \
        -d "{
            \"title\": \"$full_title\",
            \"message\": \"$message\",
            \"type\": \"$type\",
            \"priority\": $priority,
            \"metadata\": {
                \"source\": \"claude-code\",
                \"project\": \"$PROJECT_NAME\",
                \"project_path\": \"$PROJECT_PATH\",
                \"tool\": \"$TOOL_NAME\",
                \"event\": \"$HOOK_EVENT\"
            }
        }" 2>/dev/null &
}

# 调试日志（可选）
# echo "[DEBUG] Hook Event: $HOOK_EVENT, Tool: $TOOL_NAME" >> /tmp/claude-hook.log

# 根据 hook 事件类型处理
case "$HOOK_EVENT" in
    PreToolUse)
        # 工具使用前的通知 - 只通知重要操作
        case "$TOOL_NAME" in
            Write|Edit|MultiEdit|mcp__jetbrains__replace_text_in_file|mcp__jetbrains__create_new_file)
                # 生成预览 diff
                PREVIEW_DIFF_PATH=""
                if [ -x "$DIFF_HANDLER" ] && [ -n "$FILE_PATH" ]; then
                    # 通过环境变量传递正确的项目名，生成预览 diff
                    PREVIEW_DIFF_PATH=$(DIFF_PROJECT_NAME="$PROJECT_NAME" DIFF_PROJECT_PATH="$PROJECT_PATH" "$DIFF_HANDLER" "preview" "$FILE_PATH" "$OLD_STRING" "$NEW_STRING" 2>/dev/null)

                    # 如果生成了预览 diff，获取统计信息
                    if [ -n "$PREVIEW_DIFF_PATH" ] && [ -f "$PREVIEW_DIFF_PATH" ]; then
                        FILE_ID=$(echo "$FILE_PATH" | md5)
                        STATS_FILE="$HOME/Library/Application Support/NotchDrop/diffs/$PROJECT_NAME/${FILE_ID}.preview.stats.json"
                        if [ -f "$STATS_FILE" ]; then
                            # 使用 bash 提取 JSON 中的数字
                            STATS_CONTENT=$(cat "$STATS_FILE")
                            if [[ $STATS_CONTENT =~ \"added\"[[:space:]]*:[[:space:]]*([0-9]+) ]]; then
                                ADDED="${BASH_REMATCH[1]}"
                            else
                                ADDED="0"
                            fi
                            if [[ $STATS_CONTENT =~ \"removed\"[[:space:]]*:[[:space:]]*([0-9]+) ]]; then
                                REMOVED="${BASH_REMATCH[1]}"
                            else
                                REMOVED="0"
                            fi
                            MESSAGE="$(basename "$FILE_PATH") (预计 +$ADDED -$REMOVED)"
                        else
                            MESSAGE="$(basename "$FILE_PATH")"
                        fi
                    else
                        MESSAGE="$(basename "$FILE_PATH")"
                    fi
                else
                    MESSAGE="$(basename "$FILE_PATH")"
                fi

                # 发送带有预览 diff 的通知
                if [ -n "$PREVIEW_DIFF_PATH" ] && [ -f "$PREVIEW_DIFF_PATH" ]; then
                    # 发送包含预览 diff 路径的通知
                    curl -X POST "$NOTCH_SERVER" \
                        -H "Content-Type: application/json" \
                        -d "{
                            \"title\": \"[$PROJECT_NAME] ⏸️ 即将修改\",
                            \"message\": \"$MESSAGE\",
                            \"type\": \"warning\",
                            \"priority\": 3,
                            \"metadata\": {
                                \"source\": \"claude-code\",
                                \"project\": \"$PROJECT_NAME\",
                                \"project_path\": \"$PROJECT_PATH\",
                                \"file_path\": \"$FILE_PATH\",
                                \"diff_path\": \"$PREVIEW_DIFF_PATH\",
                                \"is_preview\": \"true\",
                                \"tool\": \"$TOOL_NAME\",
                                \"event\": \"$HOOK_EVENT\"
                            }
                        }" 2>/dev/null &
                else
                    # 没有预览 diff 的普通通知
                    if [[ "$TOOL_NAME" == mcp__jetbrains__* ]]; then
                        send_notification "🔧 即将修改" "$(basename "$FILE_PATH")" "warning" 3
                    else
                        send_notification "✏️ 即将修改" "$(basename "$FILE_PATH")" "warning" 3
                    fi
                fi
                ;;
            Bash|mcp__jetbrains__execute_terminal_command)
                # 过滤掉一些不重要的命令
                case "$COMMAND" in
                    echo*|sleep*|curl*localhost:9876*|tail*|head*|grep*|ls*|pwd*|date*)
                        # 这些命令静默
                        ;;
                    *)
                        # 只有重要命令才通知
                        if [[ "$TOOL_NAME" == mcp__jetbrains__* ]]; then
                            send_notification "⚙️ JetBrains 执行命令" "$COMMAND..." "warning" 2
                        else
                            send_notification "⚠️ 即将执行命令" "$COMMAND..." "warning" 2
                        fi
                        ;;
                esac
                ;;
            Task)
                send_notification "🤖 启动 Agent" "AI 任务处理中" "info" 1
                ;;
            *)
                # 其他工具都静默
                ;;
        esac
        ;;

    PostToolUse)
        # 工具使用后的通知 - 简化为完成通知
        case "$TOOL_NAME" in
            Write|Edit|MultiEdit|mcp__jetbrains__replace_text_in_file|mcp__jetbrains__create_new_file)
                # 简单的完成通知
                FILE_NAME=$(basename "$FILE_PATH")
                if [[ "$TOOL_NAME" == mcp__jetbrains__* ]]; then
                    send_notification "✅ 修改完成" "$FILE_NAME" "success" 1
                else
                    send_notification "✅ 修改完成" "$FILE_NAME" "success" 1
                fi
                ;;
            Task)
                send_notification "🤖 Agent 完成" "任务处理完毕" "success" 1
                ;;
            mcp__jetbrains__execute_terminal_command)
                send_notification "⚙️ JetBrains 命令完成" "终端命令执行完毕" "success" 0
                ;;
            *)
                # 其他操作完成都静默，包括 Bash 命令
                ;;
        esac
        ;;

    UserPromptSubmit)
        # 用户提交新提示时 - 静默
        ;;

    Stop)
        # Claude 完成响应时
        send_notification "✨ 任务完成" "Claude 已完成处理" "success" 1
        ;;

    SessionStart)
        # 会话开始时 - 静默
        ;;

    Notification)
        # Claude 等待用户确认时
        send_notification "🔔 需要你的确认" "Claude 正在等待你的选择" "warning" 3
        ;;

    *)
        # 未知事件
        send_notification "📌 Claude 事件" "$HOOK_EVENT" "info" 0
        ;;
esac

exit 0