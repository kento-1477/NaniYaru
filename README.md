# NaniYaru

## Development Workflow
- `main` direct push is not allowed.
- Use branch + PR + CI + auto-merge.
- See: `docs/ci-and-pr-workflow.md`

## Local Test
```bash
xcodebuild \
  -project NaniYaru.xcodeproj \
  -scheme NaniYaru \
  -destination "platform=iOS Simulator,name=iPhone 16" \
  CODE_SIGN_ALLOW_ENTITLEMENTS_MODIFICATION=YES \
  test
```
