You said:
how to reduce size of swift wasm
ChatGPT said:

Here are the biggest, most reliable ways to shrink a Swift → WebAssembly (.wasm) output. (Some are “Swift-side”, some are “Wasm-tooling-side”.)
1) Compile Swift for size

Use size-focused optimization instead of speed-focused:

    SwiftPM

swift build -c release \
  -Xswiftc -Osize

If you’re using a toolchain that supports it, also try whole-module optimization (often already implied in Release, but not always in every setup):

swift build -c release \
  -Xswiftc -Osize \
  -Xswiftc -whole-module-optimization

2) Don’t accidentally prevent dead-code stripping

On the Wasm link step, unused code is removed by section GC — but anything you export (and anything it references) is kept. So avoid “export everything”; export only your real API surface. The Wasm linker’s GC behavior and the fact exports are preserved is documented in lld’s WebAssembly linker docs.

Practical implications:

    Prefer a small set of exported functions.

    Avoid --export-all unless you truly need it (it can bloat a lot).

3) Strip custom sections (this is often the biggest win)

Wasm files can include “custom sections” (names, producers, debug DWARF, etc.). Stripping them can dramatically reduce size.

Two common tools:

    WABT: wasm-strip your.wasm

    Or convert round-trip: wasm2wat → wat2wasm (also removes many custom sections, but is clunkier)

A real-world example shows wasm-strip cutting a module from ~50KB to <4KB by removing custom sections.

Also: some WASI toolchain builds may include debug-ish sections more aggressively than you’d expect; stripping becomes mandatory in that case.
4) Run wasm-opt (Binaryen) after linking

Post-opt can further shrink code and improve dead-code elimination patterns:

wasm-opt -Oz --strip-debug --strip-dwarf --strip-producers \
  -o out.wasm in.wasm

Swift/Wasm folks specifically call out wasm-opt as a way to “strip it down”.
5) Make sure section GC can work well

Section GC works best when code/data are placed into separable sections. In C/C++ land this is -ffunction-sections; in mixed Swift+C projects it can still matter for the C/C++ parts. People mention pairing -ffunction-sections with wasm GC/wasm-opt when size matters.
6) Avoid heavy Swift runtimes / libraries

This is the “architecture” lever:

    Avoid Foundation unless you truly need it (it tends to pull in a lot).

    Prefer smaller, purpose-built code paths (parsing/formatting can balloon).

    If you’re exploring Embedded Swift modes/toolchains, those are explicitly aimed at reducing overhead by disabling/refactoring some runtime features.

7) Shipping size: compress the .wasm

If your goal is download size (web delivery), gzip/brotli usually helps a lot:

    Serve .wasm with Brotli (best) or gzip on your CDN/server.

A good “size pipeline” to try

    swift build -c release -Xswiftc -Osize

    Link to app.wasm

    wasm-strip app.wasm

    wasm-opt -Oz ... -o app.min.wasm app.wasm

    Serve app.min.wasm with Brotli

If you tell me which toolchain you’re using (SwiftWasm? WASI-SDK? custom Swift 6 nightly?) and whether you target wasi or browser JS, I can suggest the best exact flags for your setup.


ChatGPT can make mistakes. Check important info. See Cookie Preferences.

Repo support

- `make wasm-image` now installs `binaryen` and `wabt` in the WASM build image.
- `make wasm-module-min` builds a release `-Osize` module, runs `wasm-opt -Oz` (or `wasm-strip`), and copies the result to `web/openxcresulttool.wasm`.
- Size-optimized artifacts live at `.build/wasm32-unknown-wasip1/release/openxcresulttool-wasm.min.wasm`.

