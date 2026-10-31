# Overrides

Explicit target-machine overrides for `thinkpad-t14s-gen1-amd` belong here. Discovery reads
`discovery.json` and accepts only the allowlisted policy keys of `install/discovery/policy.json`.
An unknown key, or any attempt to override a detected fact, is invalid input. No discovery override is
defined for this profile.

`plan.json` accepts only `hostname` and `hibernate_mode` (`platform` or `shutdown`) and defines the
single override `{"hibernate_mode": "shutdown"}`. No hostname override is defined. Plan overrides apply only after a verified profile match. The mode remains resolved from the
profile when hibernation is disabled, but no sleep drop-in is delivered in that case.

See [ADR 0023](../../../docs/adr/0023-recognized-unqualified-targets-and-target-hibernate-mode.md) and
[`contracts/installation-plan.md`](../../../contracts/installation-plan.md).
