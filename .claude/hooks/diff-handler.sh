#!/bin/bash

# Diff 处理脚本 - 保存文件修改前后的快照
# 供 NotchDrop 显示文件改动对比

DIFF_DIR="$HOME/Library/Application Support/NotchDrop/diffs"

# 优先使用环境变量中的项目名，否则使用 pwd
if [ -n "$DIFF_PROJECT_NAME" ]; then
    PROJECT_NAME="$DIFF_PROJECT_NAME"
else
    PROJECT_NAME=$(basename "$(pwd)")
fi

# 确保 diff 目录存在
mkdir -p "$DIFF_DIR/$PROJECT_NAME"

# 辅助函数：生成唯一的文件ID
generate_file_id() {
    local file_path="$1"
    # 使用文件路径的 MD5 作为唯一标识
    echo "$file_path" | md5
}

# 辅助函数：保存文件快照
save_snapshot() {
    local file_path="$1"
    local snapshot_type="$2" # before 或 after
    
    if [ ! -f "$file_path" ]; then
        echo "[diff-handler] File not found: $file_path" >&2
        return 1
    fi
    
    local file_id=$(generate_file_id "$file_path")
    local snapshot_path="$DIFF_DIR/$PROJECT_NAME/${file_id}.${snapshot_type}"
    
    # 保存文件内容
    cp "$file_path" "$snapshot_path"
    
    # 同时保存元数据
    echo "$file_path" > "$DIFF_DIR/$PROJECT_NAME/${file_id}.path"
    echo "$(date +%s)" > "$DIFF_DIR/$PROJECT_NAME/${file_id}.${snapshot_type}.time"
    
    echo "[diff-handler] Saved $snapshot_type snapshot for $file_path" >&2
}

# 辅助函数：生成 diff
generate_diff() {
    local file_path="$1"
    local file_id=$(generate_file_id "$file_path")
    
    local before_path="$DIFF_DIR/$PROJECT_NAME/${file_id}.before"
    local after_path="$DIFF_DIR/$PROJECT_NAME/${file_id}.after"
    local diff_path="$DIFF_DIR/$PROJECT_NAME/${file_id}.diff"
    
    if [ ! -f "$before_path" ] || [ ! -f "$after_path" ]; then
        echo "[diff-handler] Missing snapshots for diff generation" >&2
        return 1
    fi
    
    # 生成统一格式的 diff
    diff -u "$before_path" "$after_path" > "$diff_path" 2>/dev/null
    
    # 计算改动统计
    local added=$(grep -c "^+" "$diff_path" 2>/dev/null || echo 0)
    local removed=$(grep -c "^-" "$diff_path" 2>/dev/null || echo 0)
    
    # 保存统计信息
    echo "{\"added\": $added, \"removed\": $removed, \"file\": \"$file_path\"}" > "$DIFF_DIR/$PROJECT_NAME/${file_id}.stats.json"
    
    echo "[diff-handler] Generated diff: +$added -$removed lines" >&2
    echo "$diff_path"
}

# 辅助函数：清理旧的快照（超过1小时）
cleanup_old_snapshots() {
    find "$DIFF_DIR" -type f -mmin +60 -delete 2>/dev/null
}

# 辅助函数：生成预览 diff
generate_preview_diff() {
    local file_path="$1"
    local old_text="$2"
    local new_text="$3"
    local file_id=$(generate_file_id "$file_path")
    
    # 创建临时文件来模拟修改
    local temp_before="/tmp/${file_id}.before"
    local temp_after="/tmp/${file_id}.after"
    
    # 复制原文件
    cp "$file_path" "$temp_before" 2>/dev/null || echo "" > "$temp_before"
    cp "$file_path" "$temp_after" 2>/dev/null || echo "" > "$temp_after"
    
    # 在临时文件中执行替换
    if [ -n "$old_text" ] && [ -n "$new_text" ]; then
        # 使用 Python 进行替换，避免特殊字符问题
        python3 -c "
import sys
try:
    with open('$temp_after', 'r') as f:
        content = f.read()
    old_text = '''$old_text'''
    new_text = '''$new_text'''
    new_content = content.replace(old_text, new_text, 1)
    with open('$temp_after', 'w') as f:
        f.write(new_content)
except:
    pass
" 2>/dev/null
    elif [ -n "$new_text" ]; then
        # Write 操作：整个文件替换
        echo "$new_text" > "$temp_after"
    fi
    
    # 生成预览 diff
    local preview_diff_path="$DIFF_DIR/$PROJECT_NAME/${file_id}.preview.diff"
    diff -u "$temp_before" "$temp_after" > "$preview_diff_path" 2>/dev/null
    
    # 计算改动统计
    local added=$(grep -c "^+" "$preview_diff_path" 2>/dev/null || echo 0)
    local removed=$(grep -c "^-" "$preview_diff_path" 2>/dev/null || echo 0)
    
    # 保存统计信息（标记为预览）
    echo "{\"added\": $added, \"removed\": $removed, \"file\": \"$file_path\", \"preview\": true}" > "$DIFF_DIR/$PROJECT_NAME/${file_id}.preview.stats.json"
    
    # 清理临时文件
    rm -f "$temp_before" "$temp_after"
    
    echo "[diff-handler] Generated preview diff: +$added -$removed lines" >&2
    echo "$preview_diff_path"
}

# 主逻辑
ACTION="$1"
FILE_PATH="$2"
OLD_TEXT="$3"
NEW_TEXT="$4"

case "$ACTION" in
    "before")
        save_snapshot "$FILE_PATH" "before"
        ;;
    "after")
        save_snapshot "$FILE_PATH" "after"
        generate_diff "$FILE_PATH"
        ;;
    "preview")
        # 生成预览 diff
        generate_preview_diff "$FILE_PATH" "$OLD_TEXT" "$NEW_TEXT"
        ;;
    "cleanup")
        cleanup_old_snapshots
        ;;
    *)
        echo "Usage: $0 {before|after|preview|cleanup} <file_path> [old_text new_text]" >&2
        exit 1
        ;;
esac