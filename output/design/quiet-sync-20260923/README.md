# Quiet Slumber Party refresh — 23 September 2026

Removed the transient refresh row from party detail and Home shared moments. The party list only shows its loader without a loaded list snapshot. The existing party toolbar swaps its icon for a spinner within a fixed 44-point frame. Initial detail loading, explicit action loading and stale/failure recovery are retained.

Validation: full xcodebuild test on iPhone 17e (iOS 26.5), using /tmp/slumber-repair-derived: **1131 tests passed, zero failures**. Log: /tmp/quiet-sync-tests.log. git diff --check passed.

Native iPhone 16 Pro QA (iOS 26.5): --slumber-repair-qa --repair-mode sync-cycle repeatedly alternates refreshing/current every two seconds without network. sync-cycle.png shows the toolbar spinner; idle.png shows the resting control. Agreement confirmation and all party content retain their positions. This fixture has no populated check-in draft; physical-device scroll/draft acceptance remains in the backlog. No TestFlight archive/upload was performed.
