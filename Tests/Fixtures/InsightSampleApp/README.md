# InsightSampleApp Fixture

Open `Package.swift` in Xcode, select an iOS simulator, and run tests to generate new `.xcresult` bundles.

Notes:
- `InsightSampleAppTests` includes expected failure, skip, performance, and conditional failure cases.
- Set `INSIGHT_FORCE_FAILURE=1` in the test plan environment to force a failing test.
- `InsightSampleAppUITests` includes a basic launch test and a launch performance test.
