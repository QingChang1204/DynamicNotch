# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

NotchNoti is a native macOS application that transforms the MacBook notch area into an intelligent notification center. It displays system notifications in the notch region with 14 unique animated notification types, each with custom visual effects including particle systems, dynamic gradients, and GPU-accelerated animations.

The app integrates with Claude Code via hooks and receives notifications through Unix Domain Sockets (`~/.notch.sock`) and HTTP (port 9876).

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
- Maintains PID file for single-instance enforcement
- Uses `.accessory` activation policy (no Dock icon)

**View Model** (`NotchViewModel.swift`)
- Centralized state management using Combine framework
- Manages notch states: `closed`, `opened`, `popping`
- Controls content types: `normal`, `menu`, `settings`, `history`, `stats`
- Handles ProMotion 120Hz optimized spring animations
- Manages user preferences via `@PublishedPersist` property wrapper
- Shared singleton accessible via `NotchViewModel.shared`

**Notification System** (`NotificationModel.swift`, `NotificationManager.swift`)
- 14 notification types with unique animations and colors
- 4-level priority system: low(0), normal(1), high(2), urgent(3)
- Smart notification queue with priority-based insertion
- LRU cache for history (max 50 items, max queue 10)
- Notification merging within 0.5s time window for same source
- Auto-calculated display duration based on priority and content length
- System sound playback per notification type

**Communication Servers**
- `UnixSocketServerSimple.swift`: Unix Domain Socket server at `~/.notch.sock` using BSD sockets
  - Processes statistics metadata from hook events
  - Calls `StatisticsManager.shared` to record session/tool/error data
- `NotificationServer.swift`: HTTP server on port 9876 with `/notify` and `/health` endpoints
- Both parse JSON notification requests and feed into `NotificationManager`

**Statistics System** (`Statistics.swift`)
- Session tracking with timing, tool usage, and error recording
- `StatisticsManager`: Singleton managing session lifecycle and data persistence
- `SessionStats`: Tracks project, duration, operations, success rate, top tools
- `ToolStats`: Per-tool usage count, success rate, average duration
- `ErrorRecord`: Captures tool errors with timestamp and context
- LRU cache: max 20 sessions stored in UserDefaults
- Compact UI optimized for 600×160 notch display:
  - Two-page layout (stats page + errors page)
  - Horizontal layout with left metrics, right top tools
  - Page indicators and smooth transitions
  - Shows top 3 tools and recent 3 errors maximum

**Window Management** (`NotchWindow.swift`, `NotchWindowController.swift`)
- Floating window positioned over MacBook notch area
- Window level `.statusBar + 1` to stay above most UI
- Seamless integration with notch hardware dimensions

**UI Views**
- `NotchView.swift`: Main container coordinating header, content, menu
- `NotchContentView.swift`: Displays current notification with animations
- `NotchHeaderView.swift`: Shows notch chrome and status
- `NotchSettingsView.swift`: Preferences including Claude Code integration panel
- `NotificationView.swift`: Individual notification rendering with type-specific animations
- `NotificationEffects.swift`: Visual effects (particle systems, gradients, glows)
- `NotchMenuView.swift`: Menu with history, settings, stats buttons
- `NotchStatsView.swift`: Compact statistics interface with page switching
- `CompactStatsView`: Left metrics (duration/ops/success) + right top 3 tools
- `CompactErrorView`: Scrollable recent 3 errors with compact cards

**Event Handling** (`EventMonitors.swift`, `EventMonitor.swift`)
- Global mouse and keyboard event monitoring
- Drag-and-drop detection for notch interaction
- Click outside detection for auto-closing

**Rust Hook Binary** (`.claude/hooks/rust-hook/src/main.rs`)
- Standalone binary embedded in app bundle at `Contents/MacOS/notch-hook`
- Processes 7 Claude Code hook events: SessionStart, PreToolUse, PostToolUse, Stop, Notification, PreCompact, UserPromptSubmit
- Connects to Unix socket at `~/.notch.sock` (prioritizes this over sandbox path)
- Tracks session timing with `session_start_time: Instant`
- Sends notifications with statistics metadata (event_type, session_id, tool_name, etc.)
- Filters out low-importance tools (Glob, Read for common paths)
- Bundle ID: `com.qingchang.notchnoti` (used for path detection)
- Socket priority: checks `~/.notch.sock` first, then sandbox container path
- Built with: `cargo build --release` → 863KB binary

### Data Flow

1. **Notification Reception**: Unix socket or HTTP server receives JSON
2. **Parsing**: `NotificationRequest` decoded to `NotchNotification`
3. **Queue Management**: `NotificationManager` handles priority, merging, queueing
4. **Display**: Manager opens notch via `NotchViewModel`, updates `currentNotification`
5. **Animation**: `NotificationView` renders with type-specific effects
6. **Lifecycle**: Auto-hide timer based on priority, then show next queued notification

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
- LRU caching for notification history
- Timer management on dedicated queue to prevent UI blocking

### Persistence
- `@PublishedPersist` property wrapper auto-saves to UserDefaults
- Persisted settings: language selection, haptic feedback, notification sound
- PID file at `temporaryDirectory/notchnoti.pid`
- Socket file at `~/.notch.sock`

### Integration Points
- **Claude Code**: Auto-configuration via settings panel, hook binary injection
- **Git Hooks**: Can send notifications on commit/push
- **npm Scripts**: Build/test completion notifications
- **VS Code/Cursor Tasks**: Custom task notifications

## Notification API

### Unix Socket (Recommended)
```bash
echo '{"title":"Test","message":"Hello","type":"success","priority":2}' | nc -U ~/.notch.sock
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
    "context": "string"
  }
}
```

**Statistics Metadata**: When `metadata.event_type` is present, `UnixSocketServerSimple` processes statistics:
- `session_start`: Creates new session in `StatisticsManager`
- `tool_error`: Records error with tool name, message, context
- Hook binary automatically adds timing metadata

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

### Window Positioning
Notch dimensions are detected via `NSScreen.notchSize` extension. Window frame calculated to overlay notch area precisely.

### Animation Tuning
Spring parameters in `NotchViewModel`:
- mass: 0.7 (lighter, snappier)
- stiffness: 450 (faster response)
- damping: 28 (moderate oscillation)

### Multi-language Support
`Language.swift` provides system/simplified Chinese/English options. Stored in `selectedLanguage` preference.

### Haptic Feedback
`hapticSender` PassthroughSubject triggers `NSHapticFeedbackManager` on notification events when enabled.

## Common Patterns

### Adding New Notification Type
1. Add case to `NotchNotification.NotificationType` enum
2. Define color in `color` computed property
3. Define SF Symbol in `systemImage` property
4. Add animation in `NotificationEffects.swift`
5. Add sound mapping in `playNotificationSound()`

### Modifying Display Duration
Edit `calculateDisplayDuration()` in `NotificationManager` to adjust timing logic based on priority/content length.

### Extending API
Both servers parse `NotificationRequest` struct. Extend this codable type and mapping logic in `handleNotificationRequest()`.

### Rebuilding Hook Binary After Code Changes

When modifying the Rust hook (`.claude/hooks/rust-hook/src/main.rs`):

```bash
# 1. Build new hook
cd .claude/hooks/rust-hook
cargo build --release

# 2. If app is installed in /Applications, update it there
cp target/release/notch-hook /Applications/NotchNoti.app/Contents/MacOS/
/usr/bin/codesign --force --sign "Developer ID Application: <NAME> (<TEAM_ID>)" \
   -o runtime /Applications/NotchNoti.app/Contents/MacOS/notch-hook

# 3. For development builds, update DerivedData
cp target/release/notch-hook \
   ~/Library/Developer/Xcode/DerivedData/NotchNoti-*/Build/Products/Debug/NotchNoti.app/Contents/MacOS/

# 4. Restart NotchNoti to use new hook
killall NotchNoti
open /Applications/NotchNoti.app  # or run from Xcode
```

**Common hook issues**:
- Socket not found: Check `~/.notch.sock` exists and app is running
- Status code 1: Hook binary missing or unsigned
- No statistics: Hook binary is outdated version without stats code
- Wrong socket path: Hook using sandbox path but app using `~/.notch.sock`
