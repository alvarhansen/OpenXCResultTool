import * as wasiModule from "https://esm.sh/@wasmer/wasi@1.2.2?bundle";
import * as wasmfsModule from "https://esm.sh/@wasmer/wasmfs@0.12.0?bundle";
import { unzipSync } from "https://esm.sh/fflate@0.8.2?bundle";
import path from "https://esm.sh/path-browserify@1.0.1?bundle";

const encoder = new TextEncoder();
const decoder = new TextDecoder();

const elements = {
  input: document.getElementById("xcresult-input"),
  zipInput: document.getElementById("xcresult-zip-input"),
  dropZone: document.getElementById("drop-zone"),
  bundleName: document.getElementById("bundle-name"),
  bundleCount: document.getElementById("bundle-count"),
  commandSelect: document.getElementById("command-select"),
  testIdField: document.getElementById("test-id-field"),
  testIdLabel: document.getElementById("test-id-label"),
  testIdInput: document.getElementById("test-id"),
  compactToggle: document.getElementById("compact-toggle"),
  runButton: document.getElementById("run-button"),
  smokeButton: document.getElementById("smoke-button"),
  status: document.getElementById("status"),
  output: document.getElementById("output"),
  copyButton: document.getElementById("copy-button"),
};

const commandSpecs = {
  version: {
    exportName: "openxcresulttool_version_json",
    needsTestId: false,
    requiresBundle: false,
    requiresDatabase: false,
    signature: "compact",
  },
  metadata: {
    exportName: "openxcresulttool_get_metadata_json",
    needsTestId: false,
    requiresDatabase: false,
  },
  "format-description": {
    exportName: "openxcresulttool_format_description_json",
    needsTestId: false,
    requiresBundle: false,
    requiresDatabase: false,
    signature: "compact",
  },
  graph: {
    exportName: "openxcresulttool_graph_text",
    needsTestId: false,
    requiresDatabase: false,
  },
  object: {
    exportName: "openxcresulttool_get_object_json",
    needsTestId: false,
    testIdOptional: true,
    idLabel: "Object Id",
    idPlaceholder: "Optional object id (defaults to root)",
    requiresDatabase: false,
  },
  summary: { exportName: "openxcresulttool_get_test_results_summary_json", needsTestId: false },
  tests: { exportName: "openxcresulttool_get_test_results_tests_json", needsTestId: false },
  "test-details": { exportName: "openxcresulttool_get_test_results_test_details_json", needsTestId: true },
  activities: { exportName: "openxcresulttool_get_test_results_activities_json", needsTestId: true },
  metrics: { exportName: "openxcresulttool_get_test_results_metrics_json", needsTestId: false, testIdOptional: true },
  insights: { exportName: "openxcresulttool_get_test_results_insights_json", needsTestId: false },
  "sqlite-smoke": { exportName: "openxcresulttool_sqlite_smoke_test_json", needsTestId: false },
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
  if (elements.testIdLabel) {
    elements.testIdLabel.textContent = spec.idLabel ?? "Test Id";
  }
  if (elements.testIdInput) {
    elements.testIdInput.placeholder = spec.idPlaceholder
      ?? "Optional for metrics, required for details/activities";
  }
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
    ensureDir(wasmFs.fs, "/tmp");

    stage = "wasi-construct";
    const defaultBindings = wasiModule.defaultBindings ?? {};
    const wasi = new WASI({
      args: [],
      env: {},
      preopenDirectories: {
        "/work": "/work",
        "/tmp": "/tmp",
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

function registerDatabase(instance, path, data) {
  const register = instance.exports.openxcresulttool_register_database;
  if (!register) {
    return;
  }
  const alloc = instance.exports.openxcresulttool_alloc;
  if (!alloc) {
    throw new Error("openxcresulttool_alloc export is missing.");
  }
  const dataPtr = alloc(data.length);
  if (!dataPtr) {
    throw new Error("Unable to allocate database buffer.");
  }
  const memory = new Uint8Array(instance.exports.memory.buffer, dataPtr, data.length);
  memory.set(data);

  const pathPtr = allocCString(instance, path);
  const ok = register(pathPtr, dataPtr, data.length);
  freeCString(instance, pathPtr);
  freeCString(instance, dataPtr);

  if (!ok) {
    const message = getLastError(instance) || "Unknown database registration error.";
    throw new Error(message);
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

async function prepareDatabase(instance, wasmFs) {
  const bundlePath = await mountBundle(wasmFs.fs);
  const databasePath = `${bundlePath}/database.sqlite3`;

  try {
    wasmFs.fs.statSync(databasePath);
  } catch (error) {
    throw new Error(`Database missing in WASI FS at ${databasePath}.`);
  }

  try {
    const fd = wasmFs.fs.openSync(databasePath, "r");
    wasmFs.fs.closeSync(fd);
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    throw new Error(`JS open failed for ${databasePath}: ${message}`);
  }

  let databaseBytes;
  try {
    databaseBytes = wasmFs.fs.readFileSync(databasePath);
    const headerText = decoder.decode(databaseBytes.subarray(0, 16));
    if (!headerText.startsWith("SQLite format 3")) {
      throw new Error(`Database header mismatch: ${headerText}`);
    }
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    throw new Error(`Failed to read database header: ${message}`);
  }

  registerDatabase(instance, databasePath, databaseBytes);
  return { bundlePath, databasePath, databaseBytes };
}

async function runExport() {
  const command = elements.commandSelect.value;
  const spec = commandSpecs[command];
  const testId = elements.testIdInput.value.trim();
  const compact = elements.compactToggle.checked;
  const requiresBundle = spec.requiresBundle ?? true;
  const requiresDatabase = spec.requiresDatabase ?? requiresBundle;
  const signature = spec.signature
    ?? ((spec.needsTestId || spec.testIdOptional) ? "path+testId" : "path");

  if (requiresBundle && (!state.bundleRoot || state.fileCount === 0)) {
    setStatus("Select a .xcresult folder or zip before running.", "error");
    return;
  }

  if (spec.needsTestId && !testId) {
    setStatus("This command requires a test id.", "error");
    return;
  }

  setStatus("Loading WASM runtime...", "info");
  elements.runButton.disabled = true;
  if (elements.smokeButton) {
    elements.smokeButton.disabled = true;
  }
  elements.output.textContent = "// Running...";

  try {
    const { instance, wasmFs } = await createRuntime();
    let bundlePath = null;
    if (requiresBundle) {
      if (requiresDatabase) {
        const prepared = await prepareDatabase(instance, wasmFs);
        bundlePath = prepared.bundlePath;
        if (prepared.databaseBytes && typeof prepared.databaseBytes.length === "number") {
          setStatus(`Database staged (${prepared.databaseBytes.length} bytes).`, "info");
        }
      } else {
        bundlePath = await mountBundle(wasmFs.fs);
      }
    }

    const exportFn = instance.exports[spec.exportName];
    if (!exportFn) {
      throw new Error(`Missing export: ${spec.exportName}`);
    }

    const compactFlag = compact ? 1 : 0;
    let pathPtr = 0;
    let testPtr = 0;
    let resultPtr = 0;

    if (signature === "compact") {
      resultPtr = exportFn(compactFlag);
    } else {
      if (!bundlePath) {
        throw new Error("Bundle path is required for this command.");
      }
      pathPtr = allocCString(instance, bundlePath);
      if (signature === "path+testId") {
        if (spec.needsTestId || (spec.testIdOptional && testId)) {
          testPtr = allocCString(instance, testId);
        }
        resultPtr = exportFn(pathPtr, testPtr, compactFlag);
      } else {
        resultPtr = exportFn(pathPtr, compactFlag);
      }
    }

    if (pathPtr) {
      freeCString(instance, pathPtr);
    }
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
    if (elements.smokeButton) {
      elements.smokeButton.disabled = false;
    }
  }
}

async function runSqliteSmokeTest() {
  if (!state.bundleRoot || state.fileCount === 0) {
    setStatus("Select a .xcresult folder or zip before running.", "error");
    return;
  }

  setStatus("Running SQLite smoke test...", "info");
  elements.runButton.disabled = true;
  if (elements.smokeButton) {
    elements.smokeButton.disabled = true;
  }
  elements.output.textContent = "// Running SQLite smoke test...";

  try {
    const { instance, wasmFs } = await createRuntime();
    const { bundlePath } = await prepareDatabase(instance, wasmFs);
    const exportFn = instance.exports.openxcresulttool_sqlite_smoke_test_json;
    if (!exportFn) {
      throw new Error("Missing export: openxcresulttool_sqlite_smoke_test_json");
    }
    const pathPtr = allocCString(instance, bundlePath);
    const compactFlag = elements.compactToggle.checked ? 1 : 0;
    const resultPtr = exportFn(pathPtr, compactFlag);
    freeCString(instance, pathPtr);
    if (!resultPtr) {
      const error = getLastError(instance) || "Unknown error";
      throw new Error(error);
    }
    const json = readCString(instance, resultPtr);
    freeCString(instance, resultPtr);
    elements.output.textContent = json;
    setStatus("SQLite smoke test complete.", "success");
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    elements.output.textContent = "// Failed to run sqlite smoke test.";
    setStatus(message, "error");
  } finally {
    elements.runButton.disabled = false;
    if (elements.smokeButton) {
      elements.smokeButton.disabled = false;
    }
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

  applyDirectoryFiles(files, rootName);
}

async function handleZipFile(event) {
  const [file] = Array.from(event.target.files || []);
  if (!file) {
    if (state.source === "zip") {
      resetState();
    }
    return;
  }

  await handleZipData(file);
}

function applyDirectoryFiles(files, rootName) {
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

async function handleZipData(file) {
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

function setDropActive(active) {
  if (!elements.dropZone) {
    return;
  }
  elements.dropZone.classList.toggle("dragover", active);
}

function readAllDirectoryEntries(reader) {
  return new Promise((resolve, reject) => {
    const entries = [];
    const readBatch = () => {
      reader.readEntries((batch) => {
        if (!batch.length) {
          resolve(entries);
          return;
        }
        entries.push(...batch);
        readBatch();
      }, reject);
    };
    readBatch();
  });
}

function entryRelativePath(entry, rootName) {
  if (entry.fullPath) {
    return entry.fullPath.replace(/^\//, "");
  }
  return `${rootName}/${entry.name}`;
}

async function collectFilesFromEntry(entry, rootName, files) {
  if (entry.isFile) {
    await new Promise((resolve, reject) => {
      entry.file((file) => {
        const relativePath = entryRelativePath(entry, rootName);
        try {
          Object.defineProperty(file, "webkitRelativePath", {
            value: relativePath,
          });
        } catch (error) {
          // Best effort; fall back to name if the property is read-only.
        }
        files.push(file);
        resolve();
      }, reject);
    });
    return;
  }

  if (entry.isDirectory) {
    const reader = entry.createReader();
    const children = await readAllDirectoryEntries(reader);
    for (const child of children) {
      await collectFilesFromEntry(child, rootName, files);
    }
  }
}

async function handleDrop(event) {
  const dataTransfer = event.dataTransfer;
  if (!dataTransfer) {
    setStatus("Drop a .xcresult.zip or .xcresult folder.", "error");
    return;
  }

  const items = Array.from(dataTransfer.items || []);
  const entries = items
    .map((item) => (item.webkitGetAsEntry ? item.webkitGetAsEntry() : null))
    .filter(Boolean);

  if (entries.length) {
    const xcresultEntry = entries.find((entry) => entry.isDirectory && entry.name.endsWith(".xcresult"));
    const directoryEntry = xcresultEntry || entries.find((entry) => entry.isDirectory);
    if (directoryEntry) {
      const files = [];
      await collectFilesFromEntry(directoryEntry, directoryEntry.name, files);
      if (!files.length) {
        setStatus("Dropped folder had no readable files.", "error");
        return;
      }
      applyDirectoryFiles(files, directoryEntry.name);
      return;
    }

    const zipEntry = entries.find((entry) => entry.isFile && entry.name.endsWith(".zip"));
    if (zipEntry && zipEntry.file) {
      zipEntry.file((file) => handleZipData(file));
      return;
    }
  }

  const files = Array.from(dataTransfer.files || []);
  if (files.length === 1 && files[0].name.endsWith(".zip")) {
    await handleZipData(files[0]);
    return;
  }

  setStatus("Drop a .xcresult.zip or .xcresult folder.", "error");
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
if (elements.smokeButton) {
  elements.smokeButton.addEventListener("click", runSqliteSmokeTest);
}
elements.copyButton.addEventListener("click", copyOutput);
if (elements.dropZone) {
  elements.dropZone.addEventListener("dragenter", (event) => {
    event.preventDefault();
    setDropActive(true);
  });
  elements.dropZone.addEventListener("dragover", (event) => {
    event.preventDefault();
    setDropActive(true);
  });
  elements.dropZone.addEventListener("dragleave", (event) => {
    if (event.target === elements.dropZone) {
      setDropActive(false);
    }
  });
  elements.dropZone.addEventListener("drop", async (event) => {
    event.preventDefault();
    setDropActive(false);
    await handleDrop(event);
  });
}

updateBundleMeta();
updateTestIdVisibility();
