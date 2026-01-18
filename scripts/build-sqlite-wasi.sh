#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SQLITE_VERSION="${SQLITE_VERSION:-3460100}"
SQLITE_YEAR="${SQLITE_YEAR:-2024}"
WASI_SDK_PATH="${WASI_SDK_PATH:-/opt/wasi-sdk}"

ARCHIVE_NAME="sqlite-autoconf-${SQLITE_VERSION}.tar.gz"
DOWNLOAD_URL="https://www.sqlite.org/${SQLITE_YEAR}/${ARCHIVE_NAME}"

WORK_DIR="$(mktemp -d)"
cleanup() {
    rm -rf "${WORK_DIR}"
}
trap cleanup EXIT

curl -L "${DOWNLOAD_URL}" -o "${WORK_DIR}/${ARCHIVE_NAME}"

tar -xzf "${WORK_DIR}/${ARCHIVE_NAME}" -C "${WORK_DIR}"
cd "${WORK_DIR}/sqlite-autoconf-${SQLITE_VERSION}"

CC="${WASI_SDK_PATH}/bin/wasm32-wasi-clang"
AR="${WASI_SDK_PATH}/bin/llvm-ar"
RANLIB="${WASI_SDK_PATH}/bin/llvm-ranlib"

SQLITE_CFLAGS=(
    -O2
    -DSQLITE_THREADSAFE=0
    -DSQLITE_OMIT_LOAD_EXTENSION
    -DSQLITE_ENABLE_MATH_FUNCTIONS
    -DSQLITE_ENABLE_FTS4
    -DSQLITE_ENABLE_FTS5
    -DSQLITE_ENABLE_RTREE
    -DSQLITE_ENABLE_GEOPOLY
    -DSQLITE_ENABLE_EXPLAIN_COMMENTS
    -DSQLITE_DQS=0
    -DSQLITE_ENABLE_DBPAGE_VTAB
    -DSQLITE_ENABLE_STMTVTAB
    -DSQLITE_ENABLE_DBSTAT_VTAB
    -DSQLITE_USE_URI
)

"${CC}" "${SQLITE_CFLAGS[@]}" -c sqlite3.c -o sqlite3.o
"${AR}" rcs libsqlite3.a sqlite3.o
"${RANLIB}" libsqlite3.a

mkdir -p "${ROOT_DIR}/Sources/SQLite3WASI/include" "${ROOT_DIR}/Sources/SQLite3WASI/lib"

cp sqlite3.h "${ROOT_DIR}/Sources/SQLite3WASI/include/"
cp libsqlite3.a "${ROOT_DIR}/Sources/SQLite3WASI/lib/"

cat > "${ROOT_DIR}/Sources/SQLite3WASI/VERSION" <<VERSION
sqlite-autoconf-${SQLITE_VERSION}
${DOWNLOAD_URL}
VERSION
