# Task Completion Checklist

When completing a coding task in the NotchNoti project, follow these steps:

## 1. Code Verification
- [ ] Ensure all Swift code follows the project's naming conventions
- [ ] Check that new files follow the existing file organization pattern
- [ ] Verify SwiftUI views are properly structured
- [ ] Ensure proper use of access control modifiers

## 2. Build Verification
```bash
# Build the project to ensure no compilation errors
xcodebuild -scheme NotchNoti -configuration Debug build
```

## 3. Manual Testing
Since there are no automated tests:
- [ ] Run the application locally
- [ ] Test new notification types if added
- [ ] Verify HTTP API endpoints still work
- [ ] Check that the notch display renders correctly

## 4. API Testing (if network code was modified)
```bash
# Test the notification API
curl -X POST http://localhost:9876/notify \
  -H "Content-Type: application/json" \
  -d '{"title":"Test","message":"Testing changes","type":"info"}'
```

## 5. Visual Verification
- [ ] Check animations run smoothly
- [ ] Verify ProMotion 120Hz support (if on capable hardware)
- [ ] Test both light and dark mode appearances

## 6. Performance Check
- [ ] Ensure no memory leaks (use Instruments if needed)
- [ ] Verify animations use Metal/GPU acceleration properly
- [ ] Check CPU usage remains reasonable

## 7. Documentation Updates
- [ ] Update README.md if new features were added
- [ ] Update API examples if endpoints changed
- [ ] Document any new notification types or parameters

## 8. Before Committing
- [ ] Review all changed files
- [ ] Ensure no debugging code remains
- [ ] Check no hardcoded values that should be configurable
- [ ] Verify no sensitive information in code

## Note
Since this project lacks automated testing and linting tools:
- Be extra careful with manual testing
- Consider adding SwiftLint configuration if making significant changes
- Suggest implementing unit tests for critical functionality