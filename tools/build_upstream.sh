#!/usr/bin/env bash
# macOS/Unix counterpart to tools/build_upstream.ps1
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_ROOT="${1:-}"
if [[ -z "${SOURCE_ROOT}" ]]; then
    SOURCE_ROOT="${SCRIPT_DIR}/../upstream-ultrastarfox"
fi

SOURCE="$(cd "${SOURCE_ROOT}" && pwd)"
EXPECTED_COMMIT='270e959a47d82240d9290a6c6630032c9ec53ff5'
BATCH_PATH="${SOURCE}/.starfox-port-build.bat"
SUCCESS_PATH="${SOURCE}/.starfox-port-build.ok"

find_dosbox_x() {
    if [[ -n "${DOSBOX_X:-}" ]]; then
        printf '%s\n' "${DOSBOX_X}"
        return 0
    fi

    if command -v dosbox-x >/dev/null 2>&1; then
        command -v dosbox-x
        return 0
    fi

    local candidate
    for candidate in \
        /opt/homebrew/bin/dosbox-x \
        /usr/local/bin/dosbox-x \
        /Applications/dosbox-x.app/Contents/MacOS/dosbox-x \
        /Applications/DOSBox-X.app/Contents/MacOS/dosbox-x
    do
        if [[ -x "${candidate}" ]]; then
            printf '%s\n' "${candidate}"
            return 0
        fi
    done

    return 1
}

if ! DOSBOX="$(find_dosbox_x)"; then
    echo "UltraStarFox DOSBox toolchain not found. Install DOSBox-X (brew install dosbox-x) or set DOSBOX_X." >&2
    exit 1
fi

ACTUAL_COMMIT="$(git -C "${SOURCE}" rev-parse HEAD 2>/dev/null || true)"
if [[ -z "${ACTUAL_COMMIT}" || "${ACTUAL_COMMIT}" != "${EXPECTED_COMMIT}" ]]; then
    echo "UltraStarFox must be checked out at ${EXPECTED_COMMIT} (found ${ACTUAL_COMMIT:-unknown})" >&2
    exit 1
fi

if [[ -e "${BATCH_PATH}" ]]; then
    echo "Refusing to overwrite existing temporary build file: ${BATCH_PATH}" >&2
    exit 1
fi

cleanup() {
    rm -f "${BATCH_PATH}" "${SUCCESS_PATH}"
}
trap cleanup EXIT

rm -f "${SUCCESS_PATH}"

{
    printf '%s\r\n' '@echo off'
    printf '%s\r\n' 'set path=%path%;c:\bin'
    printf '%s\r\n' 'cd sf'
    printf '%s\r\n' 'make'
    printf '%s\r\n' 'if errorlevel 1 goto failed'
    printf '%s\r\n' 'cd ..'
    printf '%s\r\n' 'echo ok>.starfox-port-build.ok'
    printf '%s\r\n' 'exit'
    printf '%s\r\n' ':failed'
    printf '%s\r\n' 'cd ..'
    printf '%s\r\n' 'exit'
} > "${BATCH_PATH}"

DOSBOX_ARGS=(-fastlaunch)
if [[ -f "${SOURCE}/dosbox-x.conf" ]]; then
    DOSBOX_ARGS+=(-conf "${SOURCE}/dosbox-x.conf")
fi
DOSBOX_ARGS+=("$(basename "${BATCH_PATH}")")

DOSBOX_STATUS=0
(cd "${SOURCE}" && "${DOSBOX}" "${DOSBOX_ARGS[@]}") || DOSBOX_STATUS=$?

if [[ "${DOSBOX_STATUS}" -ne 0 || ! -f "${SUCCESS_PATH}" ]]; then
    echo "UltraStarFox assembler build failed" >&2
    exit 1
fi

for name in SF.SFC SYMBOLS.TXT BANKS.CSV; do
    path="${SOURCE}/${name}"
    if [[ ! -f "${path}" ]]; then
        echo "UltraStarFox build did not produce ${name}" >&2
        exit 1
    fi
    stat -f '%N  %z  %Sm' -t '%Y-%m-%d %H:%M:%S' "${path}"
done
