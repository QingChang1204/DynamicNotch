# Code Style and Conventions

## Swift Coding Standards

### Naming Conventions
- **Classes/Structs/Enums**: PascalCase (e.g., `NotchNotification`, `NotificationManager`)
- **Functions/Methods**: camelCase (e.g., `applicationDidFinishLaunching`, `findScreenFitsOurNeeds`)
- **Properties/Variables**: camelCase (e.g., `isFirstOpen`, `mainWindowController`)
- **Constants**: camelCase (e.g., `bundleIdentifier`, `appVersion`)
- **View Files**: Suffixed with "View" (e.g., `NotchView`, `NotificationView`, `DiffView`)
- **Controller Files**: Suffixed with "Controller" (e.g., `NotchWindowController`, `NotchViewController`)
- **Model Files**: Descriptive names (e.g., `NotificationModel`, `NotificationServer`)

### File Organization
- Extensions prefixed with "Ext+" (e.g., `Ext+NSScreen.swift`, `Ext+URL.swift`)
- One major type per file
- Related functionality grouped together
- View models suffixed with "ViewModel"

### Code Structure
- Use of SwiftUI for UI components
- AppKit integration where needed (NSWindow, NSViewController)
- Combine framework for reactive programming
- Property wrappers like `@Published`, `@State`, `@StateObject`
- Custom property wrapper `@PublishedPersist` for persisted state

### Type System
- Strong typing throughout
- Explicit type declarations where beneficial for clarity
- Use of enums for fixed sets of values (NotificationType, Priority)
- Structs for data models (NotchNotification)
- Classes for controllers and managers

### Access Control
- Appropriate use of `private`, `internal`, `public`
- Properties marked with appropriate access levels
- Use of computed properties for derived values

### Comments and Documentation
- Minimal inline comments (code should be self-documenting)
- Chinese comments in some configuration files (e.g., build script)
- No extensive documentation blocks in Swift files

### Error Handling
- Use of optionals and safe unwrapping
- Guard statements for early returns
- Proper error propagation where needed

### Modern Swift Features
- Swift 5.9 features utilized
- Async/await patterns where appropriate
- SwiftUI's declarative syntax
- Combine for data flow

### Project Structure
```
NotchNoti/
├── Main App Files (AppDelegate, main.swift)
├── Windows & Controllers (NotchWindow, NotchWindowController, etc.)
├── Views (NotchView, NotificationView, DiffView, etc.)
├── View Models (NotchViewModel, NotchViewModel+Events)
├── Models (NotificationModel, NotificationServer)
├── Effects & Animations (NotificationEffects)
├── Utilities & Extensions (Ext+*.swift files)
├── Configuration (PerformanceConfig, ClaudeCodeSetup)
├── Networking (NotificationServer, UnixSocketServerSimple)
└── Resources (Assets.xcassets, Localizable.xcstrings)