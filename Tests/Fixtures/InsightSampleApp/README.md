# InsightSampleApp Fixture

Generate the Xcode project with XcodeGen, then run tests with `xcodebuild` to create new `.xcresult` bundles.

Steps:
1. `xcodegen generate --spec project.yml`
2. `xcodebuild -project InsightSampleApp.xcodeproj -scheme InsightSampleApp -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -resultBundlePath <path>/InsightSampleApp.xcresult test`

Notes:
- `InsightSampleAppTests` includes expected failure, skip, performance, and conditional failure cases.
- Set `INSIGHT_FORCE_FAILURE=1` in the environment to force a failing test.
- `InsightSampleAppUITests` includes a basic launch test and a launch performance test.
