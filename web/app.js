import * as wasiModule from "https://esm.sh/@wasmer/wasi@1.2.2?bundle";
import * as wasmfsModule from "https://esm.sh/@wasmer/wasmfs@0.12.0?bundle";
import { unzipSync, zipSync } from "https://esm.sh/fflate@0.8.2?bundle";
import path from "https://esm.sh/path-browserify@1.0.1?bundle";

const encoder = new TextEncoder();
const decoder = new TextDecoder();

const elements = {
  input: document.getElementById("xcresult-input"),
  zipInput: document.getElementById("xcresult-zip-input"),
  dropZone: document.getElementById("drop-zone"),
  compareInput: document.getElementById("compare-xcresult-input"),
  compareZipInput: document.getElementById("compare-xcresult-zip-input"),
  compareDropZone: document.getElementById("compare-drop-zone"),
  bundleName: document.getElementById("bundle-name"),
  bundleCount: document.getElementById("bundle-count"),
  compareBundleName: document.getElementById("compare-bundle-name"),
  compareBundleCount: document.getElementById("compare-bundle-count"),
  commandSelect: document.getElementById("command-select"),
  testIdField: document.getElementById("test-id-field"),
  testIdLabel: document.getElementById("test-id-label"),
  testIdInput: document.getElementById("test-id"),
  onlyFailuresField: document.getElementById("only-failures-field"),
  onlyFailuresToggle: document.getElementById("only-failures-toggle"),
  objectTypeField: document.getElementById("object-type-field"),
  objectTypeSelect: document.getElementById("object-type-select"),
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
    exportName: "openxcresulttool_get_metadata_from_plist_json",
    needsTestId: false,
    requiresDatabase: false,
    usePlistBytes: true,
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
    useFileRegistry: true,
  },
  object: {
    exportName: "openxcresulttool_get_object_json",
    needsTestId: false,
    testIdOptional: true,
    idLabel: "Object Id",
    idPlaceholder: "Optional object id (defaults to root)",
    requiresDatabase: false,
    useFileRegistry: true,
  },
  compare: {
    exportName: "openxcresulttool_compare_json",
    needsTestId: false,
    requiresCompare: true,
  },
  "export-diagnostics": {
    exportName: "openxcresulttool_export_diagnostics",
    needsTestId: false,
    action: "download",
    downloadSignature: "path+output",
    outputName: "diagnostics",
    useFileRegistry: true,
  },
  "export-attachments": {
    exportName: "openxcresulttool_export_attachments",
    needsTestId: false,
    testIdOptional: true,
    idPlaceholder: "Optional test id to filter attachments",
    action: "download",
    downloadSignature: "path+output+testId+flag",
    outputName: "attachments",
    showOnlyFailures: true,
    useFileRegistry: true,
  },
  "export-metrics": {
    exportName: "openxcresulttool_export_metrics",
    needsTestId: false,
    testIdOptional: true,
    idPlaceholder: "Optional test id to filter metrics",
    action: "download",
    downloadSignature: "path+output+testId",
    outputName: "metrics",
    requiresInfoPlist: true,
  },
  "export-object": {
    exportName: "openxcresulttool_export_object",
    needsTestId: true,
    idLabel: "Object Id",
    idPlaceholder: "Required object id for export",
    action: "download",
    downloadSignature: "path+output+id+type",
    outputName: "object",
    useTestIdInName: true,
    showObjectType: true,
    useFileRegistry: true,
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

const compareState = {
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

function updateBundleMeta(targetState = state, nameElement = elements.bundleName, countElement = elements.bundleCount) {
  const name = targetState.bundleRoot ? targetState.bundleRoot : "No bundle loaded.";
  nameElement.textContent = name;
  countElement.textContent = `${targetState.fileCount} files`;
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
  if (elements.onlyFailuresField && elements.onlyFailuresToggle) {
    const showOnlyFailures = Boolean(spec.showOnlyFailures);
    elements.onlyFailuresField.style.display = showOnlyFailures ? "flex" : "none";
    if (!showOnlyFailures) {
      elements.onlyFailuresToggle.checked = false;
    }
  }
  if (elements.objectTypeField && elements.objectTypeSelect) {
    const showObjectType = Boolean(spec.showObjectType);
    elements.objectTypeField.style.display = showObjectType ? "grid" : "none";
    if (!showObjectType) {
      elements.objectTypeSelect.value = "file";
    }
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

function safeReaddir(fs, dirPath) {
  try {
    return fs.readdirSync(dirPath);
  } catch (error) {
    return [];
  }
}

function resetState(
  targetState = state,
  nameElement = elements.bundleName,
  countElement = elements.bundleCount
) {
  targetState.source = "none";
  targetState.files = [];
  targetState.entries = [];
  targetState.bundleRoot = null;
  targetState.fileCount = 0;
  updateBundleMeta(targetState, nameElement, countElement);
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

function normalizeRelativePath(value) {
  return value.replace(/\\/g, "/").replace(/^\.\/+/, "");
}

function detectBundleRootFromPaths(paths) {
  for (const rawPath of paths) {
    const normalized = normalizeRelativePath(rawPath);
    const plistMatch = normalized.match(/(.+\.xcresult)\/Info\.plist$/i);
    if (plistMatch) {
      return plistMatch[1];
    }
    const dbMatch = normalized.match(/(.+\.xcresult)\/database\.sqlite3$/i);
    if (dbMatch) {
      return dbMatch[1];
    }
  }
  return null;
}

function normalizeZipEntries(zipEntries) {
  const files = Object.entries(zipEntries)
    .map(([name, data]) => ({
      name: normalizeRelativePath(name),
      data,
    }))
    .filter((entry) => !isIgnoredZipEntry(entry.name));
  const rootCandidate = detectBundleRoot(files.map((entry) => entry.name));
  const bundleRoot = rootCandidate ?? "bundle.xcresult";
  const entries = files.map((entry) => {
    const normalized = rootCandidate ? entry.name : `${bundleRoot}/${entry.name}`;
    return { path: normalized, data: entry.data };
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
    ensureDir(wasmFs.fs, "/compare");
    ensureDir(wasmFs.fs, "/tmp");

    stage = "wasi-construct";
    const defaultBindings = wasiModule.defaultBindings ?? {};
    const wasi = new WASI({
      args: [],
      env: {},
      cwd: "/",
      preopenDirectories: {
        "/": "/",
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

async function mountBundle(fs, targetState = state, mountRoot = "/work", instance = null) {
  if (targetState.source === "directory") {
    for (const file of targetState.files) {
      const relativePath = file.webkitRelativePath || file._relativePath || file.name;
      const targetPath = `${mountRoot}/${relativePath}`;
      ensureDir(fs, path.dirname(targetPath));
      const data = new Uint8Array(await file.arrayBuffer());
      fs.writeFileSync(targetPath, data);
      if (instance) {
        registerFile(instance, targetPath, data);
      }
    }
    return resolveBundlePath(fs, mountRoot, targetState);
  }
  if (targetState.source === "zip") {
    for (const entry of targetState.entries) {
      const targetPath = `${mountRoot}/${entry.path}`;
      ensureDir(fs, path.dirname(targetPath));
      fs.writeFileSync(targetPath, entry.data);
      if (instance) {
        registerFile(instance, targetPath, entry.data);
      }
    }
    return resolveBundlePath(fs, mountRoot, targetState);
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

function allocBytes(instance, data) {
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

function shouldRegisterFile(pathValue) {
  return pathValue.endsWith("/Info.plist") || pathValue.includes("/Data/");
}

function registerFile(instance, filePath, data) {
  const register = instance.exports.openxcresulttool_register_file;
  if (!register) {
    return;
  }
  if (!shouldRegisterFile(filePath)) {
    return;
  }
  const dataLength = data.length ?? 0;
  const dataPtr = dataLength ? allocBytes(instance, data) : 0;
  const pathPtr = allocCString(instance, filePath);
  const ok = register(pathPtr, dataPtr, dataLength);
  freeCString(instance, pathPtr);
  if (dataPtr) {
    freeCString(instance, dataPtr);
  }

  if (!ok) {
    const message = getLastError(instance) || "Unknown file registration error.";
    throw new Error(message);
  }
}

function listRegisteredFiles(instance, prefix) {
  const listFn = instance.exports.openxcresulttool_registered_files_json;
  if (!listFn) {
    return [];
  }
  const prefixPtr = prefix ? allocCString(instance, prefix) : 0;
  const resultPtr = listFn(prefixPtr);
  if (prefixPtr) {
    freeCString(instance, prefixPtr);
  }
  if (!resultPtr) {
    const error = getLastError(instance) || "Unable to list registered files.";
    throw new Error(error);
  }
  const json = readCString(instance, resultPtr);
  freeCString(instance, resultPtr);
  return JSON.parse(json);
}

function readRegisteredFile(instance, filePath) {
  const readFn = instance.exports.openxcresulttool_registered_file_base64;
  if (!readFn) {
    throw new Error("openxcresulttool_registered_file_base64 export is missing.");
  }
  const pathPtr = allocCString(instance, filePath);
  const resultPtr = readFn(pathPtr);
  freeCString(instance, pathPtr);
  if (!resultPtr) {
    const error = getLastError(instance) || "Unable to read registered file.";
    throw new Error(error);
  }
  const base64 = readCString(instance, resultPtr);
  freeCString(instance, resultPtr);
  const binary = atob(base64);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i += 1) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes;
}

function buildZipFromRegistry(instance, prefix, zipRootName) {
  const files = listRegisteredFiles(instance, prefix);
  const entries = {};
  let fileCount = 0;
  for (const filePath of files) {
    const relative = filePath.startsWith(`${prefix}/`)
      ? filePath.slice(prefix.length + 1)
      : path.basename(filePath);
    const zipPath = zipRootName ? `${zipRootName}/${relative}` : relative;
    entries[zipPath] = readRegisteredFile(instance, filePath);
    fileCount += 1;
  }
  if (!fileCount) {
    throw new Error("No exported files found in registry.");
  }
  const bytes = zipSync(entries, { level: 6 });
  return { bytes, fileCount };
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

function findBundleRoots(fs, mountRoot) {
  const roots = [];
  const stack = [mountRoot];
  let visited = 0;

  while (stack.length) {
    const current = stack.pop();
    const entries = safeReaddir(fs, current);
    for (const name of entries) {
      if (name === "." || name === "..") {
        continue;
      }
      const fullPath = path.join(current, name);
      let stat;
      try {
        stat = fs.statSync(fullPath);
      } catch (error) {
        continue;
      }
      visited += 1;
      if (visited > 3000) {
        return roots;
      }
      if (stat.isDirectory()) {
        if (name.endsWith(".xcresult") && fs.existsSync(`${fullPath}/Info.plist`)) {
          roots.push(fullPath);
        }
        stack.push(fullPath);
      }
    }
  }

  return roots;
}

function resolveBundlePath(fs, mountRoot, targetState) {
  const candidate = normalizeRelativePath(targetState.bundleRoot ?? "");
  const candidatePath = `${mountRoot}/${candidate}`;
  if (candidate && fs.existsSync(`${candidatePath}/Info.plist`)) {
    return candidatePath;
  }
  const roots = findBundleRoots(fs, mountRoot);
  if (roots.length === 1) {
    const resolved = roots[0];
    const relative = normalizeRelativePath(path.relative(mountRoot, resolved));
    targetState.bundleRoot = relative;
    return resolved;
  }
  return candidatePath;
}


async function prepareDatabase(instance, wasmFs, targetState = state, mountRoot = "/work") {
  const bundlePath = await mountBundle(wasmFs.fs, targetState, mountRoot, instance);
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

function normalizeZipPath(value) {
  return value.split(path.sep).join("/");
}

function safeFileName(value) {
  return value
    .trim()
    .replace(/[^a-zA-Z0-9._-]+/g, "_")
    .replace(/^_+|_+$/g, "");
}

function buildZipFromWasm(fs, rootPath, zipRootName) {
  const entries = {};
  let fileCount = 0;

  const stat = fs.statSync(rootPath);
  if (stat.isDirectory()) {
    const walk = (currentPath) => {
      const names = fs.readdirSync(currentPath);
      for (const name of names) {
        if (name === "." || name === "..") {
          continue;
        }
        const fullPath = path.join(currentPath, name);
        const itemStat = fs.statSync(fullPath);
        if (itemStat.isDirectory()) {
          walk(fullPath);
        } else {
          const relative = normalizeZipPath(path.relative(rootPath, fullPath));
          const zipPath = zipRootName ? `${zipRootName}/${relative}` : relative;
          entries[zipPath] = fs.readFileSync(fullPath);
          fileCount += 1;
        }
      }
    };
    walk(rootPath);
  } else {
    const baseName = path.basename(rootPath);
    const zipPath = zipRootName ? `${zipRootName}/${baseName}` : baseName;
    entries[zipPath] = fs.readFileSync(rootPath);
    fileCount = 1;
  }

  if (!fileCount) {
    throw new Error("No exported files found.");
  }

  const bytes = zipSync(entries, { level: 6 });
  return { bytes, fileCount };
}

function downloadZip(bytes, filename) {
  const blob = new Blob([bytes], { type: "application/zip" });
  const url = URL.createObjectURL(blob);
  const anchor = document.createElement("a");
  anchor.href = url;
  anchor.download = filename;
  anchor.click();
  setTimeout(() => URL.revokeObjectURL(url), 1000);
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

  if (command === "compare") {
    await runCompare();
    return;
  }

  if (spec.action === "download") {
    await runDownloadExport(spec);
    return;
  }

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
    let plistBytes = null;
    if (requiresBundle) {
      if (requiresDatabase) {
        const prepared = await prepareDatabase(instance, wasmFs);
        bundlePath = prepared.bundlePath;
        if (prepared.databaseBytes && typeof prepared.databaseBytes.length === "number") {
          setStatus(`Database staged (${prepared.databaseBytes.length} bytes).`, "info");
        }
      } else {
        bundlePath = await mountBundle(wasmFs.fs, state, "/work", instance);
      }
      if (spec.usePlistBytes) {
        const plistPath = `${bundlePath}/Info.plist`;
        try {
          plistBytes = wasmFs.fs.readFileSync(plistPath);
        } catch (error) {
          throw new Error(`Unable to read ${plistPath}.`);
        }
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

    if (spec.usePlistBytes) {
      const plistData = plistBytes ?? new Uint8Array();
      const dataPtr = allocBytes(instance, plistData);
      resultPtr = exportFn(dataPtr, plistData.length, compactFlag);
      freeCString(instance, dataPtr);
    } else if (signature === "compact") {
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

async function runDownloadExport(spec) {
  if (!state.bundleRoot || state.fileCount === 0) {
    setStatus("Select a .xcresult folder or zip before running.", "error");
    return;
  }

  const testId = elements.testIdInput.value.trim();
  if (spec.needsTestId && !testId) {
    setStatus("This command requires a test id.", "error");
    return;
  }

  setStatus("Loading WASM runtime...", "info");
  elements.runButton.disabled = true;
  if (elements.smokeButton) {
    elements.smokeButton.disabled = true;
  }
  elements.output.textContent = "// Running export...";

  try {
    const { instance, wasmFs } = await createRuntime();
    const { bundlePath } = await prepareDatabase(instance, wasmFs);
    const exportFn = instance.exports[spec.exportName];
    if (!exportFn) {
      throw new Error(`Missing export: ${spec.exportName}`);
    }

    const exportRoot = "/tmp/export";
    ensureDir(wasmFs.fs, exportRoot);
    const stamp = Date.now();
    const signature = spec.downloadSignature ?? "path+output";
    let exportName = `${spec.outputName}-${stamp}`;
    if (spec.useTestIdInName && testId) {
      const safeId = safeFileName(testId) || "object";
      exportName = `${spec.outputName}-${safeId}-${stamp}`;
    }
    let outputPath = `${exportRoot}/${exportName}`;
    const objectType = signature === "path+output+id+type"
      ? (elements.objectTypeSelect?.value ?? "file")
      : null;
    if (signature === "path+output+id+type" && objectType === "file") {
      const fileStem = safeFileName(testId) || "object";
      outputPath = `${outputPath}/${fileStem}.bin`;
    }

    const pathPtr = allocCString(instance, bundlePath);
    const outputPtr = allocCString(instance, outputPath);
    let testPtr = 0;
    let typePtr = 0;
    let ok = false;

    if (signature === "path+output") {
      ok = exportFn(pathPtr, outputPtr);
    } else if (signature === "path+output+testId") {
      if (testId) {
        testPtr = allocCString(instance, testId);
      }
      ok = exportFn(pathPtr, outputPtr, testPtr);
    } else if (signature === "path+output+testId+flag") {
      if (testId) {
        testPtr = allocCString(instance, testId);
      }
      const onlyFailuresFlag = elements.onlyFailuresToggle?.checked ? 1 : 0;
      ok = exportFn(pathPtr, outputPtr, testPtr, onlyFailuresFlag);
    } else if (signature === "path+output+id+type") {
      testPtr = allocCString(instance, testId);
      typePtr = allocCString(instance, objectType ?? "file");
      ok = exportFn(pathPtr, outputPtr, testPtr, typePtr);
    } else {
      throw new Error(`Unsupported export signature: ${signature}`);
    }

    freeCString(instance, pathPtr);
    freeCString(instance, outputPtr);
    if (testPtr) {
      freeCString(instance, testPtr);
    }
    if (typePtr) {
      freeCString(instance, typePtr);
    }

    if (!ok) {
      const error = getLastError(instance) || "Unknown error";
      throw new Error(error);
    }

    let zipResult = null;
    if (spec.useFileRegistry) {
      try {
        zipResult = buildZipFromRegistry(instance, outputPath, exportName);
      } catch (error) {
        zipResult = null;
      }
    }
    if (!zipResult) {
      zipResult = buildZipFromWasm(wasmFs.fs, outputPath, exportName);
    }
    const { bytes, fileCount } = zipResult;
    downloadZip(bytes, `${exportName}.zip`);
    elements.output.textContent = `// Exported ${fileCount} files to ${exportName}.zip`;
    setStatus("Export complete. Download should start shortly.", "success");
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

async function runCompare() {
  if (!state.bundleRoot || state.fileCount === 0) {
    setStatus("Select a baseline .xcresult bundle first.", "error");
    return;
  }
  if (!compareState.bundleRoot || compareState.fileCount === 0) {
    setStatus("Select a comparison .xcresult bundle to compare against.", "error");
    return;
  }

  setStatus("Loading WASM runtime...", "info");
  elements.runButton.disabled = true;
  if (elements.smokeButton) {
    elements.smokeButton.disabled = true;
  }
  elements.output.textContent = "// Running compare...";

  try {
    const { instance, wasmFs } = await createRuntime();
    const baseline = await prepareDatabase(instance, wasmFs, state, "/work");
    const current = await prepareDatabase(instance, wasmFs, compareState, "/compare");
    const exportFn = instance.exports.openxcresulttool_compare_json;
    if (!exportFn) {
      throw new Error("Missing export: openxcresulttool_compare_json");
    }
    const compactFlag = elements.compactToggle.checked ? 1 : 0;
    const baselinePtr = allocCString(instance, baseline.bundlePath);
    const currentPtr = allocCString(instance, current.bundlePath);
    const resultPtr = exportFn(baselinePtr, currentPtr, compactFlag);
    freeCString(instance, baselinePtr);
    freeCString(instance, currentPtr);
    if (!resultPtr) {
      const error = getLastError(instance) || "Unknown error";
      throw new Error(error);
    }
    const json = readCString(instance, resultPtr);
    freeCString(instance, resultPtr);
    elements.output.textContent = json;
    setStatus("Compare complete.", "success");
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    elements.output.textContent = "// Failed to run compare.";
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

function handleCompareFiles(event) {
  const files = Array.from(event.target.files || []);
  if (!files.length) {
    resetState(compareState, elements.compareBundleName, elements.compareBundleCount);
    return;
  }

  const samplePath = files[0].webkitRelativePath || files[0].name;
  const rootName = samplePath.split("/")[0] || "bundle.xcresult";

  applyDirectoryFiles(
    files,
    rootName,
    compareState,
    elements.compareBundleName,
    elements.compareBundleCount,
    elements.compareZipInput
  );
}

async function handleCompareZipFile(event) {
  const [file] = Array.from(event.target.files || []);
  if (!file) {
    if (compareState.source === "zip") {
      resetState(compareState, elements.compareBundleName, elements.compareBundleCount);
    }
    return;
  }

  await handleZipData(
    file,
    compareState,
    elements.compareBundleName,
    elements.compareBundleCount,
    elements.compareInput
  );
}

function applyDirectoryFiles(
  files,
  rootName,
  targetState = state,
  nameElement = elements.bundleName,
  countElement = elements.bundleCount,
  clearInput = elements.zipInput
) {
  targetState.source = "directory";
  targetState.files = files;
  targetState.entries = [];
  targetState.bundleRoot = rootName;
  targetState.fileCount = files.length;
  const paths = files.map((file) => file.webkitRelativePath || file.name);
  const detectedRoot = detectBundleRootFromPaths(paths);
  if (detectedRoot) {
    targetState.bundleRoot = detectedRoot;
  }
  if (clearInput) {
    clearInput.value = "";
  }
  updateBundleMeta(targetState, nameElement, countElement);
  setStatus("Bundle staged. Ready to run.", "success");
}

async function handleZipData(
  file,
  targetState = state,
  nameElement = elements.bundleName,
  countElement = elements.bundleCount,
  clearInput = elements.input
) {
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

  targetState.source = "zip";
  targetState.files = [];
  targetState.entries = normalized.entries;
  targetState.bundleRoot = normalized.bundleRoot;
  targetState.fileCount = normalized.fileCount;
  const detectedRoot = detectBundleRootFromPaths(normalized.entries.map((entry) => entry.path));
  if (detectedRoot) {
    targetState.bundleRoot = detectedRoot;
  }
  if (clearInput) {
    clearInput.value = "";
  }
  updateBundleMeta(targetState, nameElement, countElement);
  setStatus("Zip staged. Ready to run.", "success");
}

function setDropActive(dropZone, active) {
  if (!dropZone) {
    return;
  }
  dropZone.classList.toggle("dragover", active);
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
    const trimmed = entry.fullPath.replace(/^\//, "");
    if (trimmed.startsWith(`${rootName}/`)) {
      return trimmed;
    }
    return `${rootName}/${trimmed}`;
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
        try {
          file._relativePath = relativePath;
        } catch (error) {
          // Ignore if the File object is sealed.
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

async function handleDrop(
  event,
  targetState = state,
  nameElement = elements.bundleName,
  countElement = elements.bundleCount,
  clearDirectoryInput = elements.zipInput,
  clearZipInput = elements.input
) {
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
      applyDirectoryFiles(
        files,
        directoryEntry.name,
        targetState,
        nameElement,
        countElement,
        clearDirectoryInput
      );
      return;
    }

    const zipEntry = entries.find((entry) => entry.isFile && entry.name.endsWith(".zip"));
    if (zipEntry && zipEntry.file) {
      zipEntry.file((file) => handleZipData(file, targetState, nameElement, countElement, clearZipInput));
      return;
    }
  }

  const files = Array.from(dataTransfer.files || []);
  if (files.length === 1 && files[0].name.endsWith(".zip")) {
    await handleZipData(files[0], targetState, nameElement, countElement, clearZipInput);
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
if (elements.compareInput) {
  elements.compareInput.addEventListener("change", handleCompareFiles);
}
if (elements.compareZipInput) {
  elements.compareZipInput.addEventListener("change", handleCompareZipFile);
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
    setDropActive(elements.dropZone, true);
  });
  elements.dropZone.addEventListener("dragover", (event) => {
    event.preventDefault();
    setDropActive(elements.dropZone, true);
  });
  elements.dropZone.addEventListener("dragleave", (event) => {
    if (event.target === elements.dropZone) {
      setDropActive(elements.dropZone, false);
    }
  });
  elements.dropZone.addEventListener("drop", async (event) => {
    event.preventDefault();
    setDropActive(elements.dropZone, false);
    await handleDrop(event);
  });
}
if (elements.compareDropZone) {
  elements.compareDropZone.addEventListener("dragenter", (event) => {
    event.preventDefault();
    setDropActive(elements.compareDropZone, true);
  });
  elements.compareDropZone.addEventListener("dragover", (event) => {
    event.preventDefault();
    setDropActive(elements.compareDropZone, true);
  });
  elements.compareDropZone.addEventListener("dragleave", (event) => {
    if (event.target === elements.compareDropZone) {
      setDropActive(elements.compareDropZone, false);
    }
  });
  elements.compareDropZone.addEventListener("drop", async (event) => {
    event.preventDefault();
    setDropActive(elements.compareDropZone, false);
    await handleDrop(
      event,
      compareState,
      elements.compareBundleName,
      elements.compareBundleCount,
      elements.compareZipInput,
      elements.compareInput
    );
  });
}

updateBundleMeta();
updateBundleMeta(compareState, elements.compareBundleName, elements.compareBundleCount);
updateTestIdVisibility();
