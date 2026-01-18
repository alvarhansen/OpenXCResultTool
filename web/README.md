# Browser Harness

This folder contains a minimal browser harness for calling the WASM exports from `OpenXCResultToolWasm`.

## Quick Start

1. Build the WASM module:

```
make wasm-image
make wasm-sqlite
make wasm-module
```

2. Copy the module into this folder:

```
cp .build/wasm32-unknown-wasi/debug/OpenXCResultToolWasm.wasm web/openxcresulttool.wasm
```

3. Serve the folder (file:// will not work with WASM imports):

```
cd web
python3 -m http.server 8080
```

4. Open `http://localhost:8080` and select a `.xcresult` folder.

## Notes

- The harness uses `@wasmer/wasi` and `@wasmer/wasmfs` via ESM CDN imports in `web/app.js`.
- For large bundles, consider a real WASI runtime and file streaming instead of browser memory.
