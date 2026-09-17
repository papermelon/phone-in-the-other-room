#!/bin/bash
set -euo pipefail
study_dir=$(cd "$(dirname "$0")" && pwd)
project_dir=$(cd "$study_dir/../../.." && pwd)
label=${1:-revised}
source_dir=${2:-$project_dir}
build_dir=$(mktemp -d "${TMPDIR:-/tmp}/shepherd-body-export.XXXXXX")
trap 'rm -rf "$build_dir"' EXIT
python3 - "$source_dir" "$build_dir/Profile.swift" <<'PY'
from pathlib import Path
import sys
source = (Path(sys.argv[1]) / "Shared/FarmModels.swift").read_text()
Path(sys.argv[2]).write_text("import Foundation\n" + source[source.index("enum ShepherdSkinTone:"):source.index("enum FarmDecorationZone:")])
PY
sources=(
  "$build_dir/Profile.swift"
  "$source_dir/Shared/ShepherdAvatarAppearance.swift"
  "$source_dir/Shared/ShepherdArtStudy.swift"
  "$source_dir/PhoneInTheOtherRoomApp/Design/ShepherdStudyPalette.swift"
  "$source_dir/PhoneInTheOtherRoomApp/Views/ShepherdArtStudy/ShepherdStudyMasterPaths.swift"
  "$source_dir/PhoneInTheOtherRoomApp/Views/ShepherdArtStudy/ShepherdStudyPainter.swift"
  "$source_dir/PhoneInTheOtherRoomApp/Views/ShepherdArtStudy/ShepherdStudyHeadDrawing.swift"
  "$source_dir/PhoneInTheOtherRoomApp/Views/ShepherdArtStudy/ShepherdStudyCanvas.swift"
)
body_paths="$source_dir/PhoneInTheOtherRoomApp/Views/ShepherdArtStudy/ShepherdStudyBodyPaths.swift"
if [[ -f "$body_paths" ]]; then sources+=("$body_paths"); fi
xcrun swiftc -parse-as-library -module-cache-path "$build_dir/modules" "${sources[@]}" "$study_dir/ProductionExport.swift" -o "$build_dir/export"
"$build_dir/export" "$study_dir" "$label" "$project_dir"
shasum -a 256 "${sources[@]:1}" > "$study_dir/$label-source-sha256.txt"
