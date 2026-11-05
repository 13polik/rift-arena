#!/usr/bin/env bash
# Dev helper: refresh the import / class cache, then run a scene. Usage: tools/run.sh <scene.tscn> [-- args]
G="$LOCALAPPDATA/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7.2-stable_win64_console.exe"
cd "$(dirname "$0")/.."
timeout 120 "$G" --headless --path . --import 2>&1 | grep -E "SCRIPT ERROR|Parse Error|Compile Error" | sort -u
timeout ${RUN_TIMEOUT:-150} "$G" --path . "$@" 2>&1 | grep -vE "^\s*$|Unreferenced static string|at: unref|main.tscn"
