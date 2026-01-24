# Browser Harness

This folder contains a minimal browser harness for calling the WASM exports from `OpenXCResultToolWasm`.

## Quick Start

1. Build the WASM module:

```
make wasm-image
make wasm-sqlite
make wasm-module

# Size-optimized output (optional)
make wasm-module-min
```

2. Copy the module into this folder:

```
cp .build/wasm32-unknown-wasip1/debug/openxcresulttool-wasm.wasm web/openxcresulttool.wasm
```

3. Serve the folder (file:// will not work with WASM imports):

```
cd web
python3 -m http.server 8080
```

4. Open `http://localhost:8080` and select a `.xcresult` folder, or upload a `.xcresult.zip`.

## Notes

- The harness uses `@wasmer/wasi`, `@wasmer/wasmfs`, and `fflate` via ESM CDN imports in `web/app.js`.
- On macOS, `.xcresult` is a bundle, and browsers often refuse to select it via the directory picker. Use the `.zip` flow instead (Finder “Compress”, or `ditto -c -k --sequesterRsrc --keepParent Tests/Fixtures/<bundle>.xcresult /tmp/<bundle>.xcresult.zip`).
- The browser cannot reliably open SQLite files through WASI FS, so `web/app.js` reads `database.sqlite3` into memory and registers it via `openxcresulttool_register_database`. The Swift side deserializes it into an in-memory database before running queries.
- Use the "sqlite smoke test" command in the dropdown to verify the registry path and database header before running larger exports.
- For large bundles, consider a real WASI runtime and file streaming instead of browser memory.
