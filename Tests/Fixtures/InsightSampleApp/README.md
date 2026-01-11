# InsightSampleApp Fixture

Generate the Xcode project with XcodeGen, then run tests with `xcodebuild` to create new `.xcresult` bundles.

Steps:
1. `xcodegen generate --spec project.yml`
2. `xcodebuild -project InsightSampleApp.xcodeproj -scheme InsightSampleApp -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -resultBundlePath <path>/InsightSampleApp.xcresult test`
3. `xcodebuild -project InsightSampleApp.xcodeproj -scheme InsightSampleAppFailure -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -resultBundlePath <path>/InsightSampleApp-failure.xcresult test`
4. `xcodebuild -project InsightSampleApp.xcodeproj -scheme InsightSampleAppFlaky -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -resultBundlePath <path>/InsightSampleApp-flaky.xcresult test`

Notes:
- `InsightSampleAppTests` includes expected failure, skip, performance, and conditional failure cases.
- The `InsightSampleAppFailure` scheme sets `INSIGHT_FORCE_FAILURE=1` for the test run.
- The `InsightSampleAppFlaky` scheme sets `INSIGHT_FLAKY=1` to enable the flaky test.
- `InsightSampleAppUITests` includes a basic launch test and a launch performance test.
