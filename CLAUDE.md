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
```bash
./build-dmg.sh
# Output: build/NotchNoti-1.0.0.dmg
```

The DMG build script:
- Builds Release configuration without code signing
- Creates DMG with app and /Applications symlink
- Generates README.txt with installation instructions
- Output location: `build/NotchNoti-1.0.0.dmg`

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
- Controls content types: `normal`, `menu`, `settings`, `history`
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
- `NotificationServer.swift`: HTTP server on port 9876 with `/notify` and `/health` endpoints
- Both parse JSON notification requests and feed into `NotificationManager`

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

**Event Handling** (`EventMonitors.swift`, `EventMonitor.swift`)
- Global mouse and keyboard event monitoring
- Drag-and-drop detection for notch interaction
- Click outside detection for auto-closing

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
  "metadata": {"key": "value"}
}
```

## System Requirements
- macOS 13.0+ (Ventura)
- MacBook Pro (2021+) or MacBook Air (2022+) with notch
- Recommended: ProMotion display for 120Hz animations

## Development Notes

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
