#!/data/data/com.termux/files/usr/bin/bash
set -Eeuo pipefail

# TEST-SCOPED USER AUTHORIZATION (2026-09-14): local-only logging.
# BUGFIX (2026-09-14): avoid grep -q producer SIGPIPE false negatives under set -o pipefail.
# BUGFIX (2026-09-14): package dumpsys renders receiver components with the short flattened class
# form (package/.Class); verify that exact installed component instead of the fully-qualified class token.
# Do not require rclone/gdrive during this bootstrap test. Logs are queued locally for later upload.

PROJECT="dhizuku-device-owner-test"
LOG_DIR="/storage/emulated/0/Download/log"
PENDING_MANIFEST="${LOG_DIR}/dhizuku-device-owner-pending-upload.tsv"
LOCAL_ONLY_LOGGING="1"
PACKAGE="com.rosan.dhizuku"
ADMIN_CLASS="com.rosan.dhizuku.server.DhizukuDAReceiver"
ADMIN_COMPONENT="com.rosan.dhizuku/.server.DhizukuDAReceiver"
EXPECTED_VERSION="2.12.0"
EXPECTED_VERSION_CODE="19"
EXPECTED_API="37"
RELEASE_SHA256="243ce26a2dad20e660452072e8891303870b85f7e9bd18c5db65f71dbe12027c"
RESULT="NOT VERIFIED"
SERIAL=""
LOG_FILE=""

now_utc() { date -u +%Y-%m-%dT%H:%M:%SZ; }

ensure_log_dir() {
  if [[ ! -d "$LOG_DIR" ]]; then
    mkdir -p "$LOG_DIR" 2>/dev/null || true
  fi
  if [[ ! -d "$LOG_DIR" || ! -w "$LOG_DIR" ]]; then
    echo "Termux cannot write $LOG_DIR."
    echo "Run: termux-setup-storage"
    echo "Grant the Android storage permission, then run this script again."
    echo "NOT VERIFIED"
    exit 1
  fi
  if [[ -L "$LOG_DIR" || "$(readlink -f "$LOG_DIR")" != "$LOG_DIR" ]]; then
    echo "Log path is not canonical/non-symlink: $LOG_DIR"
    echo "NOT VERIFIED"
    exit 1
  fi
}

ensure_log_dir
stamp="$(date -u +%Y%m%dT%H%M%SZ)"
prefix="$(printf '%s' "${stamp}-$$-${RANDOM}" | sha256sum | awk '{print substr($1,1,8)}')"
LOG_FILE="${LOG_DIR}/${prefix}-dhizuku-device-owner-master.log"
touch "$LOG_FILE"
exec 3>&1 4>&2
exec > >(tee -a "$LOG_FILE" >&3) 2>&1

echo "=== Dhizuku Device Owner isolated test ==="
echo "time_utc=$(now_utc)"
echo "project=$PROJECT"
echo "package=$PACKAGE"
echo "admin=$ADMIN_COMPONENT"
echo "expected_version=$EXPECTED_VERSION"
echo "expected_version_code=$EXPECTED_VERSION_CODE"
echo "expected_api=$EXPECTED_API"
echo "release_sha256=$RELEASE_SHA256"
script_sha="$(sha256sum "$0" | awk '{print $1}')"
echo "script_sha256=$script_sha"
echo "logging_mode=LOCAL_ONLY_DEFERRED_UPLOAD"
echo "Note: the APK hash above identifies the verified release artifact; this script does not require re-hashing the already-installed APK."
echo "Scoped authorization: this test does not require rclone/gdrive; logs remain local until later upload."

finalize_and_exit() {
  local rc="$1"
  trap - ERR
  set +e
  echo "=== finalization ==="
  echo "android_result=$RESULT"
  exec 1>&3 2>&4
  wait || true

  local local_hash sidecar
  local_hash="$(sha256sum "$LOG_FILE" | awk '{print $1}')"
  sidecar="${LOG_FILE}.sha256"
  printf '%s  %s\n' "$local_hash" "$(basename "$LOG_FILE")" > "$sidecar"

  {
    printf '%s\t%s\t%s\t%s\n' "$(now_utc)" "$RESULT" "$local_hash" "$LOG_FILE"
  } >> "$PENDING_MANIFEST"

  echo "log_local=$LOG_FILE"
  echo "log_sha256=$local_hash"
  echo "log_sha256_sidecar=$sidecar"
  echo "pending_upload_manifest=$PENDING_MANIFEST"
  echo "log_upload_deferred=YES"
  echo "rclone_required_for_this_test=NO"
  echo "$RESULT"
  exit "$rc"
}

fail() {
  echo "ERROR: $*"
  RESULT="NOT VERIFIED"
  finalize_and_exit 1
}

unexpected_error() {
  local line="$1" rc="$2"
  echo "ERROR: unexpected failure at line $line (rc=$rc)"
  RESULT="NOT VERIFIED"
  finalize_and_exit "$rc"
}
trap 'unexpected_error "$LINENO" "$?"' ERR


echo "=== tools ==="
if ! command -v adb >/dev/null 2>&1; then
  command -v pkg >/dev/null 2>&1 || fail "adb is missing and Termux pkg is unavailable."
  echo "adb not found; installing required Termux package android-tools..."
  pkg install -y android-tools || fail "android-tools installation failed"
fi
adb version

echo
cat <<'GUIDE'
=== Wireless Debugging ===
On this Pixel:
1. Settings -> About phone -> tap Build number 7 times if Developer options is not already enabled.
2. Settings -> System -> Developer options -> Wireless debugging -> ON.
3. For first-time pairing, tap "Pair device with pairing code" and use the IP:pairing-port shown there.
4. The normal Wireless debugging screen shows a separate IP:ADB-port used for adb connect.
GUIDE

read -r -p "Pair this Termux adb client now? [y/N]: " pair_answer
if [[ "$pair_answer" =~ ^[Yy]$ ]]; then
  read -r -p "Pairing address (IP:PAIRING_PORT): " pair_addr
  [[ "$pair_addr" =~ ^[^[:space:]:]+:[0-9]+$ ]] || fail "invalid pairing address"
  echo "adb will now ask for the 6-digit pairing code shown by Android."
  adb pair "$pair_addr" || fail "adb pair failed"
fi

collect_devices() {
  adb devices | awk 'NR>1 && $2=="device" {print $1}'
}

mapfile -t devices < <(collect_devices)
if (( ${#devices[@]} == 0 )); then
  read -r -p "ADB connection address (IP:ADB_PORT): " connect_addr
  [[ "$connect_addr" =~ ^[^[:space:]:]+:[0-9]+$ ]] || fail "invalid ADB connection address"
  adb connect "$connect_addr" || fail "adb connect failed"
  sleep 1
  mapfile -t devices < <(collect_devices)
fi

if (( ${#devices[@]} == 1 )); then
  SERIAL="${devices[0]}"
elif (( ${#devices[@]} > 1 )); then
  echo "Multiple ADB devices are connected:"
  printf '  %s\n' "${devices[@]}"
  read -r -p "Type the exact target serial/IP:port: " SERIAL
  found=0
  for d in "${devices[@]}"; do
    [[ "$SERIAL" == "$d" ]] && found=1
  done
  (( found == 1 )) || fail "selected target is not one of the connected devices"
else
  fail "no authorized ADB device is connected"
fi

state_out="$(adb -s "$SERIAL" get-state 2>&1)" || fail "could not query selected ADB target state"
[[ "$state_out" == "device" ]] || fail "selected ADB target is not in device state"

echo "=== INSPECT: ADB target ==="
echo "adb_serial=$SERIAL"
id_out="$(adb -s "$SERIAL" shell id 2>&1 | tr -d '\r')"
whoami_out="$(adb -s "$SERIAL" shell whoami 2>&1 | tr -d '\r')"
selinux_out="$(adb -s "$SERIAL" shell getenforce 2>&1 | tr -d '\r')"
model_out="$(adb -s "$SERIAL" shell getprop ro.product.model 2>&1 | tr -d '\r')"
fingerprint_out="$(adb -s "$SERIAL" shell getprop ro.build.fingerprint 2>&1 | tr -d '\r')"
sdk_out="$(adb -s "$SERIAL" shell getprop ro.build.version.sdk 2>&1 | tr -d '\r')"
release_out="$(adb -s "$SERIAL" shell getprop ro.build.version.release 2>&1 | tr -d '\r')"
printf 'id=%s\nwhoami=%s\nselinux=%s\nmodel=%s\nandroid_release=%s\nsdk=%s\nfingerprint=%s\n' \
  "$id_out" "$whoami_out" "$selinux_out" "$model_out" "$release_out" "$sdk_out" "$fingerprint_out"
[[ "$id_out" == *"uid=2000(shell)"* ]] || fail "ADB shell is not UID 2000 shell"
[[ "$whoami_out" == "shell" ]] || fail "adb shell whoami is not shell"
[[ "$sdk_out" == "$EXPECTED_API" ]] || fail "Android API differs from the authorized test assumption (expected $EXPECTED_API, got $sdk_out)"

read -r -p "Confirm the model/fingerprint above is THIS fresh Pixel by typing THIS PHONE: " target_confirm
[[ "$target_confirm" == "THIS PHONE" ]] || fail "target identity was not explicitly confirmed"

echo "=== INSPECT: users ==="
current_user="$(adb -s "$SERIAL" shell am get-current-user 2>&1 | tr -d '\r[:space:]')"
users_out="$(adb -s "$SERIAL" shell pm list users 2>&1 | tr -d '\r')"
echo "current_user=$current_user"
printf '%s\n' "$users_out"
[[ "$current_user" == "0" ]] || fail "current Android user is not user 0"
mapfile -t user_ids < <(printf '%s\n' "$users_out" | sed -n 's/.*UserInfo{\([0-9][0-9]*\):.*/\1/p')
(( ${#user_ids[@]} == 1 )) || fail "unexpected number of Android users/profiles detected"
[[ "${user_ids[0]}" == "0" ]] || fail "the sole Android user is not user 0"
printf '%s\n' "$users_out" | grep -E 'UserInfo\{0:.*\}[[:space:]]+running' >/dev/null || fail "user 0 is not shown as running"

echo "=== INSPECT: existing device/profile owners ==="
owners_dpm_before="$(adb -s "$SERIAL" shell dpm list-owners 2>&1 | tr -d '\r')"
owners_cmd_before="$(adb -s "$SERIAL" shell cmd device_policy list-owners 2>&1 | tr -d '\r')"
dumpsys_before="$(adb -s "$SERIAL" shell dumpsys device_policy 2>&1 | tr -d '\r')"
printf 'dpm_list_owners=%s\n' "${owners_dpm_before:-<blank>}"
printf 'cmd_device_policy_list_owners=%s\n' "${owners_cmd_before:-<blank>}"
printf '%s\n' "$dumpsys_before" | grep -n -A6 -B3 'Device Owner Type:' || true

# Android 17 on this Pixel returns blank list-owners output when there are no owners.
# Blank output alone is never accepted. Require explicit authoritative dumpsys state:
# Device Owner Type: -1 and an empty Has PO: block, with no Device/Profile Owner section.
for owner_listing in "$owners_dpm_before" "$owners_cmd_before"; do
  if printf '%s\n' "$owner_listing" | grep -Eq 'DeviceOwner|ProfileOwner|ManagedProfileOwner'; then
    fail "an existing Device/Profile Owner is reported"
  fi
done

owners_dpm_trim="$(printf '%s' "$owners_dpm_before" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
owners_cmd_trim="$(printf '%s' "$owners_cmd_before" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
if [[ -n "$owners_dpm_trim" && "$owners_dpm_trim" != "no owners" ]]; then
  fail "unrecognized dpm list-owners output"
fi
if [[ -n "$owners_cmd_trim" && "$owners_cmd_trim" != "no owners" ]]; then
  fail "unrecognized cmd device_policy list-owners output"
fi

printf '%s\n' "$dumpsys_before" | grep -Eq '^[[:space:]]*Device Owner Type:[[:space:]]*-1[[:space:]]*$' \
  || fail "dumpsys does not explicitly report Device Owner Type: -1"
if printf '%s\n' "$dumpsys_before" | grep -Eq '^[[:space:]]*Device Owner:[[:space:]]*$|^[[:space:]]*Profile Owner([[:space:]]|\()'; then
  fail "dumpsys reports an existing Device/Profile Owner section"
fi
po_block_before="$(printf '%s\n' "$dumpsys_before" | awk '
  /^[[:space:]]*Has PO:[[:space:]]*$/ {inpo=1; next}
  inpo && /^[[:space:]]*$/ {exit}
  inpo {print}
')"
if printf '%s\n' "$po_block_before" | grep -Eq 'User[[:space:]]+[0-9]+:'; then
  fail "dumpsys reports an existing Profile Owner"
fi
echo "owner_state_before=VERIFIED_NONE"

echo "=== INSPECT: Android accounts ==="
accounts_out="$(adb -s "$SERIAL" shell dumpsys account 2>&1 | tr -d '\r')"
printf '%s\n' "$accounts_out" | sed -n '/Accounts:/,/Active Sessions:/p'
printf '%s\n' "$accounts_out" | grep -Eq '^[[:space:]]*Accounts:[[:space:]]*0([[:space:]]|$)' || fail "could not verify Accounts: 0"
if printf '%s\n' "$accounts_out" | grep -Eq '^[[:space:]]*Accounts:[[:space:]]*[1-9][0-9]*([[:space:]]|$)'; then
  fail "one or more Android accounts are present"
fi

echo "=== INSPECT: Dhizuku package/component ==="
packages_out="$(adb -s "$SERIAL" shell pm list packages --user 0 "$PACKAGE" 2>&1 | tr -d '\r')"
enabled_out="$(adb -s "$SERIAL" shell pm list packages -e --user 0 "$PACKAGE" 2>&1 | tr -d '\r')"
path_out="$(adb -s "$SERIAL" shell pm path "$PACKAGE" 2>&1 | tr -d '\r')"
pkg_dump="$(adb -s "$SERIAL" shell dumpsys package "$PACKAGE" 2>&1 | tr -d '\r')"
printf 'package_query=%s\nenabled_query=%s\npath=%s\n' "$packages_out" "$enabled_out" "$path_out"
[[ "$packages_out" == *"package:$PACKAGE"* ]] || fail "Dhizuku is not installed for user 0"
[[ "$enabled_out" == *"package:$PACKAGE"* ]] || fail "Dhizuku is not enabled for user 0"
[[ "$path_out" == package:* ]] || fail "Dhizuku package path could not be resolved"
grep -Fq "versionName=$EXPECTED_VERSION" <<<"$pkg_dump" || fail "installed Dhizuku version is not $EXPECTED_VERSION"
grep -Eq "versionCode=${EXPECTED_VERSION_CODE}([[:space:]]|$)" <<<"$pkg_dump" || fail "installed Dhizuku versionCode is not $EXPECTED_VERSION_CODE"
admin_component_line="$(grep -F -m1 "$ADMIN_COMPONENT" <<<"$pkg_dump" || true)"
[[ -n "$admin_component_line" ]] || fail "Dhizuku DeviceAdminReceiver component was not found in package state"
echo "installed_version=$EXPECTED_VERSION"
echo "installed_version_code=$EXPECTED_VERSION_CODE"
echo "admin_component_evidence=$admin_component_line"
echo "admin_component_verified=$ADMIN_COMPONENT"

echo "=== INSPECT: device-owner-only shell support ==="
dpm_help="$(adb -s "$SERIAL" shell dpm help 2>&1 | tr -d '\r')"
grep -Fq -- '--device-owner-only' <<<"$dpm_help" || fail "this Android build does not advertise --device-owner-only; refusing broader owner semantics"
echo "device_owner_only_option=VERIFIED_SUPPORTED"

echo "=== PLAN ==="
echo "All inspect checks passed. No Device Owner mutation has occurred."
echo "Note: Device provisioned=true is not itself a blocker for the ADB shell path when there are no accounts or additional users; those conditions were independently verified above."
echo "Planned mutation:"
echo "  adb -s $SERIAL shell dpm set-device-owner --user 0 --device-owner-only $ADMIN_COMPONENT"
echo
cat <<'ROLLBACK'
=== Rollback identified BEFORE mutation ===
For Dhizuku v2.12.0, the supported in-app test rollback is:
  Open Dhizuku -> Deactivate -> confirm.
Dhizuku v2.12.0 calls DevicePolicyManager.clearDeviceOwnerApp() for this action.
After deactivation, verify with:
  adb shell dpm list-owners
Expected owner-state readback after rollback: either an explicit `no owners` listing, or (on this Android 17 Pixel build) blank list-owners plus dumpsys `Device Owner Type: -1` and an empty `Has PO:` block

Important limitation:
- Android documents clearDeviceOwnerApp() as a testing-oriented, best-effort owner clear; some policies set by a device owner can remain.
- This isolated test intentionally does not configure any unrelated policies, which reduces that residual-policy risk.
- adb dpm remove-active-admin is NOT a dependable fallback for this release because that shell removal path requires an android:testOnly admin.
- If Dhizuku's own Deactivate flow fails, this script will not factory-reset the phone and will not claim rollback is available by ADB.
ROLLBACK

read -r -p "If you accept the rollback limitation and want to APPLY the Device Owner mutation, type SET DEVICE OWNER: " apply_confirm
[[ "$apply_confirm" == "SET DEVICE OWNER" ]] || fail "Device Owner mutation not authorized at the confirmation prompt"

echo "=== APPLY ==="
set +e
mutation_out="$(adb -s "$SERIAL" shell dpm set-device-owner --user 0 --device-owner-only "$ADMIN_COMPONENT" 2>&1 | tr -d '\r')"
mutation_rc=$?
set -e
printf '%s\n' "$mutation_out"
echo "mutation_exit_code=$mutation_rc"
echo "Command exit status is recorded but is NOT treated as proof."

echo "=== READ BACK ==="
owners_dpm_after="$(adb -s "$SERIAL" shell dpm list-owners 2>&1 | tr -d '\r')"
owners_cmd_after="$(adb -s "$SERIAL" shell cmd device_policy list-owners 2>&1 | tr -d '\r')"
dumpsys_after="$(adb -s "$SERIAL" shell dumpsys device_policy 2>&1 | tr -d '\r')"
printf 'dpm_list_owners_after=%s\n' "${owners_dpm_after:-<blank>}"
printf 'cmd_device_policy_list_owners_after=%s\n' "${owners_cmd_after:-<blank>}"
package_after="$(adb -s "$SERIAL" shell pm list packages --user 0 "$PACKAGE" 2>&1 | tr -d '\r')"
[[ "$package_after" == *"package:$PACKAGE"* ]] || fail "Dhizuku package disappeared after mutation"

verified_from_list=0
for owner_listing in "$owners_dpm_after" "$owners_cmd_after"; do
  if printf '%s\n' "$owner_listing" | grep -Eq "User[[:space:]]+0:[[:space:]]+admin=${PACKAGE}/\.server\.DhizukuDAReceiver,DeviceOwner([,[:space:]]|$)"; then
    verified_from_list=1
  fi
  if printf '%s\n' "$owner_listing" | grep -Eq ',ProfileOwner|ManagedProfileOwner'; then
    fail "unexpected ProfileOwner state appeared in owner listing"
  fi
done

# Independent authoritative fallback/readback from dumpsys. The Device Owner section must
# name the exact Dhizuku admin and user 0; PO cache must remain empty.
do_section_after="$(printf '%s\n' "$dumpsys_after" | awk '
  /^[[:space:]]*Device Owner:[[:space:]]*$/ {indo=1; print; next}
  indo && /^[[:space:]]*$/ {exit}
  indo {print}
')"
printf '%s\n' "$do_section_after"
grep -Fq "admin=ComponentInfo{${PACKAGE}/${ADMIN_CLASS}}" <<<"$do_section_after" \
  || fail "dumpsys Device Owner section does not name the exact Dhizuku admin"
printf '%s\n' "$do_section_after" | grep -Eq '^[[:space:]]*User ID:[[:space:]]*0[[:space:]]*$' \
  || fail "dumpsys Device Owner section does not confirm user 0"
printf '%s\n' "$dumpsys_after" | grep -Eq '^[[:space:]]*Device Owner Type:[[:space:]]*(-1)[[:space:]]*$' \
  && fail "dumpsys still reports no Device Owner after mutation"
po_block_after="$(printf '%s\n' "$dumpsys_after" | awk '
  /^[[:space:]]*Has PO:[[:space:]]*$/ {inpo=1; next}
  inpo && /^[[:space:]]*$/ {exit}
  inpo {print}
')"
if printf '%s\n' "$po_block_after" | grep -Eq 'User[[:space:]]+[0-9]+:'; then
  fail "unexpected Profile Owner appeared after mutation"
fi
if printf '%s\n' "$dumpsys_after" | grep -Eq '^[[:space:]]*Profile Owner([[:space:]]|\()'; then
  fail "unexpected Profile Owner section appeared after mutation"
fi

if (( verified_from_list == 1 )); then
  echo "owner_readback_primary=VERIFIED_BY_LIST_OWNERS_AND_DUMPSYS"
else
  echo "owner_readback_primary=VERIFIED_BY_DUMPSYS (list-owners output is blank/non-reporting on this build)"
fi

RESULT="VERIFIED"
echo "=== VERIFY ==="
echo "ADB authority: shell UID 2000 VERIFIED"
echo "Device Owner authority: $ADMIN_COMPONENT on user 0 VERIFIED by authoritative Android readback (list-owners and dumpsys)"
echo "Device Owner was actually verified: YES"
finalize_and_exit 0
