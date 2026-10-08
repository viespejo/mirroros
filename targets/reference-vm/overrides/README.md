# Overrides

Explicit target-machine overrides for `reference-vm` belong here. Discovery reads `discovery.json` and
accepts only the allowlisted policy keys of `install/discovery/policy.json`. An unknown key, or any attempt
to override a detected fact, is invalid input.

`plan.json` holds plan overrides read by `operations/install plan`. Its allowlist admits only `hostname`;
see [`contracts/installation-plan.md`](../../../contracts/installation-plan.md). It sets the hostname to
`mirroros-ref`.

No discovery override is defined yet.
