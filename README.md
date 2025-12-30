# UEFI Boot Switcher (bash + GTK/zenity)

Pick your next UEFI boot entry from a GUI instead of diving into firmware menus.

## Requirements
- `python3-gi` (Gtk 3) for the centered radio UI (auto-falls back to zenity if missing).
- `zenity` (dialogs).
- `efibootmgr` for managing EFI boot entries.
- `sudo` privileges (the script prompts via GUI and pipes the password to sudo).

## Run
```
./uefi-boot-switcher.sh
```
If run from a launcher, ensure you can enter your sudo password when prompted (via the GUI dialog).

## What it shows
- Tries to filter for entries that look like installed OS bootloaders (Windows/Linux/grub/shim/bootmgfw).
- Skips obvious network/DVD/USB placeholders. If nothing survives filtering, it falls back to showing all firmware entries so you can still pick one.

## Notes
- This sets `BootNext` only; it does not reorder permanent `BootOrder`.
- If no entries appear, run `sudo efibootmgr -v` to verify firmware entries exist. Share that output if you need the filter tuned to your firmware format.
