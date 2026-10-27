# Installation Time Measurements — Decision Log

**Conventions.** The Consolidated Plan (`installation-time-measurements_plan.md`) is the single source of truth for the *design* — the implementing agent builds from it. This log is *history*: it records the reasoning and the evolution of decisions. When a later decision revises an earlier one, the earlier entry is not rewritten (append-only); instead its `Status` carries a forward pointer to the superseding ID, so the two read as an evolution, not a live contradiction.

## DEC-001
- **Question**: What should be the first activity for improving installation time?
- **Context/Nuances**: The repository records total installation duration and publishes progress, but those do not by themselves attribute time precisely to each installation phase or configure step. Measurement agreement does not itself authorize running a build, installation, or test.
- **User Response**: “yes” to the proposed decision to begin with measurement before selecting or implementing optimizations, including the stated nuances and open question.
- **Decision**: Begin by measuring installation before choosing or implementing performance optimizations. Measurement should help locate bottlenecks by phase and step.
- **Status**: Accepted

## TODO-001
- **Question**: What is the scope of the first measurement?
- **Context/Nuances**: Choose between measuring an execution using currently available instrumentation, or designing instrumentation changes to capture durations per phase and configure step. This choice does not authorize executing a build, installation, or test.
- **User Response**: Pending.
- **Decision**: Pending.
- **Status**: Resolved by DEC-002

## DEC-002
- **Question**: Should the first measurement use current instrumentation or add phase- and step-level duration instrumentation first?
- **Context/Nuances**: Current records provide overall installation duration and progress markers, but not reliable per-phase and per-configure-step duration attribution. Instrumentation should be added before the first comparative measurement. No installation, build, or test execution is authorized by this decision.
- **User Response**: The user accepted the recommendation and asked to add the decision directly to the artifacts.
- **Decision**: Add instrumentation to record durations for installation phases and each configure step before conducting the first comparative measurement.
- **Status**: Accepted

## DEC-003
- **Question**: Where should detailed phase and configure-step durations be recorded?
- **Context/Nuances**: The engine writes `engine-run.json`; configure writes `configure-run.tsv` with step status but no per-step duration. The architecture specifies integer millisecond durations and run-associated evidence. The recommendation was to keep detailed timing in structured evidence and keep live progress concise; a final summary was only suggested as potentially useful, not decided.
- **User Response**: The user accepted the recommendation and asked to add the decision directly to the artifacts.
- **Decision**: Record detailed durations in structured per-run evidence. Keep live progress concise and do not add per-step timings to the live progress display.
- **Status**: Accepted

## TODO-002
- **Question**: Should the installer show a concise timing summary at the end of a run?
- **Context/Nuances**: Detailed timing remains available in per-run evidence regardless. A user-facing summary is optional and separate from the progress display.
- **User Response**: Pending.
- **Decision**: Pending.
- **Status**: Resolved by DEC-004

## DEC-004
- **Question**: Should the installer show a concise timing summary at the end of a run?
- **Context/Nuances**: Detailed durations will already be available in structured per-run evidence. A visible summary could be reconsidered after reviewing initial measurements.
- **User Response**: The user accepted the recommendation not to add a summary for now and asked to add the decision directly to the artifacts.
- **Decision**: Do not show an end-of-run timing summary initially. Reconsider only after reviewing initial measurement results.
- **Status**: Accepted

## DEC-005
- **Question**: Should measurements capture both the full guided-install duration and engine duration, in addition to per-operation and per-configure-step timings?
- **Context/Nuances**: The success screen reports engine duration, while VM qualification measures from QEMU launch through the installation result, including configure. The guided flow contains interactive review and confirmation, whose elapsed time should not be conflated with automated engine work.
- **User Response**: The user accepted the recommendation and asked to add the decision directly to the artifacts.
- **Decision**: Record full guided-installer elapsed duration and engine elapsed duration separately. Break down engine duration by installation operation and configure duration by configure step, so interactive elapsed time remains distinguishable from automated installation work.
- **Status**: Accepted

## DEC-006
- **Question**: Should the guided flow's individual stages be timed, including interactive stages whose durations include user reading and response time?
- **Context/Nuances**: The confirmation contract already defines ordered stages: `preparation`, `discovery_initial`, `plan`, `review`, `confirmation`, `password`, `discovery_final`, and `engine`. Stage-level duration data can show where time is spent, but interactive user time must be labeled distinctly from automated work.
- **User Response**: The user accepted the recommendation to time the guided stages and asked to add the decision directly to the artifacts.
- **Decision**: Record durations for each existing guided-installer stage. Identify interactive stages so time spent by the user is distinguishable from automated stage execution.
- **Status**: Accepted

## DEC-007
- **Question**: Should elapsed intervals use a monotonic high-resolution clock, with UTC timestamps reserved for chronology?
- **Context/Nuances**: The installer currently uses Bash `SECONDS` for displayed elapsed time, and other existing duration records use seconds. Architecture requires new durations to be integer milliseconds. Wall-clock adjustments must not distort elapsed intervals.
- **User Response**: The user accepted the recommendation and asked to add the decision directly to the artifacts.
- **Decision**: Use a monotonic high-resolution clock for new elapsed-duration measurements and record durations as integer milliseconds. Keep UTC timestamps for chronological metadata, not interval calculation.
- **Status**: Accepted

## DEC-008
- **Question**: Should timing data extend existing stage-owned records or live in a separate timing file?
- **Context/Nuances**: Guided-run, engine-run, and configure evidence already have distinct owners and formats. Extending them requires explicit format and validator/test updates, while a separate file risks creating a parallel source of truth.
- **User Response**: The user accepted the recommendation to extend the existing records and asked to add the decision directly to the artifacts.
- **Decision**: Store timing data in the existing records owned by each stage: `install-run.json` for guided-flow stages and total duration, `engine-run.json` for engine operations and duration, and `configure-run.tsv` for configure steps and duration. Update the corresponding format contracts, validators, and tests with the implementation.
- **Status**: Accepted

## DEC-009
- **Question**: Should timing data be retained for runs that fail or are cancelled, as well as successful runs?
- **Context/Nuances**: Durations for reached stages can expose slow failures and waits. Stages that were never started have no meaningful duration. Timing evidence must not alter success, failure, cancellation, or verification outcomes.
- **User Response**: The user accepted the recommendation to record timings for incomplete runs and asked to add the decision directly to the artifacts.
- **Decision**: Record durations for every reached stage, including failures and cancellations. Omit durations for stages not started. Timing data is diagnostic evidence only and does not change lifecycle outcomes.
- **Status**: Accepted

## DEC-010
- **Question**: Should full-install duration begin at guided-flow start or at live-medium boot?
- **Context/Nuances**: The guided flow has its own run record and stage lifecycle. VM qualification separately measures from QEMU launch through the installation report, which includes live boot and other setup. Combining live boot with installer duration would obscure installer-specific performance.
- **User Response**: The user accepted the recommendation to begin at guided-flow start and asked to add the decision directly to the artifacts.
- **Decision**: Define full guided-installer duration as beginning when the guided flow starts, excluding live-medium boot. Live boot may be measured separately.
- **Status**: Accepted

## DEC-011
- **Question**: Should full guided-installer duration end when the installation result is determined and recorded, before the final menu?
- **Context/Nuances**: The current flow writes its run records before presenting the optional success or failure menu. Time spent choosing whether to restart or return to the shell is post-outcome user time, not installation execution.
- **User Response**: The user accepted the recommendation and asked to add the decision directly to the artifacts.
- **Decision**: End full guided-installer duration when the installation outcome is determined and recorded, before displaying the final restart/exit menu.
- **Status**: Accepted

## DEC-012
- **Question**: How many clean reference-VM installation runs should be measured per condition?
- **Context/Nuances**: One run can be distorted by transient load or network variation. Runs should use the same artifact and VM configuration with a fresh target disk for each run. This defines a measurement protocol only; it does not authorize executing runs.
- **User Response**: The user accepted the recommendation of three runs, summarized by median and range, and asked to add the decision directly to the artifacts.
- **Decision**: Measure three clean installations per condition in the reference VM, using the same artifact and VM configuration and a fresh disk for each run. Summarize results using the median and range.
- **Status**: Accepted

## DEC-013
- **Question**: Should package versions and repository/network conditions be frozen across timing runs, or observed and recorded?
- **Context/Nuances**: MirrorOS uses rolling official repositories and does not adopt exact historical package reconstruction. Existing evidence records installed packages and mirrorlist identity. Changing repository policy to make benchmarks deterministic would exceed a measurement-only change. Network context must remain non-secret; no credentials or private connection details belong in evidence.
- **User Response**: The user accepted the recommendation to record observed conditions without pinning versions or mirrors and asked to add the decision directly to the artifacts.
- **Decision**: Do not pin package versions or alter mirror policy for timing comparisons. Record package versions and mirror/repository identity, along with relevant non-secret network conditions already observable during the run. Do not add active network probes or collect credentials or private connection data as part of timing instrumentation.
- **Status**: Accepted

## DEC-014
- **Question**: What should happen if the monotonic clock cannot be read during a run?
- **Context/Nuances**: Timing is diagnostic evidence and must not affect installation success, failure, cancellation, or verification outcomes. A missing measurement must be represented as unavailable rather than fabricated or calculated from wall-clock time.
- **User Response**: The user accepted the recommendation to continue the installation and mark the duration unavailable, and asked to add the decision directly to the artifacts.
- **Decision**: A monotonic-clock read failure must not interrupt the installation or alter its lifecycle outcome. Mark the affected duration as unavailable and record the measurement failure; do not substitute wall-clock elapsed time.
- **Status**: Accepted

## DEC-015
- **Question**: How should evidence represent a duration that could not be measured: a null value or an explicit status?
- **Context/Nuances**: Architecture permits `null` only when its “known but without a value” meaning is defined. A missing measurement must not be mistaken for zero or an unreported field, and the reason should remain diagnosable without exposing sensitive data.
- **User Response**: The user accepted the recommendation to use an explicit unavailable status, omit the duration value, and record the measurement cause.
- **Decision**: Represent a failed timing measurement with an explicit `unavailable` status, omit `duration_ms`, and record a safe measurement-failure reason. Do not use `null` or zero as a substitute.
- **Status**: Accepted

## DEC-016
- **Question**: What monotonic clock source should Bash instrumentation use, including standalone configure runs that do not require Node.js?
- **Context/Nuances**: Configure is independently invocable without a Node.js runtime dependency. `/proc/uptime` exposes a Linux monotonic uptime value at centisecond precision; it can be converted to integer milliseconds without launching another process. The recorded unit remains milliseconds, while effective resolution is 10 ms.
- **User Response**: The user accepted the recommendation to read `/proc/uptime` from Bash and asked to add the decision directly to the artifacts.
- **Decision**: Use the first `/proc/uptime` value as the monotonic timing source in Bash. Convert it to integer milliseconds; document its effective 10 ms resolution. Do not add a Node.js dependency for timing.
- **Status**: Accepted

## DEC-017
- **Question**: Should fixed engine phases outside the plan-operation loop—prechecks, postconditions, and cleanup—also be timed separately?
- **Context/Nuances**: The engine performs prechecks before plan execution, evaluates postconditions after the plan operations, runs configure after successful postconditions, and performs cleanup before final evidence is written. Timing only plan operations and configure steps would leave these phases as unexplained engine-total overhead.
- **User Response**: The user accepted the recommendation to time these fixed phases separately and asked to add the decision directly to the artifacts.
- **Decision**: Record separate durations for engine prechecks, postconditions, and cleanup, in addition to each installation-plan operation and each configure step.
- **Status**: Accepted

## DEC-018
- **Question**: Which guided-flow stages should be labeled interactive, and how should preparation be classified?
- **Context/Nuances**: `review`, `confirmation`, and `password` require user interaction. `preparation` normally performs bounded readiness checks but can offer help, retry, or cancellation. Other named stages are automated in the current flow.
- **User Response**: The user accepted the recommendation and asked to add the decision directly to the artifacts.
- **Decision**: Label `review`, `confirmation`, and `password` as interactive; label `preparation` as mixed; label `discovery_initial`, `plan`, `discovery_final`, and `engine` as automated.
- **Status**: Accepted

## DEC-019
- **Question**: Should the first performance baseline measure the current behavior with instrumentation, then compare later optimizations using the same instrumentation?
- **Context/Nuances**: Comparing instrumented runs under the same measurement contract avoids attributing instrumentation overhead to an optimization. The user noted that the interview was becoming too detailed for the immediate goal of finding installation bottlenecks; this baseline decision is accepted, but further protocol detail should be kept proportionate.
- **User Response**: The user accepted the recommendation and requested that the decision be added directly to the artifacts, while noting concern about excessive depth.
- **Decision**: Establish the current installation behavior with instrumentation as the baseline. Compare later optimization candidates using the same instrumentation and measurement contract.
- **Status**: Superseded by DEC-020

## DEC-020
- **Question**: Is this plan limited to measuring the current installation, with subsequent optimization decisions handled by a separate plan?
- **Context/Nuances**: Earlier DEC-019 included comparing later optimization candidates with the same instrumentation. The user clarified that the present plan is only for measurement; decisions and work arising from the results belong to a later, separate plan.
- **User Response**: The user explicitly confirmed this scope and asked to add the decision directly to the artifacts.
- **Decision**: Limit this plan to implementing timing instrumentation, measuring the current installation behavior, and analyzing the resulting measurements. Do not decide or implement installation optimizations under this plan. Any follow-on optimization decisions and work require a separate plan.
- **Status**: Accepted
