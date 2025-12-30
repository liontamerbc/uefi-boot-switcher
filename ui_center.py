#!/usr/bin/env python3
"""
Centered GTK radio selector for UEFI entries.
Reads lines from stdin formatted as: SELECT|ID|LABEL
Outputs the chosen ID to stdout.
"""
import sys
import gi

gi.require_version("Gtk", "3.0")
from gi.repository import Gtk  # noqa: E402


def parse_entries(stdin_lines):
    entries = []
    for line in stdin_lines:
        line = line.strip()
        if not line:
            continue
        parts = line.split("|", 2)
        if len(parts) != 3:
            continue
        pick, entry_id, label = parts
        entries.append(
            {
                "default": pick.upper() == "TRUE",
                "id": entry_id,
                "label": label,
            }
        )
    return entries


class Picker(Gtk.Window):
    def __init__(self, entries, title, text, default_id):
        super().__init__(title=title)
        self.set_border_width(16)
        self.set_resizable(False)
        self.set_position(Gtk.WindowPosition.CENTER)

        self.entries = entries
        self.default_id = default_id
        self.selected_id = None

        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12)
        box.set_halign(Gtk.Align.CENTER)

        label = Gtk.Label(label=text)
        label.set_justify(Gtk.Justification.CENTER)
        label.set_line_wrap(True)
        label.set_xalign(0.5)
        box.pack_start(label, False, False, 0)

        self.radio_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        self.radio_box.set_halign(Gtk.Align.CENTER)
        self._build_radios()
        box.pack_start(self.radio_box, False, False, 0)

        box.pack_start(Gtk.Separator(), False, False, 6)

        button_box = Gtk.Box(spacing=12)
        button_box.set_halign(Gtk.Align.CENTER)
        # Left button should read "Cancel" and abort; right should read "OK" and confirm.
        cancel_btn = Gtk.Button(label="Cancel")
        ok_btn = Gtk.Button(label="OK")
        cancel_btn.connect("clicked", self.on_cancel)
        ok_btn.connect("clicked", self.on_ok)
        button_box.pack_start(cancel_btn, False, False, 0)
        button_box.pack_start(ok_btn, False, False, 0)
        box.pack_start(button_box, False, False, 0)

        self.add(box)
        self.connect("destroy", self.on_cancel)
        self.show_all()

    def _build_radios(self):
        first = None
        active_id = self._pick_default_id()
        self.selected_id = active_id
        for entry in self.entries:
            rb = Gtk.RadioButton.new_with_label_from_widget(first, entry["label"])
            rb.set_halign(Gtk.Align.CENTER)
            rb.connect("toggled", self.on_toggle, entry["id"])
            if entry["id"] == active_id:
                rb.set_active(True)
            if first is None:
                first = rb
            self.radio_box.pack_start(rb, False, False, 0)

    def _pick_default_id(self):
        # Prefer explicit default flag, then provided default_id, else first entry.
        for entry in self.entries:
            if entry["default"]:
                return entry["id"]
        if self.default_id:
            return self.default_id
        return self.entries[0]["id"] if self.entries else ""

    def on_toggle(self, button, entry_id):
        if button.get_active():
            self.selected_id = entry_id

    def on_cancel(self, *args):
        Gtk.main_quit()

    def on_ok(self, *args):
        if self.selected_id:
            print(self.selected_id)
            sys.stdout.flush()
        Gtk.main_quit()


def main():
    entries = parse_entries(sys.stdin)
    if not entries:
        return 1
    default_id = sys.argv[1] if len(sys.argv) > 1 else ""
    picker = Picker(
        entries,
        title="Choose next boot entry",
        text="Select the UEFI entry to use for the next reboot.",
        default_id=default_id,
    )
    Gtk.main()
    return 0


if __name__ == "__main__":
    sys.exit(main())
