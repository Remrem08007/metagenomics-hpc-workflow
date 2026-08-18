#!/usr/bin/env bash

# Best-effort helpers for HPC systems that expose software through environment modules.
# These functions never require modules; they only try to load one when the requested
# executable is not already available on PATH.

try_load_module_for() {
    local executable=$1
    local module_name=$2

    command -v "$executable" >/dev/null 2>&1 && return 0

    if command -v module >/dev/null 2>&1 || type module >/dev/null 2>&1; then
        echo "${executable} not found on PATH; trying: module load ${module_name}" >&2
        module load "$module_name" >/dev/null 2>&1 || true
    fi

    command -v "$executable" >/dev/null 2>&1
}
