#!/usr/bin/bash
# shellcheck disable=SC2034 # State variables are shared across the frontend libraries sourced by run.
# Frontend contract check: contract points C1 to C10. Non-production, mock data only.
#
# Each fe_point_* function records one class: pass, pass-with-wrapper, or fail. A wrapper is listed
# only when the native Gum behavior measured by the point does not already satisfy the contract, so
# every listed wrapper is a mandatory constraint for ADR 0004. Attended points (C1, C7) record the
# maintainer's verdict next to the automated checks.

FE_SCENARIO=''
FE_LAST_STATUS=0
FE_LAST_TS=''
FE_KEPT=()

# Arguments: source file, destination name in the evidence directory.
fe_keep() {
  local src="$1"
  local dest="$2"

  [[ -f "$src" ]] || return 0
  install -m 600 -- "$src" "${EVIDENCE_RUN_DIR}/${dest}" && FE_KEPT+=("$dest")
}

# Runs a scenario in a pty. Arguments: case name, environment words, scenario arguments (a shell
# fragment, so it may carry redirections), then the keys to send.
fe_case() {
  local name="$1"
  local env_words="$2"
  local args="$3"
  local command

  shift 3
  FE_LAST_TS="${BUILD_RUN_DIR}/${name}.typescript"
  printf -v command 'bash %q %s' "$FE_SCENARIO" "$args"
  FE_LAST_STATUS=0
  fe_pty_run "$FE_LAST_TS" "$env_words" "$command" "$@" || FE_LAST_STATUS=$?
  fe_keep "$FE_LAST_TS" "transcript-${name}.typescript"
}

# Runs a scenario with no pty and no controlling terminal at all. Arguments: case name, scenario
# arguments (shell fragment). Output goes to a file; the status is in FE_LAST_STATUS.
fe_direct() {
  local name="$1"
  local args="$2"
  local command

  FE_LAST_TS="${BUILD_RUN_DIR}/${name}.txt"
  printf -v command 'bash %q %s' "$FE_SCENARIO" "$args"
  FE_LAST_STATUS=0
  env -u NO_COLOR setsid -w timeout 20 bash -c "$command" < /dev/null > "$FE_LAST_TS" 2>&1 || FE_LAST_STATUS=$?
  fe_keep "$FE_LAST_TS" "output-${name}.txt"
}

# Runs a scenario under script(1) attached to the real terminal, for the attended points.
# Arguments: case name, scenario name. The status is in FE_LAST_STATUS.
fe_attended_run() {
  local name="$1"
  local scenario="$2"
  local command

  FE_LAST_TS="${BUILD_RUN_DIR}/${name}.typescript"
  printf -v command 'bash %q %s' "$FE_SCENARIO" "$scenario"
  FE_LAST_STATUS=0
  script -qefc "$command" "$FE_LAST_TS" || FE_LAST_STATUS=$?
  fe_keep "$FE_LAST_TS" "transcript-${name}.typescript"
}

# Prints how many of the six review steps appear in the transcript.
fe_steps_seen() {
  local step
  local seen=0

  for step in 1 2 3 4 5 6; do
    if fe_has "$1" "Step ${step}/6"; then
      seen=$((seen + 1))
    fi
  done
  printf '%s' "$seen"
}

fe_point_c1() {
  local ok=yes
  local seen
  local answer
  local detail
  local extra
  local flow_status

  printf '\n%s\n' 'C1 (attended): the six-step plan review flow, with a transcript.'
  printf '%s\n' \
    'Walk the flow to the end: read the target, defaults, and destructive lines, open the pager' \
    '("Inspect the complete plan", scroll, quit with q), continue, and answer the confirmation.' \
    'Judge whether the six steps are clear, the destructive lines stand out, and cancelling is possible.'
  while :; do
    read -r -p 'Press Enter to start C1: ' answer || return 1
    fe_attended_run c1-review review
    seen="$(fe_steps_seen "$FE_LAST_TS")"
    [[ "$seen" -eq 6 ]] && break
    read -r -p "Only ${seen} of 6 steps were reached. Repeat the walkthrough? [y/N] " answer || break
    [[ "$answer" == [yY]* ]] || break
  done
  flow_status="$FE_LAST_STATUS"
  fe_ask_verdict C1 || return 1
  [[ "$FE_VERDICT" == pass ]] || ok=no
  [[ "$seen" -eq 6 ]] || ok=no
  fe_has "$FE_LAST_TS" 'DESTRUCTIVE:' || ok=no
  fe_has "$FE_LAST_TS" "$MOCK_REVIEW_PROMPT" || ok=no
  detail="steps seen ${seen}/6, flow status ${flow_status}, verdict ${FE_VERDICT}"
  extra="$(jq -nc --arg verdict "$FE_VERDICT" --arg note "$FE_NOTE" --argjson steps "$seen" \
    '{attended: {verdict: $verdict, note: $note}, steps_seen: $steps}')"
  fe_record C1 "$(fe_class "$ok" yes)" 'tty_precheck,confirm_status_map' \
    "$flow_status" "$detail" "$extra"
}

fe_point_c7() {
  local ok=yes
  local answer
  local detail
  local extra

  printf '\n%s\n' 'C7 (attended): visual rendering on this surface.'
  printf '%s\n' \
    'Check that borders, colors, spinner glyphs, and the bold destructive line render legibly,' \
    'with no replacement characters or missing glyphs. The spinners run for about six seconds.'
  read -r -p 'Press Enter to start C7: ' answer || return 1
  fe_attended_run c7-visual visual
  fe_ask_verdict C7 || return 1
  [[ "$FE_VERDICT" == pass ]] || ok=no
  [[ "$FE_LAST_STATUS" -eq 0 ]] || ok=no
  detail="scenario status ${FE_LAST_STATUS}, TERM ${FE_TERM}, verdict ${FE_VERDICT}"
  extra="$(jq -nc --arg verdict "$FE_VERDICT" --arg note "$FE_NOTE" '{attended: {verdict: $verdict, note: $note}}')"
  fe_record C7 "$(fe_class "$ok" no)" '' "$FE_LAST_STATUS" "$detail" "$extra"
}

fe_point_c2() {
  local ok=yes
  local entry
  local name
  local key
  local wrapped=no
  local observed
  local -A st=()
  local -A native=()

  for entry in 'yes:y' 'no:n' 'esc:\033' 'enter:\r' 'ctrlc:\003'; do
    name="${entry%%:*}"
    key="${entry#*:}"
    fe_case "c2-${name}" '' confirm "$key"
    st[$name]="$FE_LAST_STATUS"
    native[$name]="$(fe_marker "$FE_LAST_TS" FE_NATIVE)"
  done
  [[ "${st[yes]}" == 0 && "${st[no]}" == 3 && "${st[esc]}" == 3 && "${st[enter]}" == 3 ]] || ok=no
  [[ "${st[ctrlc]}" != 0 ]] || ok=no
  [[ "${native[no]}" == 3 ]] || wrapped=yes
  observed="$(jq -nc --argjson yes "${st[yes]}" --argjson no "${st[no]}" --argjson esc "${st[esc]}" \
    --argjson enter "${st[enter]}" --argjson ctrl_c "${st[ctrlc]}" \
    '{yes: $yes, no: $no, esc: $esc, enter_on_default: $enter, ctrl_c_recorded_only: $ctrl_c}')"
  fe_record C2 "$(fe_class "$ok" "$wrapped")" 'confirm_status_map' "$observed" \
    "native decline status ${native[no]:-none}, native Esc status ${native[esc]:-none}; default focus is No; Ctrl+C ${st[ctrlc]} not remapped"
}

fe_point_c3() {
  local ok=yes
  local wrapped=no
  local native_status=0
  local stdout_file="${BUILD_RUN_DIR}/c3-stdout-redirect.txt"
  local quoted
  local -A st=()

  setsid -w timeout 10 gum confirm 'native probe' < /dev/null > /dev/null 2>&1 || native_status=$?
  [[ "$native_status" -eq 2 ]] || wrapped=yes

  fe_direct c3-no-pty 'confirm'
  st[no_pty]="$FE_LAST_STATUS"
  fe_has "$FE_LAST_TS" 'FE_CONFIRMED=1' && ok=no
  fe_direct c3-no-pty-flags 'confirm --yes --non-interactive'
  st[no_pty_flags]="$FE_LAST_STATUS"
  fe_has "$FE_LAST_TS" 'FE_CONFIRMED=1' && ok=no
  fe_case c3-stdin-redirected '' 'confirm < /dev/null' y
  st[stdin_redirected]="$FE_LAST_STATUS"
  fe_has "$FE_LAST_TS" 'FE_CONFIRMED=1' && ok=no
  printf -v quoted '%q' "$stdout_file"
  fe_case c3-stdout-redirected '' "confirm > ${quoted}" y
  st[stdout_redirected]="$FE_LAST_STATUS"
  if [[ -f "$stdout_file" ]] && fe_has "$stdout_file" 'FE_CONFIRMED=1'; then
    ok=no
  fi
  rm -f -- "$stdout_file"
  fe_case c3-flags-with-tty '' 'confirm --yes --non-interactive' n
  st[flags_with_tty]="$FE_LAST_STATUS"
  fe_has "$FE_LAST_TS" 'No, cancel' || ok=no

  [[ "${st[no_pty]}" == 2 && "${st[no_pty_flags]}" == 2 && "${st[stdin_redirected]}" == 2 \
    && "${st[stdout_redirected]}" == 2 && "${st[flags_with_tty]}" == 3 ]] || ok=no
  fe_record C3 "$(fe_class "$ok" "$wrapped")" 'tty_precheck' \
    "$(jq -nc --argjson a "${st[no_pty]}" --argjson b "${st[no_pty_flags]}" --argjson c "${st[stdin_redirected]}" \
      --argjson d "${st[stdout_redirected]}" --argjson e "${st[flags_with_tty]}" \
      '{no_pty: $a, no_pty_with_flags: $b, stdin_redirected: $c, stdout_redirected: $d, flags_with_tty_declined: $e}')" \
    "native gum confirm without a terminal returns ${native_status}; flags never confirm and still prompt with a terminal"
}

fe_point_c4() {
  local ok=yes
  local samples="${BUILD_RUN_DIR}/c4-samples.txt"
  local control="${BUILD_RUN_DIR}/c4-control"
  local status=0
  local mask=no
  local sampled=no
  local control_clean=no
  local control_planted=no
  local planted_status=0
  local detail

  : > "$samples"
  fe_sampler_start "$samples"
  fe_case c4-secrets '' secrets "$PROTO_USER_PASSWORD" '\r' "$PROTO_ROOT_PASSWORD" '\r'
  fe_sampler_stop
  status="$FE_LAST_STATUS"
  [[ "$status" -eq 0 ]] || ok=no

  if [[ -f "$FE_SECRET_OUT" ]]; then
    [[ "$(sed -n 1p "$FE_SECRET_OUT")" == "$PROTO_USER_PASSWORD" \
      && "$(sed -n 2p "$FE_SECRET_OUT")" == "$PROTO_ROOT_PASSWORD" ]] || ok=no
    rm -f -- "$FE_SECRET_OUT"
  else
    ok=no
  fi

  proto_secrets_canary_search "$FE_LAST_TS" || ok=no
  proto_secrets_canary_search "$samples" || ok=no
  proto_secrets_canary_search "$FLOW_LOG" || ok=no
  grep -aqF 'gum input --password' "$samples" && sampled=yes
  [[ "$sampled" == yes ]] || ok=no
  fe_has "$FE_LAST_TS" $'\xe2\x80\xa2' && mask=yes

  # Negative control: the search must return 0 on a clean directory and 1 on a planted canary.
  mkdir -m 700 -- "$control" "${control}/clean" "${control}/planted"
  printf '%s\n' 'no secret here' > "${control}/clean/file"
  printf '%s\n' "$PROTO_USER_PASSWORD" > "${control}/planted/file"
  proto_secrets_canary_search "${control}/clean" && control_clean=yes
  proto_secrets_canary_search "${control}/planted" || planted_status=$?
  [[ "$planted_status" -ne 1 ]] || control_planted=yes
  rm -rf -- "$control"
  [[ "$control_clean" == yes && "$control_planted" == yes ]] || ok=no

  grep -aE '(^| )gum |script -q|scenario\.sh' "$samples" | sort -u > "${BUILD_RUN_DIR}/c4-cmdline.txt"
  fe_keep "${BUILD_RUN_DIR}/c4-cmdline.txt" c4-cmdline.txt
  detail="mask glyph seen ${mask}, command-line sampler saw gum ${sampled}, negative control clean ${control_clean} planted ${control_planted}"
  fe_record C4 "$(fe_class "$ok" no)" '' "$status" "$detail"
}

fe_point_c5() {
  local ok=yes
  local wrapped=no
  local off_status
  local off_colors
  local on_colors
  local cue

  fe_case c5-no-color 'NO_COLOR=1' styled n '\r'
  off_status="$FE_LAST_STATUS"
  off_colors="$(fe_color_count "$FE_LAST_TS")"
  [[ "$off_status" -eq 3 && "$off_colors" -eq 0 ]] || ok=no
  fe_has "$FE_LAST_TS" 'DESTRUCTIVE:' || ok=no
  fe_has "$FE_LAST_TS" '> No, cancel' || ok=no
  fe_case c5-color-control '' styled n '\r'
  on_colors="$(fe_color_count "$FE_LAST_TS")"
  [[ "$on_colors" -gt 0 ]] || ok=no
  fe_case c5-native-confirm 'NO_COLOR=1' native-confirm n '\r'
  cue="$(fe_native_focus_cue "$FE_LAST_TS")"
  [[ "$cue" == yes ]] || wrapped=yes
  fe_record C5 "$(fe_class "$ok" "$wrapped")" 'colorless_confirm' "$off_status" \
    "NO_COLOR color lines ${off_colors} (colored control ${on_colors}); native gum confirm focus cue without color: ${cue}"
}

fe_point_c6() {
  local ok=yes
  local status
  local colors

  fe_case c6-dumb 'TERM=dumb' styled n '\r'
  status="$FE_LAST_STATUS"
  colors="$(fe_color_count "$FE_LAST_TS")"
  [[ "$status" -eq 3 ]] || ok=no
  fe_has "$FE_LAST_TS" 'DESTRUCTIVE:' || ok=no
  fe_has "$FE_LAST_TS" 'Step 3/6' || ok=no
  fe_has "$FE_LAST_TS" '> No, cancel' || ok=no
  fe_record C6 "$(fe_class "$ok" yes)" 'colorless_confirm' "$status" \
    "TERM=dumb degrades to the text-cursor confirmation; destructive marker and steps present; color lines ${colors}"
}

fe_point_c8() {
  local ok=yes
  local wrapped=no
  local ok_status
  local fail_status
  local native_status
  local plain_status
  local title='Stage 1/1: Applying the mock partition layout'

  fe_case c8-ok '' stage-ok
  ok_status="$FE_LAST_STATUS"
  [[ "$ok_status" -eq 0 ]] || ok=no
  fe_has "$FE_LAST_TS" "$title" || ok=no
  fe_case c8-fail '' stage-fail
  fail_status="$FE_LAST_STATUS"
  [[ "$fail_status" -eq 5 ]] || ok=no
  fe_has "$FE_LAST_TS" "$title" || ok=no
  fe_has "$FE_LAST_TS" 'Stage failed:' || ok=no
  fe_has "$FE_LAST_TS" 'Reason:' || ok=no
  fe_has "$FE_LAST_TS" 'Next action:' || ok=no
  fe_has "$FE_LAST_TS" 'status 7' || ok=no
  grep -qF 'original_status=7' "$FLOW_LOG" || ok=no
  fe_case c8-native '' native-spin
  native_status="$FE_LAST_STATUS"
  [[ "$native_status" -eq 7 ]] || ok=no
  fe_direct c8-plain 'stage-fail'
  plain_status="$FE_LAST_STATUS"
  [[ "$plain_status" -eq 5 ]] || ok=no
  fe_has "$FE_LAST_TS" "Stage: ${title}" || ok=no
  [[ "$(LC_ALL=C grep -acP '\x1b' "$FE_LAST_TS" || true)" -eq 0 ]] || ok=no
  [[ "$native_status" -eq 5 ]] || wrapped=yes
  fe_record C8 "$(fe_class "$ok" "$wrapped")" 'stage_status_normalization,spin_plain_fallback' \
    "$(jq -nc --argjson ok "$ok_status" --argjson fail "$fail_status" --argjson native "$native_status" \
      --argjson plain "$plain_status" '{success: $ok, failure: $fail, native_child_status_preserved: $native, failure_without_tty: $plain}')" \
    "native gum spin preserves the child status (${native_status}); the flow normalizes it to 5 and records the original"
}

fe_point_c9() {
  local ok=yes
  local native_emits=no
  local out="${BUILD_RUN_DIR}/c9-stdout-redirect.txt"
  local quoted
  local text="$FLOW_HEADER_TEXT"

  fe_case c9-tty '' header
  fe_has "$FE_LAST_TS" "$text" || ok=no
  fe_has "$FE_LAST_TS" 'FE_HEADER_DONE' || ok=no
  fe_case c9-stdin-redirected '' 'header < /dev/null'
  fe_has "$FE_LAST_TS" "$text" && ok=no
  fe_has "$FE_LAST_TS" 'FE_HEADER_DONE' || ok=no
  printf -v quoted '%q' "$out"
  fe_case c9-stdout-redirected '' "header > ${quoted}"
  if [[ -f "$out" ]]; then
    fe_has "$out" "$text" && ok=no
    fe_has "$out" 'FE_HEADER_DONE' || ok=no
  else
    ok=no
  fi
  rm -f -- "$out"
  fe_case c9-non-interactive-flag '' 'header --non-interactive'
  fe_has "$FE_LAST_TS" "$text" && ok=no
  fe_has "$FE_LAST_TS" 'FE_HEADER_DONE' || ok=no
  fe_direct c9-no-pty 'header'
  fe_has "$FE_LAST_TS" "$text" && ok=no
  fe_has "$FE_LAST_TS" 'FE_HEADER_DONE' || ok=no
  if grep -qF -- "$text" "$FLOW_LOG"; then
    ok=no
  fi
  if gum style --border rounded "$text" < /dev/null 2> /dev/null | grep -qF -- "$text"; then
    native_emits=yes
  fi
  fe_record C9 "$(fe_class "$ok" "$native_emits")" 'tty_gate' 'null' \
    "header present only with a terminal and without the flag; absent with stdin or stdout redirected, in non-interactive mode, and in the log; native gum style prints it without a terminal: ${native_emits}"
}

fe_point_c10() {
  local ok=yes
  local escapes
  local lines

  [[ -s "$FLOW_LOG" ]] || ok=no
  escapes="$(LC_ALL=C grep -acP '\x1b' "$FLOW_LOG" || true)"
  [[ "$escapes" -eq 0 ]] || ok=no
  proto_secrets_canary_search "$FLOW_LOG" || ok=no
  lines="$(wc -l < "$FLOW_LOG")"
  fe_record C10 "$(fe_class "$ok" no)" '' 'null' \
    "persistent log has ${lines} plain-text lines, ${escapes} lines with ANSI, no canary, no styled header"
}
