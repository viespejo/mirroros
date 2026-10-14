# Epic 4 Restructure Technical Interview — Decision Log

## DEC-001
- **Question**: What does this plan deliver: an Epic 4 restructure only, the restructure plus the first implementation slice, or no restructure?
- **Context/Nuances**: After Story 4.1, exploration is already free in the maintainer's private VM laboratory (Story 4.1 DEC-009, DEC-014); the rigidity is in how registration is sliced. Stories 4.2 and 4.3 are horizontal foundations that would build `configure` machinery before any real capability is applied (tension with NFR37). Stories 4.4–4.10 are cut by component while real work crosses them (Story 4.6 is a grab bag; the owned Quickshell shell is spread across 4.6, 4.7, and 4.10; visual work touches everything but comes last). Their Given/When/Then criteria anticipate decisions that exploration should inform. Mixing the restructure with implementation would repeat the problem of fixing the shape before evidence. Plan 02-12 is the documentation-only precedent.
- **User Response**: Accepted option A.
- **Decision**: This plan restructures Epic 4 as documentation only (`docs/epics.md`, plus aligned updates to `docs/mvp-scope.md` owning-story references and `docs/architecture.md` if needed). Implementation of the new Story 4.2 belongs to a later plan.
- **Status**: Accepted

## DEC-002
- **Question**: Which shape should the restructured Epic 4 take: walking skeleton plus open increments, walking skeleton plus predefined reorderable vertical slices, or the current component stories reordered?
- **Context/Nuances**: Open increments maximize freedom but lose FR-to-story traceability in `docs/epics.md` and hide what remains for the MVP. Component stories keep the cuts that do not match real work. Vertical slices are usable experiences with outcome-level criteria rather than tool-level ones. Illustrative slices (contents decided later): walking skeleton (minimal `configure` delivering SDDM+uwsm → Hyprland → terminal, shell, tmux end to end); desktop shell and keyboard controls; desktop operations and hardware; development and browser; visual coherence and first-login closure. Horizontal foundations (former 4.2 machinery and 4.3 provenance) grow with each slice instead of being built in advance.
- **User Response**: Accepted option B.
- **Decision**: Epic 4 adopts a walking skeleton (Story 4.2) first, predefined intermediate vertical slices that may be reordered, split, or merged as a reviewed update of `docs/epics.md` based on VM evidence, and a final closure story last. A common "registration done" contract applies to every slice and replaces the horizontal foundation stories.
- **Status**: Accepted

## DEC-003
- **Question**: Where do the obligations of the former horizontal Stories 4.2 (configure machinery) and 4.3 (provenance) go?
- **Context/Nuances**: Building all machinery up front has no consumer (NFR37). Some properties must exist once the first slice runs (entry point, validation before mutation, failure outcome, interruption-safe rerun, evidence). Others have no consumer yet: runtime secret handling and detection of two owners of the same package, file, or service. The inherited ADR 0003/0008/0009 obligations (Limine snapshot tool AUR pinning, Gradle response, `yay` update path) are not part of the contract and get an owner later.
- **User Response**: Accepted.
- **Decision**: Three tiers. (1) Common per-slice contract, stated in the Epic 4 introduction and cited by each slice, applied only to what the slice applies: bounded Bash `configure` scripts over native formats (ADR 0010); provenance for every package and external artifact (name, source class, repository or URL, identity evidence where offered, review responsibility); AUR `PKGBUILD` reviewed and built unprivileged; external configuration repositories checked out or linked, never copied; narrow privilege with user configuration not run as root; `configure` checks its own postconditions; a full rerun on a configured system makes no unnecessary mutation; clean installation plus `configure` in the reference VM without manual steps; `docs/mvp-scope.md` updated with selected providers; no secrets or personal content committed. (2) Mechanism properties established once by Story 4.2 and inherited: independent `operations/configure` entry point, prerequisite validation before mutation, failure outcome identifying the failed step and never presented as ready, interruption-safe rerun, secret-free evidence. (3) Conditional clauses activated by the first slice that needs them: runtime secret supply with an actionable blocked outcome when an external secret is missing, and detection of two owners of the same package, file, or service.
- **Status**: Accepted

## DEC-004
- **Question**: Which capabilities does the Story 4.2 walking skeleton deliver?
- **Context/Nuances**: A TTY-only skeleton proves the mechanism but leaves out the riskiest path (graphical session in the VM with VirGL, SDDM, uwsm). Adding the Quickshell bar or launcher would put the most uncertain, owned QML work into the slice that must ship first and stable. A minimal usable graphical login is the smallest state the maintainer can live in and iterate from, and it validates ADR 0011 and the Story 4.1 session decisions early.
- **User Response**: Accepted option B.
- **Decision**: The Story 4.2 walking skeleton delivers a minimal usable graphical login: SDDM with its stock theme (password login, no autologin), a session started through `uwsm start hyprland.desktop`, Hyprland with minimal native configuration (open a terminal, close a window, exit the session), a terminal emulator, an interactive shell, and tmux. Story 4.2 selects the open terminal and interactive-shell providers from VM exploration as a reviewed update of `docs/mvp-scope.md`. The file manager, the owned SDDM theme, and the Quickshell shell belong to later slices.
- **Status**: Accepted

## DEC-005
- **Question**: Does Story 4.2 integrate `configure` into the guided installer before the first normal reboot, or is that integration deferred to the closure story?
- **Context/Nuances**: Epic 3 DEC-015 and DEC-017 require the guided installation to run `configure` before the first normal reboot while `configure` stays independently invocable. The installer operates on the target through `arch-chroot "$TARGET"`. The two execution contexts differ sharply: the installed system has live systemd, a user session, and D-Bus; the installer target root has no running systemd (units can be enabled, not started), user configuration needs `runuser` or equivalent, and unprivileged AUR builds happen inside the chroot. Deferring integration risks every slice assuming a live system and breaking in the chroot at the end. The maintainer's exploration loop stays fast: `configure` runs against the installed VM with snapshots, and clean installation is used only as registration proof.
- **User Response**: Accepted option A.
- **Decision**: Story 4.2 defines both execution contexts of `configure` (the running installed system and a target root invoked by the guided installer before the first normal reboot) and integrates the installer invocation after base installation. The common per-slice contract requires every slice to work in both contexts.
- **Status**: Accepted

## DEC-006
- **Question**: Who owns the obligations inherited from ADRs 0003, 0008, and 0009 through the former Story 3.2?
- **Context/Nuances**: ADR 0003 and ADR 0009 make the default `btrfs-limine` option depend on two single-maintainer AUR packages (Limine snapshot tools), prebuilt and pinned in the artifact; Gradle dependencies remain pinned by version only and the post-installation update path is open. ADR 0008 sets `yay` with review and unprivileged build as the installed-system AUR path and notes that updates would build unpinned AUR head until pinned. Placing them in Story 4.2 would fatten the skeleton; placing them in the closure story would mix system maintenance with first-login coherence and push a default-option concern to the end. The general "reviewed, unprivileged AUR build" mechanics stay in the common contract (DEC-003) and are applied by whichever slice first installs from the AUR.
- **User Response**: Accepted option A.
- **Decision**: A dedicated vertical slice, "Safe system updates", owns `yay` as the installed-system AUR path (reviewed `PKGBUILD`, unprivileged build), the pinned and reviewed post-installation update path of the Limine snapshot tools, and the response to Gradle dependencies pinned by version only. The retired Epic 3 correspondence table redirects former Story 3.2 to this slice; accepted ADRs are not modified.
- **Status**: Accepted

## DEC-007
- **Question**: How are the remaining `docs/mvp-scope.md` capabilities grouped into vertical slices?
- **Context/Nuances**: The browser's acceptance depends on portals, file selection, and clipboard, so a browser-only story would be thin and coupled. The former Story 4.6 grab bag splits by validation mode: hardware and connectivity are only partly validatable in the VM (no audio device, Story 4.1 DEC-014), while desktop integration is fully validatable there. The owned Quickshell shell is the most uncertain, iteration-heavy work and stands alone. Alternative rejected: a separate browser slice with the file manager placed in the shell slice.
- **User Response**: Accepted.
- **Decision**: Epic 4 has seven stories after Story 4.1, in indicative and reorderable order: 4.2 minimal graphical login (walking skeleton, DEC-004); 4.3 desktop shell and session control (Quickshell bar, launcher, notifications, OSD, session menu; lock and idle; window, workspace, and monitor bindings; scratchpad; shortcut reference); 4.4 hardware and connectivity (audio, Bluetooth, brightness, media keys, battery, lid, suspend and hibernate in use, Wi-Fi and Bluetooth connection through the shell or a terminal interface); 4.5 desktop integration and graphical applications (portals, polkit agent, clipboard and history, screenshots, file manager, browser); 4.6 development tooling (Git, Neovim and Pi from external repositories, Docker, Node.js, command-line search utilities); 4.7 safe system updates (DEC-006); 4.8 visual coherence and first-login closure (owned SDDM theme, typography, palette, cursor and icons, full frozen-scope coverage check, no welcome application or background daemon).
- **Status**: Accepted

## DEC-008
- **Question**: How are keyboard bindings distributed across slices, and when is the frequent-action list frozen?
- **Context/Nuances**: `docs/mvp-scope.md` makes frequent-action adjustments reviewed updates until former Story 4.7 (keyboard controls) completes. With slices, frequent actions span Stories 4.3 (session, windows), 4.4 (volume, brightness, media, connectivity), and 4.5 (screenshots, clipboard). Freezing after Story 4.3 would be premature because hardware and desktop actions would not yet be explored in the VM. Story 4.2 carries only the minimal DEC-004 bindings and Story 4.3 may adjust them once conventions exist (accepted cost).
- **User Response**: Accepted.
- **Decision**: Story 4.3 owns binding conventions (modifier scheme and translation from the maintainer's i3 configuration per Story 4.1 DEC-012), the shortcut reference, and the absence of conflicting bindings. Each slice binds its own frequent actions under those conventions and adds them to the reference; a slice is not registered while one of its frequent actions lacks a keyboard path. The frequent-action list freezes when Story 4.8 completes, and Story 4.8 verifies FR64. `docs/mvp-scope.md` is updated in this plan to move the freeze point to Story 4.8 and renumber open-provider owners per DEC-007.
- **Status**: Accepted

## DEC-009
- **Question**: How are Epic 4 FRs mapped to the restructured stories?
- **Context/Nuances**: Cross-cutting FRs are assigned to the story that establishes them; the common contract makes later slices keep them. FR24 and FR61 say "capability modules": following the 02-12 precedent, PRD-derived copies keep PRD wording and ADR 0010 prevails, so modules are satisfied as per-slice scripts with declared prerequisites. FR21 is also required in Story 4.2 through the contract but is mapped where provenance weighs most. FR29 is conditional (DEC-003).
- **User Response**: Accepted.
- **Decision**: 4.1: FR20, FR62, FR63. 4.2: FR22, FR23, FR24, FR25, FR26, FR27, FR28, FR30, FR31, FR61, FR65. 4.3: FR23, FR64, FR65. 4.4: FR23, FR31. 4.5: FR23, FR31, FR65. 4.6: FR21, FR23, FR29 (FR29 indicative; moves as a reviewed update if another slice needs secrets first). 4.7: FR21 and NFR12. 4.8: FR30, FR31, FR64, FR65.
- **Status**: Accepted

## DEC-010
- **Question**: How are story numbers handled when slices are reordered, split, or merged?
- **Context/Nuances**: Story numbers are referenced from `docs/mvp-scope.md`, the FR Coverage Map, plans, summaries, and commits. Renumbering on every change would break those references, which the Epic 3 restructure deliberately avoided (Epic 3 DEC-020). Renumbering to reflect order was rejected.
- **User Response**: Accepted.
- **Decision**: Story numbers are stable identifiers, not positions. The Epic 4 introduction states that order is indicative: Story 4.2 first, Story 4.8 last, the rest ordered by VM evidence. Reordering does not renumber. Splitting adds new numbers after the highest existing one, and Story 4.8 remains the closure story. Merging retires one number and leaves a "Merged into 4.x" note in its place. Every reorder, split, or merge is a commit that cites its evidence.
- **Status**: Accepted

## DEC-011
- **Question**: How are references to former Epic 4 story numbers in accepted ADRs handled?
- **Context/Nuances**: ADR 0010 says "Story 4.3 decides the form" of provenance; ADR 0011 cites Stories 4.4 and 4.7 and validation through Story 4.4; ADR 0012 says Stories 4.4 and 4.7 decide the shell location. Numbers 4.3–4.8 are reused with new meanings, so without a translation "Story 4.4" in ADR 0011 would point to the hardware slice. Amending the ADRs is cheap because they are fresh but breaks the rule that accepted ADRs are not rewritten, as applied to former Story 3.2. `operations/configure` and `docs/procedures/configure.md` still correctly cite Story 4.2.
- **User Response**: Accepted option A.
- **Decision**: Accepted ADRs are not modified. `docs/epics.md` adds a correspondence table from the former Epic 4 numbering to the new one, placed before the stories and stating that numbers 4.3–4.8 are reused: former 4.2 → 4.2 plus the common contract; 4.3 → common contract plus 4.6 and 4.7; 4.4 → 4.2; 4.5 → 4.2 (terminal, shell, tmux) and 4.5 (file manager); 4.6 → 4.4 and 4.5; 4.7 → 4.3; 4.8 → 4.6; 4.9 → 4.5; 4.10 → 4.8. `docs/mvp-scope.md`, `docs/architecture.md`, and the retired Epic 3 references in `docs/epics.md` are updated to the new numbering. `operations/configure` and `docs/procedures/configure.md` stay unchanged.
- **Status**: Accepted
