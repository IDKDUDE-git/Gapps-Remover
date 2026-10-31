#!/usr/bin/env bash

set -u
set -o pipefail

PACKAGES=(
    com.google.android.gms
    com.google.android.gms.location.history
    com.google.android.gms.supervision
    com.google.android.gsf
    com.android.vending
)

PRESERVE_PACKAGES=(
    com.android.chrome
    com.google.android.apps.maps
    com.google.android.apps.photos
)

usage() {
    cat <<'EOF'
Usage: remove-google-user.sh [status|remove|restore|list-others|remove-others|restore-others] [device-serial]

status   Show whether the selected Google packages are installed for user 0.
remove   Uninstall those packages for user 0 only; system files are untouched.
restore  Restore those packages for user 0 if they are present in the ROM.

list-others     List Google packages that would be affected, excluding Chrome,
                Maps, Photos, and Android overlay packages.
remove-others   Remove those packages for user 0 after explicit confirmation.
restore-others  Restore those packages for user 0 if present in the ROM.

Select a device with the optional serial or ANDROID_SERIAL.
EOF
}

fail() {
    printf 'Error: %s\n' "$*" >&2
    exit 1
}

ACTION="${1:-status}"
SERIAL="${2:-${ANDROID_SERIAL:-}}"

case "$ACTION" in
    status|remove|restore|list-others|remove-others|restore-others) ;;
    -h|--help|help)
        usage
        exit 0
        ;;
    *) usage >&2; fail "Unknown action: $ACTION" ;;
esac

[[ $# -le 2 ]] || { usage >&2; fail "Too many arguments."; }

command -v adb >/dev/null 2>&1 ||
    fail "adb was not found. Install Android platform-tools and add adb to PATH."

ADB_COMMAND=(adb)
if [[ -n "$SERIAL" ]]; then
    ADB_COMMAND+=(-s "$SERIAL")
fi

if ! device_state=$("${ADB_COMMAND[@]}" get-state 2>&1); then
    printf '%s\n' "$device_state" >&2
    fail "No authorized ADB device is available. Enable USB debugging and accept the authorization prompt."
fi
[[ "$device_state" == device ]] || fail "ADB device is not ready: $device_state"

if [[ "$ACTION" == remove ]]; then
    cat <<'EOF'
This will remove the listed packages from Android user 0.
It does not erase their system files, but Google-dependent apps and features
may stop working. Use "restore" to bring back packages included in the ROM.
EOF
    read -r -p "Type REMOVE to continue: " confirmation
    [[ "$confirmation" == REMOVE ]] || fail "Cancelled; no packages were changed."
fi

if [[ "$ACTION" == restore-others ]]; then
    package_list_args=(pm list packages -u --user 0)
else
    package_list_args=(pm list packages --user 0)
fi

if ! installed_packages=$("${ADB_COMMAND[@]}" shell "${package_list_args[@]}" 2>&1); then
    printf '%s\n' "$installed_packages" >&2
    fail "Could not list packages for user 0."
fi
installed_packages="${installed_packages//$'\r'/}"

is_preserved_package() {
    local candidate="$1"
    local preserved
    for preserved in "${PRESERVE_PACKAGES[@]}"; do
        [[ "$candidate" == "$preserved" ]] && return 0
    done
    return 1
}

if [[ "$ACTION" == list-others || "$ACTION" == remove-others || "$ACTION" == restore-others ]]; then
    dynamic_packages=()
    while IFS= read -r line; do
        [[ "$line" == package:* ]] || continue
        package="${line#package:}"
        [[ "$package" == com.google.* || "$package" == com.android.vending ]] || continue
        [[ "$package" == *".overlay."* ]] && continue
        is_preserved_package "$package" && continue
        dynamic_packages+=("$package")
    done <<<"$installed_packages"

    if [[ ${#dynamic_packages[@]} -eq 0 ]]; then
        printf 'No matching Google packages found.\n'
        exit 0
    fi

    if [[ "$ACTION" == list-others ]]; then
        printf 'Packages to remove (preserving Chrome, Maps, Photos, and Android overlays):\n'
        printf '  %s\n' "${dynamic_packages[@]}"
        exit 0
    fi

    if [[ "$ACTION" == remove-others ]]; then
        printf 'The following packages will be removed for user 0; system files are untouched:\n'
        printf '  %s\n' "${dynamic_packages[@]}"
        printf '\nOther apps/features that depend on Google services may stop working.\n'
        printf 'Type REMOVE-GOOGLE to continue: '
        read -r confirmation
        [[ "$confirmation" == REMOVE-GOOGLE ]] ||
            fail "Cancelled; no packages were changed."
    fi

    for package in "${dynamic_packages[@]}"; do
        if [[ "$ACTION" == remove-others ]]; then
            result=$("${ADB_COMMAND[@]}" shell pm uninstall --user 0 "$package" 2>&1) ||
                { printf '%s\n' "$result" >&2; fail "Could not remove $package for user 0."; }
            result="${result//$'\r'/}"
            [[ "$result" == *Success* ]] ||
                { printf '%s\n' "$result" >&2; fail "ADB did not confirm removal of $package."; }
            printf '%s: removed for user 0\n' "$package"
        else
            result=$("${ADB_COMMAND[@]}" shell cmd package install-existing --user 0 "$package" 2>&1) ||
                { printf '%s\n' "$result" >&2; fail "Could not restore $package for user 0."; }
            result="${result//$'\r'/}"
            [[ "$result" == *installed* ]] ||
                { printf '%s\n' "$result" >&2; fail "ADB did not confirm restoration of $package."; }
            printf '%s: restored for user 0\n' "$package"
        fi
    done
    exit 0
fi

for package in "${PACKAGES[@]}"; do
    if grep -Fqx "package:$package" <<<"$installed_packages"; then
        installed=true
    else
        installed=false
    fi

    case "$ACTION" in
        status)
            if [[ "$installed" == true ]]; then
                printf '%s: installed for user 0\n' "$package"
            else
                printf '%s: not installed for user 0\n' "$package"
            fi
            ;;
        remove)
            if [[ "$installed" == false ]]; then
                printf '%s: already absent for user 0; skipping\n' "$package"
                continue
            fi
            if ! result=$("${ADB_COMMAND[@]}" shell pm uninstall --user 0 "$package" 2>&1); then
                printf '%s\n' "$result" >&2
                fail "Could not remove $package for user 0."
            fi
            result="${result//$'\r'/}"
            if [[ "$result" != *Success* ]]; then
                printf '%s\n' "$result" >&2
                fail "ADB did not confirm removal of $package."
            fi
            printf '%s: removed for user 0\n' "$package"
            ;;
        restore)
            if [[ "$installed" == true ]]; then
                printf '%s: already installed for user 0; skipping\n' "$package"
                continue
            fi
            if ! result=$("${ADB_COMMAND[@]}" shell cmd package install-existing --user 0 "$package" 2>&1); then
                printf '%s\n' "$result" >&2
                fail "Could not restore $package for user 0."
            fi
            result="${result//$'\r'/}"
            if [[ "$result" != *installed* ]]; then
                printf '%s\n' "$result" >&2
                fail "ADB did not confirm restoration of $package."
            fi
            printf '%s: restored for user 0\n' "$package"
            ;;
    esac
done
