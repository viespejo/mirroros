#!/usr/bin/bash

CONTAINER_IMAGE_TAG='docker.io/archlinux/archlinux:latest'
CONTAINER_IMAGE_DIGEST=''
CONTAINER_IMAGE_REFERENCE=''
CONTAINER_ARCHISO_VERSION=''
CONTAINER_EXPECTED_ARCHISO_VERSION=''
CONTAINER_NAME=''
CONTAINER_ID=''
CONTAINER_ISO_PATH=''
CONTAINER_ISO_NAME=''
CONTAINER_CREATE_ATTEMPTED=0
CONTAINER_STOP_VERIFIED=0
CONTAINER_CAPTURE_OUTPUT=''
CONTAINER_FAILURE_STATUS=0
CONTAINER_LOGS_DIR=''
CONTAINER_CONFIG_IDENTITY=''
CONTAINER_CONFIG_ISSUER=''
CONTAINER_TIMEOUT_PULL=600
CONTAINER_TIMEOUT_COSIGN=600
CONTAINER_TIMEOUT_PREPARE=1800
CONTAINER_TIMEOUT_BUILD=7200
CONTAINER_TIMEOUT_EXTRACTION=1800
CONTAINER_TIMEOUT_EXPORT=900
CONTAINER_TIMEOUT_DOCKER=120

container_validate_checkout() {
  local config_path="${BUILDER_DIR}/arch-image-signature.conf"
  local upstream_path="${REPOSITORY_ROOT}/image/archiso/UPSTREAM.md"
  local version_records
  local version_count

  if [[ ! -r "$config_path" || ! -r "$upstream_path" ]]; then
    printf '%s\n' 'MirrorOS build: image signature configuration or Archiso upstream record is missing.' >&2
    return 6
  fi
  if ! /usr/bin/bash -n "$config_path" >/dev/null 2>&1; then
    printf 'MirrorOS build: damaged image signature configuration: %s\n' "$config_path" >&2
    return 6
  fi
  # shellcheck disable=SC1090 # Signature settings are resolved relative to the builder.
  source "$config_path"
  CONTAINER_CONFIG_IDENTITY="${ARCH_CI_IDENTITY_REGEXP:-}"
  CONTAINER_CONFIG_ISSUER="${ARCH_CI_ISSUER:-}"
  if [[ -z "$CONTAINER_CONFIG_IDENTITY" || -z "$CONTAINER_CONFIG_ISSUER" ]]; then
    printf 'MirrorOS build: incomplete image signature configuration: %s\n' "$config_path" >&2
    return 6
  fi

  version_records="$(awk -F'`' '/^- \*\*Package version:\*\*/ { print $2 }' "$upstream_path")" || {
    printf 'MirrorOS build: could not read the Archiso version in %s.\n' "$upstream_path" >&2
    return 2
  }
  version_count="$(printf '%s\n' "$version_records" | awk 'NF { count++ } END { print count + 0 }')"
  if [[ "$version_count" -ne 1 || -z "$version_records" ]]; then
    printf 'MirrorOS build: expected exactly one Archiso package version in %s.\n' "$upstream_path" >&2
    return 2
  fi
  CONTAINER_EXPECTED_ARCHISO_VERSION="$version_records"
}

container_initialize() {
  local status

  if container_validate_checkout; then
    :
  else
    status=$?
    return "$status"
  fi
  CONTAINER_NAME="mirroros-archiso-build-${RUN_ID}"
  CONTAINER_LOGS_DIR="${EVIDENCE_RUN_DIR}/logs"
  if ! mkdir -m 700 -- "$CONTAINER_LOGS_DIR"; then
    printf 'MirrorOS build: could not create private stage log directory: %s\n' "$CONTAINER_LOGS_DIR" >&2
    return 5
  fi
}

container_stage_header() {
  local stage="$1"
  local log_path="${CONTAINER_LOGS_DIR}/${stage}.log"

  printf '\n== Stage: %s ==\n' "$stage" | tee -a "$log_path"
  chmod 600 -- "$log_path"
}

container_run_stage() {
  local stage="$1"
  local timeout_seconds="$2"
  shift 2
  local log_path="${CONTAINER_LOGS_DIR}/${stage}.log"
  local child_status
  local tee_status
  local kill_after=60s
  local had_errexit=0
  local -a pipeline_status=()

  container_stage_header "$stage" || return 5
  [[ "$stage" == 'container-stop' ]] && kill_after=1s
  [[ "$-" == *e* ]] && had_errexit=1
  set +e
  timeout --signal=TERM --kill-after="$kill_after" "${timeout_seconds}s" "$@" 2>&1 | tee -a "$log_path"
  pipeline_status=("${PIPESTATUS[@]}")
  (( had_errexit == 1 )) && set -e
  child_status="${pipeline_status[0]:-5}"
  tee_status="${pipeline_status[1]:-5}"
  chmod 600 -- "$log_path" || return 5
  build_outcome_record_tool_status "$stage" "$child_status"
  build_outcome_add_diagnostic "logs/${stage}.log"
  if [[ "$child_status" -ne 0 ]]; then
    return "$child_status"
  fi
  if [[ "$tee_status" -ne 0 ]]; then
    return "$tee_status"
  fi
}

container_run_capture_stage() {
  local stage="$1"
  local timeout_seconds="$2"
  shift 2
  local log_path="${CONTAINER_LOGS_DIR}/${stage}.log"
  local capture_path="${BUILD_RUN_DIR}/.${stage}.output.$$.tmp"
  local command_status

  container_stage_header "$stage" || return 5
  if timeout --signal=TERM --kill-after=60s "${timeout_seconds}s" "$@" > "$capture_path" 2>&1; then
    command_status=0
  else
    command_status=$?
  fi
  chmod 600 -- "$capture_path" || {
    rm -f -- "$capture_path"
    return 5
  }
  if ! tee -a "$log_path" < "$capture_path"; then
    rm -f -- "$capture_path"
    return 5
  fi
  CONTAINER_CAPTURE_OUTPUT="$(<"$capture_path")"
  rm -f -- "$capture_path"
  chmod 600 -- "$log_path" || return 5
  build_outcome_record_tool_status "$stage" "$command_status"
  build_outcome_add_diagnostic "logs/${stage}.log"
  return "$command_status"
}

container_set_failure() {
  local stage="$1"
  local normalized_status="$2"
  local original_status="${3:-}"

  CONTAINER_FAILURE_STATUS="$normalized_status"
  build_outcome_mark_failure "$normalized_status" "$stage" "$original_status"
}

container_verify_image() {
  local digest_output
  local repository_digest
  local digest
  local status
  local -a digest_matches=()

  if container_run_stage image-pull "$CONTAINER_TIMEOUT_PULL" \
    docker pull --platform=linux/amd64 "$CONTAINER_IMAGE_TAG"; then
    :
  else
    status=$?
    container_set_failure image-pull 5 "$status"
    return 5
  fi

  if container_run_capture_stage image-digest "$CONTAINER_TIMEOUT_DOCKER" \
    docker image inspect --format '{{range .RepoDigests}}{{println .}}{{end}}' "$CONTAINER_IMAGE_TAG"; then
    digest_output="$CONTAINER_CAPTURE_OUTPUT"
  else
    status=$?
    container_set_failure image-digest 5 "$status"
    return 5
  fi

  while IFS= read -r repository_digest; do
    case "$repository_digest" in
      docker.io/archlinux/archlinux@sha256:*|archlinux/archlinux@sha256:*)
        digest="${repository_digest#*@sha256:}"
        ;;
      *)
        continue
        ;;
    esac
    [[ "$digest" =~ ^[a-f0-9]{64}$ ]] || continue
    digest_matches+=("$digest")
  done <<< "$digest_output"
  if [[ "${#digest_matches[@]}" -ne 1 ]]; then
    printf 'MirrorOS build: expected exactly one %s digest; found %s.\n' \
      "$CONTAINER_IMAGE_TAG" "${#digest_matches[@]}" >&2
    container_set_failure image-digest 2 0
    return 2
  fi
  CONTAINER_IMAGE_DIGEST="sha256:${digest_matches[0]}"
  CONTAINER_IMAGE_REFERENCE="docker.io/archlinux/archlinux@${CONTAINER_IMAGE_DIGEST}"

  if container_run_stage image-signature-verification "$CONTAINER_TIMEOUT_COSIGN" \
    cosign verify \
      --certificate-identity-regexp "$CONTAINER_CONFIG_IDENTITY" \
      --certificate-oidc-issuer "$CONTAINER_CONFIG_ISSUER" \
      "$CONTAINER_IMAGE_REFERENCE"; then
    build_outcome_set_validation signature_verification passed
  else
    status=$?
    build_outcome_set_validation signature_verification failed
    if [[ "$status" -eq 124 || "$status" -eq 137 ]]; then
      container_set_failure image-signature-verification 5 "$status"
      return 5
    fi
    printf '%s\n' \
      'MirrorOS build: Cosign rejected the resolved Arch image digest; construction stopped before container creation.' \
      'Check the official Arch identity and issuer in image/builder/arch-image-signature.conf before retrying.' >&2
    container_set_failure image-signature-verification 2 "$status"
    return 2
  fi
}

container_create() {
  local status
  local identity_path="${EVIDENCE_RUN_DIR}/container-identity.json"
  local -a create_arguments=(
    docker create
    --privileged
    --platform=linux/amd64
    --name "$CONTAINER_NAME"
    --label org.mirroros.stage=build
    --label "org.mirroros.run-id=${RUN_ID}"
    --mount "type=bind,source=${SOURCE_CAPTURE_PROFILE_PATH},target=/profile,readonly"
  )

  if [[ "$BUILD_NO_CACHE" -eq 0 ]]; then
    create_arguments+=(--mount 'type=volume,source=mirroros-pacman-cache,target=/var/cache/pacman/pkg')
  fi
  create_arguments+=("$CONTAINER_IMAGE_REFERENCE" sleep infinity)
  CONTAINER_CREATE_ATTEMPTED=1
  if container_run_capture_stage container-create "$CONTAINER_TIMEOUT_DOCKER" "${create_arguments[@]}"; then
    :
  else
    status=$?
    container_set_failure container-create 5 "$status"
    return 5
  fi
  CONTAINER_ID="${CONTAINER_CAPTURE_OUTPUT//$'\r'/}"
  CONTAINER_ID="${CONTAINER_ID//$'\n'/}"
  if [[ ! "$CONTAINER_ID" =~ ^[a-f0-9]{64}$ ]]; then
    printf '%s\n' 'MirrorOS build: Docker returned an invalid container ID; leaving the named resource for manual recovery.' >&2
    build_outcome_add_leftover "container-name:${CONTAINER_NAME}"
    container_set_failure container-create 5 0
    return 5
  fi

  printf '{\n  "container_id": "%s",\n  "name": "%s",\n  "labels": {\n    "org.mirroros.stage": "build",\n    "org.mirroros.run-id": "%s"\n  }\n}\n' \
    "$CONTAINER_ID" "$CONTAINER_NAME" "$RUN_ID" > "$identity_path" || {
      container_set_failure container-identity 5 ''
      return 5
    }
  chmod 600 -- "$identity_path" || {
    container_set_failure container-identity 5 ''
    return 5
  }
  build_outcome_add_diagnostic 'container-identity.json'
}

container_check_expected_version() {
  local actual
  local status

  if container_run_capture_stage archiso-version "$CONTAINER_TIMEOUT_DOCKER" \
    docker exec "$CONTAINER_ID" pacman -Q archiso; then
    actual="${CONTAINER_CAPTURE_OUTPUT//$'\r'/}"
  else
    status=$?
    build_outcome_set_validation archiso_version failed
    container_set_failure archiso-version 5 "$status"
    return 5
  fi
  CONTAINER_ARCHISO_VERSION="${actual#archiso }"
  if [[ "$actual" != "archiso ${CONTAINER_EXPECTED_ARCHISO_VERSION}" ]]; then
    printf 'MirrorOS build: installed Archiso version %q does not match profile version %q.\n' \
      "$CONTAINER_ARCHISO_VERSION" "$CONTAINER_EXPECTED_ARCHISO_VERSION" >&2
    printf '%s\n' 'No ISO was produced. Review docs/procedures/update-archiso.md and update the imported profile explicitly.' >&2
    build_outcome_set_validation archiso_version failed
    container_set_failure archiso-version 2 0
    return 2
  fi
  build_outcome_set_validation archiso_version passed
}

container_find_iso() {
  local status
  local -a candidates=()

  if container_run_capture_stage iso-discovery "$CONTAINER_TIMEOUT_DOCKER" \
    docker exec "$CONTAINER_ID" find /out -maxdepth 1 -type f -name '*.iso' -print; then
    :
  else
    status=$?
    container_set_failure iso-discovery 5 "$status"
    return 5
  fi
  while IFS= read -r candidate; do
    [[ -n "$candidate" ]] && candidates+=("$candidate")
  done <<< "$CONTAINER_CAPTURE_OUTPUT"
  if [[ "${#candidates[@]}" -ne 1 || "${candidates[0]:-}" != /out/* ]]; then
    printf 'MirrorOS build: expected exactly one ISO in the container output; found %s.\n' "${#candidates[@]}" >&2
    container_set_failure iso-discovery 5 0
    return 5
  fi
  CONTAINER_ISO_PATH="${candidates[0]}"
  CONTAINER_ISO_NAME="${CONTAINER_ISO_PATH##*/}"
  if [[ "$CONTAINER_ISO_NAME" == '.' || "$CONTAINER_ISO_NAME" == '..' || "$CONTAINER_ISO_NAME" != *.iso ]]; then
    printf 'MirrorOS build: invalid ISO output filename: %s\n' "$CONTAINER_ISO_NAME" >&2
    container_set_failure iso-discovery 5 0
    return 5
  fi
}

container_export_outputs() {
  local iso_destination="${BUILD_RUN_DIR}/${CONTAINER_ISO_NAME}"
  local manifest_destination="${BUILD_RUN_DIR}/pkglist.x86_64.txt"
  local mirrorlist_destination="${EVIDENCE_RUN_DIR}/mirrorlist"
  local status
  local expected_owner
  local actual_owner
  local file_path

  expected_owner="$(id -u):$(id -g)"

  if container_run_stage export-iso "$CONTAINER_TIMEOUT_EXPORT" \
    docker cp "${CONTAINER_ID}:${CONTAINER_ISO_PATH}" "$iso_destination"; then
    :
  else
    status=$?
    container_set_failure export-iso 5 "$status"
    return 5
  fi
  if container_run_stage export-package-manifest "$CONTAINER_TIMEOUT_EXPORT" \
    docker cp "${CONTAINER_ID}:/out/pkglist.x86_64.txt" "$manifest_destination"; then
    :
  else
    status=$?
    container_set_failure export-package-manifest 5 "$status"
    return 5
  fi
  if container_run_stage export-mirrorlist "$CONTAINER_TIMEOUT_EXPORT" \
    docker cp "${CONTAINER_ID}:/out/mirrorlist" "$mirrorlist_destination"; then
    :
  else
    status=$?
    container_set_failure export-mirrorlist 5 "$status"
    return 5
  fi

  for file_path in "$iso_destination" "$manifest_destination" "$mirrorlist_destination"; do
    if [[ ! -f "$file_path" || -L "$file_path" || ! -s "$file_path" ]]; then
      printf 'MirrorOS build: exported file is missing, empty, or not regular: %s\n' "$file_path" >&2
      container_set_failure output-verification 5 ''
      return 5
    fi
    actual_owner="$(stat -c '%u:%g' -- "$file_path")" || {
      container_set_failure output-verification 5 ''
      return 5
    }
    if [[ "$actual_owner" != "$expected_owner" ]]; then
      printf 'MirrorOS build: exported file ownership %s does not match invoking user %s: %s\n' \
        "$actual_owner" "$expected_owner" "$file_path" >&2
      container_set_failure output-verification 5 ''
      return 5
    fi
    chmod 600 -- "$file_path" || {
      container_set_failure output-verification 5 ''
      return 5
    }
  done
  CONTAINER_ISO_NAME="${iso_destination##*/}"
}

container_read_state() {
  local status

  if container_run_capture_stage container-state "$CONTAINER_TIMEOUT_DOCKER" \
    docker inspect --format '{{.State.Status}}' "$CONTAINER_ID"; then
    CONTAINER_CAPTURE_OUTPUT="${CONTAINER_CAPTURE_OUTPUT//$'\r'/}"
    CONTAINER_CAPTURE_OUTPUT="${CONTAINER_CAPTURE_OUTPUT//$'\n'/}"
    return 0
  else
    status=$?
    printf 'MirrorOS build: could not verify state of container %s (status %s).\n' "$CONTAINER_ID" "$status" >&2
    return "$status"
  fi
}

container_stop_and_verify() {
  local state
  local status

  if [[ -z "$CONTAINER_ID" ]]; then
    return 0
  fi
  if container_read_state; then
    state="$CONTAINER_CAPTURE_OUTPUT"
  else
    return 1
  fi
  case "$state" in
    running|paused|restarting)
      if container_run_stage container-stop 60 \
        docker stop -t 30 "$CONTAINER_ID"; then
        :
      else
        status=$?
        printf 'MirrorOS build: Docker stop failed for container %s (status %s).\n' "$CONTAINER_ID" "$status" >&2
        return 1
      fi
      if container_read_state; then
        state="$CONTAINER_CAPTURE_OUTPUT"
      else
        return 1
      fi
      ;;
    created|exited)
      ;;
    *)
      printf 'MirrorOS build: refusing to remove container %s with unrecognized state %q.\n' "$CONTAINER_ID" "$state" >&2
      return 1
      ;;
  esac
  if [[ "$state" != 'created' && "$state" != 'exited' ]]; then
    printf 'MirrorOS build: container %s did not reach a verified stopped state (state %q).\n' "$CONTAINER_ID" "$state" >&2
    return 1
  fi
  CONTAINER_STOP_VERIFIED=1
}

container_preserve_diagnostics() {
  local status
  local preserve_status=0
  local report_path="${EVIDENCE_RUN_DIR}/gitleaks-diagnostics.json"

  if [[ -n "$CONTAINER_ID" ]]; then
    if container_run_stage container-logs "$CONTAINER_TIMEOUT_DOCKER" docker logs "$CONTAINER_ID"; then
      :
    else
      status=$?
      printf 'MirrorOS build: could not export container log diagnostics (status %s).\n' "$status" >&2
      build_outcome_record_tool_status container-logs "$status"
      preserve_status=5
    fi
  fi
  if [[ -e "$report_path" || -L "$report_path" ]]; then
    printf 'MirrorOS build: refusing to overwrite existing Gitleaks report: %s\n' "$report_path" >&2
    return 5
  fi
  if gitleaks dir --redact --no-banner --report-format json \
    --report-path "$report_path" "$EVIDENCE_RUN_DIR"; then
    chmod 600 -- "$report_path" || return 5
    build_outcome_set_validation evidence_secret_scan passed
    build_outcome_add_diagnostic 'gitleaks-diagnostics.json'
    [[ "$preserve_status" -eq 0 ]] || return "$preserve_status"
    return 0
  else
    status=$?
  fi
  [[ ! -e "$report_path" ]] || chmod 600 -- "$report_path"
  build_outcome_add_diagnostic 'gitleaks-diagnostics.json'
  build_outcome_record_tool_status evidence-secret-scan "$status"
  if [[ "$status" -eq 1 ]]; then
    build_outcome_set_validation evidence_secret_scan failed
    printf 'MirrorOS build: Gitleaks detected a secret in retained evidence; private logs and redacted report are preserved at %s.\n' \
      "$report_path" >&2
    return 2
  fi
  build_outcome_set_validation evidence_secret_scan failed
  printf 'MirrorOS build: Gitleaks evidence scan failed with original status %s.\n' "$status" >&2
  return 5
}

container_remove_verified() {
  local status

  [[ -n "$CONTAINER_ID" ]] || return 0
  if [[ "$CONTAINER_STOP_VERIFIED" -ne 1 ]]; then
    printf 'MirrorOS build: retaining container %s because its stopped state was not verified.\n' "$CONTAINER_ID" >&2
    build_outcome_add_leftover "container:${CONTAINER_ID}"
    return 1
  fi
  if container_run_stage container-remove "$CONTAINER_TIMEOUT_DOCKER" docker rm "$CONTAINER_ID"; then
    CONTAINER_ID=''
    CONTAINER_CREATE_ATTEMPTED=0
    return 0
  else
    status=$?
    printf 'MirrorOS build: could not remove stopped container %s (status %s).\n' "$CONTAINER_ID" "$status" >&2
    build_outcome_record_tool_status container-remove "$status"
    build_outcome_add_leftover "container:${CONTAINER_ID}"
    return 1
  fi
}

container_cleanup_current() {
  local status=0
  local scan_status=0
  local guidance='Inspect the recorded container identity and state; preserve evidence before authorized manual removal.'

  if [[ -n "$CONTAINER_ID" ]]; then
    if ! container_stop_and_verify; then
      status=1
      build_outcome_add_leftover "container:${CONTAINER_ID}"
      build_outcome_add_leftover "build:${BUILD_RUN_DIR}"
      guidance='Do not remove the active or unverifiable container. Review container-identity.json and run.lock, then preserve permitted diagnostics before authorized recovery.'
    fi
  elif [[ "$CONTAINER_CREATE_ATTEMPTED" -eq 1 ]]; then
    status=1
    build_outcome_add_leftover "container-name:${CONTAINER_NAME}"
    build_outcome_add_leftover "build:${BUILD_RUN_DIR}"
    guidance='Docker creation was attempted but no verified container ID was recorded. Do not adopt or remove a resource by name alone; inspect Docker and preserve evidence manually.'
  fi

  if container_preserve_diagnostics; then
    :
  else
    scan_status=$?
    if [[ "$scan_status" -eq 2 ]]; then
      if [[ "$BUILD_PRIMARY_STATUS" -eq 0 ]]; then
        build_outcome_mark_failure 2 evidence-secret-scan 1
      fi
    else
      if [[ "$status" -eq 0 ]]; then
        status=1
        guidance='Preserve the private evidence and review the Gitleaks result before removing resources.'
      fi
      if [[ "$BUILD_PRIMARY_STATUS" -eq 0 ]]; then
        build_outcome_mark_failure 5 evidence-secret-scan "$scan_status"
      fi
    fi
  fi

  if [[ "$status" -eq 0 && -n "$CONTAINER_ID" ]]; then
    if ! container_remove_verified; then
      status=1
      guidance='Inspect the recorded container identity and state; preserve evidence before authorized manual removal.'
    fi
  elif [[ "$status" -ne 0 && -n "$CONTAINER_ID" && "$CONTAINER_STOP_VERIFIED" -eq 1 ]]; then
    build_outcome_add_leftover "container:${CONTAINER_ID}"
  fi
  if [[ "$status" -eq 0 ]]; then
    build_outcome_mark_cleanup_success
    return 0
  fi
  build_outcome_note_cleanup_failure "$guidance"
  return 1
}

container_construct() {
  local status
  local prep_script='pacman -Syu --noconfirm && pacman -S --needed --noconfirm archiso'
  # shellcheck disable=SC2016 # This script is interpreted inside the container.
  local extraction_script='xorriso -osirrox on -indev "$1" -extract /arch/pkglist.x86_64.txt /out/pkglist.x86_64.txt && cp /etc/pacman.d/mirrorlist /out/mirrorlist'

  if container_initialize; then
    :
  else
    status=$?
    container_set_failure container-initialize "$status" ''
    return "$status"
  fi
  if container_verify_image; then
    :
  else
    return "$CONTAINER_FAILURE_STATUS"
  fi
  if container_create; then
    :
  else
    return "$CONTAINER_FAILURE_STATUS"
  fi

  if container_run_stage container-start "$CONTAINER_TIMEOUT_DOCKER" docker start "$CONTAINER_ID"; then
    :
  else
    status=$?
    container_set_failure container-start 5 "$status"
    return 5
  fi
  if container_run_stage package-preparation "$CONTAINER_TIMEOUT_PREPARE" \
    docker exec "$CONTAINER_ID" bash -Eeuo pipefail -c "$prep_script"; then
    :
  else
    status=$?
    container_set_failure package-preparation 5 "$status"
    return 5
  fi
  if container_check_expected_version; then
    :
  else
    return "$CONTAINER_FAILURE_STATUS"
  fi
  if container_run_stage container-workdirs "$CONTAINER_TIMEOUT_DOCKER" \
    docker exec "$CONTAINER_ID" mkdir -p /work /out; then
    :
  else
    status=$?
    container_set_failure container-workdirs 5 "$status"
    return 5
  fi
  if container_run_stage mkarchiso "$CONTAINER_TIMEOUT_BUILD" \
    docker exec --env "SOURCE_DATE_EPOCH=${BUILD_SOURCE_DATE_EPOCH}" \
      "$CONTAINER_ID" mkarchiso -v -w /work -o /out /profile; then
    :
  else
    status=$?
    container_set_failure mkarchiso 5 "$status"
    return 5
  fi
  if container_find_iso; then
    :
  else
    return "$CONTAINER_FAILURE_STATUS"
  fi
  if container_run_stage output-extraction "$CONTAINER_TIMEOUT_EXTRACTION" \
    docker exec "$CONTAINER_ID" bash -Eeuo pipefail -c \
      "$extraction_script" mirroros-container "$CONTAINER_ISO_PATH"; then
    :
  else
    status=$?
    container_set_failure output-extraction 5 "$status"
    return 5
  fi
  if container_export_outputs; then
    :
  else
    return "$CONTAINER_FAILURE_STATUS"
  fi
  CONTAINER_FAILURE_STATUS=0
}
