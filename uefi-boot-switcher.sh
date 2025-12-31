#!/usr/bin/env bash
# GUI to choose the next UEFI boot target via zenity + efibootmgr.

set -euo pipefail

sudo_bin="$(command -v sudo || true)"
if [[ -z "$sudo_bin" ]]; then
  echo "sudo is required to manage UEFI entries." >&2
  exit 1
fi

PKG_MGR=""
if command -v apt-get >/dev/null 2>&1; then
  PKG_MGR="apt"
elif command -v pacman >/dev/null 2>&1; then
  PKG_MGR="pacman"
elif command -v dnf >/dev/null 2>&1; then
  PKG_MGR="dnf"
elif command -v zypper >/dev/null 2>&1; then
  PKG_MGR="zypper"
fi

install_pkg() {
  case "$PKG_MGR" in
    apt)
      sudo apt-get -y install "$@"
      ;;
    pacman)
      sudo pacman -S --needed --noconfirm "$@"
      ;;
    dnf)
      sudo dnf -y install "$@"
      ;;
    zypper)
      sudo zypper --non-interactive install --no-recommends "$@"
      ;;
    *)
      echo "No supported package manager detected; please install dependencies manually." >&2
      return 1
      ;;
  esac
}

ensure_dep() {
  local cmd="$1" apt_pkg="$2" pac_pkg="$3" dnf_pkg="$4" zypper_pkg="$5"
  if command -v "$cmd" >/dev/null 2>&1; then
    return 0
  fi

  local pkg=""
  case "$PKG_MGR" in
    apt) pkg="$apt_pkg" ;;
    pacman) pkg="$pac_pkg" ;;
    dnf) pkg="$dnf_pkg" ;;
    zypper) pkg="$zypper_pkg" ;;
    *) ;;
  esac

  if [[ -z "$pkg" ]]; then
    echo "Missing dependency: $cmd. Install it manually." >&2
    return 1
  fi

  echo "Installing $pkg to satisfy $cmd..."
  install_pkg "$pkg" || {
    echo "Failed to install $pkg. Please install $cmd manually." >&2
    exit 1
  }
}

ensure_dep "zenity" "zenity" "zenity" "zenity" "zenity"
ensure_dep "efibootmgr" "efibootmgr" "efibootmgr" "efibootmgr" "efibootmgr"

# Optional: try to install python3-gi for the centered GTK UI
ensure_python_gi() {
  if ! command -v python3 >/dev/null 2>&1; then
    return 0
  fi

  if python3 - <<'PY' >/dev/null 2>&1
import gi  # noqa: F401
PY
  then
    return 0
  fi

  local pkg=""
  case "$PKG_MGR" in
    apt) pkg="python3-gi" ;;
    pacman) pkg="python-gobject" ;;
    dnf) pkg="python3-gobject" ;;
    zypper) pkg="python3-gobject" ;;
    *) pkg="" ;;
  esac

  if [[ -n "$pkg" ]]; then
    echo "Installing $pkg to enable the centered GTK UI..."
    install_pkg "$pkg" || echo "Could not install $pkg; falling back to zenity UI." >&2
  fi
}

ensure_python_gi

password_cache=""
password_cancelled=0

prompt_password() {
  while :; do
    pw="$(zenity --password \
      --title="UEFI Boot Switcher" \
      --text="Authentication is required to manage UEFI boot entries.")"
    status=$?
    if (( status != 0 )); then
      password_cancelled=1
      return 1
    fi
    if [[ -n "$pw" ]]; then
      password_cache="$pw"
      return 0
    fi
    zenity --error --title="UEFI Boot Switcher" --text="Password cannot be empty."
  done
}

run_efi() {
  if (( EUID == 0 )); then
    efibootmgr "$@"
    return
  fi

  if [[ -z "$password_cache" ]]; then
    if ! prompt_password; then
      return 1
    fi
  fi

  if sudo -S -p "" efibootmgr "$@" <<<"$password_cache"; then
    return
  fi

  password_cache=""
  zenity --error --title="UEFI Boot Switcher" --text="Authentication failed. Please try again."
  run_efi "$@"
}

efi_out=""
efi_raw=""
efi_status=0
efi_raw="$(run_efi -v 2>&1)" || efi_status=$?
if (( efi_status != 0 )); then
  if (( password_cancelled )) || [[ -z "$password_cache" ]]; then
    exit 0
  fi
  clean_out="$(printf '%s\n' "$efi_raw" | sed '/Adwaita-WARNING/d')"
  zenity --error --title="UEFI Boot Switcher" --text="Failed to read EFI entries (efibootmgr -v).\n\n$clean_out"
  exit 1
fi
efi_out="$efi_raw"

current="$(printf '%s\n' "$efi_out" | awk '/^BootCurrent:/ {print $2}')"
bootnext="$(printf '%s\n' "$efi_out" | awk '/^BootNext:/ {print $2}')"

parse_entries() {
  local phase="$1"
  printf '%s\n' "$efi_out" | awk -v phase="$phase" '
    function trim(s) { gsub(/^[ \t]+|[ \t]+$/, "", s); return s }
    BEGIN {
      osre = "(windows|microsoft|ubuntu|debian|fedora|arch|manjaro|endeavouros|opensuse|suse|tumbleweed|leap|nixos|mint|pop|zorin|void|gentoo|kali|parrot|alma|rocky|centos|oracle|rhel|linux|bootmgfw|grub|shim|efi)";
    }
    /^Boot[0-9A-Fa-f]{4}\*/ {
      id = substr($1, 5, 4)
      rest = $0
      sub(/^Boot[0-9A-Fa-f]{4}\* */, "", rest)
      lower = tolower(rest)

      path = ""
      if (match(rest, /File\([^)]*\)/)) {
        path = substr(rest, RSTART, RLENGTH)
      }

      desc = rest
      sub(/[ \t]HD\(.*/, "", desc)
      sub(/[ \t]File\(.*/, "", desc)
      desc = trim(desc)
      if (desc == "" && path != "") desc = path
      if (desc == "") desc = "Boot" id

      if (phase == "filter") {
        dlow = tolower(desc)
        if (dlow == "uefi os" && (path == "" || tolower(path) ~ /bootx64\.efi/)) next
        if (path == "" && lower !~ osre) next
        if (lower ~ /(ipv4|ipv6|pxe|http|network)/) next
        if (lower ~ /(usb|removable|dvd|cd|cdrom)/ && lower !~ osre) next
      }

      printf "%s|%s|%s\n", id, desc, path
    }
  '
}

mapfile -t entries < <(parse_entries filter)
fallback_used=0
if ((${#entries[@]} == 0)); then
  mapfile -t entries < <(parse_entries loose)
  fallback_used=1
fi

if ((${#entries[@]} == 0)); then
  zenity --error --title="UEFI Boot Switcher" --text="No UEFI boot entries found. Run 'efibootmgr -v' to verify entries exist."
  exit 1
fi

choices=()
ui_lines=()
declare -A dedup_map dedup_score label_map
order=()
default_id="$bootnext"
[[ -z "$default_id" ]] && default_id="$current"

score_for() {
  local id="$1"
  if [[ -n "$bootnext" && "$id" == "$bootnext" ]]; then
    echo 3
  elif [[ "$id" == "$current" ]]; then
    echo 2
  else
    echo 1
  fi
}

for entry in "${entries[@]}"; do
  id="${entry%%|*}"
  rest="${entry#*|}"
  desc="${rest%%|*}"
  path="${rest#*|}"
  key="$(printf '%s|%s' "${desc,,}" "${path,,}")"
  score="$(score_for "$id")"

  if [[ -z "${dedup_map[$key]+x}" ]]; then
    dedup_map[$key]="$entry"
    dedup_score[$key]=$score
    order+=("$key")
  else
    if (( score > dedup_score[$key] )); then
      dedup_map[$key]="$entry"
      dedup_score[$key]=$score
    fi
  fi
done

# Ensure there is always a default selection.
if [[ -z "$default_id" && ${#order[@]} -gt 0 ]]; then
  first_entry="${dedup_map[${order[0]}]}"
  default_id="${first_entry%%|*}"
fi

for key in "${order[@]}"; do
  entry="${dedup_map[$key]}"
  id="${entry%%|*}"
  rest="${entry#*|}"
  desc="${rest%%|*}"
  path="${rest#*|}"
  label="$desc"
  [[ "$id" == "$current" ]] && label="$label (current)"
  [[ -n "$bootnext" && "$id" == "$bootnext" ]] && label="$label (next)"
  if [[ -n "$path" ]]; then
    path_display="${path#File(}"
    path_display="${path_display%)}"
    label="$label — $path_display"
  fi
  pick="FALSE"
  [[ -n "$default_id" && "$id" == "$default_id" ]] && pick="TRUE"
  choices+=("$pick" "$id" "$label")
  ui_lines+=("$pick|$id|$label")
  label_map["$id"]="$label"
done

dialog_text="Select the UEFI entry to use for the next reboot."
if ((fallback_used)); then
  dialog_text="$dialog_text\nNo clear OS-only entries detected; showing all firmware entries."
fi

run_zenity_selection() {
  zenity --list \
    --radiolist \
    --title="Choose next boot entry" \
    --text="$dialog_text" \
    --column="Select" --column="ID" --column="Entry" \
    --print-column=2 --hide-column=2 \
    "${choices[@]}"
}

run_center_ui() {
  printf '%s\n' "${ui_lines[@]}" | python3 "$(dirname "$0")/ui_center.py" "$default_id"
}

have_python_ui=0
if command -v python3 >/dev/null 2>&1; then
  if python3 - <<'PY' >/dev/null 2>&1
import sys
try:
    import gi  # noqa: F401
    have = True
except Exception:
    have = False
sys.exit(0 if have else 1)
PY
  then
    have_python_ui=1
  fi
fi

if ((have_python_ui)); then
  selection="$(run_center_ui)" || selection=""
else
  selection="$(run_zenity_selection)" || selection=""
fi

if [[ -z "${selection:-}" ]]; then
  exit 0
fi

selection_label="${label_map[$selection]:-$selection}"

if ! zenity --question \
    --title="Confirm reboot" \
    --text="<span justify='center'>Are you sure you want to reboot into \"${selection_label}\"?</span>" \
    --width=420 \
    --ok-label="Yes" --cancel-label="No"; then
  exit 0
fi

if run_efi -n "$selection"; then
  systemctl reboot
else
  zenity --error --title="UEFI Boot Switcher" --text="Failed to set BootNext with efibootmgr."
  exit 1
fi
