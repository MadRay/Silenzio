#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/dist/Silenzio.app"

"$ROOT/Scripts/package-app.sh" debug
open "$APP"
