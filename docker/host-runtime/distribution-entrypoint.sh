#!/usr/bin/env bash
set -euo pipefail

CONFIG="${CABLE_CONFIG:?CABLE_CONFIG is required}"
WORKSPACE="${CABLE_WORKSPACE:?CABLE_WORKSPACE is required}"
PLUGIN_HOME="${CABLE_PLUGIN_HOME:?CABLE_PLUGIN_HOME is required}"
EXPECTED_COMMIT="${CABLE_RUNTIME_COMMIT:?CABLE_RUNTIME_COMMIT is required}"
EXPECTED_TREE="${CABLE_RUNTIME_TREE:?CABLE_RUNTIME_TREE is required}"

case "$CONFIG" in
    /*) ;;
    *) echo "CABLE_CONFIG 必须是绝对路径" >&2; exit 2 ;;
esac
case "$WORKSPACE" in
    /*) ;;
    *) echo "CABLE_WORKSPACE 必须是绝对路径" >&2; exit 2 ;;
esac
case "$PLUGIN_HOME" in
    /*) ;;
    *) echo "CABLE_PLUGIN_HOME 必须是绝对路径" >&2; exit 2 ;;
esac

test -r "$CONFIG"
test -r /opt/cable/runtime-info.json

/opt/venv/bin/python /opt/cable/source/scripts/distribution_runtime.py check \
    --runtime-info /opt/cable/runtime-info.json \
    --expected-commit "$EXPECTED_COMMIT" \
    --expected-tree "$EXPECTED_TREE"

if [[ "${1:-}" == "publish" ]]; then
    shift
    exec /opt/venv/bin/python /opt/cable/source/scripts/install_plugin_distribution.py \
        --distribution /opt/cable/distribution \
        --bundle /opt/cable/distribution/bundles/"${CABLE_PLUGIN_BUNDLE:-base}".toml \
        --workspace "$WORKSPACE" --plugins-home "$PLUGIN_HOME" --config "$CONFIG" \
        --publish "$@"
fi

mkdir -p "$WORKSPACE" "$PLUGIN_HOME"

# 首次激活由宿主侧先联网取好 extra 包与 wheel（--extra-inputs），在服务启动之前用本子命令离线装好并提交选择；
# 这样随后的正常启动选择已提交，不联网，健康检查期限与下载耗时无关。
if [[ "${1:-}" == "ensure" ]]; then
    shift
    exec /opt/venv/bin/python /opt/cable/source/scripts/install_plugin_distribution.py \
        --distribution /opt/cable/distribution \
        --bundle /opt/cable/distribution/bundles/"${CABLE_PLUGIN_BUNDLE:-base}".toml \
        --workspace "$WORKSPACE" --plugins-home "$PLUGIN_HOME" --config "$CONFIG" \
        --ensure-bundle --receipt "$WORKSPACE/runtime/distribution-install.json" "$@"
fi

# 补装是否完成以"选择已经提交"为判据：首装中途失败时回执已写、选择仍是空，重试仍要补装；
# 选择已提交的实例由 cable-release 在停机前处理，启动不联网（没有缺口本来也不联网）。
extra_args=()
selection_committed="$(/opt/venv/bin/python - "$WORKSPACE/runtime/plugin-stable.json" <<'PY'
import json, sys
from pathlib import Path
path = Path(sys.argv[1])
print("1" if path.exists() and json.loads(path.read_text(encoding="utf-8")).get("root_ref") else "0")
PY
)"
if [[ "$selection_committed" != "1" ]]; then
    extra_args=(--extra-repo "${CABLE_EXTRA_REPO:-https://github.com/12vivi/cable-plugins.git}")
fi

/opt/venv/bin/python /opt/cable/source/scripts/install_plugin_distribution.py \
    --distribution /opt/cable/distribution \
    --bundle /opt/cable/distribution/bundles/"${CABLE_PLUGIN_BUNDLE:-base}".toml \
    --workspace "$WORKSPACE" \
    --plugins-home "$PLUGIN_HOME" \
    --config "$CONFIG" \
    --ensure-bundle "${extra_args[@]}" \
    --receipt "$WORKSPACE/runtime/distribution-install.json"

command="${1:-gateway}"
export CABLE_DOCKER_RUNTIME=1
shift || true
exec /opt/venv/bin/python /opt/cable/source/main.py \
    "$command" \
    --config "$CONFIG" \
    --workspace "$WORKSPACE" \
    "$@"
