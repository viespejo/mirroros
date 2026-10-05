#!/usr/bin/bash

PUBLICATION_CANDIDATE_DIR=''
PUBLICATION_DESTINATION_DIR=''
PUBLICATION_SCAN_SCRATCH=''
PUBLICATION_SCAN_CLASS=''
PUBLICATION_SCAN_ORIGINAL_STATUS=''
PUBLICATION_SCAN_CLEANUP_FAILED=0

publication_sha256() {
  local checksum_output

  checksum_output="$(sha256sum -- "$1")" || return 1
  printf '%s\n' "${checksum_output%% *}"
}

publication_tool_version() {
  local output

  if output="$("$@" 2>&1)"; then
    :
  else
    output=''
  fi
  output="${output%%$'\n'*}"
  output="${output//$'\r'/}"
  [[ -n "$output" ]] || output='unknown'
  printf '%s' "$output"
}

publication_write_metadata_input() {
  local input_path="${BUILD_RUN_DIR}/.artifact-metadata-input.$$.json"
  local iso_path="${BUILD_RUN_DIR}/${CONTAINER_ISO_NAME}"
  local manifest_path="${BUILD_RUN_DIR}/pkglist.x86_64.txt"
  local iso_size
  local iso_sha256
  local manifest_sha256
  local mirrorlist_sha256
  local dirty_text=false
  local -a tool_versions=()
  local tool
  local version

  if [[ "$SOURCE_CAPTURE_DIRTY" -eq 1 ]]; then
    dirty_text=true
  fi
  if ! iso_size="$(stat -c '%s' -- "$iso_path")" || \
    ! iso_sha256="$(publication_sha256 "$iso_path")" || \
    ! manifest_sha256="$(publication_sha256 "$manifest_path")" || \
    ! mirrorlist_sha256="$(publication_sha256 "${EVIDENCE_RUN_DIR}/mirrorlist")"; then
    printf '%s\n' 'MirrorOS build: could not calculate artifact or repository-configuration identity.' >&2
    return 5
  fi

  for tool in docker cosign gitleaks git node; do
    case "$tool" in
      docker) version="$(publication_tool_version docker --version)" ;;
      cosign) version="$(publication_tool_version cosign version)" ;;
      gitleaks) version="$(publication_tool_version gitleaks version)" ;;
      git) version="$(publication_tool_version git --version)" ;;
      node) version="$(publication_tool_version node --version)" ;;
    esac
    tool_versions+=("${tool}=${version}")
  done

  if node --input-type=module - \
    "$input_path" "$RUN_ID" "$SOURCE_CAPTURE_COMMIT" "$dirty_text" \
    "$SOURCE_CAPTURE_PROFILE_IDENTITY" "$BUILD_SOURCE_DATE_EPOCH" \
    "$CONTAINER_IMAGE_DIGEST" "$CONTAINER_ARCHISO_VERSION" \
    "$CONTAINER_CONFIG_IDENTITY" "$CONTAINER_CONFIG_ISSUER" \
    "$CONTAINER_ISO_NAME" "$iso_size" "$iso_sha256" \
    'pkglist.x86_64.txt' "$manifest_sha256" \
    "evidence/archiso-build/${RUN_ID}/mirrorlist" "$mirrorlist_sha256" \
    "$BUILD_VALIDATION_SIGNATURE" "$BUILD_VALIDATION_ARCHISO" \
    "$BUILD_VALIDATION_PROFILE_SCAN" "$BUILD_VALIDATION_EVIDENCE_SCAN" \
    "$BUILD_VALIDATION_BUNDLE" \
    "${#tool_versions[@]}" "${tool_versions[@]}" \
    "${#SOURCE_CAPTURE_DIRTY_PATHS[@]}" "${SOURCE_CAPTURE_DIRTY_PATHS[@]}" <<'NODE'
import { writeFileSync } from 'node:fs';

const args = process.argv.slice(2);
const [
  outputPath,
  runId,
  commit,
  dirtyText,
  profileIdentity,
  sourceDateEpochText,
  imageDigest,
  archisoVersion,
  cosignIdentity,
  cosignIssuer,
  isoName,
  isoSizeText,
  isoSha256,
  manifestName,
  manifestSha256,
  mirrorlistPath,
  mirrorlistSha256,
  signatureOutcome,
  archisoOutcome,
  profileScanOutcome,
  evidenceScanOutcome,
  bundleOutcome,
  toolCountText,
] = args;
let cursor = 23;
const toolVersions = {};
for (const entry of args.slice(cursor, cursor + Number(toolCountText))) {
  const separator = entry.indexOf('=');
  toolVersions[entry.slice(0, separator)] = entry.slice(separator + 1);
}
cursor += Number(toolCountText);
const dirtyPathCount = Number(args[cursor++]);
const dirtyPaths = args.slice(cursor, cursor + dirtyPathCount);
const limitations = [
  'Official rolling repositories can resolve different package versions across builds.',
  'The native package manifest does not record per-package repository attribution.',
];
if (dirtyText === 'true') {
  limitations.push('The repository was dirty; the profile capture is identified by its recorded dirty-path list, not a content hash.');
}
const document = {
  execution: {
    run_id: runId,
    commit,
    dirty: dirtyText === 'true',
    profile_identity: profileIdentity,
    dirty_paths: dirtyPaths,
  },
  construction: {
    architecture: 'x86_64',
    image_digest: imageDigest,
    archiso_version: archisoVersion,
    source_date_epoch: Number(sourceDateEpochText),
    tool_versions: toolVersions,
    cosign: { identity: cosignIdentity, issuer: cosignIssuer },
  },
  repository_configuration: {
    pacman_conf: 'image/archiso/pacman.conf',
    mirrorlist: { path: mirrorlistPath, sha256: mirrorlistSha256 },
  },
  artifact: {
    iso: { name: isoName, size_bytes: Number(isoSizeText), sha256: isoSha256 },
    package_manifest: { name: manifestName, sha256: manifestSha256 },
  },
  controls: {
    secret_scan_scope: 'mirroros-created-content',
    outcomes: {
      signature_verification: signatureOutcome,
      archiso_version: archisoOutcome,
      profile_secret_scan: profileScanOutcome,
      evidence_secret_scan: evidenceScanOutcome,
      bundle_validation: bundleOutcome,
    },
  },
  traceability_limitations: limitations,
  boot_qualification: 'not_performed',
};
writeFileSync(outputPath, `${JSON.stringify(document, null, 2)}\n`, { mode: 0o600 });
NODE
  then
    chmod 600 -- "$input_path" || {
      rm -f -- "$input_path"
      return 5
    }
  else
    printf '%s\n' 'MirrorOS build: could not prepare artifact metadata input.' >&2
    rm -f -- "$input_path"
    return 5
  fi

  if node "${BUILDER_DIR}/build-documents.mjs" write-metadata \
    --input "$input_path" --output "${PUBLICATION_CANDIDATE_DIR}/artifact-metadata.json"; then
    rm -f -- "$input_path" || return 5
    return 0
  else
    local writer_status=$?
    rm -f -- "$input_path" || true
    printf 'MirrorOS build: artifact metadata contract failed (status %s).\n' "$writer_status" >&2
    return 6
  fi
}

publication_prepare_bundle() {
  local distribution_dir="${REPOSITORY_ROOT}/dist"
  local source_iso="${BUILD_RUN_DIR}/${CONTAINER_ISO_NAME}"
  local source_manifest="${BUILD_RUN_DIR}/pkglist.x86_64.txt"
  local candidate_iso
  local candidate_manifest
  local validation_status

  PUBLICATION_CANDIDATE_DIR="${distribution_dir}/.tmp-${RUN_ID}"
  PUBLICATION_DESTINATION_DIR="${distribution_dir}/${RUN_ID}"
  if [[ -e "$PUBLICATION_CANDIDATE_DIR" || -L "$PUBLICATION_CANDIDATE_DIR" ]]; then
    printf 'MirrorOS build: refusing existing publication staging path: %s\n' "$PUBLICATION_CANDIDATE_DIR" >&2
    return 2
  fi
  if [[ -e "$PUBLICATION_DESTINATION_DIR" || -L "$PUBLICATION_DESTINATION_DIR" ]]; then
    printf 'MirrorOS build: refusing existing publication destination: %s\n' "$PUBLICATION_DESTINATION_DIR" >&2
    return 2
  fi
  if ! mkdir -m 700 -- "$PUBLICATION_CANDIDATE_DIR"; then
    printf 'MirrorOS build: could not create private publication staging directory: %s\n' "$PUBLICATION_CANDIDATE_DIR" >&2
    PUBLICATION_CANDIDATE_DIR=''
    return 5
  fi

  candidate_iso="${PUBLICATION_CANDIDATE_DIR}/${CONTAINER_ISO_NAME}"
  candidate_manifest="${PUBLICATION_CANDIDATE_DIR}/pkglist.x86_64.txt"
  if ! cp -- "$source_iso" "$candidate_iso" || ! cp -- "$source_manifest" "$candidate_manifest" || \
    ! chmod 600 -- "$candidate_iso" "$candidate_manifest"; then
    printf '%s\n' 'MirrorOS build: could not stage the exported ISO and package manifest.' >&2
    return 5
  fi
  if ! cmp -s -- "$source_iso" "$candidate_iso" || ! cmp -s -- "$source_manifest" "$candidate_manifest"; then
    printf '%s\n' 'MirrorOS build: staged artifact bytes differ from verified exports.' >&2
    return 5
  fi

  BUILD_VALIDATION_BUNDLE='passed'
  if publication_write_metadata_input; then
    :
  else
    validation_status=$?
    BUILD_VALIDATION_BUNDLE='failed'
    return "$validation_status"
  fi
  if ! (cd -- "$PUBLICATION_CANDIDATE_DIR" && \
    sha256sum -- "$CONTAINER_ISO_NAME" artifact-metadata.json pkglist.x86_64.txt > SHA256SUMS); then
    printf '%s\n' 'MirrorOS build: could not write bundle checksums.' >&2
    BUILD_VALIDATION_BUNDLE='failed'
    return 5
  fi
  if ! chmod 600 -- "${PUBLICATION_CANDIDATE_DIR}/SHA256SUMS"; then
    printf '%s\n' 'MirrorOS build: could not set private checksum permissions.' >&2
    BUILD_VALIDATION_BUNDLE='failed'
    return 5
  fi

  if node "${BUILDER_DIR}/build-documents.mjs" validate-bundle \
    --metadata "${PUBLICATION_CANDIDATE_DIR}/artifact-metadata.json" \
    --iso "$candidate_iso" \
    --manifest "$candidate_manifest" \
    --checksums "${PUBLICATION_CANDIDATE_DIR}/SHA256SUMS"; then
    BUILD_VALIDATION_BUNDLE='passed'
  else
    validation_status=$?
    printf 'MirrorOS build: staged bundle validation failed (status %s).\n' "$validation_status" >&2
    BUILD_VALIDATION_BUNDLE='failed'
    return 6
  fi
}

publication_validate_and_publish() {
  local source_iso="${BUILD_RUN_DIR}/${CONTAINER_ISO_NAME}"
  local source_manifest="${BUILD_RUN_DIR}/pkglist.x86_64.txt"
  local candidate_iso="${PUBLICATION_CANDIDATE_DIR}/${CONTAINER_ISO_NAME}"
  local candidate_manifest="${PUBLICATION_CANDIDATE_DIR}/pkglist.x86_64.txt"
  local validation_status
  local rename_status

  if [[ ! -d "$PUBLICATION_CANDIDATE_DIR" || -L "$PUBLICATION_CANDIDATE_DIR" ]]; then
    printf '%s\n' 'MirrorOS build: publication staging directory is missing or unsafe.' >&2
    return 5
  fi
  if [[ -e "$PUBLICATION_DESTINATION_DIR" || -L "$PUBLICATION_DESTINATION_DIR" ]]; then
    printf 'MirrorOS build: refusing existing publication destination: %s\n' "$PUBLICATION_DESTINATION_DIR" >&2
    return 2
  fi
  if ! cmp -s -- "$source_iso" "$candidate_iso" || ! cmp -s -- "$source_manifest" "$candidate_manifest"; then
    printf '%s\n' 'MirrorOS build: publication staging no longer matches verified exports.' >&2
    return 5
  fi
  if node "${BUILDER_DIR}/build-documents.mjs" validate-bundle \
    --metadata "${PUBLICATION_CANDIDATE_DIR}/artifact-metadata.json" \
    --iso "$candidate_iso" \
    --manifest "$candidate_manifest" \
    --checksums "${PUBLICATION_CANDIDATE_DIR}/SHA256SUMS"; then
    BUILD_VALIDATION_BUNDLE='passed'
  else
    validation_status=$?
    printf 'MirrorOS build: final staged bundle validation failed (status %s).\n' "$validation_status" >&2
    BUILD_VALIDATION_BUNDLE='failed'
    return 6
  fi
  if mv -T -- "$PUBLICATION_CANDIDATE_DIR" "$PUBLICATION_DESTINATION_DIR"; then
    build_outcome_record_tool_status publication-rename 0
  else
    rename_status=$?
    build_outcome_record_tool_status publication-rename "$rename_status"
    build_outcome_mark_failure 5 publication "$rename_status"
    printf 'MirrorOS build: atomic publication rename failed for %s.\n' "$PUBLICATION_DESTINATION_DIR" >&2
    return 5
  fi
  PUBLICATION_CANDIDATE_DIR=''
  BUILD_PUBLISHED=true
}

publication_abort_candidate() {
  if [[ -z "$PUBLICATION_CANDIDATE_DIR" ]]; then
    return 0
  fi
  if [[ -e "$PUBLICATION_CANDIDATE_DIR" || -L "$PUBLICATION_CANDIDATE_DIR" ]]; then
    if [[ -L "$PUBLICATION_CANDIDATE_DIR" || ! -d "$PUBLICATION_CANDIDATE_DIR" ]]; then
      printf 'MirrorOS build: refusing to remove unsafe publication staging path: %s\n' "$PUBLICATION_CANDIDATE_DIR" >&2
      build_outcome_add_leftover "publication:${PUBLICATION_CANDIDATE_DIR}"
      build_outcome_note_cleanup_failure 'Preserve the unexpected publication staging path and inspect it before authorized manual cleanup.'
      return 1
    fi
    if ! rm -rf -- "$PUBLICATION_CANDIDATE_DIR"; then
      printf 'MirrorOS build: could not remove rejected publication staging path: %s\n' "$PUBLICATION_CANDIDATE_DIR" >&2
      build_outcome_add_leftover "publication:${PUBLICATION_CANDIDATE_DIR}"
      build_outcome_note_cleanup_failure 'Preserve and inspect the rejected publication staging directory before authorized manual cleanup.'
      return 1
    fi
  fi
  PUBLICATION_CANDIDATE_DIR=''
}

publication_scan_content() {
  local report_name="$1"
  local bundle_directory="${2:-}"
  local scan_root
  local report_path="${EVIDENCE_RUN_DIR}/${report_name}"
  local scanner_status
  local file_name

  PUBLICATION_SCAN_CLASS=''
  PUBLICATION_SCAN_ORIGINAL_STATUS=''
  PUBLICATION_SCAN_CLEANUP_FAILED=0
  if ! command -v gitleaks >/dev/null 2>&1; then
    printf '%s\n' 'MirrorOS build: gitleaks is missing; evidence secret scan prerequisite is unmet.' >&2
    PUBLICATION_SCAN_CLASS='missing'
    return 2
  fi
  if [[ ! "$report_name" =~ ^[A-Za-z0-9._-]+$ || -e "$report_path" || -L "$report_path" ]]; then
    printf 'MirrorOS build: refusing invalid or existing Gitleaks report path: %s\n' "$report_path" >&2
    PUBLICATION_SCAN_CLASS='scanner-error'
    PUBLICATION_SCAN_ORIGINAL_STATUS=5
    return 5
  fi
  if ! PUBLICATION_SCAN_SCRATCH="$(mktemp -d "${TMPDIR:-/tmp}/mirroros-build-scan.XXXXXX")"; then
    printf '%s\n' 'MirrorOS build: could not create private Gitleaks scan input.' >&2
    PUBLICATION_SCAN_CLASS='scanner-error'
    PUBLICATION_SCAN_ORIGINAL_STATUS=5
    return 5
  fi
  if ! chmod 700 -- "$PUBLICATION_SCAN_SCRATCH"; then
    publication_cleanup_scan_scratch || true
    PUBLICATION_SCAN_CLASS='scanner-error'
    PUBLICATION_SCAN_ORIGINAL_STATUS=5
    return 5
  fi
  scan_root="$PUBLICATION_SCAN_SCRATCH/content"
  if ! mkdir -m 700 -- "$scan_root" || ! cp -a -- "${EVIDENCE_RUN_DIR}/." "$scan_root/"; then
    printf '%s\n' 'MirrorOS build: could not stage private evidence for Gitleaks.' >&2
    publication_cleanup_scan_scratch || true
    PUBLICATION_SCAN_CLASS='scanner-error'
    PUBLICATION_SCAN_ORIGINAL_STATUS=5
    return 5
  fi
  if [[ -n "$bundle_directory" ]]; then
    for file_name in artifact-metadata.json SHA256SUMS pkglist.x86_64.txt; do
      if [[ ! -f "${bundle_directory}/${file_name}" || -L "${bundle_directory}/${file_name}" ]] || \
        ! cp -- "${bundle_directory}/${file_name}" "$scan_root/"; then
        printf 'MirrorOS build: could not stage bundle record for Gitleaks: %s\n' "$file_name" >&2
        publication_cleanup_scan_scratch || true
        PUBLICATION_SCAN_CLASS='scanner-error'
        PUBLICATION_SCAN_ORIGINAL_STATUS=5
        return 5
      fi
    done
  fi

  umask 077
  if gitleaks dir --redact --no-banner --report-format json \
    --report-path "$report_path" "$scan_root"; then
    scanner_status=0
  else
    scanner_status=$?
  fi
  if [[ -e "$report_path" ]]; then
    if ! chmod 600 -- "$report_path"; then
      scanner_status=5
    fi
  elif [[ "$scanner_status" -eq 0 || "$scanner_status" -eq 1 ]]; then
    printf '%s\n' 'MirrorOS build: Gitleaks did not produce its required redacted report.' >&2
    scanner_status=5
  fi
  if ! publication_cleanup_scan_scratch && [[ "$scanner_status" -eq 0 ]]; then
    scanner_status=5
  fi
  build_outcome_add_diagnostic "$report_name"
  if [[ "$scanner_status" -eq 0 ]]; then
    PUBLICATION_SCAN_CLASS='success'
    build_outcome_record_tool_status "${report_name%.json}" 0
    return 0
  fi
  PUBLICATION_SCAN_ORIGINAL_STATUS="$scanner_status"
  build_outcome_record_tool_status "${report_name%.json}" "$scanner_status"
  if [[ "$scanner_status" -eq 1 ]]; then
    PUBLICATION_SCAN_CLASS='finding'
    printf 'MirrorOS build: Gitleaks detected a secret in MirrorOS-created content; private evidence and the redacted report are preserved at %s.\n' \
      "$report_path" >&2
    return 2
  fi
  PUBLICATION_SCAN_CLASS='scanner-error'
  printf 'MirrorOS build: Gitleaks evidence scan failed with original status %s.\n' "$scanner_status" >&2
  return 5
}

publication_cleanup_scan_scratch() {
  if [[ -z "$PUBLICATION_SCAN_SCRATCH" ]]; then
    return 0
  fi
  if [[ -e "$PUBLICATION_SCAN_SCRATCH" || -L "$PUBLICATION_SCAN_SCRATCH" ]]; then
    if ! rm -rf -- "$PUBLICATION_SCAN_SCRATCH"; then
      printf 'MirrorOS build: could not remove private Gitleaks scan input: %s\n' "$PUBLICATION_SCAN_SCRATCH" >&2
      build_outcome_add_leftover "scan:${PUBLICATION_SCAN_SCRATCH}"
      PUBLICATION_SCAN_CLEANUP_FAILED=1
      return 1
    fi
  fi
  PUBLICATION_SCAN_SCRATCH=''
}

publication_record_scan_failure() {
  local stage="$1"

  BUILD_VALIDATION_EVIDENCE_SCAN='failed'
  case "$PUBLICATION_SCAN_CLASS" in
    finding)
      build_outcome_mark_failure 2 "$stage" 1
      ;;
    missing)
      build_outcome_mark_failure 2 "$stage" ''
      ;;
    scanner-error)
      build_outcome_mark_failure 5 "$stage" "${PUBLICATION_SCAN_ORIGINAL_STATUS:-5}"
      ;;
    *)
      build_outcome_mark_failure 5 "$stage" 5
      ;;
  esac
  if [[ "$PUBLICATION_SCAN_CLEANUP_FAILED" -eq 1 ]]; then
    build_outcome_note_cleanup_failure 'Preserve the private Gitleaks scan input and inspect it before authorized manual cleanup.'
  fi
}

publication_finalize_result() {
  local first_report='gitleaks-final-1.json'
  local second_report='gitleaks-final-2.json'
  local bundle_directory=''

  [[ "$BUILD_PUBLISHED" == 'true' ]] && bundle_directory="$PUBLICATION_DESTINATION_DIR"
  build_outcome_add_diagnostic "$first_report"
  if ! build_outcome_write_result; then
    build_outcome_mark_failure 5 execution-result ''
    printf '%s\n' 'MirrorOS build: could not write the final execution result.' >&2
  fi
  if publication_scan_content "$first_report" "$bundle_directory"; then
    return "$BUILD_PRIMARY_STATUS"
  else
    publication_record_scan_failure final-secret-scan
  fi

  build_outcome_add_diagnostic "$second_report"
  if ! build_outcome_write_result; then
    build_outcome_mark_failure 5 execution-result ''
    printf '%s\n' 'MirrorOS build: could not update the final execution result after scanning.' >&2
  fi
  if publication_scan_content "$second_report" "$bundle_directory"; then
    :
  else
    publication_record_scan_failure final-secret-scan
  fi
  return "$BUILD_PRIMARY_STATUS"
}
