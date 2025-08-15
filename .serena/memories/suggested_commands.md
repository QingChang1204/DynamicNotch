# Suggested Commands for NotchNoti Development

## Build Commands

### Build Release Version
```bash
xcodebuild -scheme NotchNoti -configuration Release build
```

### Build Debug Version
```bash
xcodebuild -scheme NotchNoti -configuration Debug build
```

### Create DMG Package
```bash
./build-dmg.sh
```
This script will:
- Build the Release version
- Create a DMG installer
- Include README and installation instructions
- Output: `build/NotchNoti-1.0.0.dmg`

## Running the Application

### Run from Xcode
```bash
open NotchNoti.xcodeproj
# Then use Xcode's Run button or Cmd+R
```

### Run Built App
```bash
open build/Release/NotchNoti.app
```

## Testing Notifications

### Send Test Notification
```bash
# Success notification
curl -X POST http://localhost:9876/notify \
  -H "Content-Type: application/json" \
  -d '{"title":"✅ Test Success","message":"Build completed","type":"success","priority":2}'

# Error notification
curl -X POST http://localhost:9876/notify \
  -H "Content-Type: application/json" \
  -d '{"title":"❌ Test Error","message":"Build failed","type":"error","priority":3}'

# AI notification
curl -X POST http://localhost:9876/notify \
  -H "Content-Type: application/json" \
  -d '{"title":"🤖 AI Analysis","message":"Processing...","type":"ai"}'
```

## Git Commands

### Common Git Operations
```bash
git status
git add .
git commit -m "feat: your message"
git push origin main
```

## System Utilities (macOS/Darwin)

### File Operations
```bash
ls -la          # List files with details
find . -name "*.swift"  # Find Swift files
grep -r "pattern" .     # Search in files
```

### Process Management
```bash
ps aux | grep NotchNoti  # Check if app is running
killall NotchNoti        # Stop the app
```

### Network Debugging
```bash
lsof -i :9876   # Check what's using port 9876
netstat -an | grep 9876  # Check port status
```

## Development Tools

### Clean Build
```bash
xcodebuild clean
rm -rf ~/Library/Developer/Xcode/DerivedData
```

### View Console Logs
```bash
log show --predicate 'subsystem == "com.qingchang.notchnoti"' --info
```

## Note on Testing/Linting
This project does not currently have:
- Unit tests or test framework configured
- SwiftLint or SwiftFormat for code linting
- Continuous Integration setup

Consider adding these tools if code quality automation is needed.