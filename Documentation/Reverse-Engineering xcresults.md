Reverse-Engineering Xcode’s .xcresult Format

Understanding the .xcresult Bundle Structure and Encoding

An Xcode .xcresult is not a single flat file but a bundle (directory) containing test results, logs, code coverage, and attachments from a build/test run ￼ ￼. Inside the bundle, Xcode stores data in a binary, database-like format, rather than human-readable plist or JSON. In fact, with Xcode 11 Apple introduced Result Bundle version 3, which uses Zstandard compression for its internal data files ￼. Each .xcresult bundle includes an Info.plist (with metadata like the format version) and one or more data files that hold the actual result objects in compressed form. Attachments (screenshots, logs, etc.) are embedded in the bundle as well – often in subdirectories (e.g. a Diagnostics folder for logs) – and are referenced by unique IDs in the data files.

At the top of the result data structure is an ActionsInvocationRecord object, which is the root of the result bundle’s object graph ￼ ￼. This root contains arrays of actions (each action might correspond to a test plan or build action) and various metadata. Each action in turn contains an ActionResult with references (by ID) to detailed data: for example, testsRef, diagnosticsRef, and logRef are references to the test results, diagnostics data, and build log respectively ￼ ￼. These references are stored as opaque identifiers (often looking like base64 strings) which serve as keys into the result bundle’s data store. The bundle effectively acts as a key-value store of objects: given an object ID, Xcode’s tool can retrieve the corresponding object or binary file. For instance, the testsRef ID points to an ActionTestPlanRunSummaries object containing the full hierarchy of test suites/cases and their results ￼ ￼. Similarly, each attachment (like a screenshot image or a .log file) has an ID that can be used to extract that file from the bundle.

Because of this design, the raw contents of the .xcresult bundle appear as opaque binary blobs. In fact, Apple’s official guidance is to use the xcresulttool utility (bundled with Xcode) to query these bundles ￼. The tool reads the compressed binary data and outputs either JSON or the raw file data for a given reference. The internal encoding is not documented in plain terms by Apple, but evidence strongly suggests that it’s based on Google Protocol Buffers (Protobuf) or a similar serialization scheme. Notably, the Xcode runtime includes the Swift Protobuf library (you can see com.apple.protobuf.SwiftProtobuf loaded alongside Xcode’s XCResultKit) ￼, and the structure of the JSON output (with _name types and _value fields) closely aligns with how Protobuf objects could be represented in JSON. In other words, the .xcresult data files are likely serialized Protobuf messages (compressed with Zstd for space efficiency) rather than something like a SQLite database. This explains why the format can change across Xcode versions without backward compatibility – Apple can evolve the Protobuf schema, and they expect developers to use the provided tool or schema description to adapt ￼ ￼.

To summarize, a .xcresult bundle contains:
	•	An Info.plist with metadata (like result bundle version, etc.).
	•	One or more data blobs (Zstd-compressed) that store the object graph (likely as Protobuf-encoded objects). All top-level results are under the ActionsInvocationRecord root.
	•	Subdirectories for attachments or logs (e.g. Attachments, Diagnostics), where actual files (images, .log text, .plist sub-reports, etc.) are stored. These are referenced by IDs in the object graph.

The result schema includes dozens of object types (Action records, Test summaries, Issue summaries, Code coverage reports, etc.). Apple made this schema discoverable via xcresulttool. Running xcrun xcresulttool formatDescription yields a full JSON schema of all object types, properties and their relationships ￼ ￼. (The root type is ActionsInvocationRecord, as mentioned in Xcode’s man pages ￼.) This schema essentially documents the structure one needs to parse – it’s the analog of a .proto definition or class model for the result bundle. Tools and libraries can use it to dynamically parse results in a future-proof way.

Existing Open-Source Efforts to Parse .xcresult

Several community tools have emerged to extract data from .xcresult bundles, but almost all rely on Apple’s xcresulttool (or related Xcode command-line tools) under the hood, rather than fully reimplementing the format parser from scratch. For example:
	•	xcresultparser (by a7ex) – an open-source Swift CLI that converts .xcresult into various formats (JUnit XML, JSON, HTML, etc.). It works by invoking Xcode’s own tools: it uses xcresulttool to get the high-level JSON, and xccov (for coverage) to get coverage info, then parses those outputs in Swift ￼ ￼. Internally it leverages Apple’s schema by using the XCResultKit library to map JSON to Swift types ￼. This tool is Mac-only (since it calls Xcode utilities) and essentially automates what you’d do manually with xcresulttool.
	•	xcparse (by ChargePoint) – another CLI that specifically extracts attachments (screenshots) and coverage. ChargePoint’s blog explains that with Xcode 11’s new format, they used xcresulttool to dump JSON from the bundle and then decoded it using Swift’s Codable against the known schema types ￼ ￼. xcparse doesn’t itself read the binary format – it relies on Apple’s tool to produce JSON first ￼.
	•	XCResultKit – a Swift package by David House that provides a native API to navigate .xcresult data in Swift. Under the covers, it too calls out to xcresulttool to fetch the contents of the result bundle (there is even a version check and call to the tool in the code) and then wraps the JSON in Swift types for convenience ￼ ￼. It essentially shields you from dealing with the JSON manually but is not independent of Apple’s parsing. (It’s included in Xcode’s toolchain as a private framework, which is why it can be used via xcrun.)
	•	Other parsers and reporters: Tools like XCTestHTMLReport and Allure reporting integrations also lean on the above libraries or the xcresulttool JSON output. For instance, Allure’s XCResults integration expects you to use the standard Xcode results – their docs simply suggest using the results bundle or converting via tools ￼. XCTestHTMLReport originally parsed the older TestSummaries.plist and later switched to using XCResultKit when Xcode 11 arrived (because the plist went away) – again piggybacking on Apple’s logic.

Notably, no well-known open-source project has fully re-implemented the .xcresult binary decoder from scratch for cross-platform use. All current solutions require running on macOS (with Xcode installed) so that xcresulttool or related binaries are available. This means on CI systems, developers often export the .xcresult from a macOS build agent and then either convert it to JSON or another format on the Mac, or upload it for later examination in Xcode. As Codecov’s team noted, these files “can be difficult to use outside the Apple ecosystem” because of their proprietary binary format ￼. The Codecov GitHub Action, for example, by default calls xccov/xcresulttool to convert coverage data one file at a time, which was slow ￼ ￼. This led the community to create faster converters (like xcresultparser) but still, those require macOS.

One semi-exception is the Cachi/CachiKit project (by Subito) which provides a web viewer for test results. Cachi is written in Swift and advertises parsing .xcresult files for a web UI ￼, but it too runs on Mac and uses the native frameworks. It doesn’t free us from Apple’s parsing; it just presents the data nicely via a server. In short, while you can find many tools to extract or transform .xcresult data, they assume you can run Apple’s tools or at least Swift libraries on a Mac. There isn’t yet an official cross-platform parser in, say, pure Python or Rust that reads the bytes directly – creating one is exactly the challenge here.

.xcresult and Protobuf – Hints of the Underlying Format

Although Apple hasn’t published “.proto” schema files for the result bundle, there are strong hints that Protobuf is the foundation:
	•	As mentioned, Xcode’s private XCResultKit framework links against SwiftProtobuf ￼. This implies the result objects are defined as Swift Protobuf messages. It’s likely Apple chose Protobuf for its efficient binary encoding and schema evolution capabilities (which they leverage to evolve the format between Xcode versions).
	•	The JSON output from xcresulttool corresponds to the Protobuf JSON encoding of those messages. For example, in the JSON, each object has a "_type": { "_name": "TypeName" } and then its fields. Fields that are primitive types appear with "_value" keys ￼ ￼. This is exactly how Protobuf’s JSON representation would include type info and use a special key for the value of scalar fields. An array (repeated field) is represented with "_values": [ ... ] ￼ ￼. The presence of these markers suggests the data was originally a typed object that the tool is serializing to JSON for us. In Protobuf terms, the Reference type (for IDs) likely contains a string field (the ID value), hence the JSON shows id { _value: "…ID…" ￼.
	•	Each object type (ActionRecord, TestSummary, etc.) in the formatDescription schema corresponds to a Protobuf message. The schema even shows inheritance (some types have superclasses or “subtypes” in the JSON schema) ￼, which Protobuf might model via oneOf or simply separate messages. Apple’s decision to provide a machine-readable schema is reminiscent of how one would share .proto definitions without exposing the raw files – they give you a JSON schema to use for parsing.

So while we don’t have the official .proto, we can infer the structure. The Xcode 11 release notes (as captured in Fastlane’s issue) indicate that “a JSON representation of the root object can be exported” and “xcresulttool also provides the description of its format”, explicitly so third parties can parse future versions ￼ ￼. This is essentially Apple confirming: use the schema, not the binary, as your contract. They anticipated that third-party developers might write code to interpret these results, and provided xcresulttool as the gateway.

For a reverse-engineer, all this means .xcresult likely contains one or more Protobuf message blobs (serialized binary), possibly indexed by a table of contents. The Zstandard compression could be applied at the file level or even per-message. In practice, developers have noticed that some attachments in Xcode 12+ .xcresult bundles came out as “standard compressed data” requiring decompression before use ￼. This suggests that not only the main result file, but possibly large attachments (screenshots, etc.) are stored compressed to save space.

Strategies to Reverse Engineer and Parse .xcresult Without Xcode

Building a cross-platform parser involves tackling both compression and serialization:
	•	Handling Compression: The first step is to identify and decompress the data. Given the known use of Zstandard (zstd), you can use a zstd library on Linux to decompress .xcresult contents. If you inspect the bundle files with a hex editor or file command after extracting the package, you might find the Zstd magic bytes (0xFD2FB528) at the start of certain files. Indeed, the “database-like” files in the bundle are likely .dat files compressed with zstd. You will need to decompress those to get the raw serialized data. (In some cases, attachments might be double-compressed – e.g., an image might already be a PNG, which Xcode still wrapped in zstd. The parser should detect this and decompress accordingly.)
	•	Decoding the Serialized Data: Once decompressed, you’ll have the binary blob of the result objects. If our Protobuf assumption is correct, the challenge is to decode it. There are a few approaches:
	1.	Obtain or reconstruct the Protobuf schema – This is the ideal scenario. If you had the .proto definitions for the result bundle, you could simply use protoc on them to generate code in your language of choice (C++, Go, Rust, etc.), then feed the binary data to the generated classes for parsing. While Apple hasn’t published the schema, you can reconstruct a close equivalent:
	•	Use xcresulttool formatDescription --format json on a sample .xcresult (you’d need a Mac for this one-time step, or find the output posted online) to get the full schema in JSON form. From this, you can deduce message names, field names, and data types. You won’t directly get field numbers, but the schema likely lists properties in order, and field numbers might correspond to some stable ordering.
	•	Additionally, you can leverage the fact that Xcode’s XCResultKit is compiled with SwiftProtobuf. Advanced reverse-engineering tools like Arkadiy’s Protobuf extractor can scan a compiled binary for Protobuf descriptors ￼. This has been done in other contexts: by scanning Xcode’s binaries or the XCResultKit framework, one might extract the embedded .proto or at least the descriptor data (which includes field numbers and types). There are CLI tools and scripts (e.g. the open-source pbtk tool ￼ or Arkadiy’s ProtobufExtractor blog ￼) that automate pulling out Protobuf schema from apps. Using such a tool on XCResultKit could yield actual .proto files for the result bundle messages.
	•	If extracting the descriptors is difficult, one could also manually map out a few messages by comparing the JSON output to the binary. For example, if you know testsCount in JSON was “2” ￼, you could search the decompressed binary for the value 0x02 (in VarInt form) and see its field tag, etc. This is tedious, but doable for confirming field numbers.
In summary, recovering the schema is a crucial step. Once you have a schema (even if slightly approximate), you can leverage Protobuf libraries on Linux to parse the data. If the schema isn’t exact, Protobuf parsing might still succeed for known fields and ignore unknown ones (which gives flexibility across versions).
	2.	Use JSON as an intermediary – A less elegant but practical approach is to mimic what existing tools do: invoke Apple’s tool in an automated way to get JSON, then parse that JSON cross-platform. Since the goal is to not depend on Xcode at runtime, you might still consider using it at design-time. For instance, you could maintain a suite of tests where you run xcresulttool on example result bundles to produce JSON, and use those as reference outputs for your parser. From the JSON, construct your own data models (classes or structs) in the new tool. Essentially, you use Apple’s tool to guide development but not in production. This doesn’t free you from needing a Mac somewhere (at least to generate sample data or if you want to dynamically support new Xcode versions’ schema). However, you could also embed the schema JSON in your tool and use it for guidance when parsing binaries.
	3.	Treat it as a black box binary format – parse everything manually from scratch. This would involve reading the binary at the byte level, figuring out lengths, offsets, etc. If it truly is Protobuf, writing a custom decoder is reinventing the wheel (better to use a Protobuf lib once you know the schema). If it were an SQLite database, one could open it with SQLite libraries – but it’s not SQLite (after decompression you won’t find the SQLite header). Thus, a manual parse means essentially writing a Protobuf decoder without .proto files – not recommended given the complexity of the format (nested messages, strings, repeated fields, etc.). A far better use of time is extracting the schema or using an existing Protobuf decoding approach.
	•	Use of Reverse-Engineering Tools: As mentioned, tools like protoc (with --decode or --decode_raw) can be helpful if you have partial info. For example, protoc --decode_raw will try to heuristically decode a binary blob without a schema – it won’t give field names but can outline the structure (it will show field numbers and data types). This might confirm whether it’s Protobuf (most likely yes). Another tool is protod (Protocol Buffer Decoder) which can sometimes make educated guesses about message structure. Utilizing these on a decompressed .xcresult main file could quickly validate your assumptions about the format. There are also community scripts for parsing unknown Protobuf streams – those could give you a head-start on identifying message boundaries and field tags.
	•	Leverage Apple’s Format Description at runtime? Since Apple provided the schema in JSON form via xcresulttool, one creative idea is to ship a small JSON schema with your tool and use it to drive a generic parser. For instance, one could write a program that reads the format description JSON (which lists all types, their properties, and types of each property) and then uses reflection to decode a binary given that metadata. This is quite advanced, but essentially you’d be writing a mini Protobuf interpreter using Apple’s schema as the definition. While intriguing, this likely duplicates the work of just using Protobuf libraries – if you can get the schema, it’s simpler to compile it into concrete classes.

Given all the above, the most feasible path is: extract the Protobuf schema and use a Protobuf library. This aligns with how Xcode itself likely works (they have generated classes for the results). By doing this, you future-proof your solution because if Apple adds new fields, the schema approach will allow you to ignore unknown fields or update the schema accordingly (just as they intended with the JSON formatDescription being available).

Guidance and Resources for Building the Parser
	1.	Start with Apple’s documentation (indirect as it is): Review the Xcode 11 release notes snippet about result bundles ￼ ￼ to understand the intended usage. It explicitly mentions using xcresulttool and highlights that the format can change, which is why using the schema is important. Also, use xcresulttool formatDescription yourself (if possible) on a sample result to get the full picture of object types and relationships.
	2.	Examine sample outputs: Use simple Xcode projects to generate .xcresult bundles (for instance, run a trivial unit test) and run xcresulttool get --format json to dump the JSON. This will let you see real-world examples of the JSON structure for tests, failures, attachments, etc. (You already have a head start with samples from Chromium’s scripts ￼ ￼ which show pieces of the JSON.) Seeing these will help confirm how data is nested and where IDs point to actual files.
	3.	Use Protobuf reverse-engineering tools: If you have access to a Mac, locate the XCResultKit.framework (within Xcode’s bundle) and attempt to extract proto descriptors. The arkadiyt/ProtoDetox or similar CLI can scan binaries for the \x0a\x0b patterns that denote serialized FileDescriptorProtos ￼. If successful, this could yield a nearly complete .proto file for the result bundle types. Alternatively, the pbtk project on GitHub might assist in extracting or reconstructing the schemas from the binary ￼. This is an advanced step, but the payoff is huge: you’d get field names and numeric tags.
	4.	Implement stepwise decoding: For each section of the result:
	•	Invocation record and actions: Once decompressed, decode the root ActionsInvocationRecord message. This will give you arrays of ActionRecord (one per test run or build run). Each ActionRecord contains references (IDs) for further data. Your parser should store a mapping of ID -> object (or ID -> file path if the object is an external file). Likely the bundle has an indexed table of all objects by ID – possibly the entire blob is one big message that contains sub-messages with IDs. Ensure you can handle looking up an object by ID. (This might involve first reading a top-level index message that maps IDs to byte offsets – if Apple did something like that. It’s not clear if they did, or if they simply rely on the Protobuf internal structure. The presence of explicit IDs in JSON suggests the IDs are actual data fields, not low-level memory addresses, so possibly the bundle doesn’t need an external index – the IDs themselves might be keys to find external files in the bundle directories.)
	•	Attachments and logs: Plan to extract files by their ID. Often, the diagnosticsRef and others ultimately refer to directories or files in the .xcresult. For example, a log might be stored as an actual text file in ./<uuid>_Test/Diagnostics/.../Test.log inside the bundle. The xcresulttool export commands simply copy those out. Your tool can mimic this by reading the file directly once you know the path or by interpreting any directory structure encoded in the bundle. (The Info.plist might list some top-level folder structure or naming convention for these files.)
	•	Coverage data: Xcode also stores code coverage in the result (if enabled) as .xccov archives within the bundle. Those are yet another format (also not simple JSON – they have their own tool xccov). If cross-platform coverage is a goal, you might consider invoking the open-source llvm-cov (if you can convert Xcode’s coverage to LCOV). However, if focusing on tests and logs, you can possibly skip in-depth coverage parsing (or use xcresultparser output as a reference).
	5.	Testing and Validation: As you develop your parser library, continuously validate it against Xcode’s output. For example, run your tool on a .xcresult and also run xcresulttool on the same bundle, then compare key data (number of tests, names of failed tests, etc.) to ensure your interpretation is correct. This is crucial as a sanity check, since reverse engineering can miss subtle details (e.g., a field being optional vs repeated).
	6.	Community references and support: Keep these references handy:
	•	The Fastlane trainer PR discussion for Xcode 11 ￼ ￼ – it outlines the steps needed to parse results and confirms no TestSummary.plist exists in new format.
	•	Isaac Halvorson’s Codecov blog ￼ – underscores why we need a conversion (useful when justifying the effort).
	•	The Codecov example and xcresultparser README – to understand how others structure the output (you might even choose to piggy-back on their JSON schema or output format for initial implementation).
	•	Apple Developer Documentation (if any) on Result Bundles. For instance, Xcode 16.3 release notes mention improvements to xcresulttool (like a new --legacy flag to read older bundles) ￼ ￼. This tells you that as Xcode evolves, you may need to update the parser for new schema versions (or support multiple versions).
	•	Chromium’s xcode_log_parser.py script – it uses xcresulttool in a clever way (calls once to get root JSON, then uses the IDs) ￼ ￼. Reading that script can give insight into the sequence of steps to traverse the result graph. While they rely on Apple’s tool, the traversal logic (get root -> find testsRef -> get tests details -> find failures, etc.) is instructive for your own traversal code once you can decode the data.
	7.	Plan for schema evolution: It’s wise to design your library to be tolerant to unknown fields. If using Protobuf, set the decoder to ignore unknown fields (this is default in most Protobuf libs). This way, if Apple adds new data (say a new metric or a new type of attachment), your parser won’t break – it just won’t have a field for that, but everything else still parses. You might even include a mode to output warnings if an unknown field is encountered (to easily spot when a new Xcode version has introduced changes).

By following these strategies, you can incrementally build a cross-platform CLI and library to parse .xcresult. In summary: use the available schema descriptions, harness Protobuf tooling to avoid reinventing parsing logic, and validate against Apple’s outputs. The result will be an open-source tool that can run on Linux (or anywhere) and directly consume Xcode result bundles – freeing you from needing Mac-specific tools for result analysis.

References
	•	Apple Xcode 11 Release Notes (Result Bundles format v3 and usage of xcresulttool) ￼ ￼.
	•	Discussion in Fastlane trainer about Xcode 11’s new .xcresult format using Zstandard compression ￼.
	•	Chromium Project’s sample JSON output of xcresulttool – illustrates the structure of an ActionsInvocationRecord and nested references ￼ ￼.
	•	ChargePoint engineering blog on xcparse (using xcresulttool JSON and Codable models) ￼ ￼.
	•	Codecov blog “Pre-Converting .xcresult Files…” – confirms .xcresult is a binary format not directly usable by typical tools ￼ and discusses using xcresultparser to convert it.
	•	The open-source xcresultparser README – notes that it relies on Xcode 13’s xcresulttool/xccov to get JSON, parsed via XCResultKit ￼ ￼.
	•	Evidence of Protobuf usage in Xcode’s result processing (XCResultKit loading SwiftProtobuf) ￼.
	•	Pol Piella’s blog “How to programmatically parse an XCResult bundle” – provides context on what an .xcresult contains and why it isn’t human-readable ￼ ￼.

Debug/Reverse-Engineering Workflow (Project Notes)

Use the xcresulttool JSON as the oracle, then map fields to SQLite tables.

CLI quick reference
	•	openxcresulttool get test-results summary --path Tests/Fixtures/<bundle>.xcresult --format json
	•	openxcresulttool get test-results tests --path Tests/Fixtures/<bundle>.xcresult --format json
	•	openxcresulttool get test-results test-details --path Tests/Fixtures/<bundle>.xcresult --test-id "<TestId>" --format json
	•	openxcresulttool get test-results activities --path Tests/Fixtures/<bundle>.xcresult --test-id "<TestId>" --format json
	•	openxcresulttool get test-results metrics --path Tests/Fixtures/<bundle>.xcresult --format json
	•	openxcresulttool get test-results insights --path Tests/Fixtures/<bundle>.xcresult --format json
	•	openxcresulttool get build-results --path Tests/Fixtures/<bundle>.xcresult --format json
	•	openxcresulttool get content-availability --path Tests/Fixtures/<bundle>.xcresult --format json
	•	openxcresulttool get log --path Tests/Fixtures/<bundle>.xcresult --type build --format json
	•	openxcresulttool get log --path Tests/Fixtures/<bundle>.xcresult --type action --format json
	•	openxcresulttool get object --legacy --path Tests/Fixtures/<bundle>.xcresult --id "<ObjectId>" --format json
	•	openxcresulttool export diagnostics --path Tests/Fixtures/<bundle>.xcresult --output-path ./Diagnostics
	•	openxcresulttool export attachments --path Tests/Fixtures/<bundle>.xcresult --output-path ./Attachments
	•	openxcresulttool export metrics --path Tests/Fixtures/<bundle>.xcresult --output-path ./Metrics
	•	openxcresulttool export object --legacy --path Tests/Fixtures/<bundle>.xcresult --output-path ./Object --type directory --id "<ObjectId>"
	•	openxcresulttool graph --legacy --path Tests/Fixtures/<bundle>.xcresult [--id "<ObjectId>"]
	•	openxcresulttool formatDescription get --legacy [--format json] [--hash] [--include-event-stream-types]
	•	openxcresulttool formatDescription diff --legacy [--format text | markdown] <version1.json> <version2.json>
	•	openxcresulttool compare <comparison.xcresult> --baseline-path <baseline.xcresult> [--summary] [--test-failures] [--tests] [--build-warnings] [--analyzer-issues]
	•	openxcresulttool merge --output-path <merged.xcresult> <bundle1.xcresult> <bundle2.xcresult> [<bundleN.xcresult>]
	•	openxcresulttool metadata get --path Tests/Fixtures/<bundle>.xcresult
	•	openxcresulttool metadata addExternalLocation --path Tests/Fixtures/<bundle>.xcresult --identifier "<Id>" --link "<URL>" --description "<Description>"
	•	openxcresulttool version

xcresulttool parity map
	•	Implemented (OpenXCResultTool parity targets):
		get test-results summary, tests, insights, test-details, activities, metrics
		get build-results
		get content-availability
		get log (build/action/console)
		get object (legacy JSON/raw, requires --legacy)
		export diagnostics
		export attachments
		export metrics
		export object
		graph
		formatDescription get
		formatDescription diff
		compare
		merge (OpenXCResultTool uses SQLite + Data union; output differs from xcresulttool)
		metadata get
		metadata addExternalLocation
		version
	Merged bundle notes:
		•	When a merged bundle contains multiple actions/test plan runs, `get test-results tests` nests Device → Test Plan Configuration nodes under each Test Case, and summary statistics include the "tests ran on N configurations and M devices" entry. OpenXCResultTool mirrors this behavior.
		•	For `get test-results test-details`/`activities`, `xcresulttool` may require an identifier URL if a test identifier is duplicated across runs.
Core commands
	•	Dump the summary JSON (oracle):
		xcrun xcresulttool get test-results summary --path Tests/Fixtures/<bundle>.xcresult --format json
	•	Inspect the DB schema:
		sqlite3 Tests/Fixtures/<bundle>.xcresult/database.sqlite3 ".tables"
		sqlite3 Tests/Fixtures/<bundle>.xcresult/database.sqlite3 ".schema <Table>"
	•	Quick counts:
		sqlite3 Tests/Fixtures/<bundle>.xcresult/database.sqlite3 "select result, count(*) from TestCaseResultsByDestinationAndConfiguration where destination_fk is null and configuration_fk is null group by result;"

Log parsing (fileBacked2 data.<id>)
	•	Find the logRef IDs (action/build):
		xcrun xcresulttool get object --legacy --path Tests/Fixtures/<bundle>.xcresult --format json
		# actionResult.logRef.id._value and buildResult.logRef.id._value
	•	Inspect the raw object data for a log:
		xcrun xcresulttool get object --legacy --path Tests/Fixtures/<bundle>.xcresult --id "<logRefId>" --format raw
	•	The on-disk payload lives in Data/data.<id> and is usually zstd-compressed.
		Check the magic bytes (0x28 B5 2F FD) and decompress with zstd if present.
	•	Parity oracle for output shape:
		xcrun xcresulttool get log --path Tests/Fixtures/<bundle>.xcresult --type build --format json
		xcrun xcresulttool get log --path Tests/Fixtures/<bundle>.xcresult --type action --format json

Known mappings (summary)
	•	title: Actions.name + " - " + TestPlans.name
	•	start/finish: Actions.started/finished + 978307200 (Core Data epoch)
	•	environmentDescription: Invocations.scheme + " · Built with " + host platform + host OS version
	•	counts: TestCaseResultsByDestinationAndConfiguration (root), TestCaseRuns (per device/config)
	•	testFailures: TestIssues where isTopLevel=1 and testCaseRun_fk is not null

Insights mapping (longestTestRunsInsights)
	•	Source fixture: Tests/Fixtures/Test-Kickstarter-Framework-iOS-2026.01.11_21-21-05-+0200.xcresult
	•	Base dataset: TestCaseRuns joined through TestSuiteRuns -> TestableRuns for a given TestPlanRun.
	•	mean: avg(TestCaseRuns.duration) across all runs (567 in this fixture).
	•	stddev: sqrt(avg(duration * duration) - mean * mean); threshold = mean + (3 * stddev).
	•	associatedTestIdentifiers: TestCases.identifierURL for runs where duration > threshold.
	•	durationOfSlowTests: sum(duration) for runs where duration > threshold (10.948390007019043 here).
	•	impact: "(" + floor(100 * durationOfSlowTests / sum(duration)) + "%)".
	•	meanTime: formatted mean with 1 decimal + " across <count> test runs" (locale-dependent: "0,1s" here).
	•	title: "<count> longest test runs with outlier durations exceeding <threshold>s (three standard deviations)".
	•	targetName: Testables.name via TestSuiteRuns.testableRun_fk -> TestableRuns.testable_fk.
	•	testPlanConfigurationName: TestPlanConfigurations.name via TestPlanRuns.configuration_fk.
	•	deviceName: RunDestinations.name; osNameAndVersion: Platforms.userDescription + " " + Devices.operatingSystemVersion.
	•	Ordering of associatedTestIdentifiers in xcresulttool output still needs confirmation.

SQL sketch (per test plan run)
	•	Base runs:
		select TestCaseRuns.duration, TestCases.identifierURL
		from TestCaseRuns
		join TestCases on TestCases.rowid = TestCaseRuns.testCase_fk
		join TestSuiteRuns on TestSuiteRuns.rowid = TestCaseRuns.testSuiteRun_fk
		join TestableRuns on TestableRuns.rowid = TestSuiteRuns.testableRun_fk
		where TestableRuns.testPlanRun_fk = :testPlanRunId;
	•	Mean/stddev:
		select avg(duration) as mean,
		       sqrt(avg(duration * duration) - (avg(duration) * avg(duration))) as stddev
		from TestCaseRuns
		join TestSuiteRuns on TestSuiteRuns.rowid = TestCaseRuns.testSuiteRun_fk
		join TestableRuns on TestableRuns.rowid = TestSuiteRuns.testableRun_fk
		where TestableRuns.testPlanRun_fk = :testPlanRunId;

Adding fixtures and snapshots
	•	Drop the .xcresult in Tests/Fixtures/.
	•	Generate snapshot JSON:
		xcrun xcresulttool get test-results summary --path Tests/Fixtures/<bundle>.xcresult --format json > Tests/Fixtures/<bundle>.summary.json
	•	Run tests:
		swift test

Next subcommands checklist
	•	[x] get test-results summary (SQLite-backed, snapshot-tested)
	•	[x] get test-results tests (SQLite-backed, snapshot-tested)
	•	[x] get test-results test-details
	•	[x] get test-results activities
	•	[x] get test-results metrics
	•	[x] get test-results insights

Pending investigations
	•	[ ] Incomplete: run timeout scheme with test repetition flags (`-test-iterations`, `-test-repetition-mode retry-on-failure`). Xcode 26.2 `xcodebuild` CLI rejects `-test-repetition-mode`; revisit with a version that supports it or via test plans.
