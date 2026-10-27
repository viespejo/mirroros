# Installation Time Measurements — Consolidated Plan

## Scope

This plan covers timing instrumentation, measurement of current installation behavior, and analysis of the resulting data only. It does not select or implement installation optimizations. Decisions and work arising from these measurements belong to a separate follow-on plan. [DEC-001, DEC-020]

## Goal

Identify the dominant contributors to MirrorOS installation time. Use the measurements to inform a separate plan; do not decide or implement optimizations here. [DEC-001, DEC-020]

## Measurement instrumentation

Before the first comparative measurement, add instrumentation that records both full guided-installer elapsed duration and engine elapsed duration. Record engine duration by installation operation and configure duration by configure step. Keep interactive elapsed time distinguishable from automated installation work, so review and confirmation time is not conflated with engine execution. [DEC-001, DEC-002, DEC-005]

## Measurement output

Detailed durations will be recorded in structured per-run evidence. Live progress will remain concise and will not display per-step timings. The installer will not show an end-of-run timing summary initially; reconsider only after reviewing the first measurements. [DEC-003, DEC-004]

## Timing breakdown

Record full guided-installer and engine durations separately; break down engine time into prechecks, each installation-plan operation, postconditions, configure, and cleanup. Break configure time down by each configure step. Also record each existing guided flow stage (`preparation`, `discovery_initial`, `plan`, `review`, `confirmation`, `password`, `discovery_final`, and `engine`). Classify `review`, `confirmation`, and `password` as interactive; classify `preparation` as mixed because readiness checks are automated but recovery choices may require user input; classify `discovery_initial`, `plan`, `discovery_final`, and `engine` as automated. Start full guided-installer duration when the guided flow starts; exclude live-medium boot, which may be measured separately. End it when the installation outcome is determined and recorded, before the final restart/exit menu. [DEC-005, DEC-006, DEC-010, DEC-011, DEC-017, DEC-018]

## Duration clock and units

In Bash, read the first value of `/proc/uptime` as the monotonic timing source and convert elapsed intervals to integer milliseconds (`duration_ms`). Its effective resolution is 10 ms. Do not add a Node.js dependency for timing, including to standalone `configure`. Use UTC timestamps only for chronological metadata; do not derive elapsed time from wall-clock timestamps. If the monotonic clock cannot be read, set an explicit `unavailable` timing status, omit `duration_ms`, and record a safe measurement-failure reason; do not encode the failure as `null` or zero. Never substitute wall-clock elapsed time. Measurement failures must not interrupt the installation or change its lifecycle outcome. [DEC-007, DEC-014, DEC-015, DEC-016]

## Evidence ownership

Extend the existing stage-owned records rather than creating a separate timing file: `install-run.json` owns guided-flow stages and full guided duration, `engine-run.json` owns engine duration and installation-operation durations, and `configure-run.tsv` owns configure duration and per-step durations. Update the relevant format contracts, validators, and tests together with implementation. [DEC-008]

Record durations for every stage reached, including failed or cancelled runs; omit durations for stages not started. Timing evidence is diagnostic only and must not change lifecycle outcomes or make an incomplete run appear successful. [DEC-009]

## Measurement protocol

Measure the current installation behavior with instrumentation. For the initial measurement condition, collect three clean installations in the reference VM, using the same artifact and VM configuration and a fresh target disk for each run. Summarize the three results by median and range. [DEC-012, DEC-020]

Do not pin package versions or change mirror policy for timing comparisons. Record package versions and mirror/repository identity, plus relevant non-secret network conditions already observed. Do not add active network probes or capture credentials or private connection details for timing evidence. [DEC-013]

## Measurement constraints

Decisions to add instrumentation or define a measurement protocol do not authorize running a build, installation, or test. Any such execution requires separate authorization. [DEC-001, DEC-002, DEC-012]

## Open decisions and TODOs

No open decisions are currently recorded.
