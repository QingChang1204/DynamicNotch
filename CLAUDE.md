# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

NotchNoti is a native macOS application that transforms the MacBook notch area into an intelligent notification center. It displays system notifications in the notch region with 14 unique animated notification types, each with custom visual effects including particle systems, dynamic gradients, and GPU-accelerated animations.

The app integrates with Claude Code via hooks and receives notifications through Unix Domain Sockets (sandbox path) and HTTP (port 9876).

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

**IMPORTANT**: The build script does NOT include the hook binary. You must manually update it:

```bash
# 1. Build the Rust hook first
cd .claude/hooks/rust-hook
cargo build --release

# 2. Build Release app
xcodebuild -scheme NotchNoti -configuration Release build

# 3. Copy hook to Release app bundle
cp .claude/hooks/rust-hook/target/release/notch-hook \
   ~/Library/Developer/Xcode/DerivedData/NotchNoti-*/Build/Products/Release/NotchNoti.app/Contents/MacOS/

# 4. Sign everything (if distributing)
/usr/bin/codesign --force --sign "Developer ID Application: <NAME> (<TEAM_ID>)" \
   -o runtime \
   ~/Library/Developer/Xcode/DerivedData/NotchNoti-*/Build/Products/Release/NotchNoti.app/Contents/MacOS/notch-hook

/usr/bin/codesign --force --deep --sign "Developer ID Application: <NAME> (<TEAM_ID>)" \
   -o runtime \
   ~/Library/Developer/Xcode/DerivedData/NotchNoti-*/Build/Products/Release/NotchNoti.app

# 5. Create and sign DMG
hdiutil create -volname "NotchNoti" \
   -srcfolder ~/Library/Developer/Xcode/DerivedData/NotchNoti-*/Build/Products/Release/NotchNoti.app \
   -ov -format UDZO build/NotchNoti-1.0.0-Signed.dmg

/usr/bin/codesign --force --sign "Developer ID Application: <NAME> (<TEAM_ID>)" \
   build/NotchNoti-1.0.0-Signed.dmg
```

**Why manual steps are needed**:
- The `build-dmg.sh` script builds without the latest hook binary
- Hook binary must be compiled from Rust source before packaging
- Code signing requires the hook to be signed first, then the app bundle
- Using `/usr/bin/codesign` avoids conflicts with conda/homebrew versions

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
  - Persistent storage for analysis (max 1000 items in UserDefaults)
  - Notification merging within 0.5s time window for same source
  - Auto-calculated display duration based on priority and content length
  - System sound playback per notification type
  - Weak timer references to avoid memory leaks

**Communication Servers**
- `UnixSocketServerSimple.swift`: BSD socket server in sandbox container
  - Path: `NSHomeDirectory()/.notch.sock` → `~/Library/Containers/com.qingchang.notchnoti/Data/.notch.sock`
  - Processes statistics metadata from hook events
  - Calls `StatisticsManager.shared` to record session/tool/error data
  - Background queue processing (`.userInteractive` QoS)
- `NotificationServer.swift`: HTTP server on port 9876
  - Endpoints: `/notify` (POST), `/health` (GET)
  - CORS headers for local web access
  - Background queue processing (`.userInteractive` QoS)
- Both parse `NotificationRequest` and feed into `NotificationManager`

**Dual Statistics System**
- `Statistics.swift` - **Work Session Tracking**:
  - `StatisticsManager`: Session lifecycle management (max 20 sessions)
  - `WorkSession`: Tracks project, duration, operations, work mode, intensity
  - `Activity`: Individual tool usage records with timing
  - Work mode classification: writing, researching, debugging, developing, exploring
  - Intensity levels based on pace (operations per minute)
  - Today/weekly trend analysis
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
- `NotchStatsView.swift`: Compact statistics interface with page switching (3 pages)
- `CompactNotificationStatsView`: Notification statistics with ring chart visualization

**Event Handling** (`EventMonitors.swift`, `EventMonitor.swift`)
- Global mouse and keyboard event monitoring
- Drag-and-drop detection for notch interaction (32pt detection range)
- Click outside detection for auto-closing

**Rust Hook Binary** (`.claude/hooks/rust-hook/src/main.rs`)
- Standalone binary embedded in app bundle at `Contents/MacOS/notch-hook`
- Processes 7 Claude Code hook events: SessionStart, PreToolUse, PostToolUse, Stop, Notification, PreCompact, UserPromptSubmit
- Socket path: `~/Library/Containers/com.qingchang.notchnoti/Data/.notch.sock` (hardcoded Bundle ID)
- Tracks session timing with `session_start_time: Instant`
- Sends notifications with statistics metadata (event_type, session_id, tool_name, duration)
- Filters low-importance operations (echo, ls, pwd, curl localhost:9876)
- Smart tool classification with icons and priorities
- Diff preview generation for Edit/Write/MultiEdit operations
- Built with: `cargo build --release` → ~863KB binary

### Critical Architecture Details

**Bundle Identifier Mismatch**:
- Xcode project: `wiki.qaq.NotchNoti`
- Rust hook hardcodes: `com.qingchang.notchnoti`
- **Important**: If changing Bundle ID, must update Rust hook path logic

**Socket Path Resolution**:
- Swift: Uses `NSHomeDirectory()` which returns sandbox container path in sandboxed builds
- Rust: Manually constructs path with hardcoded Bundle ID
- Both resolve to: `~/Library/Containers/com.qingchang.notchnoti/Data/.notch.sock`
- **Note**: No fallback to non-sandbox path currently implemented

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
10. **Dual Storage**: Saves to memory cache (50) and persistent storage (1000)
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
  - Persistent layer: 1000 items for analytics (complete history)
- Statistics storage: 20 work sessions in UserDefaults
- PID file at `temporaryDirectory/notchnoti.pid`

### Integration Points
- **Claude Code**: Auto-configuration via settings panel, hook binary injection
- **Git Hooks**: Can send notifications on commit/push
- **npm Scripts**: Build/test completion notifications
- **VS Code/Cursor Tasks**: Custom task notifications

## Notification API

### Unix Socket (Recommended)
Socket path: `~/Library/Containers/com.qingchang.notchnoti/Data/.notch.sock`

```bash
# Test connection
echo '{"title":"Test","message":"Hello","type":"success","priority":2}' | \
  nc -U ~/Library/Containers/com.qingchang.notchnoti/Data/.notch.sock
```

### HTTP Server
```bash
curl -X POST http://localhost:9876/notify \
  -H "Content-Type: application/json" \
  -d '{"title":"Test","message":"Hello","type":"info","priority":1}'
```

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
Both servers parse `NotificationRequest` struct. To add fields:
1. Update `NotificationRequest` in `NotificationServer.swift`
2. Update parsing in `UnixSocketServerSimple.swift`
3. Update `NotchNotification` model in `NotificationModel.swift`
4. Update mapping logic in `handleNotificationRequest()`

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
ls -la ~/Library/Containers/com.qingchang.notchnoti/Data/.notch.sock

# 2. Send test notification
echo '{"title":"Test","message":"Socket working!","type":"success","priority":2}' | \
  nc -U ~/Library/Containers/com.qingchang.notchnoti/Data/.notch.sock

# 3. Test HTTP endpoint
curl http://localhost:9876/health

# 4. Monitor hook output (when running from Xcode)
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
