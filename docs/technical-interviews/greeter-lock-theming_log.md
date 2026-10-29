# Greeter and lock under themes — Decision log

Date: 2026-10-29

The maintainer asked to adapt the greeter and lock screen to the theming introduced by the fixed Osaka Jade theme
(`visual/theme`) and compared the current surfaces with synthetic browser prototypes before deciding. Omarchy
`4.0.6-1` on the reference VM was inspected read-only as an idea reference; no Omarchy code or asset is copied.
Prototype files and screenshots stayed under the ignored `evidence/prototypes/greeter-lock-theme/` directory and are
not committed. Browser previews are not runtime qualification. The plan was later approved and materialized; see its
final state.

## DEC-001
- **Question**: Should the Plymouth splash follow the selected theme?
- **Context/Nuances**: The splash is embedded in the initramfs; changing it requires a privileged boot-image
  regeneration. It appears before any user is known, while the theme selection
  (`$XDG_STATE_HOME/mirroros/current/theme`) is per user. Omarchy's theme switch changes neither Plymouth nor SDDM;
  its splash keeps a fixed Tokyo Night background under Osaka Jade. Alternatives were unchanged splash, a one-time
  jade recolor, and regeneration on every theme change.
- **User Response**: "si, A para el splash".
- **Decision**: Keep the splash unchanged (ADR 0019): it is product identity, independent of the theme.
- **Status**: Accepted

## DEC-002
- **Question**: Should the greeter follow a theme?
- **Context/Nuances**: The greeter is also system-wide and pre-login, and follows the splash during boot. Fixed jade
  colors would need ADR amendments, a recolored symbol raster and would introduce a color jump after the gray splash;
  following the last user's theme would require the greeter to read a user's home state. The proposed principle is:
  system surfaces (splash, greeter) are neutral product identity; user surfaces (desktop, lock) follow the theme.
- **User Response**: "si, vamos con G1".
- **Decision**: The greeter keeps the splash's neutral colors (`#101315`, `#CACCCC`, failure `#a55555`) and does
  not follow any theme. Following the last user's theme is rejected.
- **Status**: Accepted

## DEC-003
- **Question**: Can the greeter continue the splash without a visible jump, and how should its form look?
- **Context/Nuances**: Both surfaces already share the size formula (at most 320 px, 42% of width, 22% of height),
  but the greeter centers a whole column, so its symbol sits about 100 px above the splash symbol at 1920x1080.
  Proportional bounds are scale-independent; only the 320 px cap differs, because Plymouth uses device pixels and
  QML logical pixels. The synthetic prototype compared the current layout with a variant anchored to the splash
  rectangle.
- **User Response**: "confirmados" (after "debería de no notar salto con el splash").
- **Decision**: Draw the greeter symbol in exactly the splash rectangle, statically; compute the 320 px cap in device
  pixels. Place the form below the symbol with a gap of 5% of the display height. Password field 280x44, 1 px
  border in the foreground at 35% opacity rising to 85% while typing or authenticating, fill `#15191c`, failure in
  `#a55555`.
- **Status**: Accepted

## DEC-004
- **Question**: Should the account name and selector always be shown?
- **Context/Nuances**: Omarchy's greeter shows no account. ADR 0014 requires displaying the selected account; the
  current theme already hides the selector arrow with a single account.
- **User Response**: "usuario: ok...solo mostramos si hay mas de uno".
- **Decision**: Show the account name and selector only when more than one account is listed. With one account,
  the greeter shows only the symbol and the password field in the center.
- **Status**: Accepted

## DEC-005
- **Question**: How should the keyboard layout appear in the greeter?
- **Context/Nuances**: Hiding it when only one layout exists never applies: `layouts.lua` always adds the declared
  `us,es` layouts to the configured one (ADR 0015). Showing it only after a switch was considered.
- **User Response**: "distribution: L1 (tal como version N)".
- **Decision**: Always show the active layout and the `Super+I` hint, de-emphasized in the bottom-left corner,
  opposite the unchanged power control in the bottom-right corner.
- **Status**: Accepted

## DEC-006
- **Question**: Should the handoff between splash and greeter be addressed?
- **Context/Nuances**: Arch's `sddm.service` starts after `plymouth-quit.service`, and SDDM `0.21.0` has no Plymouth
  integration; a black frame and the greeter compositor's background appear before the greeter. Retaining the splash
  would hide SDDM failures, against the diagnostic boundaries of ADR 0014 and ADR 0019.
- **User Response**: "no nos preocumamos por el hueco entre splash y greeter".
- **Decision**: Leave the handoff unchanged; no compositor or Plymouth change.
- **Status**: Accepted

## DEC-007
- **Question**: Which lock layout should be used?
- **Context/Nuances**: The maintainer preferred the simplicity of Omarchy's lock: one password field over a blurred
  background. MirrorOS's lock always uses the configured layout and layout switching does not work while locked
  (ADR 0015), so the layout label is constant information.
- **User Response**: "1. yes" (no clock and no layout).
- **Decision**: The lock shows only the password field: no clock and no keyboard layout.
- **Status**: Accepted

## DEC-008
- **Question**: What should the lock background be?
- **Context/Nuances**: The user's selected background (`$XDG_STATE_HOME/mirroros/current/background`, ADR 0020) is
  image data, not a screenshot, so no window or notification content is shown. Guest tests T1 and T3–T6 confirmed
  that hyprlock follows the link and uses the solid color when the image is missing. A lighter treatment was
  requested after T3.
- **User Response**: "yes, me vale"; later "quizas mejor el background menos oscuro?" and "me vale" after T6.
- **Decision**: Use the selected background with `blur_passes = 3`, `blur_size = 8` and `brightness = 0.9`, and the
  theme background color as fallback.
- **Status**: Accepted

## DEC-009
- **Question**: How should the lock field be sized and styled?
- **Context/Nuances**: Omarchy 4 draws a 381x67 logical-pixel field with a 3 px border. Guest test T1 showed that
  hyprlock `0.9.6` sizes are physical pixels, not scaled by the monitor; percentages are accepted. At 1920x1080 and
  scale 1.6, `31.5%, 9.5%` matched Omarchy's field in the maintainer's screenshots. hyprlock has no input-field
  font size; text size follows the field height.
  During installed VM qualification of the delivered file, the maintainer found the border thinner and the text
  slightly larger than Omarchy's. Omarchy 4's lock is Quickshell QML (`LockView.qml`), so its 3 px border and 18 px
  text are logical pixels (about 5 px and 29 px at scale 1.6). T7 showed that hyprlock `0.9.6` ignores a Pango
  `size` attribute in the placeholder; T8 showed that a lower field reduces the text.
- **User Response**: "3. cómo hace Omarchy?", then "me vale" after T6; after T8, "yes".
- **Decision**: Field `31.5%, 8.4%`, 5 px border in the theme accent, no rounding, fill of the theme background at
  80%, placeholder `Enter Password` in the theme foreground at 60% opacity.
- **Status**: Accepted

## DEC-010
- **Question**: How should failed authentication be shown?
- **Context/Nuances**: `pam_faillock` locks the account for 10 minutes after three failures; then even the correct
  password fails. With `$PAMFAIL ($ATTEMPTS)`, the message became long and confusing, and the default fail timeout
  was too short to read. A generic message would hide the lockout. In hyprlock `0.9.6`, `fail_timeout` is a
  `general` option.
- **User Response**: "si, el tiempo de error es muy rápido y no da tiempo a verlo"; T6 accepted.
- **Decision**: `fail_text = <i>$PAMFAIL</i>` without an attempt counter and `general:fail_timeout = 5000`. The
  system faillock policy is unchanged.
- **Status**: Accepted

## DEC-011
- **Question**: Where do the lock colors come from?
- **Context/Nuances**: The maintainer's theme direction is to use the shared `current/theme` link so consumers do not
  embed a theme name; trusted-path resolution is required for executable Lua, while Foot follows the link directly.
  hyprlock configuration is not Lua, but may run commands through label `cmd[]`, like Foot's command settings; the
  user's own `hyprlock.conf` is already user-writable. Guest test T2 showed that a missing sourced file is logged and
  the lock still starts with variables defined before the `source` line. A product-path alternative was proposed and
  withdrawn after the maintainer recalled the link decision.
- **User Response**: "2. yes" (colors from the theme); "adelante" after the correction.
- **Decision**: Each theme publishes a `hyprlock.conf` with color variables. The managed user `hyprlock.conf`
  defines literal fallbacks first and then sources `~/.local/state/mirroros/current/theme/hyprlock.conf`, following
  the link like Foot, with the same default-state-path limitation.
- **Status**: Accepted

## DEC-012
- **Question**: Should the lock field follow the Hyprland monitor scale?
- **Context/Nuances**: After changing the VM to 2383x1261 at scale 1, the maintainer saw an unchanged lock, while
  Omarchy's lock follows the scale. hyprlock `0.9.6` lays out every widget in the lock surface's pixel buffer
  (logical size times scale): percentages follow the physical resolution, pixel values and `outline_thickness` are
  physical, and the text size follows the physical field height, so no hyprlock value follows the scale. Hyprlang
  `0.6.8` does not substitute environment variables in values, and `source` expands only `~` and globs. The DEC-009
  values were calibrated only at 1920x1080 and scale 1.6. Alternatives: document the limitation; generate the
  field geometry from the scale when locking; or a custom QML lock (architecture change, new ADR).
- **User Response**: "2" (generate the geometry when locking).
- **Decision**: Amends the DEC-009 geometry. The field is 378x57 logical pixels with a 3 logical-pixel border, the
  DEC-009 result at scale 1.6. `lock-screen` reads the focused monitor's scale from `hyprctl monitors -j` before
  starting hyprlock and replaces `~/.cache/mirroros/lock/geometry.conf` with `$field_size` and `$field_border` in
  physical pixels, rounded. The managed `hyprlock.conf` defines the DEC-009 values as fallbacks and sources that
  file after the theme. When the scale cannot be read the file is removed, so the fallbacks apply; locking never
  depends on it. With several outputs at different scales, the focused output's scale applies to all of them.
- **Status**: Accepted
