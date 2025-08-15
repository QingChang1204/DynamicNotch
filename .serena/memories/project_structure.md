# NotchNoti Project Structure

## Root Directory
```
DynamicNotch/
├── NotchNoti/              # Main application source code
├── NotchNoti.xcodeproj/    # Xcode project configuration
├── Resources/              # Additional resources
├── build-dmg.sh           # DMG packaging script
├── README.md              # Project documentation
├── LICENSE                # MIT License
└── .gitignore            # Git ignore rules
```

## NotchNoti Source Directory Structure

### Core Application Files
- `main.swift` - Application entry point, sets up app delegate
- `AppDelegate.swift` - Main application delegate, handles lifecycle
- `NotchNoti.entitlements` - App sandbox and permissions
- `Info.plist` - Application configuration

### Window Management
- `NotchWindow.swift` - Custom NSWindow for notch display
- `NotchWindowController.swift` - Window controller
- `NotchViewController.swift` - View controller for notch window

### Views (SwiftUI)
- `NotchView.swift` - Main notch view container
- `NotchContentView.swift` - Content area of notch
- `NotchHeaderView.swift` - Header section of notch
- `NotchMenuView.swift` - Menu/settings view
- `NotchSettingsView.swift` - Settings interface
- `NotificationView.swift` - Individual notification display
- `DiffView.swift` - Code diff preview window

### View Models & Data
- `NotchViewModel.swift` - Main view model
- `NotchViewModel+Events.swift` - Event handling extension
- `NotificationModel.swift` - Notification data structures
- `NotificationManager.swift` - Notification queue management

### Networking & Communication
- `NotificationServer.swift` - HTTP server (port 9876)
- `UnixSocketServerSimple.swift` - Unix socket server
- `notch-hook` - Hook system binary

### Effects & Animations
- `NotificationEffects.swift` - Visual effects and animations
- `PerformanceConfig.swift` - Performance optimization settings

### Utilities & Extensions
- `Ext+NSScreen.swift` - Screen utilities
- `Ext+NSImage.swift` - Image handling
- `Ext+NSAlert.swift` - Alert dialogs
- `Ext+URL.swift` - URL utilities
- `Ext+FileProvider.swift` - File system access
- `PublishedPersist.swift` - Persistent state wrapper

### Event Monitoring
- `EventMonitor.swift` - Base event monitor
- `EventMonitors.swift` - Specific event monitors

### Configuration & Setup
- `ClaudeCodeSetup.swift` - Claude Code integration
- `Language.swift` - Localization support

### Resources
- `Assets.xcassets/` - Images, icons, colors
- `Localizable.xcstrings` - Localized strings
- `InfoPlist.xcstrings` - Plist localizations

## Build Output
```
build/
├── Release/
│   └── NotchNoti.app
├── Debug/
│   └── NotchNoti.app
└── NotchNoti-1.0.0.dmg  # After running build-dmg.sh
```

## Key Architectural Patterns
1. **MVC-like Structure**: Controllers manage windows, Views handle UI, Models contain data
2. **SwiftUI + AppKit**: Hybrid approach using SwiftUI for views, AppKit for window management
3. **Reactive Programming**: Combine framework for data flow
4. **Singleton Services**: NotificationManager for centralized notification handling
5. **Protocol-Oriented**: Event monitoring system uses protocols