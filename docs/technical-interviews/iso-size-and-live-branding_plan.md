# ISO Size and Live Branding — Consolidated Interview Plan

## Objective and scope

Reduce the MirrorOS live ISO's size before proceeding to Story 2.6, while giving the installation medium a consistent MirrorOS identity. Visible live-media branding covers the ISO filename, volume label, metadata, boot menus, welcome, and live-system identification. Necessary Arch technical references and upstream attribution remain accurate. Installed-system branding is outside this delivery. [DEC-001]

## Package selection and capability preservation

The live environment will serve MirrorOS installation and minimal rescue rather than a general-purpose rescue suite. It must still boot, inspect disks, mount supported filesystems, and run arch-chroot. Ethernet/Wi-Fi, basic diagnostics, and tools required by accepted storage options remain available. Initially preserve the complete firmware set rather than trading compatibility for unmeasured savings. [DEC-002]

Audit every tool used by the MirrorOS installer before removing packages, including indirect dependencies and alternative execution paths. Remove only tools without a justified live-environment use, and adjust their associated overlays to avoid dangling service references or startup commands. No concrete package-removal list has been approved. [DEC-002, TODO-001]

## Observations and verification needs

The existing local artifact at `dist/20261012T234437Z-1e6dbbfd-61ef-4ef7-b0a9-c7b59bd3bc85/archlinux-2026.10.12-x86_64.iso` is 1,682,014,208 bytes. This is an observed baseline, not evidence that any particular package causes the size difference from official Arch media. The current profile already uses XZ SquashFS compression. Measure the reduced profile and verify installation and minimal-rescue capabilities; package names and declared removals alone do not prove compressed-size savings. [DEC-002, TODO-001]

## Optimization policy

Minimize packages without a justified MirrorOS live use to reduce both ISO size and build duration, while preserving the installer, indirect dependencies, minimal rescue, and the initial complete firmware set required by DEC-002. No mandatory size target applies. The official Arch download page reports release 2026.10.01 at a rounded 1.5 GB; this is context only, not a byte-exact or package-equivalent benchmark. Measure size and build duration before and after, and do not attribute package-specific savings without evidence. [DEC-003]

## Open implementation questions

The exact package and overlay changes, detailed verification matrix, measurement procedure, and exact branding values remain unresolved. The dependency audit must inform concrete removal decisions rather than assuming that inherited upstream tools are unused. [TODO-001]

## Planning workflow

Persistence was explicitly requested and the two backfilled decisions were approved before these artifacts were written. This document tracks the interview, not the final executable plan. The final `.agents/plans/` draft requires separate approval before materialization.

## Alternative installer removal

Remove archinstall from the live package declaration because MirrorOS supplies its own guided installer. Update the reference-VM native-installation-tools check, affected tests, and documentation so they no longer require archinstall. Continue requiring pacstrap, genfstab, and arch-chroot; removing the alternative installer must not weaken validation of native installation or minimal rescue. [DEC-004]

## Inherited accessibility functions

Remove inherited speech-boot and Braille functions together with dedicated packages, services, sounds, and associated boot entries. Preserve the keyboard, font, and terminal tools required by the MirrorOS live console. Select exact removals through the dependency audit rather than treating all console-related packages as accessibility-only. No accessible installer qualification is claimed. [DEC-005]

## Live editor

Keep Vim as the live editor for configuration repair and minimal rescue. Remove Nano unless a necessary dependency is demonstrated by the audit. This does not modify installed-system editor policy. [DEC-006]

## Live boot scope

The live profile will provide UEFI boot only. Remove BIOS/Legacy boot modes, Syslinux, and other BIOS-exclusive resources; retain any shared dependencies needed by UEFI or the installer. This narrows inherited media contents to the existing supported boot boundary and does not alter installed-system boot choices. Attribution and boot-scope documentation must reflect the resulting local delta. [DEC-007]

## Remote access

Keep OpenSSH in the live medium with the existing inherited profile defaults. Do not change server startup, authentication, or credentials in this delivery. The checked-in service-enabling symlink does not establish that sshd was active in the user's booted artifact; resolving that runtime discrepancy is outside the package-reduction scope. The proposed manual-start decision was not accepted. [DEC-008]

## Exact branding values

Use `mirroros-YYYY.MM.DD-x86_64.iso`, volume label `MIRROROS_YYYYMM`, publisher `MirrorOS` without an invented URL, application `MirrorOS Live/Rescue`, and live hostname `mirroros`. Keep date-based versioning and existing technical Archiso internal paths; visible boot and welcome text follows DEC-001 without indiscriminate upstream-reference replacement. [DEC-001, DEC-009]

## Package-audit review gate

Begin implementation with a reviewable per-package table: keep/remove disposition, rationale, provided tools, dependency relationships, and affected configuration. Cover installer paths, VM qualification, networking, and minimal rescue. The maintainer must explicitly review the table before remaining cuts are applied; already accepted concrete choices remain binding. Advanced rescue tools, VPN/modem tools, and non-reference hypervisor agents are audit candidates, not preapproved removals. [DEC-010]

## Acceptance verification

Deliver a reproducible manual QEMU/UEFI guide with commands, expected results, and a verdict checklist for visible branding, installer startup, installation, and minimal rescue using ext4/Btrfs mounts and arch-chroot. Use disposable virtual disks only and retain existing automated tests as complementary checks. Exercise Ethernet in QEMU; Wi-Fi needs a separately available device and must not be claimed as validated by ordinary virtual Ethernet. Record artifact-size and build-time comparison with cache conditions documented. Every build and VM run still requires explicit authorization. [DEC-011]
