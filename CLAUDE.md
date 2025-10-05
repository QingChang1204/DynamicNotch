# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

NotchNoti is a native macOS application that transforms the MacBook notch area into an intelligent notification center. It displays system notifications in the notch region with 14 unique animated notification types, each with custom visual effects including particle systems, dynamic gradients, and GPU-accelerated animations.

The app integrates with Claude Code via two mechanisms:
1. **Hooks** (passive monitoring): Unix Domain Socket server receives event notifications from Rust hook binary
2. **MCP Server** (active interaction): Model Context Protocol server allows Claude to actively control the notch interface

## Build Commands

### Standard Development Build
```bash
# Open in Xcode
open NotchNoti.xcodeproj

# Build from command line (Release)
xcodebuild -scheme NotchNoti -configuration Release build

# Build from command line (Debug)
xcodebuild -scheme NotchNoti -configuration Debug build
```

### Create DMG Distribution Package

**RECOMMENDED**: Use the automated build script for all DMG creation.

```bash
./build-dmg-signed.sh
```

**What the script does automatically**:
1. Auto-detects signing certificates (tries Developer ID > Apple Distribution > Apple Development)
2. Builds Swift app in Release configuration
3. Copies and signs the `notch-hook` binary (if present in project root)
4. Signs the entire app bundle
5. Creates a DMG with README
6. Signs the DMG file
7. Outputs to: `build/NotchNoti-<version>-<timestamp>.dmg`

**When Rust hook code was modified**:
If you changed `.claude/hooks/rust-hook/src/main.rs`, rebuild the hook first:

```bash
# 1. Build new Rust hook
cd .claude/hooks/rust-hook
cargo build --release

# 2. Copy to project root (where build script expects it)
cp target/release/notch-hook ../../notch-hook

# 3. Run the automated build script
cd ../..
./build-dmg-signed.sh
```

**Script features**:
- ✅ Automatic certificate selection
- ✅ Graceful handling if hook binary is missing
- ✅ Timestamped output files
- ✅ Signs with hardened runtime (`-o runtime`)
- ✅ Uses `/usr/bin/codesign` to avoid conda/homebrew conflicts
- ✅ Creates compressed UDZO DMG format

## Project Structure

The Xcode project is organized into 10 functional Groups (with physical folder structure):

```
NotchNoti/
├── Core/                           # Application entry point
│   ├── main.swift                  # App bootstrap
│   └── AppDelegate.swift           # Lifecycle management
│
├── Windows & Controllers/          # Window management layer
│   ├── NotchWindow.swift
│   ├── NotchWindowController.swift
│   ├── NotchViewController.swift
│   └── SummaryWindowController.swift
│
├── Views/                          # All UI components
│   ├── Notch Views/               # Main notch interface
│   │   ├── NotchView.swift
│   │   ├── NotchHeaderView.swift
│   │   ├── NotchContentView.swift
│   │   ├── NotchMenuView.swift
│   │   ├── NotchSettingsView.swift
│   │   └── NotchCompactViews.swift
│   │
│   ├── Notification Views/        # Notification rendering
│   │   ├── NotificationView.swift
│   │   ├── NotificationEffects.swift
│   │   └── DiffView.swift
│   │
│   └── Feature Views/             # Specialized features
│       ├── AISettingsWindowSwiftUI.swift
│       └── SessionSummary.swift
│
├── ViewModels & State/            # State management (MVVM)
│   ├── NotchViewModel.swift
│   ├── NotchViewModel+Events.swift
│   └── PendingActionStore.swift
│
├── Models & Data/                 # Business logic and data models
│   ├── NotificationModel.swift
│   ├── NotificationStats.swift
│   ├── Statistics.swift
│   └── AIAnalysis.swift
│
├── Communication/                 # External communication
│   ├── UnixSocketServerSimple.swift
│   └── MCPServer.swift
│
├── Integration/                   # Third-party integrations
│   ├── ClaudeCodeSetup.swift
│   └── GlobalShortcuts.swift
│
├── Event Handling/                # System event monitoring
│   ├── EventMonitor.swift
│   └── EventMonitors.swift
│
├── Utilities & Extensions/        # Helpers and extensions
│   ├── Extensions/
│   │   ├── Ext+NSScreen.swift
│   │   ├── Ext+NSImage.swift
│   │   ├── Ext+NSAlert.swift
│   │   ├── Ext+URL.swift
│   │   └── Ext+FileProvider.swift
│   │
│   └── Helpers/
│       ├── Language.swift
│       ├── PerformanceConfig.swift
│       └── PublishedPersist.swift
│
└── Resources/                     # Assets and configuration
    ├── Assets.xcassets
    ├── Localizable.xcstrings
    ├── InfoPlist.xcstrings
    ├── Info.plist
    ├── NotchNoti.entitlements
    └── notch-hook                 # Rust binary (876KB)
```

**Architecture Pattern**: MVVM (Model-View-ViewModel)
- **Views** render UI based on ViewModels
- **ViewModels** manage state and business logic
- **Models** define data structures and persistence
- **Communication** handles external I/O (sockets, MCP)

## Architecture

### Core Components

**Application Lifecycle** (`AppDelegate.swift`)
- Entry point managing window controllers and screen detection
- Monitors for screen parameter changes to rebuild windows for notch display
- Maintains PID file for single-instance enforcement (`temporaryDirectory/notchnoti.pid`)
- Uses `.accessory` activation policy (no Dock icon)
- Creates standard Edit menu for copy/paste support

**View Model** (`NotchViewModel.swift`)
- Centralized state management using Combine framework
- Manages notch states: `closed`, `opened`, `popping`
- Controls content types: `normal`, `menu`, `settings`, `history`, `stats`, `aiAnalysis`
- Handles ProMotion 120Hz optimized spring animations (mass: 0.7, stiffness: 450, damping: 28)
- Manages user preferences via `@PublishedPersist` property wrapper
- Shared singleton accessible via `NotchViewModel.shared` (weak reference)

**Notification System** (`NotificationModel.swift`)
- 14 notification types with unique animations and colors
- 4-level priority system: low(0), normal(1), high(2), urgent(3)
- **NotificationManager**: Singleton managing notification lifecycle
  - Smart notification queue with priority-based insertion (max 10 queued)
  - LRU cache for UI display (max 50 items in memory)
  - Persistent storage for analysis (max 5000 items in UserDefaults with batch saving)
  - Notification merging within 0.5s time window for same source
  - Auto-calculated display duration based on priority and content length
  - System sound playback per notification type
  - Weak timer references to avoid memory leaks
  - 100ms debounce timer for batch saving to prevent I/O blocking

**Communication Servers**
- `UnixSocketServerSimple.swift`: **Primary notification receiver** (BSD socket)
  - Path: `NSHomeDirectory()/.notch.sock` → `~/.notch.sock` (非沙盒应用)
  - Processes statistics metadata from hook events
  - Calls `StatisticsManager.shared` to record session/tool/error data
  - Parses `NotificationRequest` JSON and feeds into `NotificationManager`
  - Background queue processing (`.userInteractive` QoS)
  - **Note**: HTTP server (NotificationServer.swift) was removed in recent cleanup

**Dual Statistics System**
- `Statistics.swift` - **Work Session Tracking**:
  - `StatisticsManager`: Session lifecycle management (max 20 sessions)
  - `WorkSession`: Tracks project, duration, operations, work mode, intensity
  - `Activity`: Individual tool usage records with timing
  - Work mode classification: writing, researching, debugging, developing, exploring
  - Intensity levels based on pace (operations per minute)
  - Today/weekly trend analysis
  - **Graphical Dashboard UI** (600×160px optimized):
    - Left: 90×90px circular progress ring showing session duration
    - Center: Vertical bar chart for TOP 6 tools with gradient fills
    - Right: Today summary card with icon+number combinations
    - Single-page horizontal layout (no tabs/scrolling)
- `NotificationStats.swift` - **Notification Analytics**:
  - `NotificationStatsManager`: Notification distribution tracking
  - Type distribution (success/error/warning/etc.)
  - Priority distribution and time slot analysis
  - Tool usage statistics extraction from metadata
  - Action type classification (file modification, command execution, etc.)
  - Compact UI for 600×160 notch display

**Window Management** (`NotchWindow.swift`, `NotchWindowController.swift`)
- Floating window positioned over MacBook notch area
- Window level `.statusBar + 1` to stay above most UI
- Seamless integration with notch hardware dimensions via `NSScreen.notchSize` extension
- Automatic rebuild on screen parameter changes

**UI Views**
- `NotchView.swift`: Main container coordinating header, content, menu
- `NotchContentView.swift`: Displays current notification with animations
- `NotchHeaderView.swift`: Shows notch chrome and status
- `NotchSettingsView.swift`: Preferences including Claude Code integration panel
- `NotificationView.swift`: Individual notification rendering with type-specific animations
- `NotificationEffects.swift`: Visual effects (particle systems, gradients, glows)
- `NotchMenuView.swift`: Menu with history, settings, stats buttons
- `NotchCompactViews.swift`: Compact views optimized for 600×160 notch area
  - `CompactNotificationHistoryView`: Vertical list with search (max 6 items)
  - `CompactStatsView`: Routes to work session statistics dashboard
  - `CompactAIAnalysisView`: AI insights with project selection
- `Statistics.swift`: Work session statistics with graphical dashboard
  - `CompactWorkSessionStatsView`: Three-column horizontal layout
    - Circular progress ring (session duration)
    - Vertical bar chart (TOP 6 tools)
    - Today summary card (sessions/time/ops)

**Event Handling** (`EventMonitors.swift`, `EventMonitor.swift`)
- Global mouse and keyboard event monitoring
- Drag-and-drop detection for notch interaction (32pt detection range)
- Click outside detection for auto-closing

**Rust Hook Binary** (`.claude/hooks/rust-hook/src/main.rs`)
- Standalone binary embedded in app bundle at `Contents/MacOS/notch-hook`
- Processes 7 Claude Code hook events: SessionStart, PreToolUse, PostToolUse, Stop, Notification, PreCompact, UserPromptSubmit
- Socket path: `~/.notch.sock` (非沙盒路径)
- Tracks session timing with `session_start_time: Instant`
- Sends notifications with statistics metadata (event_type, session_id, tool_name, duration)
- Filters low-importance operations (echo, ls, pwd, curl localhost:9876)
- Smart tool classification with icons and priorities
- Diff preview generation for Edit/Write/MultiEdit operations
- Built with: `cargo build --release` → ~863KB binary

### Critical Architecture Details

**Bundle Identifier** (Unified):
- **All components now use**: `com.qingchang.notchnoti`
- Xcode project: `com.qingchang.notchnoti`
- Rust hook: `com.qingchang.notchnoti`
- Unified in recent updates for consistency

**Socket Path Resolution**:
- Swift: Uses `NSHomeDirectory()` which returns user home directory (`~`)
- Rust: Uses `dirs::home_dir()` for cross-platform home directory resolution
- Both resolve to: `~/.notch.sock`
- **Note**: App is NOT sandboxed, uses direct home directory path

**Memory Management**:
- All timers use `weak var` references to prevent retain cycles
- NotificationManager uses `[weak self]` in async closures
- LRU caching prevents unbounded memory growth
- Background queue processing prevents UI blocking

### Data Flow

1. **Notification Reception**: Unix socket or HTTP server receives JSON
2. **Parsing**: `NotificationRequest` decoded to `NotchNotification`
3. **Thread Safety**: Ensures main thread execution for UI updates
4. **Merging Check**: Checks if notification should merge with current (0.5s window, same source)
5. **Priority Handling**: Urgent notifications interrupt current, others queue
6. **Queue Management**: Priority-based insertion, max 10 queued
7. **Display**: Manager opens notch via `NotchViewModel`, updates `currentNotification`
8. **Sound**: Plays type-specific system sound if enabled
9. **Animation**: `NotificationView` renders with type-specific effects
10. **Dual Storage**: Saves to memory cache (50) and persistent storage (5000, batch-saved)
11. **Statistics**: Both `StatisticsManager` and `NotificationStatsManager` record data
12. **Lifecycle**: Auto-hide timer based on priority, then show next queued notification

### Notification Types and Effects

Each type has unique animations defined in `NotificationEffects.swift`:
- **success**: Checkmark elastic scale + green glow + gradient
- **error**: Shake effect + red-orange gradient + dynamic glow
- **warning**: Pulse flashing + dynamic shadow
- **info**: Ripple expansion + breathing effect
- **hook**: Link elastic animation + continuous pulse
- **toolUse**: 360° rotation + wobble
- **progress**: Gradient ring rotating continuously
- **celebration**: Golden star particle rain + bounce animation
- **reminder**: Pendulum swing effect
- **download/upload**: Jump animation + circular progress bar
- **security**: Red alert flash + pulse glow
- **ai**: Dynamic gradient background + breathing pulse
- **sync**: 360° continuous rotation

## Key Technical Details

### Dependencies (Swift Package Manager)
- `LaunchAtLogin-Modern`: Auto-launch on macOS login
- `SpringInterpolation`: Physics-based spring animations
- `ColorfulX`: Advanced color manipulation and effects
- `ColorVector`: Color vector math utilities

### Performance Optimizations
- ProMotion 120Hz support with optimized spring physics
- Metal GPU acceleration for all animations
- Background queues for socket/HTTP processing (`.userInteractive` QoS)
- LRU caching for notification history (dual-layer: memory + persistent)
- Timer management on dedicated queue to prevent UI blocking
- Weak references for timers and closures to prevent memory leaks

### Persistence Strategy
- `@PublishedPersist` property wrapper auto-saves to UserDefaults
- Persisted settings: language selection, haptic feedback, notification sound
- Dual-layer notification storage:
  - Memory layer: 50 items for UI display (fast, prevents lag)
  - Persistent layer: 5000 items for analytics (complete history, with batch saving)
- Statistics storage: 20 work sessions in UserDefaults
- PID file at `temporaryDirectory/notchnoti.pid`

### Integration Points
- **Claude Code**: Auto-configuration via settings panel, hook binary injection
- **Git Hooks**: Can send notifications on commit/push
- **npm Scripts**: Build/test completion notifications
- **VS Code/Cursor Tasks**: Custom task notifications

## Notification API

### Unix Socket (Primary Method)
Socket path: `~/.notch.sock`

```bash
# Test connection
echo '{"title":"Test","message":"Hello","type":"success","priority":2}' | \
  nc -U ~/.notch.sock
```

**Note**: HTTP server was removed in recent updates. Unix socket is now the only communication method.

### JSON Schema
```json
{
  "title": "string (required)",
  "message": "string (required)",
  "type": "info|success|warning|error|hook|toolUse|progress|celebration|reminder|download|upload|security|ai|sync",
  "priority": 0-3,
  "icon": "string (optional)",
  "actions": [{"label": "string", "action": "string", "style": "normal|primary|destructive"}],
  "metadata": {
    "event_type": "session_start|tool_use|tool_error",
    "session_id": "string",
    "project": "string",
    "tool_name": "string",
    "error_message": "string",
    "context": "string",
    "duration": "number (seconds)"
  }
}
```

**Statistics Metadata**: When `metadata.event_type` is present, `UnixSocketServerSimple` processes statistics:
- `session_start`: Creates new session in `StatisticsManager` with project name
- `tool_use`/`tool_success`/`tool_complete`: Records activity with tool name and duration
- `tool_error`: Records error with tool name, message, context
- `session_end`/`Stop`: Ends current session
- Hook binary automatically adds timing and session metadata

## System Requirements
- macOS 13.0+ (Ventura)
- MacBook Pro (2021+) or MacBook Air (2022+) with notch
- Recommended: ProMotion display for 120Hz animations

## Development Notes

### Removed Files (Cleanup History)

The following files were removed during iterative development cleanup:
- **AISettingsWindow.swift** (281 lines) - Old AI settings window version 1, replaced by newer implementation
- **AISettingsWindowController.swift** (284 lines) - Old AI settings window version 2, unused
- **NotificationServer.swift** (~200 lines) - HTTP server, functionality moved to UnixSocketServerSimple.swift
- **build-dmg.sh** - Simple DMG build script, replaced by build-dmg-signed.sh
- **build-dmg-distribution.sh** - Old distribution script, replaced by build-dmg-signed.sh

If you encounter references to these files in old documentation, they no longer exist.

### UI Design Constraints - CRITICAL

**Notch Display Area**: 600×160 pixels (ultra-wide, very short)

This severe aspect ratio requires specialized UI patterns:

1. **Horizontal-first layouts**: Use HStack with left/right sections, not vertical ScrollViews
2. **Compact fonts**: Use `.caption` and `.caption2` for most text
3. **Limit item counts**: Show TOP 3 instead of TOP 5, recent 3 errors max
4. **Page-based navigation**: Use ZStack page switching instead of tabs/scrolling
5. **Visual indicators**: Small dots, icons, colors instead of text labels
6. **Minimal spacing**: 4-8pt spacing instead of 12-16pt

**Bad patterns for notch**:
- ❌ Three-tab Picker with large sections
- ❌ Vertical ScrollView with large cards
- ❌ `.title` or `.headline` fonts
- ❌ Showing 5+ items in a list
- ❌ Complex nested VStacks

**Good patterns for notch**:
- ✅ Two-page ZStack with transitions
- ✅ HStack with 2-3 sections
- ✅ Page indicator dots (6×6pt circles)
- ✅ `.caption2` fonts (10pt)
- ✅ Color-coded status (green/orange/red dots)

### Screen Detection
`findScreenFitsOurNeeds()` in `AppDelegate` locates the built-in screen with notch. Falls back to main screen if no notch detected.

### Multi-language Support
`Language.swift` provides system/simplified Chinese/English options. Stored in `selectedLanguage` preference.

### Haptic Feedback
`hapticSender` PassthroughSubject triggers `NSHapticFeedbackManager` on notification events when enabled.

## Common Development Tasks

### Adding New Notification Type
1. Add case to `NotchNotification.NotificationType` enum in `NotificationModel.swift`
2. Define color in `color` computed property
3. Define SF Symbol in `systemImage` property
4. Add animation in `NotificationEffects.swift`
5. Add sound mapping in `playNotificationSound()` in `NotificationManager`
6. Update documentation in README.md and this file

### Modifying Display Duration
Edit `calculateDisplayDuration()` in `NotificationManager.swift` to adjust timing logic based on priority/content length.

Current logic:
- Urgent: 2.0s
- High: 1.5s
- Normal: 1.0s
- Low: 0.8s
- +0.5s per 50 characters (max +2.0s)
- Diff notifications: fixed 2.0s

### Extending Communication API
The Unix socket server parses `NotificationRequest` struct. To add fields:
1. Update `NotificationRequest` struct in `NotificationModel.swift`
2. Update parsing in `UnixSocketServerSimple.swift`
3. Update `NotchNotification` model in `NotificationModel.swift`
4. Update mapping logic in `handleNotificationRequest()` in `UnixSocketServerSimple.swift`

### Rebuilding Hook Binary After Code Changes

When modifying the Rust hook (`.claude/hooks/rust-hook/src/main.rs`):

```bash
# 1. Build new hook
cd .claude/hooks/rust-hook
cargo build --release

# 2. For development builds, update DerivedData
cp target/release/notch-hook \
   ~/Library/Developer/Xcode/DerivedData/NotchNoti-*/Build/Products/Debug/NotchNoti.app/Contents/MacOS/

# 3. If app is installed in /Applications, update it there
cp target/release/notch-hook /Applications/NotchNoti.app/Contents/MacOS/
/usr/bin/codesign --force --sign "Developer ID Application: <NAME> (<TEAM_ID>)" \
   -o runtime /Applications/NotchNoti.app/Contents/MacOS/notch-hook

# 4. Restart NotchNoti to use new hook
killall NotchNoti
open /Applications/NotchNoti.app  # or run from Xcode
```

### Testing Socket Communication

```bash
# 1. Check if app is running and socket exists
ls -la ~/.notch.sock

# 2. Send test notification
echo '{"title":"Test","message":"Socket working!","type":"success","priority":2}' | \
  nc -U ~/.notch.sock

# 3. Monitor hook output (when running from Xcode)
# Check Xcode console for [UnixSocket], [NotificationManager], [DEBUG] prefixed logs
```

### Common Issues and Solutions

**Hook not connecting**:
- Verify socket file exists at correct sandbox path
- Check NotchNoti app is running (look for menubar icon)
- Ensure hook binary is present in app bundle
- Check hook binary has correct permissions/signature
- Review Xcode console for socket creation messages

**Notifications not appearing**:
- Check notification queue isn't full (max 10)
- Verify JSON format matches schema
- Ensure priority is 0-3
- Check type is one of 14 valid types
- Review [NotificationManager] logs in console

**Statistics not recording**:
- Ensure `metadata.event_type` is present in notification
- Check `metadata.tool_name` is provided for tool operations
- Verify `metadata.project` is set for session_start
- Review [Stats] logs in console

**Path resolution errors in Hook**:
- Bundle ID must match in both Xcode project and Rust code
- If changing Bundle ID, update `main.rs:105` socket path
- Verify sandbox container path exists
- Check CLAUDE_PROJECT_DIR environment variable is set

## MCP (Model Context Protocol) Integration

### Overview

NotchNoti now supports MCP, enabling Claude Code to **actively control** the notch interface, not just passively receive events. This creates a bidirectional communication channel.

### Architecture

**Hook System** (Passive):
```
Claude Code → Rust Hook → Unix Socket → NotchNoti
(Event notifications when I use tools)
```

**MCP System** (Active):
```
Claude Code ⟷ MCP Server (NotchNoti --mcp) ⟷ NotchNoti GUI
(I can call tools to control the notch)
```

### Setup

1. **Add MCP SDK dependency** in Xcode:
   - URL: `https://github.com/modelcontextprotocol/swift-sdk.git`
   - Version: `0.10.0` or later
   - Product: `ModelContextProtocol`

2. **Add MCP files to project**:
   - Add `NotchNoti/MCP/*.swift` to Xcode target

3. **Configure Claude Code** (`~/.config/claude/config.json`):
```json
{
  "mcpServers": {
    "notchnoti": {
      "command": "/Applications/NotchNoti.app/Contents/MacOS/NotchNoti",
      "args": ["--mcp"],
      "env": {}
    }
  }
}
```

### MCP Tools

Claude can call these tools to control the notch:

#### 1. `notch_show_progress`
Display a progress notification with percentage:
```json
{
  "title": "Building project",
  "progress": 0.65,
  "cancellable": true
}
```

#### 2. `notch_show_result`
Show an operation result with type-specific styling:
```json
{
  "title": "Build Complete",
  "type": "success",
  "message": "15 tests passed in 2.3s",
  "stats": {"duration": "2.3s", "tests": "15/15"}
}
```

Types: `success`, `error`, `warning`, `info`, `celebration`

#### 3. `notch_ask_confirmation`
Request user confirmation (interactive):
```json
{
  "question": "Delete 3 files?",
  "options": ["Confirm", "Cancel", "Show Details"]
}
```

Returns: `{"choice": "Confirm"}`

### MCP Resources

Claude can read these resources for context:

#### 1. `notch://stats/session`
Current work session statistics:
```json
{
  "project": "DynamicNotch",
  "duration": 3600,
  "activities": 45,
  "pace": 5.2,
  "intensity": "🎯 专注",
  "work_mode": "writing"
}
```

#### 2. `notch://notifications/history`
Recent notification history (last 10):
```json
[
  {
    "title": "Build Complete",
    "message": "Success",
    "type": "success",
    "timestamp": "2025-10-04T10:30:00Z"
  }
]
```

### Use Cases

**Scenario 1: Long Task Progress**
```
Claude: Running build...
  → notch_show_progress({"title": "Building", "progress": 0})
  ... build continues ...
  → notch_show_progress({"progress": 0.5})
  ... build completes ...
  → notch_show_result({"type": "success", "title": "Build Complete"})
```

**Scenario 2: Context-Aware Suggestions**
```
Claude: Let me check your work pace
  → Read resource: notch://stats/session
  → Analyze: pace = 8.5 (intense)
  → notch_show_result({
      "type": "warning",
      "message": "You've been working intensely for 90 minutes. Consider a break!"
    })
```

**Scenario 3: Smart Confirmation**
```
User: Delete all test files
Claude: This will delete 12 files
  → notch_ask_confirmation({
      "question": "Delete 12 test files?",
      "options": ["Confirm", "Cancel", "Show List"]
    })
  → User clicks "Confirm"
  → Proceed with deletion
```

### Performance Considerations

- **Async/Await**: All MCP operations are async, non-blocking
- **MainActor**: MCP server runs on main thread for UI safety
- **Shared State**: MCP and GUI share `NotchViewModel` and managers
- **Concurrent Requests**: Handled via Swift 6 TaskGroup
- **Low Latency**: Stdio transport, typically <10ms

### Debugging

**Check MCP server logs**:
```bash
# MCP server stdout/stderr goes to Claude Code
# Look for [MCP] prefixed messages in Claude Code output
```

**Common issues**:
- **Tool not found**: Check tool name matches exactly (snake_case)
- **Invalid arguments**: Verify JSON schema compliance
- **Server won't start**: Check Swift 6.0+ and ModelContextProtocol framework
- **No response**: Ensure NotchNoti GUI is running (for shared state)

### Differences: Hook vs MCP

| Feature | Hook (Passive) | MCP (Active) |
|---------|---------------|--------------|
| Direction | One-way (Hook → App) | Two-way (Claude ⟷ App) |
| Trigger | Automatic (on tool use) | Manual (Claude decides) |
| Use Case | Monitoring, logging | Control, interaction |
| Data Flow | Events only | Tools + Resources + Prompts |
| Latency | ~5ms | ~10ms |
| Complexity | Simple | Rich |

### Future Extensions

Planned MCP tools:
- `notch_open_view({"view": "stats"})` - Open specific views
- `notch_set_custom_content({...})` - Display custom SwiftUI
- `notch_update_progress({...})` - Streaming progress updates
- `notch_close()` - Programmatically close notch

Planned resources:
- `notch://diffs/recent` - Recent code changes with previews
- `notch://errors/patterns` - Recurring error pattern analysis
- `notch://workspace/context` - Current workspace state

