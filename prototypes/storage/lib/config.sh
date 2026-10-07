#!/usr/bin/bash
# shellcheck disable=SC2034 # State variables are shared across the harness libraries sourced by harness.sh.
# Storage prototype harness: track paths and deadlines of the boots added on top of the 02-01 harness.
# The installation (1800 s) and verification (600 s) deadlines are inherited from
# prototypes/installation/lib/config.sh and are not redefined here.

# Track segment of the build and evidence paths (consumed by the generic resources module).
PROTO_TRACK='storage'

# Deadlines in seconds. Each one limits the time until a boot reaches the stated event.
STORAGE_POWEROFF_DEADLINE_SECONDS=120   # After a report: time until the guest powers itself off
STORAGE_ACTION_DEADLINE_SECONDS=300     # Damage and hibernation boots: time until the guest powers off
STORAGE_CONFIRM_DEADLINE_SECONDS=180    # Damaged boot: no verification report may arrive in this time
STORAGE_RECOVER_DEADLINE_SECONDS=900    # Rescue boot: time until the guest powers off
STORAGE_RESUME_DEADLINE_SECONDS=600     # Resume boot: time until the resumed action reports
STORAGE_ATTENDED_DEADLINE_SECONDS=7200  # Attended boots: documented limit (not enforced by a timer)

# Every boot of a run has a name. Evidence file names derive from it.
STORAGE_BOOT_NAMES=(install prepare damage confirm recover final hibernate resume pending)
