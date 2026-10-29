# File manager source and ownership

The maintainer selected Nautilus for Story 4.5 while reviewing the Omarchy wallpaper integration.
The capability installs Arch's `extra/nautilus` package (GPL-3.0-or-later); no upstream code or configuration is
copied into MirrorOS. Omarchy's `install/omarchy-base.packages` was the package-selection reference.

This step only ensures package presence. Personal settings, optional `sushi` and `gvfs-*` integrations, default
application associations and desktop-portal configuration are not managed here. Dependencies such as GVfs,
localsearch, UDisks2 and xdg-desktop-portal-gtk retain their packaged behavior; package installation is not a
selection or qualification of the desktop portal provider for Hyprland.

The shell's Install > Style > Background action opens the personal theme-background directory in Nautilus.
Installing the package does not launch Nautilus or change the running shell.
