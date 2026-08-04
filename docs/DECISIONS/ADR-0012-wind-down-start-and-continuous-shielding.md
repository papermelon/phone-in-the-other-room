# ADR-0012: Wind Down start confirmation and continuous app barrier

**Status:** Accepted for TestFlight build 10
**Date:** 2026-08-04

## Context

The Wind Down screen previously created a running session and countdown before the
NFC action was complete. That made the tag read like a placement check, while the
actual user intent is an app-access barrier: selected apps should become limited
when the user deliberately starts the ritual, and the registered Wind Down tag is
the normal way to end that barrier early.

Build 9 also created Live Activities by default and used the remote-token request
path even when backend Live Activity delivery was disabled. This added an avoidable
ActivityKit/extension path to the most sensitive start transition.

## Decision

Every manual Night Watch start shows a short preflight. The user chooses whether
to show a Live Activity for that run. For App Shielding, the session starts
immediately after confirmation; for NFC + App Shielding, no run, countdown, Live
Activity, or shield is created until the registered Wind Down tag is read.

The NFC copy describes a Wind Down tag and an app-access barrier. A matching tag
confirms the barrier and is the normal early-exit credential; a mismatched or
cancelled scan leaves the session and its shield unchanged.

When shielding is enabled and a selection exists, the DeviceActivity schedule uses
one protected-session interval from the run start (or successful NFC confirmation)
through the scheduled morning-quiet finish. This deliberately spans the overnight
phase. The app reconciles the ManagedSettings store immediately, while the monitor
extension enforces the same interval when the app is suspended or terminated. A
stale interval callback may not clear a currently active replacement schedule.

The existing fail-open emergency exit remains available. Completion, authenticated
NFC exit, and emergency exit clear the shield. Legacy two-bookend snapshots remain
decodable and are still understood by the monitor.

Local Live Activities use `pushType: nil` unless the separately gated Supabase
push configuration is enabled. The per-run consent is persisted with a backwards-
compatible default for older runs.

## Consequences

- Users get one explicit, understandable start action and a predictable barrier.
- Overnight app limits remain active instead of disappearing between bookends.
- Physical-device QA must prove both direct ManagedSettings application and the
  terminated-app DeviceActivity callback, including Family Controls distribution
  capability and the shared App Group.
- App Store/TestFlight copy and privacy notes must describe the optional Live
  Activity and selected-app barrier accurately.
