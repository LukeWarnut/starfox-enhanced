#!/usr/bin/env bash
# macOS/Unix counterpart to play-starfox.ps1
set -euo pipefail

MAP="${1:-TITLEMAP}"
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROM_PATH="${PROJECT_ROOT}/upstream-ultrastarfox/SF.SFC"
SYMBOLS_PATH="${PROJECT_ROOT}/upstream-ultrastarfox/SYMBOLS.TXT"
BUILD_PATH="${PROJECT_ROOT}/build/release"
EXECUTABLE_PATH="${BUILD_PATH}/starfox_pc"

if [[ ! -f "${ROM_PATH}" || ! -f "${SYMBOLS_PATH}" ]]; then
    echo "Missing SF.SFC or SYMBOLS.TXT. Run tools/build_upstream.sh first." >&2
    exit 1
fi

if [[ ! -f "${EXECUTABLE_PATH}" ]]; then
    cmake -S "${PROJECT_ROOT}" -B "${BUILD_PATH}" -G Ninja -DCMAKE_BUILD_TYPE=Release \
        || { echo "CMake configuration failed." >&2; exit 1; }
    cmake --build "${BUILD_PATH}" --target starfox_pc -j 8 \
        || { echo "Star Fox build failed." >&2; exit 1; }
fi

"${EXECUTABLE_PATH}" "${ROM_PATH}" "${SYMBOLS_PATH}" "${MAP}"
