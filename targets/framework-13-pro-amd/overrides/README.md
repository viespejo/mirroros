# Overrides

Explicit target-machine overrides for `framework-13-pro-amd` belong here. Discovery reads `discovery.json`
and accepts only the allowlisted policy keys of `install/discovery/policy.json`. An unknown key, or any
attempt to override a detected fact, is invalid input.

`plan.json` holds plan overrides read by `operations/install plan`. Its allowlist admits only `hostname`;
see [`contracts/installation-plan.md`](../../../contracts/installation-plan.md).

No override is defined yet.
