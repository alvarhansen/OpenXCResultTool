import * as wasiModule from "https://esm.sh/@wasmer/wasi@1.2.2?bundle";
import * as wasmfsModule from "https://esm.sh/@wasmer/wasmfs@0.12.0?bundle";
import { unzipSync } from "https://esm.sh/fflate@0.8.2?bundle";
import path from "https://esm.sh/path-browserify@1.0.1?bundle";

const encoder = new TextEncoder();
const decoder = new TextDecoder();

const elements = {
  input: document.getElementById("xcresult-input"),
  zipInput: document.getElementById("xcresult-zip-input"),
  bundleName: document.getElementById("bundle-name"),
  bundleCount: document.getElementById("bundle-count"),
  commandSelect: document.getElementById("command-select"),
  testIdField: document.getElementById("test-id-field"),
  testIdInput: document.getElementById("test-id"),
  compactToggle: document.getElementById("compact-toggle"),
  runButton: document.getElementById("run-button"),
  status: document.getElementById("status"),
  output: document.getElementById("output"),
  copyButton: document.getElementById("copy-button"),
};

const commandSpecs = {
  summary: { exportName: "openxcresulttool_get_test_results_summary_json", needsTestId: false },
  tests: { exportName: "openxcresulttool_get_test_results_tests_json", needsTestId: false },
  "test-details": { exportName: "openxcresulttool_get_test_results_test_details_json", needsTestId: true },
  activities: { exportName: "openxcresulttool_get_test_results_activities_json", needsTestId: true },
  metrics: { exportName: "openxcresulttool_get_test_results_metrics_json", needsTestId: false, testIdOptional: true },
  insights: { exportName: "openxcresulttool_get_test_results_insights_json", needsTestId: false },
};

const state = {
  source: "none",
  files: [],
  entries: [],
  bundleRoot: null,
  fileCount: 0,
};

let wasiReady = false;

function setStatus(message, tone = "info") {
  elements.status.textContent = message;
  elements.status.dataset.tone = tone;
}

function updateBundleMeta() {
  const name = state.bundleRoot ? state.bundleRoot : "No bundle loaded.";
  elements.bundleName.textContent = name;
  elements.bundleCount.textContent = `${state.fileCount} files`;
}

function updateTestIdVisibility() {
  const command = elements.commandSelect.value;
  const spec = commandSpecs[command];
  elements.testIdField.style.display = spec.needsTestId || spec.testIdOptional ? "grid" : "none";
}

function ensureDir(fs, dirPath) {
  const parts = dirPath.split("/").filter(Boolean);
  let current = "";
  for (const part of parts) {
    current += `/${part}`;
    try {
      fs.mkdirSync(current);
    } catch (error) {
      if (error.code !== "EEXIST") {
        throw error;
      }
    }
  }
}

function resetState() {
  state.source = "none";
  state.files = [];
  state.entries = [];
  state.bundleRoot = null;
  state.fileCount = 0;
  updateBundleMeta();
}

function isIgnoredZipEntry(name) {
  if (name.endsWith("/")) {
    return true;
  }
  if (name.startsWith("__MACOSX/") || name.includes("/__MACOSX/")) {
    return true;
  }
  if (name.endsWith(".DS_Store")) {
    return true;
  }
  const parts = name.split("/");
  return parts.some((part) => part.startsWith("._"));
}

function detectBundleRoot(paths) {
  if (!paths.length) {
    return null;
  }
  const roots = new Set(paths.map((name) => name.split("/")[0]).filter(Boolean));
  if (roots.size !== 1) {
    return null;
  }
  const [candidate] = roots;
  return candidate.endsWith(".xcresult") ? candidate : null;
}

function normalizeZipEntries(zipEntries) {
  const files = Object.keys(zipEntries).filter((name) => !isIgnoredZipEntry(name));
  const rootCandidate = detectBundleRoot(files);
  const bundleRoot = rootCandidate ?? "bundle.xcresult";
  const entries = files.map((name) => {
    const normalized = rootCandidate ? name : `${bundleRoot}/${name}`;
    return { path: normalized, data: zipEntries[name] };
  });
  return { bundleRoot, entries, fileCount: entries.length };
}

async function createRuntime() {
  let stage = "wasi-init";
  try {
    if (!wasiReady) {
      const init = wasiModule.init ?? wasiModule.default;
      if (typeof init === "function") {
        await init();
      }
      wasiReady = true;
    }

    stage = "bindings";
    const WasmFs = wasmfsModule.WasmFs;
    const WASI = wasiModule.WASI;
    if (!WasmFs || !WASI) {
      throw new Error("WASI runtime failed to load. Check the CDN imports.");
    }
    const wasmFs = new WasmFs();
    if (!wasmFs.fs) {
      throw new Error("WASI filesystem failed to initialize.");
    }
    if (!("volume" in wasmFs.fs)) {
      wasmFs.fs.volume = wasmFs.volume;
    }
    ensureDir(wasmFs.fs, "/work");

    stage = "wasi-construct";
    const defaultBindings = wasiModule.defaultBindings ?? {};
    const wasi = new WASI({
      args: [],
      env: {},
      preopenDirectories: {
        "/work": "/work",
      },
      bindings: {
        ...defaultBindings,
        fs: wasmFs.fs,
        path,
      },
    });

    stage = "wasm-fetch";
    const wasmResponse = await fetch("openxcresulttool.wasm");
    if (!wasmResponse.ok) {
      throw new Error("openxcresulttool.wasm not found. Copy it into web/ before running.");
    }

    stage = "wasm-instantiate";
    const module = await WebAssembly.compileStreaming(wasmResponse);
    const instance = await WebAssembly.instantiate(module, wasi.getImports(module));

    stage = "wasi-start";
    if (typeof wasi.initialize === "function") {
      wasi.initialize(instance);
    } else if (typeof wasi.start === "function") {
      try {
        wasi.start(instance);
      } catch (error) {
        const message = String(error);
        if (!message.includes("exit code: 0")) {
          console.warn(error);
        }
      }
    }

    return { instance, wasmFs };
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    throw new Error(`${stage}: ${message}`);
  }
}

async function mountBundle(fs) {
  if (state.source === "directory") {
    for (const file of state.files) {
      const relativePath = file.webkitRelativePath || file.name;
      const targetPath = `/work/${relativePath}`;
      ensureDir(fs, path.dirname(targetPath));
      const data = new Uint8Array(await file.arrayBuffer());
      fs.writeFileSync(targetPath, data);
    }
    return `/work/${state.bundleRoot}`;
  }
  if (state.source === "zip") {
    for (const entry of state.entries) {
      const targetPath = `/work/${entry.path}`;
      ensureDir(fs, path.dirname(targetPath));
      fs.writeFileSync(targetPath, entry.data);
    }
    return `/work/${state.bundleRoot}`;
  }
  throw new Error("No bundle loaded.");
}

function allocCString(instance, value) {
  const data = encoder.encode(`${value}\0`);
  const alloc = instance.exports.openxcresulttool_alloc;
  if (!alloc) {
    throw new Error("openxcresulttool_alloc export is missing.");
  }
  const ptr = alloc(data.length);
  if (!ptr) {
    throw new Error("Unable to allocate memory inside WASM.");
  }
  const memory = new Uint8Array(instance.exports.memory.buffer, ptr, data.length);
  memory.set(data);
  return ptr;
}

function readCString(instance, ptr) {
  const memory = new Uint8Array(instance.exports.memory.buffer);
  let end = ptr;
  while (memory[end] !== 0) {
    end += 1;
  }
  return decoder.decode(memory.subarray(ptr, end));
}

function freeCString(instance, ptr) {
  const free = instance.exports.openxcresulttool_free;
  if (free && ptr) {
    free(ptr);
  }
}

function getLastError(instance) {
  const errorPtr = instance.exports.openxcresulttool_last_error?.();
  if (!errorPtr) {
    return null;
  }
  const message = readCString(instance, errorPtr);
  freeCString(instance, errorPtr);
  return message;
}

async function runExport() {
  if (!state.bundleRoot || state.fileCount === 0) {
    setStatus("Select a .xcresult folder or zip before running.", "error");
    return;
  }

  const command = elements.commandSelect.value;
  const spec = commandSpecs[command];
  const testId = elements.testIdInput.value.trim();
  const compact = elements.compactToggle.checked;

  if (spec.needsTestId && !testId) {
    setStatus("This command requires a test id.", "error");
    return;
  }

  setStatus("Loading WASM runtime...", "info");
  elements.runButton.disabled = true;
  elements.output.textContent = "// Running...";

  try {
    const { instance, wasmFs } = await createRuntime();
    const bundlePath = await mountBundle(wasmFs.fs);

    const exportFn = instance.exports[spec.exportName];
    if (!exportFn) {
      throw new Error(`Missing export: ${spec.exportName}`);
    }

    const pathPtr = allocCString(instance, bundlePath);
    const compactFlag = compact ? 1 : 0;
    let testPtr = 0;
    if (spec.needsTestId || (spec.testIdOptional && testId)) {
      testPtr = allocCString(instance, testId);
    }

    let resultPtr = 0;
    if (spec.needsTestId || spec.testIdOptional) {
      resultPtr = exportFn(pathPtr, testPtr, compactFlag);
    } else {
      resultPtr = exportFn(pathPtr, compactFlag);
    }

    freeCString(instance, pathPtr);
    if (testPtr) {
      freeCString(instance, testPtr);
    }

    if (!resultPtr) {
      const error = getLastError(instance) || "Unknown error";
      throw new Error(error);
    }

    const json = readCString(instance, resultPtr);
    freeCString(instance, resultPtr);

    elements.output.textContent = json;
    setStatus("Export complete.", "success");
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    elements.output.textContent = "// Failed to run export.";
    setStatus(message, "error");
  } finally {
    elements.runButton.disabled = false;
  }
}

function handleFiles(event) {
  const files = Array.from(event.target.files || []);
  if (!files.length) {
    resetState();
    return;
  }

  const samplePath = files[0].webkitRelativePath || files[0].name;
  const rootName = samplePath.split("/")[0] || "bundle.xcresult";

  state.source = "directory";
  state.files = files;
  state.entries = [];
  state.bundleRoot = rootName;
  state.fileCount = files.length;
  if (elements.zipInput) {
    elements.zipInput.value = "";
  }
  updateBundleMeta();
  setStatus("Bundle staged. Ready to run.", "success");
}

async function handleZipFile(event) {
  const [file] = Array.from(event.target.files || []);
  if (!file) {
    if (state.source === "zip") {
      resetState();
    }
    return;
  }

  setStatus("Unpacking zip...", "info");
  let entries;
  try {
    const data = new Uint8Array(await file.arrayBuffer());
    entries = unzipSync(data);
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    setStatus(`Failed to unzip: ${message}`, "error");
    return;
  }

  const normalized = normalizeZipEntries(entries);
  if (normalized.fileCount === 0) {
    setStatus("Zip did not contain readable files.", "error");
    return;
  }

  state.source = "zip";
  state.files = [];
  state.entries = normalized.entries;
  state.bundleRoot = normalized.bundleRoot;
  state.fileCount = normalized.fileCount;
  if (elements.input) {
    elements.input.value = "";
  }
  updateBundleMeta();
  setStatus("Zip staged. Ready to run.", "success");
}

async function copyOutput() {
  const text = elements.output.textContent;
  if (!text || text.startsWith("//")) {
    setStatus("Nothing to copy yet.", "error");
    return;
  }
  await navigator.clipboard.writeText(text);
  setStatus("Copied output to clipboard.", "success");
}

elements.input.addEventListener("change", handleFiles);
if (elements.zipInput) {
  elements.zipInput.addEventListener("change", handleZipFile);
}
elements.commandSelect.addEventListener("change", updateTestIdVisibility);
elements.runButton.addEventListener("click", runExport);
elements.copyButton.addEventListener("click", copyOutput);

updateBundleMeta();
updateTestIdVisibility();
