# NotchNoti Project Overview

## Purpose
NotchNoti is a macOS native application that transforms the MacBook's notch area into an intelligent notification center. It provides visual notifications with unique animations for 14 different notification types.

## Key Features
- **Notch Notification Display**: Shows notifications elegantly in the MacBook notch area
- **HTTP API Service**: REST API on port 9876 for sending notifications
- **Unix Socket Support**: Alternative communication via Unix socket
- **Notification Queue Management**: Smart queue system that doesn't lose notifications
- **Priority System**: 4 priority levels (Low/Normal/High/Urgent)
- **Notification Merging**: Automatically merges consecutive notifications from the same source
- **History Management**: LRU cache for last 100 notifications
- **Diff Preview**: Code change comparison preview window
- **Notification Sounds**: Configurable system notification sounds

## Notification Types (14 types with unique animations)
1. Success - Check mark with elastic scaling + green glow
2. Error - Vibration effect + red-orange gradient
3. Warning - Pulse flash + dynamic shadow
4. Info - Ripple expansion + breathing effect
5. Hook - Link elastic animation + continuous pulse
6. Tool Use - 360° rotation + swing animation
7. Progress - Gradient ring loop rotation
8. Celebration - Golden star particle rain + bounce animation
9. Reminder - Pendulum swing effect
10. Download - Drop down animation + circular progress bar
11. Upload - Jump up animation + circular progress bar
12. Security - Red warning flash + pulse glow
13. AI - Dynamic gradient background + breathing pulse
14. Sync - 360° continuous rotation

## Tech Stack
- **Language**: Swift 5.9
- **UI Framework**: SwiftUI
- **macOS Target**: 13.0+ (Ventura and above)
- **Networking**: Network.framework (native)
- **Reactive Programming**: Combine framework
- **Rendering**: Metal for GPU acceleration
- **Display Support**: ProMotion 120Hz optimization

## Integration Points
- Claude Code integration for AI operations monitoring
- Git hooks support
- npm scripts integration
- VS Code/Cursor task integration
- General HTTP API for any application

## Target Hardware
- MacBook Pro (2021+) with notch display
- MacBook Air (2022+) with notch display