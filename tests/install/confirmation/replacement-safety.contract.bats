# Ephemeral approval binding only; no discovery, engine, credentials or disk operations.
# shellcheck disable=SC1091,SC2034,SC2329 # Flow library consumes shared state and provider doubles.
setup() {
  SOURCE_ROOT="$(cd -- "${BATS_TEST_DIRNAME}/../../.." && pwd -P)"
  source "${SOURCE_ROOT}/install/confirmation/lib/flow.sh"
  FLOW_FACTS_FINAL=synthetic-final FLOW_FACTS_INITIAL=synthetic-initial FLOW_RUN_DIR=$BATS_TEST_TMPDIR
  CALLS="${BATS_TEST_TMPDIR}/calls"
  : > "$CALLS"
  declare -gA FLOW_REVIEW=([plan_digest]=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa)
  CURRENT_DIGEST=${FLOW_REVIEW[plan_digest]}
  flow_log() { :; }
  flow_reached() { :; }
  flow_run_discovery() { printf 'discover\n' >> "$CALLS"; }
  flow_compare() { printf 'compare\n' >> "$CALLS"; }
  flow_plan_field() { FLOW_FIELD=$CURRENT_DIGEST; }
  flow_finish_standard() { printf '%s\n' "$*" >> "$CALLS"; exit "$1"; }
  timing_end() { :; }
  gum() { :; }
}

@test "replacement approval captures the full displayed plan digest and accepts only an unchanged plan" {
  flow_confirmed
  [ "$FLOW_CONFIRMED" = true ]
  [ "$FLOW_CONFIRMED_DIGEST" = "${FLOW_REVIEW[plan_digest]}" ]
  run flow_revalidate
  [ "$status" -eq 0 ]
  grep -qxF discover "$CALLS"
  grep -qxF compare "$CALLS"
}

@test "a changed plan with a recomputed digest cannot reuse the displayed approval" {
  flow_confirmed
  CURRENT_DIGEST=bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
  run flow_revalidate
  [ "$status" -eq 2 ]
  grep -qxF '2 invalidated digest_recheck digest_mismatch' "$CALLS"
}
