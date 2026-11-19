# Quattro notification integration — Decision Log

## DEC-001
- **Question**: Should plan 02-42 include both product shell integration and migration of the validated notification consumers, with the private bar/history check first?
- **Context/Nuances**: The product bar and panel already have a close-after-history acknowledgement flow. Reuse it instead of importing the scratch panel. Consumer changes are not needed to run the first check. No plan dependencies were selected.
- **User Response**: Approved the proposed scope and explicitly requested persistence and direct registration.
- **Decision**: Use one plan, 02-42, with two ordered commit blocks: integrate the tested Quattro-derived notification card and engine code into the product shell and validate the real bar and panel on the VM's private D-Bus; then migrate the shared emitter and validated consumers in separate commits. Leave the installed shell and the global keyboard shortcut out of scope.
- **Status**: Accepted

## DEC-002
- **Question**: Should plan 02-42 retain standard live notification actions but reject commands delegated by a notification, including after restoration?
- **Context/Nuances**: Standard D-Bus actions return an identifier to the live sender; they do not instruct the shell to launch a program. Quattro's executable hints let one-shot senders leave persistent launchers, but structural argv validation does not authorize the sender. A confined sender's ability to reach this path depends on its bus access and filtering, and activation requires user interaction. No product consumer was found that needs executable hints. The fingerprint invitation uses a standard `setup` action and lets its own service launch setup.
- **User Response**: Yes, confirmed the proposed execution boundary for plan 02-42.
- **Decision**: Keep standard D-Bus actions for live notifications only. Reject executable hints on intake and discard executable fields from legacy persisted rows on load, including active-state restoration and history replay. Keep older records readable without their executable behavior. Do not build a token, sender allowlist, or persistent action registration channel in this plan. Revisit only for a concrete consumer, starting with a fixed operation and validated data rather than arbitrary commands.
- **Status**: Accepted

## DEC-003
- **Question**: Should the tested Quattro candidate be the notification engine base, with MirrorOS-specific integration and state compatibility added to it?
- **Context/Nuances**: Use the candidate for cards, stacks, navigation, actions, and expiration, not as a replacement for the entire shell. MirrorOS owns the real bar and panel, state path, configurable retention, and while-locked count. The candidate excludes new transient notices from persistence. Older rows do not reliably identify previously transient notices, so do not infer which ones to delete. Dropping executable fields is intentional under DEC-002, not a promise of byte-for-byte state compatibility. The candidate's quiet-state writer would discard MirrorOS fields and the candidate does not apply product notification preferences; resolve those contracts separately without rewriting installed state.
- **User Response**: Yes. Do the work one part at a time and explain what is being done at each step.
- **Decision**: Start from the tested candidate engine and add the MirrorOS-specific contracts incrementally. Retain the MirrorOS state path, configurable retention, and continued readability of legacy live/history content and while-locked state; retain the candidate's transient filter. Verify state compatibility using test copies on private D-Bus, not installed state. Explain each step's changes, retained behavior, and verification before moving to the next part.
- **Status**: Accepted

## DEC-004
- **Question**: Should plan 02-42 remove the built-in notification panel and defer the while-locked counter to a future notification-center plugin?
- **Context/Nuances**: Removing the panel also removes the history-expand-and-close acknowledgement path. This supersedes the panel and counter portions of DEC-001 and DEC-003, but does not change on-disk history or its retention.
- **User Response**: No built-in panel; consider the counter later in a notification-center plugin. Explicitly confirmed this revised scope.
- **Decision**: Remove the built-in panel. Defer the while-locked counter and its plugin integration outside 02-42. Remove the attended bar-to-panel acknowledgement test from the plan.
- **Status**: Accepted

## DEC-005
- **Question**: Should MirrorOS remove global timed snooze and retain manual Do Not Disturb, following Omarchy 4.5?
- **Context/Nuances**: Manual Do Not Disturb stays on until explicitly switched off. Dropping global timed snooze removes automatic resumption after a selected period. Per-source snooze and the screen-sharing offer are separate decisions.
- **User Response**: Yes; match Omarchy 4.5 here too.
- **Decision**: Do not port global timed snooze into the candidate. Retain manual Do Not Disturb.
- **Status**: Accepted

## DEC-006
- **Question**: Should plan 02-42 also omit per-source timed snooze, as in Omarchy 4.5?
- **Context/Nuances**: Removing per-source snooze removes the shell control for temporarily silencing one notification source while leaving other sources audible or visible. Manual Do Not Disturb remains available under DEC-005. The screen-sharing offer is a separate decision.
- **User Response**: Yes; match Omarchy 4.5 for per-source snooze as well.
- **Decision**: Do not port per-source timed snooze into the candidate.
- **Status**: Accepted

## DEC-007
- **Question**: Should MirrorOS remove the notification silence suggestion shown when screen sharing begins, as in Omarchy 4.5?
- **Context/Nuances**: The offer starts a timed silence only if accepted. Timed snooze is already out of scope under DEC-005 and DEC-006. Screen sharing itself is not affected.
- **User Response**: Yes; match Omarchy 4.5 here as well.
- **Decision**: Do not port notification-specific screen-sharing detection or its silence offer. Do not replace the offer with automatic muting. Manual Do Not Disturb remains available.
- **Status**: Accepted

## DEC-008
- **Question**: Should MirrorOS replace configurable history retention with Omarchy 4.5's fixed limits while retaining MirrorOS storage paths?
- **Context/Nuances**: The fixed limits are 24 hours from closure and at most 100 entries. A previous seven-day preference no longer protects entries older than 24 hours; a previous disabled-history preference no longer prevents new persistent entries. Verify both cases with test copies, not installed state. This supersedes the configurable retention portion of DEC-003, not the legacy content readability or transient-filter requirements.
- **User Response**: Yes; match Omarchy 4.5 except for the paths.
- **Decision**: Use fixed 24-hour and 100-entry history limits. Keep MirrorOS state paths and read legacy notification records, subject to the new limits and the executable-field policy in DEC-002.
- **Status**: Accepted

## DEC-009
- **Question**: Should the new notification engine ignore the legacy `notifications` section of `shell.json` without removing it?
- **Context/Nuances**: The installed reference VM has only `stacking: "source"` in that section, matching the installed default and the tested candidate's grouping. Other installations may have custom values that will no longer take effect. Keeping these keys on disk allows the older engine to read them on rollback. The new engine keeps the already validated candidate behavior, including the countdown. The Do Not Disturb verification-code exception is a separate policy decision.
- **User Response**: Yes; the old notification preferences are no longer needed and should be ignored.
- **Decision**: Stop applying the legacy `notifications` section in the new engine. Do not delete or rewrite that section as part of the integration; keep reading preferences for the rest of the shell normally.
- **Status**: Accepted

## DEC-010
- **Question**: How should the candidate handle an existing MirrorOS `quiet.json` when adopting the upstream format?
- **Context/Nuances**: The installed VM uses the legacy shape (`snoozes`, `dnd`, `silencedSince`, and `codesBypassQuiet`); the candidate uses only `dnd`. Both VM files currently have `dnd: false`. The `configure` operation publishes the runtime but does not read or write user configuration or private shell state.
- **User Response**: Yes, confirmed the candidate format in the MirrorOS path without a separate migration.
- **Decision**: Use the candidate reader and writer at the existing MirrorOS state path. Preserve the stored `dnd` boolean, ignore legacy fields without converting an active timed snooze into manual Do Not Disturb, and write only `dnd` on the next normal runtime save. Do not copy the prototype file or add a configure-time migration. Once the runtime rewrites the file, rollback can still read `dnd` but cannot recover the discarded fields.
- **Status**: Accepted

## DEC-011
- **Question**: Should MirrorOS adopt the full Omarchy 4.5 notification keybinding map, including the global keyboard-navigation shortcut?
- **Context/Nuances**: The history shortcut stays unchanged. The retired panel shortcut becomes the manual Do Not Disturb toggle. Including keyboard navigation supersedes the deferral in DEC-001. The contextual action remains subject to DEC-002 and must never execute sender-supplied commands.
- **User Response**: Yes, confirmed the complete 4.5 notification map, including keyboard navigation.
- **Decision**: Match `v4.5.0`: `Super+,` contextual action; `Super+Shift+,` dismiss all; `Super+Ctrl+,` keyboard navigation; `Super+Alt+,` dismiss newest; `Super+Shift+Alt+,` replay history; `Super+Ctrl+Alt+,` toggle Do Not Disturb. Make this a separate commit after private engine validation; leave unrelated shortcuts unchanged.
- **Status**: Accepted

## DEC-012
- **Question**: Should MirrorOS retain the tested candidate's notification card body click behavior?
- **Context/Nuances**: A body click is distinct from clicking an explicit action button. The candidate does not synthesize a primary action or use window focus or URL opening as a fallback for a body click.
- **User Response**: Yes; keep the candidate's body click behavior.
- **Decision**: On a body click, invoke the standard `default` D-Bus action only if supplied by the live sender, then close the card. Otherwise, just close the card. Do not add window-focus or link-opening fallbacks to the body click. Explicit action buttons retain their behavior.
- **Status**: Accepted

## DEC-013
- **Question**: Should the shared sender use an internal runtime path for product callers and a public symlink, both delivered by the existing `desktop/shell` configure step?
- **Context/Nuances**: MirrorOS-owned callers already use absolute paths under `/usr/share/mirroros`. `cfg_system_link` leaves occupied destinations alone. Power, screenshot, and clipboard are installed before the shell in the current configure order. A partial update or an active session can therefore encounter a missing sender even though a complete install delivers it before the next graphical login.
- **User Response**: Yes; confirmed the internal path and public alias, both delivered by `desktop/shell`.
- **Decision**: Deliver one executable at `/usr/share/mirroros/shell/notifications/mirroros-notification-send`. Product callers use that absolute path. Publish `/usr/bin/mirroros-notification-send` as a convenience symlink after publishing the runtime, without overwriting an occupied destination. Do not add or reorder configure steps. Validate the sender before migrating callers, and verify that its absence does not change the outcome of the primary operation.
- **Status**: Accepted

## DEC-014
- **Question**: How should the validated consumers be grouped into commits?
- **Context/Nuances**: Validate the engine and publish the shared sender before migrating consumers. Fingerprint continues to use direct `notify-send --wait`; its change is limited to the tested glyph.
- **User Response**: Yes; confirmed the proposed consumer commit split.
- **Decision**: Use one independently verified commit each for Reminders (script and form), Battery, Capture, Clipboard History, and Fingerprint. Explain and verify each before moving on.
- **Status**: Accepted

## DEC-015
- **Question**: Should plan 02-42 include deployment with `configure` in the reference VM after a short private engine check?
- **Context/Nuances**: The original prototype needed the installed shell untouched for comparison. Product validation must also exercise configure delivery, the installed shell, real bindings, and consumer delivery. Configure does not migrate private state, but the new runtime may prune history and rewrite stored fields. A rollback point must include both the installed delivery and private state.
- **User Response**: Yes; include the VM deployment and materialize the revised plan directly.
- **Decision**: Keep a short private-bus compatibility and action check first. Then deploy to the reference VM with configure, restart the graphical session, and validate the installed engine, bindings, sender delivery and consumers in stages. Require a rollback point before deploying. Deployment elsewhere is out of scope.
- **Status**: Accepted
