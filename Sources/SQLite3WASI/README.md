# SQLite3 WASI Artifacts

This directory contains a WASI-built `libsqlite3.a` and its headers used when
cross-compiling with the Swift WASM SDK. Regenerate the artifacts with:

`make wasm-image`
`make wasm-sqlite`
