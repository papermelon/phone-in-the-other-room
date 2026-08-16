#!/bin/sh
set -eu

project="PhoneInTheOtherRoom.xcodeproj"
scheme="PhoneInTheOtherRoomSlumberPartyQA"
scheme_file="$project/xcshareddata/xcschemes/$scheme.xcscheme"

if ! command -v xcodegen >/dev/null 2>&1; then
    echo "error: xcodegen is required to validate the Slumber Party QA lane" >&2
    exit 1
fi

xcodegen generate >/dev/null

if ! command -v xmllint >/dev/null 2>&1; then
    echo "error: xmllint is required to validate the Slumber Party QA scheme" >&2
    exit 1
fi

scheme_configuration() {
    action="$1"
    if ! xmllint --xpath "string(/Scheme/$action/@buildConfiguration)" "$scheme_file" 2>/dev/null; then
        echo "error: could not read $action from the QA scheme" >&2
        exit 1
    fi
}

assert_scheme_configuration() {
    action="$1"
    expected="$2"
    actual="$(scheme_configuration "$action")"
    [ "$actual" = "$expected" ] || {
        echo "error: $action does not use $expected" >&2
        exit 1
    }
}

assert_scheme_configuration TestAction SlumberPartyQA
assert_scheme_configuration LaunchAction SlumberPartyQA
assert_scheme_configuration AnalyzeAction SlumberPartyQA
assert_scheme_configuration ProfileAction Release
assert_scheme_configuration ArchiveAction SlumberPartyQA

build_settings() {
    configuration="$1"
    if ! output="$(xcodebuild -showBuildSettings \
        -project "$project" \
        -scheme "$scheme" \
        -configuration "$configuration" \
        -sdk iphonesimulator 2>/dev/null)"; then
        echo "error: could not read $configuration build settings" >&2
        exit 1
    fi
    printf '%s\n' "$output"
}

setting_value() {
    setting="$1"
    awk -v setting="$setting" '$0 ~ "^[[:space:]]*" setting " = " { sub("^[[:space:]]*" setting " = ", ""); print; exit }'
}

qa_settings="$(build_settings SlumberPartyQA)"
release_settings="$(build_settings Release)"
debug_settings="$(build_settings Debug)"
qa_flag="$(printf '%s\n' "$qa_settings" | setting_value SUPABASE_NIGHT_FLOCK_ENABLED)"
release_flag="$(printf '%s\n' "$release_settings" | setting_value SUPABASE_NIGHT_FLOCK_ENABLED)"
qa_conditions="$(printf '%s\n' "$qa_settings" | setting_value SWIFT_ACTIVE_COMPILATION_CONDITIONS)"
release_conditions="$(printf '%s\n' "$release_settings" | setting_value SWIFT_ACTIVE_COMPILATION_CONDITIONS)"
debug_conditions="$(printf '%s\n' "$debug_settings" | setting_value SWIFT_ACTIVE_COMPILATION_CONDITIONS)"

[ "$qa_flag" = "YES" ] || { echo "error: SlumberPartyQA flag is not YES" >&2; exit 1; }
[ "$release_flag" = "YES" ] || { echo "error: Release flag is not YES" >&2; exit 1; }
case " $qa_conditions " in
    *" SLUMBER_PARTY_QA "*) ;;
    *) echo "error: SlumberPartyQA compiler condition is missing" >&2; exit 1 ;;
esac
case " $release_conditions " in
    *" SLUMBER_PARTY_QA "*) echo "error: Release contains the Slumber Party QA compiler condition" >&2; exit 1 ;;
    *) ;;
esac
case " $debug_conditions " in
    *" SLUMBER_PARTY_QA "*) echo "error: Debug contains the Slumber Party QA compiler condition" >&2; exit 1 ;;
    *) ;;
esac

echo "SlumberPartyQA: SUPABASE_NIGHT_FLOCK_ENABLED=YES"
echo "Release: SUPABASE_NIGHT_FLOCK_ENABLED=YES"
echo "SlumberPartyQA compiler condition: present only in SlumberPartyQA"
