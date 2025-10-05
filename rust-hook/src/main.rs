use anyhow::{Context, Result};
use clap::{Parser, Subcommand};
use serde::{Deserialize, Serialize};
use serde_json::Value;
use sha2::{Digest, Sha256};
use similar::{ChangeTag, TextDiff};
use std::collections::HashMap;
use std::fs;
use std::io::{self, Read, Write};
use std::os::unix::net::UnixStream;
use std::path::{Path, PathBuf};

#[derive(Parser)]
#[command(name = "notch-hook")]
#[command(about = "NotchNoti hook for Claude Code", long_about = None)]
struct Cli {
    #[command(subcommand)]
    command: Option<Commands>,
}

#[derive(Subcommand)]
enum Commands {
    /// Process Claude Code hook event
    Hook,
    /// Generate diff preview
    Diff {
        #[arg(long)]
        action: String,
        #[arg(long)]
        file_path: String,
        #[arg(long)]
        old_text: Option<String>,
        #[arg(long)]
        new_text: Option<String>,
    },
}

#[derive(Debug, Deserialize)]
struct HookEvent {
    hook_event_name: String,
    tool_name: Option<String>,
    tool_input: Option<Value>,
    tool_output: Option<Value>,  // 用于 PostToolUse
    error: Option<String>,        // 用于错误情况
}

#[derive(Debug, Serialize)]
struct Notification {
    title: String,
    message: String,
    #[serde(rename = "type")]
    notification_type: String,
    priority: u8,
    metadata: HashMap<String, String>,
}

#[derive(Debug, Serialize)]
struct DiffStats {
    added: usize,
    removed: usize,
    file: String,
    preview: bool,
}

struct NotchHook {
    project_path: PathBuf,
    project_name: String,
    diff_dir: PathBuf,
    socket_path: PathBuf,
    session_start_time: std::time::Instant,
    tool_start_times: std::collections::HashMap<String, std::time::Instant>,
}

impl NotchHook {
    fn new() -> Result<Self> {
        // 优先使用 CLAUDE_PROJECT_DIR 环境变量，这是最可靠的项目路径
        let project_path = std::env::var("CLAUDE_PROJECT_DIR")
            .map(PathBuf::from)
            .unwrap_or_else(|_| {
                eprintln!("[WARNING] CLAUDE_PROJECT_DIR not set, falling back to current dir");
                std::env::current_dir().unwrap()
            });
        
        eprintln!("[DEBUG] Using project path: {}", project_path.display());
        
        let project_name = project_path
            .file_name()
            .and_then(|n| n.to_str())
            .unwrap_or("unknown")
            .to_string();

        let diff_dir = dirs::home_dir()
            .context("Could not find home directory")?
            .join("Library")
            .join("Application Support")
            .join("NotchNoti")
            .join("diffs")
            .join(&project_name);

        fs::create_dir_all(&diff_dir)?;

        // Unix Socket 路径 - 统一使用 com.qingchang.notchnoti
        let home_dir = dirs::home_dir()
            .context("Could not find home directory")?;

        let socket_path = home_dir.join("Library/Containers/com.qingchang.notchnoti/Data/.notch.sock");

        if !socket_path.exists() {
            eprintln!("[WARNING] Unix Socket not found at: {}", socket_path.display());
            eprintln!("[INFO] NotchNoti可能未运行，请确保应用已启动");
        } else {
            eprintln!("[DEBUG] Found Unix Socket at: {}", socket_path.display());
        }

        Ok(Self {
            project_path,
            project_name,
            diff_dir,
            socket_path,
            session_start_time: std::time::Instant::now(),
            tool_start_times: std::collections::HashMap::new(),
        })
    }

    fn process_hook_event(mut self) -> Result<()> {
        let mut input = String::new();
        io::stdin().read_to_string(&mut input)?;

        let event: HookEvent = serde_json::from_str(&input)?;

        // 记录调试信息
        eprintln!(
            "[DEBUG] Hook Event: {}, Tool: {}",
            event.hook_event_name,
            event.tool_name.as_deref().unwrap_or("unknown")
        );

        // 支持两种命名格式: PascalCase 和 snake_case
        match event.hook_event_name.as_str() {
            "PreToolUse" | "pre_tool_use" => self.handle_pre_tool_use(&event)?,
            "PostToolUse" | "post_tool_use" => self.handle_post_tool_use(&event)?,
            "Stop" | "stop" => self.handle_stop()?,
            "Notification" | "notification" => self.handle_notification()?,
            "SessionStart" | "session_start" => self.handle_session_start()?,
            "UserPromptSubmit" | "user_prompt_submit" => self.handle_user_prompt_submit(&event)?,
            "PreCompact" | "pre_compact" => self.handle_pre_compact()?,
            _ => {
                eprintln!("[DEBUG] Unhandled event: {}", event.hook_event_name);
            }
        }

        Ok(())
    }

    fn handle_pre_tool_use(&self, event: &HookEvent) -> Result<()> {
        let tool_name = event.tool_name.as_deref().unwrap_or("");

        // 根据工具类型选择合适的通知类型
        let _notification_type = match tool_name {
            "Edit" | "MultiEdit" | "Write" => "tool_use",
            "Bash" => "warning",
            "Task" => "ai",
            "Read" | "Grep" | "Glob" | "LS" => "info",
            "WebFetch" | "WebSearch" => "download",
            "TodoWrite" => "reminder",
            _ if tool_name.starts_with("mcp__") => "sync",
            _ => "info",
        };
        
        match tool_name {
            "MultiEdit" => {
                // MultiEdit 特殊处理：显示批量修改数量
                if let Some(tool_input) = &event.tool_input {
                    if let Some(file_path) = self.extract_file_path(tool_name, tool_input)? {
                        let relative_path = self.get_relative_path(&file_path);
                        
                        // 提取 edits 数组的长度
                        let edits_count = if let Some(edits) = tool_input.get("edits").and_then(|v| v.as_array()) {
                            edits.len()
                        } else {
                            0
                        };
                        
                        let message = if edits_count > 0 {
                            format!("{} (批量修改 {} 处)", relative_path, edits_count)
                        } else {
                            format!("{} (批量修改)", relative_path)
                        };
                        
                        self.send_notification(
                            format!("[{}] 📝 批量修改", self.project_name),
                            message,
                            "tool_use",
                            2,
                        )?;
                    }
                }
            }
            // JetBrains MCP 文件修改 - 支持diff预览
            "mcp__jetbrains__replace_text_in_file" => {
                if let Some(tool_input) = &event.tool_input {
                    let file_path = self.extract_file_path(tool_name, tool_input)?;
                    let (old_text, new_text) = self.extract_text_content(tool_name, tool_input)?;
                    
                    // 尝试生成diff预览
                    if let Some(ref file_path) = file_path {
                        // 只有当有old_text和new_text时才生成diff
                        if old_text.is_some() && new_text.is_some() {
                            if let Ok((diff_path, stats)) = self.generate_preview_diff(file_path, old_text.as_deref(), new_text.as_deref()) {
                                let relative_path = self.get_relative_path(file_path);
                                let message = format!("{} (预计 +{} -{})", relative_path, stats.added, stats.removed);
                                
                                self.send_notification_with_diff(
                                    format!("[{}] ✏️ JetBrains IDE 修改", self.project_name),
                                    message,
                                    "sync",
                                    2,
                                    Some(diff_path),
                                    Some(file_path.clone()),
                                    tool_name,
                                )?;
                                return Ok(());
                            }
                        }
                    }
                    
                    // 如果无法生成diff，发送普通通知
                    if let Some(file_path) = file_path {
                        let relative_path = self.get_relative_path(&file_path);
                        self.send_notification(
                            format!("[{}] ✏️ JetBrains IDE 修改", self.project_name),
                            relative_path,
                            "sync",
                            2,
                        )?;
                    }
                }
            }
            "mcp__jetbrains__create_new_file" => {
                if let Some(tool_input) = &event.tool_input {
                    let file_path = self.extract_file_path(tool_name, tool_input)?;
                    
                    if let Some(file_path) = file_path {
                        let relative_path = self.get_relative_path(&file_path);
                        self.send_notification(
                            format!("[{}] 🆕 JetBrains 创建文件", self.project_name),
                            relative_path,
                            "sync",
                            2,
                        )?;
                    }
                }
            }
            "mcp__jetbrains__navigate_to_definition" | "mcp__jetbrains__find_usages" | "mcp__jetbrains__search_everywhere" => {
                if let Some(tool_input) = &event.tool_input {
                    let target = tool_input.get("symbol")
                        .or_else(|| tool_input.get("query"))
                        .and_then(|v| v.as_str())
                        .unwrap_or("未知目标");
                    
                    let (icon, action) = match tool_name {
                        "mcp__jetbrains__navigate_to_definition" => ("🎯", "跳转定义"),
                        "mcp__jetbrains__find_usages" => ("🔗", "查找引用"),
                        "mcp__jetbrains__search_everywhere" => ("🌐", "全局搜索"),
                        _ => ("🔍", "搜索"),
                    };
                    
                    self.send_notification(
                        format!("[{}] {} JetBrains {}", self.project_name, icon, action),
                        target.chars().take(80).collect::<String>(),
                        "sync",
                        1,
                    )?;
                }
            }
            "mcp__jetbrains__run_configuration" | "mcp__jetbrains__debug_configuration" => {
                if let Some(tool_input) = &event.tool_input {
                    let config_name = tool_input.get("configuration")
                        .and_then(|v| v.as_str())
                        .unwrap_or("默认配置");
                    
                    let (icon, action) = if tool_name.contains("debug") {
                        ("🐞", "调试")
                    } else {
                        ("▶️", "运行")
                    };
                    
                    self.send_notification(
                        format!("[{}] {} JetBrains {}", self.project_name, icon, action),
                        config_name.to_string(),
                        "sync",
                        2,
                    )?;
                }
            }
            "Edit" | "Write" => {
                if let Some(tool_input) = &event.tool_input {
                    let file_path = self.extract_file_path(tool_name, tool_input)?;
                    let (old_text, new_text) = self.extract_text_content(tool_name, tool_input)?;
                    
                    // 生成预览diff
                    if let Some(ref file_path) = file_path {
                        if let Ok((diff_path, stats)) = self.generate_preview_diff(file_path, old_text.as_deref(), new_text.as_deref()) {
                            let relative_path = self.get_relative_path(file_path);
                            let message = format!("{} (预计 +{} -{})", relative_path, stats.added, stats.removed);
                            
                            self.send_notification_with_diff(
                                format!("[{}] ⏸️ 即将修改", self.project_name),
                                message,
                                "tool_use",  // 改为 tool_use，表示工具操作而非警告
                                2,  // 降低优先级从 3→2
                                Some(diff_path),
                                Some(file_path.clone()),
                                tool_name,
                            )?;
                            return Ok(());
                        }
                    }
                    
                    // 发送普通通知
                    if let Some(file_path) = file_path {
                        let relative_path = self.get_relative_path(&file_path);
                        self.send_notification(
                            format!("[{}] ✏️ 即将修改", self.project_name),
                            relative_path,
                            "tool_use",  // 改为 tool_use
                            2,  // 降低优先级从 3→2
                        )?;
                    }
                }
            }
            "mcp__jetbrains__execute_terminal_command" => {
                if let Some(tool_input) = &event.tool_input {
                    if let Some(command) = tool_input.get("command").and_then(|v| v.as_str()) {
                        let cmd_preview: String = command.chars().take(80).collect();
                        
                        self.send_notification(
                            format!("[{}] 💻 JetBrains 终端", self.project_name),
                            format!("{}", cmd_preview),
                            "sync",
                            2,
                        )?;
                    }
                }
            }
            "Bash" => {
                if let Some(tool_input) = &event.tool_input {
                    if let Some(command) = tool_input.get("command").and_then(|v| v.as_str()) {
                        let cmd_preview: String = command.chars().take(80).collect();
                        
                        // 根据命令类型分类
                        let (should_notify, priority, icon) = if command.starts_with("git ") {
                            (true, 2, "🔀")  // Git 操作
                        } else if command.starts_with("npm ") || command.starts_with("yarn ") || command.starts_with("pnpm ") {
                            (true, 2, "📦")  // 包管理器
                        } else if command.starts_with("rm ") || command.starts_with("mv ") {
                            (true, 3, "⚠️")  // 危险操作
                        } else if command.starts_with("docker ") || command.starts_with("kubectl ") {
                            (true, 2, "🐳")  // 容器操作
                        } else if command.starts_with("make ") || command.starts_with("cargo ") || command.starts_with("go ") {
                            (true, 1, "🔨")  // 构建命令
                        } else if command.starts_with("pytest") || command.starts_with("jest") || command.starts_with("test") {
                            (true, 1, "🧪")  // 测试命令
                        } else if command.starts_with("echo") || command.starts_with("ls") || 
                                  command.starts_with("pwd") || command.starts_with("date") ||
                                  command.starts_with("curl localhost:9876") {
                            (false, 0, "")  // 忽略的命令
                        } else {
                            (true, 1, "💻")  // 其他命令
                        };
                        
                        if should_notify {
                            self.send_notification(
                                format!("[{}] {} 执行命令", self.project_name, icon),
                                format!("{}...", cmd_preview),
                                "tool_use",  // 统一用 tool_use，不再根据优先级判断
                                priority.min(2),  // 限制最高优先级为 2
                            )?;
                        }
                    }
                }
            }
            "Task" => {
                if let Some(tool_input) = &event.tool_input {
                    let subagent_type = tool_input.get("subagent_type")
                        .and_then(|v| v.as_str())
                        .unwrap_or("general-purpose");
                    
                    let description = tool_input.get("description")
                        .and_then(|v| v.as_str())
                        .unwrap_or("AI 任务处理中");
                    
                    let icon = match subagent_type {
                        "statusline-setup" => "⚙️",
                        "output-style-setup" => "🎨",
                        _ => "🤖",
                    };
                    
                    self.send_notification(
                        format!("[{}] {} Agent 启动", self.project_name, icon),
                        format!("{} ({})", description, subagent_type),
                        "ai",
                        2,
                    )?;
                }
            }
            "Read" | "Grep" | "Glob" | "LS" => {
                // 搜索和读取操作 - 低优先级通知
                if let Some(tool_input) = &event.tool_input {
                    let target = match tool_name {
                        "Read" => tool_input.get("file_path").and_then(|v| v.as_str()),
                        "Grep" => tool_input.get("pattern").and_then(|v| v.as_str()),
                        "Glob" => tool_input.get("pattern").and_then(|v| v.as_str()),
                        "LS" => tool_input.get("path").and_then(|v| v.as_str()),
                        _ => None,
                    };
                    
                    if let Some(target) = target {
                        let icon = match tool_name {
                            "Read" => "📖",
                            "Grep" => "🔍",
                            "Glob" => "📁",
                            "LS" => "📋",
                            _ => "ℹ️",
                        };
                        
                        self.send_notification(
                            format!("[{}] {} {}", self.project_name, icon, tool_name),
                            target.chars().take(100).collect::<String>(),
                            "info",
                            0,  // 低优先级
                        )?;
                    }
                }
            }
            "WebFetch" | "WebSearch" => {
                if let Some(tool_input) = &event.tool_input {
                    let url_or_query = tool_input.get("url")
                        .or_else(|| tool_input.get("query"))
                        .and_then(|v| v.as_str())
                        .unwrap_or("");
                    
                    let icon = if tool_name == "WebSearch" { "🔎" } else { "🌐" };
                    
                    self.send_notification(
                        format!("[{}] {} 网络访问", self.project_name, icon),
                        url_or_query.chars().take(100).collect::<String>(),
                        "download",
                        1,
                    )?;
                }
            }
            "TodoWrite" => {
                if let Some(tool_input) = &event.tool_input {
                    if let Some(todos) = tool_input.get("todos").and_then(|v| v.as_array()) {
                        let total = todos.len();
                        let completed = todos.iter().filter(|t| 
                            t.get("status").and_then(|s| s.as_str()) == Some("completed")
                        ).count();
                        
                        self.send_notification(
                            format!("[{}] 📋 任务更新", self.project_name),
                            format!("进度: {}/{} 完成", completed, total),
                            "reminder",
                            1,
                        )?;
                    }
                }
            }
            // JetBrains MCP 其他工具的处理
            tool if tool.starts_with("mcp__jetbrains__") => {
                // 根据工具名称分类处理
                let (icon, action, priority) = match tool {
                    // 项目信息类
                    "mcp__jetbrains__get_run_configurations" => ("⚙️", "获取运行配置", 0),
                    "mcp__jetbrains__get_project_modules" => ("📦", "获取项目模块", 0),
                    "mcp__jetbrains__get_project_dependencies" => ("🔗", "获取项目依赖", 0),
                    "mcp__jetbrains__get_project_problems" => ("⚠️", "获取项目问题", 1),
                    "mcp__jetbrains__get_project_vcs_status" => ("🔀", "获取VCS状态", 1),
                    
                    // 文件操作类
                    "mcp__jetbrains__list_directory_tree" => ("🌳", "列出目录树", 0),
                    "mcp__jetbrains__find_files_by_name_keyword" => ("🔍", "按名称搜索文件", 1),
                    "mcp__jetbrains__find_files_by_glob" => ("📁", "按模式搜索文件", 1),
                    "mcp__jetbrains__get_all_open_file_paths" => ("📂", "获取打开的文件", 0),
                    "mcp__jetbrains__open_file_in_editor" => ("📝", "打开文件", 1),
                    "mcp__jetbrains__get_file_text_by_path" => ("📖", "读取文件内容", 0),
                    "mcp__jetbrains__get_file_problems" => ("🔴", "获取文件问题", 1),
                    "mcp__jetbrains__reformat_file" => ("✨", "格式化文件", 2),
                    
                    // 搜索和分析类
                    "mcp__jetbrains__search_in_files_by_text" => ("🔎", "文本搜索", 1),
                    "mcp__jetbrains__search_in_files_by_regex" => ("🔍", "正则搜索", 1),
                    "mcp__jetbrains__get_symbol_info" => ("ℹ️", "获取符号信息", 0),
                    "mcp__jetbrains__rename_refactoring" => ("✏️", "重命名重构", 2),
                    
                    // 执行类
                    "mcp__jetbrains__execute_run_configuration" => ("▶️", "执行运行配置", 2),
                    
                    // Git类
                    "mcp__jetbrains__find_commit_by_message" => ("📜", "搜索提交", 1),
                    
                    // 默认
                    _ => ("🔧", "JetBrains操作", 1),
                };
                
                // 提取有意义的参数信息
                let detail = if let Some(tool_input) = &event.tool_input {
                    if let Some(path) = tool_input.get("directoryPath")
                        .or_else(|| tool_input.get("pathInProject"))
                        .or_else(|| tool_input.get("filePath"))
                        .or_else(|| tool_input.get("path"))
                        .and_then(|v| v.as_str()) {
                        path.chars().take(80).collect()
                    } else if let Some(pattern) = tool_input.get("pattern")
                        .or_else(|| tool_input.get("globPattern"))
                        .or_else(|| tool_input.get("nameKeyword"))
                        .or_else(|| tool_input.get("searchText"))
                        .or_else(|| tool_input.get("regexPattern"))
                        .or_else(|| tool_input.get("text"))
                        .and_then(|v| v.as_str()) {
                        pattern.chars().take(80).collect()
                    } else if let Some(config) = tool_input.get("configurationName")
                        .and_then(|v| v.as_str()) {
                        config.to_string()
                    } else {
                        String::new()
                    }
                } else {
                    String::new()
                };
                
                // 对于低优先级的操作，只有当有详细信息时才发送通知
                if priority > 0 || !detail.is_empty() {
                    let message = if detail.is_empty() {
                        action.to_string()
                    } else {
                        detail
                    };
                    
                    self.send_notification(
                        format!("[{}] {} JetBrains {}", self.project_name, icon, action),
                        message,
                        "sync",
                        priority,
                    )?;
                }
            }
            _ => {}
        }
        
        Ok(())
    }

    fn handle_post_tool_use(&self, event: &HookEvent) -> Result<()> {
        let tool_name = event.tool_name.as_deref().unwrap_or("");

        // 检查是否有错误
        if let Some(error) = &event.error {
            let mut metadata = HashMap::new();
            metadata.insert("event_type".to_string(), "tool_error".to_string());
            metadata.insert("tool_name".to_string(), tool_name.to_string());
            metadata.insert("error_message".to_string(), error.clone());

            self.send_notification_with_metadata(
                format!("[{}] ❌ 工具执行失败", self.project_name),
                format!("{}: {}", tool_name, error.chars().take(100).collect::<String>()),
                "error",
                3,
                metadata,
            )?;
            return Ok(());
        }
        
        match tool_name {
            "MultiEdit" => {
                // MultiEdit 完成通知
                if let Some(tool_input) = &event.tool_input {
                    if let Ok(Some(file_path)) = self.extract_file_path(tool_name, tool_input) {
                        let relative_path = self.get_relative_path(&file_path);
                        
                        // 提取 edits 数组的长度
                        let edits_count = if let Some(edits) = tool_input.get("edits").and_then(|v| v.as_array()) {
                            edits.len()
                        } else {
                            0
                        };
                        
                        let message = if edits_count > 0 {
                            format!("{} ({} 处修改已完成)", relative_path, edits_count)
                        } else {
                            relative_path
                        };
                        
                        self.send_notification(
                            format!("[{}] ✅ 批量修改完成", self.project_name),
                            message,
                            "success",
                            0,  // 降低完成通知的优先级
                        )?;
                    }
                }
            }
            "mcp__jetbrains__replace_text_in_file" | "mcp__jetbrains__create_new_file" => {
                if let Some(tool_input) = &event.tool_input {
                    if let Ok(Some(file_path)) = self.extract_file_path(tool_name, tool_input) {
                        let relative_path = self.get_relative_path(&file_path);
                        let icon = if tool_name.contains("create") { "🆕" } else { "✏️" };
                        let action = if tool_name.contains("create") { "文件已创建" } else { "IDE 修改完成" };
                        
                        self.send_notification(
                            format!("[{}] ✅ JetBrains {}", self.project_name, action),
                            relative_path,
                            "success",
                            0,
                        )?;
                    }
                }
            }
            "Edit" | "Write" => {
                if let Some(tool_input) = &event.tool_input {
                    if let Ok(Some(file_path)) = self.extract_file_path(tool_name, tool_input) {
                        let relative_path = self.get_relative_path(&file_path);
                        self.send_notification(
                            format!("[{}] ✅ 修改完成", self.project_name),
                            relative_path,
                            "success",
                            0,  // 降低完成通知的优先级
                        )?;
                    }
                }
            }
            "Task" => {
                self.send_notification(
                    format!("[{}] ✨ Agent 完成", self.project_name),
                    "AI 任务处理完毕".to_string(),
                    "success",
                    1,
                )?;
            }
            "Bash" => {
                // Bash 命令完成，可以显示部分输出
                if let Some(tool_output) = &event.tool_output {
                    if let Some(output) = tool_output.as_str() {
                        let preview: String = output.lines()
                            .take(2)
                            .collect::<Vec<_>>()
                            .join(" | ")
                            .chars()
                            .take(100)
                            .collect();
                        
                        if !preview.is_empty() {
                            self.send_notification(
                                format!("[{}] ✅ 命令完成", self.project_name),
                                preview,
                                "success",
                                0,
                            )?;
                        }
                    }
                }
            }
            _ => {}
        }
        
        Ok(())
    }

    fn handle_stop(&self) -> Result<()> {
        self.send_notification(
            format!("[{}] 🎉 会话结束", self.project_name),
            "Claude 已完成所有任务".to_string(),
            "celebration",
            2,
        )?;
        Ok(())
    }

    fn handle_notification(&self) -> Result<()> {
        // Notification hook 会在 Claude Code 等待用户输入或需要权限时触发
        eprintln!("[NOTIFICATION] Claude Code is waiting for user interaction");

        self.send_notification(
            format!("[{}] 🔔 需要你的响应", self.project_name),
            "Claude 正在等待你的选择，请查看 Claude Code 窗口".to_string(),
            "reminder",
            3,
        )?;
        Ok(())
    }
    
    fn handle_session_start(&self) -> Result<()> {
        eprintln!("[DEBUG] Session started for project: {}", self.project_name);

        // 发送会话开始通知
        let mut metadata = HashMap::new();
        metadata.insert("event_type".to_string(), "session_start".to_string());
        metadata.insert("session_id".to_string(), format!("{}", std::process::id()));
        metadata.insert("project".to_string(), self.project_name.clone());  // 添加项目名称

        self.send_notification_with_metadata(
            format!("[{}] 🚀 会话开始", self.project_name),
            "Claude Code 会话已启动".to_string(),
            "ai",
            0,  // 低优先级
            metadata,
        )?;
        Ok(())
    }
    
    fn handle_user_prompt_submit(&self, event: &HookEvent) -> Result<()> {
        eprintln!("[DEBUG] UserPromptSubmit event received");
        eprintln!("[DEBUG] Tool input: {:?}", event.tool_input);

        // 检查是否是确认对话框（Claude Code 询问用户）
        if let Some(tool_input) = &event.tool_input {
            eprintln!("[DEBUG] Raw input: {}", tool_input);

            // 尝试解析为字符串（可能是 JSON 或纯文本）
            if let Some(input_str) = tool_input.as_str() {
                eprintln!("[DEBUG] Input string: {}", input_str);

                // 检测是否包含选项（例如："Allow", "Deny", "Accept", "Reject"）
                let has_options = input_str.contains("allow") ||
                                 input_str.contains("deny") ||
                                 input_str.contains("accept") ||
                                 input_str.contains("reject") ||
                                 input_str.contains("yes") ||
                                 input_str.contains("no");

                if has_options {
                    eprintln!("[DEBUG] Detected confirmation prompt!");

                    // 发送交互式通知到刘海
                    let mut metadata = HashMap::new();
                    metadata.insert("prompt_type".to_string(), "user_confirmation".to_string());
                    metadata.insert("prompt_text".to_string(), input_str.to_string());

                    self.send_notification_with_metadata(
                        format!("[{}] 📋 需要响应", self.project_name),
                        format!("{}", input_str.chars().take(200).collect::<String>()),
                        "confirmation",
                        3,
                        metadata,
                    )?;
                }
            } else if let Some(obj) = tool_input.as_object() {
                eprintln!("[DEBUG] Input is object: {:?}", obj);
                // 可能是结构化的确认请求
            }
        }

        Ok(())
    }
    
    fn handle_pre_compact(&self) -> Result<()> {
        self.send_notification(
            format!("[{}] 🗜️ 内存优化", self.project_name),
            "正在压缩上下文以节省内存".to_string(),
            "info",
            0,
        )?;
        Ok(())
    }

    fn extract_file_path(&self, tool_name: &str, tool_input: &Value) -> Result<Option<PathBuf>> {
        let path_str = match tool_name {
            "Edit" | "Write" | "MultiEdit" => {
                tool_input.get("file_path").and_then(|v| v.as_str())
            }
            "mcp__jetbrains__replace_text_in_file" | "mcp__jetbrains__create_new_file" => {
                tool_input.get("pathInProject").and_then(|v| v.as_str())
            }
            _ => None,
        };

        if let Some(path_str) = path_str {
            // 统一的路径处理策略
            let path = if path_str.starts_with('/') {
                // 看起来像绝对路径
                let abs_path = PathBuf::from(path_str);
                
                // 检查是否真的是绝对路径（文件存在）
                if abs_path.exists() {
                    eprintln!("[DEBUG] Using absolute path: {}", abs_path.display());
                    abs_path
                } else {
                    // 可能是错误的绝对路径格式（如 /README.md），当作相对路径处理
                    let relative = path_str.trim_start_matches('/');
                    let resolved = self.project_path.join(relative);
                    eprintln!("[DEBUG] Converted false absolute path {} to {}", path_str, resolved.display());
                    resolved
                }
            } else {
                // 相对路径 - 所有工具都统一相对于项目根
                let resolved = self.project_path.join(path_str);
                eprintln!("[DEBUG] Resolved relative path {} to {}", path_str, resolved.display());
                resolved
            };
            
            Ok(Some(path))
        } else {
            Ok(None)
        }
    }

    fn extract_text_content(&self, tool_name: &str, tool_input: &Value) -> Result<(Option<String>, Option<String>)> {
        let (old_text, new_text) = match tool_name {
            "Edit" => (
                tool_input.get("old_string").and_then(|v| v.as_str()).map(String::from),
                tool_input.get("new_string").and_then(|v| v.as_str()).map(String::from),
            ),
            "Write" => (
                None,
                tool_input.get("content").and_then(|v| v.as_str()).map(String::from),
            ),
            "mcp__jetbrains__replace_text_in_file" => (
                tool_input.get("oldText").and_then(|v| v.as_str()).map(String::from),
                tool_input.get("newText").and_then(|v| v.as_str()).map(String::from),
            ),
            "mcp__jetbrains__create_new_file" => (
                None,
                tool_input.get("text").and_then(|v| v.as_str()).map(String::from),
            ),
            _ => (None, None),
        };
        
        Ok((old_text, new_text))
    }

    fn generate_preview_diff(
        &self,
        file_path: &Path,
        old_text: Option<&str>,
        new_text: Option<&str>,
    ) -> Result<(PathBuf, DiffStats)> {
        let file_id = self.generate_file_id(file_path);
        
        // 读取原文件内容
        let original_content = if file_path.exists() {
            fs::read_to_string(file_path)?
        } else {
            String::new()
        };
        
        // 生成修改后的内容
        let modified_content = if let (Some(old), Some(new)) = (old_text, new_text) {
            // Edit操作：替换文本
            let result = original_content.replacen(old, new, 1);
            
            // 调试：检查替换是否发生
            if result == original_content {
                eprintln!("[DEBUG] Warning: Text replacement didn't occur!");
                eprintln!("[DEBUG] Looking for: {:?}", old);
                eprintln!("[DEBUG] File starts with: {:?}", original_content.lines().next());
            }
            
            result
        } else if let Some(new) = new_text {
            // Write操作：替换整个文件
            new.to_string()
        } else {
            original_content.clone()
        };
        
        // 生成diff
        let diff = TextDiff::from_lines(&original_content, &modified_content);
        
        // 计算统计
        let mut added = 0;
        let mut removed = 0;
        
        for change in diff.iter_all_changes() {
            match change.tag() {
                ChangeTag::Insert => added += 1,
                ChangeTag::Delete => removed += 1,
                ChangeTag::Equal => {}
            }
        }
        
        // 保存diff文件
        let diff_path = self.diff_dir.join(format!("{}.preview.diff", file_id));
        let unified_diff = diff
            .unified_diff()
            .context_radius(3)
            .header(&format!("--- {}", file_path.display()), &format!("+++ {}", file_path.display()))
            .to_string();
        fs::write(&diff_path, unified_diff)?;
        
        // 保存统计信息
        let stats = DiffStats {
            added,
            removed,
            file: file_path.to_string_lossy().to_string(),
            preview: true,
        };
        
        let stats_path = self.diff_dir.join(format!("{}.preview.stats.json", file_id));
        fs::write(&stats_path, serde_json::to_string(&stats)?)?;
        
        Ok((diff_path, stats))
    }

    fn generate_file_id(&self, file_path: &Path) -> String {
        let mut hasher = Sha256::new();
        hasher.update(file_path.to_string_lossy().as_bytes());
        hex::encode(hasher.finalize())
    }

    fn get_relative_path(&self, file_path: &Path) -> String {
        file_path
            .strip_prefix(&self.project_path)
            .unwrap_or(file_path)
            .to_string_lossy()
            .to_string()
    }

    fn send_notification(
        &self,
        title: String,
        message: String,
        notification_type: &str,
        priority: u8,
    ) -> Result<()> {
        self.send_notification_with_metadata(title, message, notification_type, priority, HashMap::new())
    }

    fn send_notification_with_metadata(
        &self,
        title: String,
        message: String,
        notification_type: &str,
        priority: u8,
        extra_metadata: HashMap<String, String>,
    ) -> Result<()> {
        let mut metadata = HashMap::new();
        metadata.insert("source".to_string(), "claude-code".to_string());
        metadata.insert("project".to_string(), self.project_name.clone());
        metadata.insert("project_path".to_string(), self.project_path.to_string_lossy().to_string());
        metadata.insert("session_duration".to_string(), format!("{:.1}", self.session_start_time.elapsed().as_secs_f64()));

        // 合并额外的 metadata
        for (key, value) in extra_metadata {
            metadata.insert(key, value);
        }

        let notification = Notification {
            title,
            message,
            notification_type: notification_type.to_string(),
            priority,
            metadata,
        };

        // 只使用 Unix Socket，不再降级到HTTP
        if let Err(e) = self.send_via_socket(&notification) {
            eprintln!("[ERROR] Failed to send notification via socket: {}", e);
            eprintln!("[INFO] 请确保NotchNoti应用正在运行");
        }

        Ok(())
    }
    
    fn send_via_socket(&self, notification: &Notification) -> Result<()> {
        // 连接到 Unix Socket
        let mut stream = UnixStream::connect(&self.socket_path)
            .context("Failed to connect to Unix socket")?;

        // 序列化并发送 JSON
        let json = serde_json::to_string(notification)?;
        stream.write_all(json.as_bytes())
            .context("Failed to write to socket")?;

        // 读取响应（可选）
        let mut response = String::new();
        stream.read_to_string(&mut response).ok();

        Ok(())
    }


    fn is_dangerous_operation(&self, tool_name: &str, tool_input: &Option<Value>) -> Result<bool> {
        match tool_name {
            "Bash" => {
                // 检查 Bash 命令是否包含危险操作
                if let Some(input) = tool_input {
                    if let Some(command) = input.get("command").and_then(|v| v.as_str()) {
                        let dangerous_keywords = [
                            "rm -rf",
                            "sudo",
                            "chmod 777",
                            "mkfs",
                            "> /dev/",
                            "dd if=",
                            "curl | bash",
                            "wget | sh",
                            ":(){ :|:& };:",  // Fork bomb
                        ];

                        for keyword in &dangerous_keywords {
                            if command.contains(keyword) {
                                eprintln!("[SECURITY] Detected dangerous command: {}", keyword);
                                return Ok(true);
                            }
                        }
                    }
                }
            }
            "Write" | "Edit" => {
                // 检查是否修改系统配置文件或敏感文件
                if let Some(input) = tool_input {
                    if let Some(file_path) = self.extract_file_path(tool_name, input)? {
                        let sensitive_patterns = [
                            ".ssh/",
                            ".aws/",
                            "package.json",  // 可能添加恶意依赖
                            "Cargo.toml",
                            ".env",
                            "credentials",
                        ];

                        let path_str = file_path.to_string_lossy();
                        for pattern in &sensitive_patterns {
                            if path_str.contains(pattern) {
                                eprintln!("[SECURITY] Detected sensitive file modification: {}", pattern);
                                return Ok(true);
                            }
                        }
                    }
                }
            }
            _ => {}
        }

        Ok(false)
    }


    fn format_operation_details(&self, tool_name: &str, tool_input: &Option<Value>) -> String {
        match tool_name {
            "Bash" => {
                if let Some(input) = tool_input {
                    if let Some(command) = input.get("command").and_then(|v| v.as_str()) {
                        return format!("执行命令: {}", command.chars().take(100).collect::<String>());
                    }
                }
                "执行 Bash 命令".to_string()
            }
            "Write" | "Edit" => {
                if let Some(input) = tool_input {
                    if let Ok(Some(file_path)) = self.extract_file_path(tool_name, input) {
                        let relative_path = self.get_relative_path(&file_path);
                        return format!("修改敏感文件: {}", relative_path);
                    }
                }
                "修改文件".to_string()
            }
            _ => format!("执行操作: {}", tool_name),
        }
    }
    
    fn send_notification_with_diff(
        &self,
        title: String,
        message: String,
        notification_type: &str,
        priority: u8,
        diff_path: Option<PathBuf>,
        file_path: Option<PathBuf>,
        tool_name: &str,
    ) -> Result<()> {
        let mut metadata = HashMap::new();
        metadata.insert("source".to_string(), "claude-code".to_string());
        metadata.insert("project".to_string(), self.project_name.clone());
        metadata.insert("project_path".to_string(), self.project_path.to_string_lossy().to_string());
        metadata.insert("tool_name".to_string(), tool_name.to_string());  // 统一使用 tool_name
        metadata.insert("event_type".to_string(), "PreToolUse".to_string());  // 统一使用 event_type
        
        if let Some(path) = file_path {
            metadata.insert("file_path".to_string(), path.to_string_lossy().to_string());
        }
        
        if let Some(path) = diff_path {
            metadata.insert("diff_path".to_string(), path.to_string_lossy().to_string());
            metadata.insert("is_preview".to_string(), "true".to_string());
            eprintln!("[DEBUG] Adding diff_path to metadata: {}", path.display());
        }
        
        let notification = Notification {
            title,
            message,
            notification_type: notification_type.to_string(),
            priority,
            metadata,
        };

        // 打印要发送的完整JSON以便调试
        eprintln!("[DEBUG] Sending JSON to NotchNoti:");
        eprintln!("{}", serde_json::to_string_pretty(&notification)?);
        
        // 只使用 Unix Socket
        if let Err(e) = self.send_via_socket(&notification) {
            eprintln!("[ERROR] Failed to send notification with diff: {}", e);
        }
        
        Ok(())
    }

    fn handle_diff_command(
        &self,
        action: &str,
        file_path: &str,
        old_text: Option<String>,
        new_text: Option<String>,
    ) -> Result<()> {
        let path = PathBuf::from(file_path);
        
        match action {
            "preview" => {
                let (diff_path, stats) = self.generate_preview_diff(
                    &path,
                    old_text.as_deref(),
                    new_text.as_deref(),
                )?;
                
                eprintln!("[diff-handler] Generated preview diff: +{} -{} lines", stats.added, stats.removed);
                println!("{}", diff_path.display());
            }
            _ => {
                eprintln!("Unknown diff action: {}", action);
            }
        }
        
        Ok(())
    }
}

fn main() -> Result<()> {
    let cli = Cli::parse();
    let hook = NotchHook::new()?;
    
    match cli.command {
        Some(Commands::Diff { action, file_path, old_text, new_text }) => {
            hook.handle_diff_command(&action, &file_path, old_text, new_text)?;
        }
        _ => {
            // 默认处理hook事件
            hook.process_hook_event()?;
        }
    }
    
    Ok(())
}
