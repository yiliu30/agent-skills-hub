#!/usr/bin/env bash
set -euo pipefail

json_escape() {
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

command_path() {
  if command -v "$1" >/dev/null 2>&1; then
    command -v "$1"
  else
    true
  fi
}

version_line() {
  local cmd="$1"
  shift || true
  if command -v "$cmd" >/dev/null 2>&1; then
    "$cmd" "$@" 2>&1 | head -n 1 || true
  fi
}

gpu_info=""
if command -v sycl-ls >/dev/null 2>&1; then
  gpu_info="$(sycl-ls 2>/dev/null | grep -i 'gpu' || true)"
elif command -v clinfo >/dev/null 2>&1; then
  gpu_info="$(clinfo 2>/dev/null | grep -i -m 6 'device.*gpu\\|intel.*graphics\\|intel.*arc' || true)"
fi

unitrace_path="$(command_path unitrace)"
icpx_path="$(command_path icpx)"
sycl_ls_path="$(command_path sycl-ls)"
ze_info_path="$(command_path ze_info)"

printf '{\n'
printf '  "unitrace_available": %s,\n' "$([ -n "$unitrace_path" ] && echo true || echo false)"
printf '  "unitrace_path": "%s",\n' "$(json_escape "$unitrace_path")"
printf '  "icpx_available": %s,\n' "$([ -n "$icpx_path" ] && echo true || echo false)"
printf '  "icpx_path": "%s",\n' "$(json_escape "$icpx_path")"
printf '  "icpx_version": "%s",\n' "$(json_escape "$(version_line icpx --version)")"
printf '  "sycl_ls_available": %s,\n' "$([ -n "$sycl_ls_path" ] && echo true || echo false)"
printf '  "ze_info_available": %s,\n' "$([ -n "$ze_info_path" ] && echo true || echo false)"
printf '  "ZE_FLAT_DEVICE_HIERARCHY": "%s",\n' "$(json_escape "${ZE_FLAT_DEVICE_HIERARCHY:-}")"
printf '  "SYCL_DEVICE_FILTER": "%s",\n' "$(json_escape "${SYCL_DEVICE_FILTER:-}")"
printf '  "ONEAPI_DEVICE_SELECTOR": "%s",\n' "$(json_escape "${ONEAPI_DEVICE_SELECTOR:-}")"
printf '  "gpu_devices": "%s"\n' "$(json_escape "$gpu_info")"
printf '}\n'
