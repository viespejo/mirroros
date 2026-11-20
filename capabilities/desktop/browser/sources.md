# Browser sources

[ADR 0032](../../../docs/adr/0032-chrome-supply-chain-and-update-flow.md) governs Google Chrome as the Story 4.5
browser and `extra/chromium` as the alternative provider.

## Google Chrome stable

- Chrome is proprietary. MirrorOS does not redistribute its binary: each device downloads Google's amd64 Debian
  package and assembles an Arch package locally as the selected non-root user.
- The packaging baseline is [AUR `google-chrome`](https://aur.archlinux.org/cgit/aur.git/tree/?h=google-chrome&id=5bc819b6f8c16a9b613fd8b74462c23952191ba2).
  The recipe header lists the divergences. `eula_text.html` is unchanged from that revision; the reviewed local
  sources are checksummed in the recipe. The AUR install hook is not used; it only prints launcher tips.
- The [Google Linux apt channel](https://dl.google.com/linux/chrome/deb/) is a build source, not a pacman
  repository. Its verified `InRelease` authenticates `Packages`, which supplies the stable amd64 version and
  `.deb` SHA256. `makepkg` verifies the payload against that SHA256. The primary fingerprint is pinned in
  `chrome-channel`; only valid signing subkeys bound to it are accepted.
- The Arch package uses the `MirrorOS Browser` packager identity and the Debian release with a `.1` suffix.
  Configure records the upstream URL, `.deb` SHA256, `InRelease` date and signing subkey in `sources.tsv`.
  A successful manual update appends the corresponding provenance under the user's MirrorOS state directory.

## Desktop integration

- `policies/mirroros.json` retains two keys from [Omarchy `origin/quattro` at `2eb7eb3`](https://github.com/basecamp/omarchy/blob/2eb7eb3/default/chromium/policies/omarchy.json).
  Chrome `158.0.8127.36-1.1` on the reference VM marked the other five keys deprecated and rejected
  `BrowserColorScheme` as unknown. [OMARCHY-LICENSE](OMARCHY-LICENSE) retains the MIT notice.
- MirrorOS-owned `policies/recommended.json` uses [Chrome's recommended policy tier on Linux](https://support.google.com/chrome/a/answer/9027408)
  for editable defaults: session restoration, Google search, the Home button, and disabled background mode.
  It also recommends Standard protection via
  [`SafeBrowsingProtectionLevel`](https://chromeenterprise.google/policies/#SafeBrowsingProtectionLevel).
- MirrorOS adds the mandatory [`SyncTypesListDisabled`](https://chromeenterprise.google/policies/#SyncTypesListDisabled)
  policy to `policies/mirroros.json` to exclude apps, extensions, preferences, and themes from Google sync
  without blocking other supported types.
- The MirrorOS-owned `browser-theme-color` reads the trusted product theme resolved by
  [visual/theme](../../visual/theme/sources.md) and writes a separate device policy. The neutral `browser-open`
  launcher respects the effective HTTPS default; system associations are owned by
  [desktop/portal](../portal/sources.md#default-applications).

## Reference VM qualification

Running-system configure and a clean guided installation on `mirroros-ref` installed `158.0.8127.36-1.1`.
The guided run recorded `.deb` SHA256 `4696bce00b128f385a870ba2eb6eede61698f22374ea0d8e09af8a1c6543d397`,
`InRelease` date `2026-11-20T09:08:59Z`, and signing subkey `0E225917414670F4442C250DFD533C07C264648F`.
Both user units were enabled. Target configure succeeded, and `desktop/browser` took 65.86 seconds; the
shared package compression setting was not changed because the step timing does not isolate compression.
The [browser procedure](../../../docs/procedures/browser.md#reference-vm-results) records the attended results
and remaining verification limits.
