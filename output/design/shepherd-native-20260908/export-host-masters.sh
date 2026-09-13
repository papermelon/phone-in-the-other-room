#!/bin/bash
set -euo pipefail
study_dir=$(cd "$(dirname "$0")" && pwd)
project_dir=$(cd "$study_dir/../../.." && pwd)
build_dir=$(mktemp -d "${TMPDIR:-/tmp}/shepherd-master-export.XXXXXX")
trap 'rm -rf "$build_dir"' EXIT
cd "$project_dir"
python3 - "$build_dir/Profile.swift" <<'PYTHON'
from pathlib import Path
import sys
source = Path("Shared/FarmModels.swift").read_text()
Path(sys.argv[1]).write_text("import Foundation\n" + source[source.index("enum ShepherdSkinTone:"):source.index("enum FarmDecorationZone:")])
PYTHON
xcrun swiftc -D DEBUG -parse-as-library -module-cache-path "$build_dir/modules" \
  "$build_dir/Profile.swift" \
  Shared/ShepherdAvatarAppearance.swift \
  Shared/ShepherdArtStudy.swift \
  PhoneInTheOtherRoomApp/Design/ShepherdStudyPalette.swift \
  PhoneInTheOtherRoomApp/Views/ShepherdArtStudy/ShepherdStudyMasterPaths.swift \
  PhoneInTheOtherRoomApp/Views/ShepherdArtStudy/ShepherdStudyPainter.swift \
  PhoneInTheOtherRoomApp/Views/ShepherdArtStudy/ShepherdStudyHeadDrawing.swift \
  PhoneInTheOtherRoomApp/Views/ShepherdArtStudy/ShepherdStudyCanvas.swift \
  "$study_dir/HostMasterExport.swift" -o "$build_dir/export"
"$build_dir/export" "$study_dir"
