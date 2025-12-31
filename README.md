<!-- Optional banner slot -->
<!-- <p align="center"><img src="YOUR_BANNER_URL_HERE" alt="UEFI Boot Switcher Banner" /></p> -->

<h1 align="center">🦁 UEFI Boot Switcher 🦁</h1>
<h3 align="center">Pick your next boot target from a friendly GUI</h3>

<p align="center">Pick your next UEFI boot entry from a GUI instead of diving into firmware menus.</p>

<p align="center">━━✦━━</p>

<h3 align="center">🛠️ Stack & Requirements</h3>

<p align="center">
  <img src="https://img.shields.io/badge/Linux-8B0000?style=for-the-badge&logo=linux&logoColor=F5F5F5" />
  <img src="https://img.shields.io/badge/bash-7C5E3C?style=for-the-badge&logo=gnu-bash&logoColor=F5F5F5" />
  <img src="https://img.shields.io/badge/GTK3-C19A3F?style=for-the-badge&logo=gtk&logoColor=1C1C1C" />
  <img src="https://img.shields.io/badge/zenity-1C1C1C?style=for-the-badge&logo=gnome&logoColor=C19A3F" />
  <img src="https://img.shields.io/badge/efibootmgr-F1551D?style=for-the-badge&logo=linux&logoColor=F5F5F5" />
</p>

<ul>
  <li><strong>python3-gi (GTK 3)</strong> powers the centered radio UI—automatically falls back to zenity if GTK is missing.</li>
  <li><strong>zenity</strong> for dialogs when GTK isn’t available.</li>
  <li><strong>efibootmgr</strong> to list and set firmware entries.</li>
  <li><strong>sudo privileges</strong>; the script prompts via GUI and pipes your password to sudo.</li>
</ul>

<h3 align="center">🚀 Run It</h3>

```bash
./uefi-boot-switcher.sh
```

<p><strong>Dependencies:</strong> the script will try to install <code>zenity</code>, <code>efibootmgr</code>, and (optionally) <code>python3-gi</code> via your package manager (apt/pacman/dnf/zypper). If your distro uses something else, install those manually first.</p>
<p><strong>Flags:</strong> <code>--no-install</code> (skip auto-installs), <code>--no-reboot</code> (set BootNext but don’t reboot automatically).</p>

<p align="center">━━✦━━</p>

<h3 align="center">🧭 What You’ll See</h3>
<ul>
  <li>Filters for entries that look like OS bootloaders (Windows/Linux/grub/shim/bootmgfw).</li>
  <li>Skips obvious network/DVD/USB placeholders.</li>
  <li>If filtering yields nothing, it will show every firmware entry so you can still pick one.</li>
</ul>

<h3 align="center">🧩 Notes & Safety</h3>
<ul>
  <li>Sets <code>BootNext</code> only; it does not reorder your permanent <code>BootOrder</code>.</li>
  <li>If no entries appear, run <code>sudo efibootmgr -v</code> to verify firmware entries exist—share that output if you need the filter tuned for your firmware format.</li>
  <li>Requires sudo; the script prompts via GUI and only sets the next boot, never writes a new BootOrder.</li>
  <li>If entries are missing, ensure firmware/BIOS is not hiding them (e.g., fast boot) and that <code>efibootmgr -v</code> shows them.</li>
</ul>

<p align="center" style="color:#F1551D; font-family:JetBrains Mono; font-size:18px;">
  ───────────── ✝ ─────────────
</p>

<p align="center" style="color:#F1551D; font-family:JetBrains Mono; font-size:18px;">
  🦁 Built for smooth reboots — choose boldly, boot cleanly.
</p>

<p align="center" style="font-size:12px;">
  Licensing: GPL-3.0 — see <a href="LICENSE">LICENSE</a>.
</p>
