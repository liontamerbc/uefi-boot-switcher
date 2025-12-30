#!/usr/bin/env python3
"""
Password prompt with reversed button order (OK on the left, Cancel on the right).
Args: <title> <text>
Prints the password to stdout on OK; exits non-zero on cancel/close.
"""
import sys
import gi

gi.require_version("Gtk", "3.0")
from gi.repository import Gtk  # noqa: E402


class PasswordDialog(Gtk.Window):
    def __init__(self, title, text):
        super().__init__(title=title)
        self.set_border_width(16)
        self.set_resizable(False)
        self.set_position(Gtk.WindowPosition.CENTER)

        self.result = 1

        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12)
        box.set_halign(Gtk.Align.CENTER)

        label = Gtk.Label(label=text)
        label.set_justify(Gtk.Justification.CENTER)
        label.set_line_wrap(True)
        label.set_xalign(0.5)
        box.pack_start(label, False, False, 0)

        self.entry = Gtk.Entry()
        self.entry.set_visibility(False)
        self.entry.set_activates_default(True)
        box.pack_start(self.entry, False, False, 0)

        box.pack_start(Gtk.Separator(), False, False, 6)

        btn_box = Gtk.Box(spacing=12)
        btn_box.set_halign(Gtk.Align.CENTER)

        ok_btn = Gtk.Button(label="OK")
        cancel_btn = Gtk.Button(label="Cancel")
        ok_btn.get_style_context().add_class("suggested-action")
        ok_btn.connect("clicked", self.on_ok)
        cancel_btn.connect("clicked", self.on_cancel)

        btn_box.pack_start(ok_btn, False, False, 0)
        btn_box.pack_end(cancel_btn, False, False, 0)
        box.pack_start(btn_box, False, False, 0)

        self.add(box)
        self.connect("destroy", self.on_cancel)
        self.set_default(ok_btn)
        self.entry.grab_focus()
        self.show_all()

    def on_ok(self, *args):
        print(self.entry.get_text())
        sys.stdout.flush()
        self.result = 0
        Gtk.main_quit()

    def on_cancel(self, *args):
        self.result = 1
        Gtk.main_quit()


def main():
    title = sys.argv[1] if len(sys.argv) > 1 else "Password"
    text = sys.argv[2] if len(sys.argv) > 2 else "Enter password:"
    dlg = PasswordDialog(title, text)
    Gtk.main()
    return dlg.result


if __name__ == "__main__":
    sys.exit(main())
