#!/usr/bin/env bash
set -euo pipefail

CONFIG="${CABLE_CONFIG:?CABLE_CONFIG is required}"
WORKSPACE="${CABLE_WORKSPACE:?CABLE_WORKSPACE is required}"

case "$CONFIG" in
    /*) ;;
    *) echo "CABLE_CONFIG 必须是绝对路径" >&2; exit 2 ;;
esac
case "$WORKSPACE" in
    /*) ;;
    *) echo "CABLE_WORKSPACE 必须是绝对路径" >&2; exit 2 ;;
esac

test -f /opt/cable/runtime-info.json
test -r "$CONFIG"
mkdir -p "$WORKSPACE"
mkdir -p "${CABLE_PLUGIN_HOME:?CABLE_PLUGIN_HOME is required}"

/opt/venv/bin/python -m agent.runtime_identity \
    --runtime-info /opt/cable/runtime-info.json \
    --release-manifest "${CABLE_RELEASE_MANIFEST:?CABLE_RELEASE_MANIFEST is required}" \
    --expected-commit "${CABLE_RUNTIME_COMMIT:?CABLE_RUNTIME_COMMIT is required}" \
    --host-checkout "${CABLE_RUNTIME_CHECKOUT:?CABLE_RUNTIME_CHECKOUT is required}"

if [[ "${CABLE_EXECUTION_MODE:-local}" == "host-bridge" ]]; then
    : "${CABLE_HOST_BRIDGE_SOCKET:?CABLE_HOST_BRIDGE_SOCKET is required}"
    : "${CABLE_HOST_BRIDGE_TOKEN:?CABLE_HOST_BRIDGE_TOKEN is required}"
    /opt/venv/bin/python -m agent.plugins.entrypoints \
        --distribution "${CABLE_PLUGIN_DISTRIBUTION:?CABLE_PLUGIN_DISTRIBUTION is required}" \
        --workspace "$WORKSPACE" --config "$CONFIG" bridge-doctor \
        --socket "$CABLE_HOST_BRIDGE_SOCKET" \
        --token "$CABLE_HOST_BRIDGE_TOKEN" \
        --expected-release-commit "$CABLE_RUNTIME_COMMIT" \
        --expected-toolchain-digest "${CABLE_HOST_TOOLCHAIN_DIGEST:?CABLE_HOST_TOOLCHAIN_DIGEST is required}"
fi

command="${1:-supervise}"
shift || true
exec /opt/venv/bin/python /opt/cable/source/main.py \
    "$command" \
    --config "$CONFIG" \
    --workspace "$WORKSPACE" \
    "$@"
