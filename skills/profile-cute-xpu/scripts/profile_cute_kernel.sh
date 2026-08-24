#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  profile_cute_kernel.sh --app "<executable and args>" [options]

Options:
  --app CMD          Application command to profile. Required.
  --out DIR         Output directory. Default: profile_results
  --kernel NAME     Exact kernel name for --include-kernels. Optional.
  --mode MODE       timing | overview | full. Default: overview.
  --interval US     unitrace sampling interval in microseconds. Default: 25.
  --arch ARCH       bmg | cri | auto. Default: auto. Controls memory pass choice.
  --timeout SEC     Optional timeout per profiling pass.
  --dry-run         Print commands without executing.
  --help            Show this help.

Modes:
  timing    Run unitrace device timing only.
  overview  Run timing and ComputeBasic.
  full      Run timing, ComputeBasic, VectorEngineStalls, and MemoryProfile on BMG.

Notes:
  Run timing first without --kernel when the exact mangled kernel name is unknown.
  Hardware metrics generally require ZE_FLAT_DEVICE_HIERARCHY=FLAT.
EOF
}

app=""
out="profile_results"
kernel=""
mode="overview"
interval="25"
arch="auto"
timeout_sec=""
dry_run=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    --app) app="${2:-}"; shift 2 ;;
    --out) out="${2:-}"; shift 2 ;;
    --kernel) kernel="${2:-}"; shift 2 ;;
    --mode) mode="${2:-}"; shift 2 ;;
    --interval) interval="${2:-}"; shift 2 ;;
    --arch) arch="${2:-}"; shift 2 ;;
    --timeout) timeout_sec="${2:-}"; shift 2 ;;
    --dry-run) dry_run=1; shift ;;
    --help|-h) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

if [ -z "$app" ]; then
  echo "--app is required" >&2
  usage >&2
  exit 2
fi

case "$mode" in
  timing|overview|full) ;;
  *) echo "Invalid --mode: $mode" >&2; exit 2 ;;
esac

case "$arch" in
  auto|bmg|cri) ;;
  *) echo "Invalid --arch: $arch" >&2; exit 2 ;;
esac

if [ "$dry_run" -eq 0 ] && ! command -v unitrace >/dev/null 2>&1; then
  echo "unitrace not found in PATH" >&2
  exit 127
fi

mkdir -p "$out"

export ZE_FLAT_DEVICE_HIERARCHY="${ZE_FLAT_DEVICE_HIERARCHY:-FLAT}"

run_cmd() {
  local label="$1"
  shift
  printf '\n[%s]\n' "$label"
  printf '%q ' "$@"
  printf '\n'
  if [ "$dry_run" -eq 1 ]; then
    return 0
  fi
  if [ -n "$timeout_sec" ]; then
    timeout "$timeout_sec" "$@"
  else
    "$@"
  fi
}

kernel_args=()
if [ -n "$kernel" ]; then
  kernel_args=(--include-kernels "$kernel")
fi

run_profile_pass() {
  local label="$1"
  shift
  # Use bash -lc so --app can contain normal quoted application arguments.
  run_cmd "$label" bash -lc "$*"
}

run_profile_pass "device timing" \
  "unitrace -d -v -o '$(printf "%q" "$out/timing.csv")' $app"

if [ "$mode" = "timing" ]; then
  exit 0
fi

include_fragment=""
if [ "${#kernel_args[@]}" -gt 0 ]; then
  include_fragment="--include-kernels $(printf "%q" "$kernel")"
fi

run_profile_pass "ComputeBasic" \
  "unitrace -k -g ComputeBasic -i $(printf "%q" "$interval") -o '$(printf "%q" "$out/metrics_basic.csv")' $include_fragment $app"

if [ "$mode" = "overview" ]; then
  exit 0
fi

run_profile_pass "VectorEngineStalls" \
  "unitrace -k -g VectorEngineStalls -i $(printf "%q" "$interval") -o '$(printf "%q" "$out/metrics_stalls.csv")' $include_fragment $app"

if [ "$arch" = "bmg" ] || [ "$arch" = "auto" ]; then
  run_profile_pass "MemoryProfile" \
    "unitrace -k -g MemoryProfile -i $(printf "%q" "$interval") -o '$(printf "%q" "$out/metrics_memory.csv")' $include_fragment $app"
fi
