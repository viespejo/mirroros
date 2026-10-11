// The one place where the hibernation swapfile policy is computed (ADR 0007, contracts/installation-plan.md).
// Generation, validation, and the choice helpers consume it; no screen or renderer repeats these rules.
// All arithmetic uses safe integers: bytes for memory and disks, MiB for the swapfile.

export const MEBIBYTE = 1048576;
export const GIBIBYTE = 1073741824;
export const SWAPFILE_MINIMUM_MIB = 512;
export const SWAPFILE_PRIORITY = 0;
export const RESUME_PARAMETERS = ['resume=', 'resume_offset='];

// Detected memory is a positive safe integer of bytes; nothing else is ever assumed.
export function isMemoryBytes(value) {
  return Number.isSafeInteger(value) && value > 0;
}

// ceil(memory_total_bytes / 1 GiB) * 1024 MiB. The division by a power of two is exact for safe integers.
export function swapfileMaximumMib(memoryBytes) {
  if (!isMemoryBytes(memoryBytes)) return undefined;
  const maximum = Math.ceil(memoryBytes / GIBIBYTE) * 1024;
  return Number.isSafeInteger(maximum) ? maximum : undefined;
}

// The editable range of the swapfile size. The maximum is also the default; the minimum is an input limit and
// no claim of sufficient hibernation capacity.
export function swapfileRange(memoryBytes) {
  const maximum = swapfileMaximumMib(memoryBytes);
  if (maximum === undefined) return undefined;
  return {
    minimum: SWAPFILE_MINIMUM_MIB,
    maximum,
    default: maximum,
    unit: 'MiB',
    memory_total_bytes: memoryBytes,
  };
}

// True for an integer MiB inside the range derived from the detected memory.
export function isSwapfileSizeInRange(size, memoryBytes) {
  const maximum = swapfileMaximumMib(memoryBytes);
  return maximum !== undefined && Number.isSafeInteger(size) && size >= SWAPFILE_MINIMUM_MIB && size <= maximum;
}

// Returns an error description, or undefined when the size is acceptable. Messages never echo the value.
export function checkSwapfileSize(size, memoryBytes) {
  if (!Number.isSafeInteger(size)) return `swapfile_size must be an integer count of MiB`;
  if (size < SWAPFILE_MINIMUM_MIB) return `swapfile_size must be an integer from ${SWAPFILE_MINIMUM_MIB} MiB`;
  const maximum = swapfileMaximumMib(memoryBytes);
  if (maximum !== undefined && size > maximum) {
    return `swapfile_size must be an integer from ${SWAPFILE_MINIMUM_MIB} to ${maximum} MiB`;
  }
  return undefined;
}

// A size below the raw detected memory is valid but warned about; equality does not warn.
export function isSwapfileBelowRam(size, memoryBytes) {
  return Number.isSafeInteger(size) && isMemoryBytes(memoryBytes) && size * MEBIBYTE < memoryBytes;
}

// The bytes the ESP, the root minimum, and the swapfile (when present) need on the disk, or undefined when a
// term is not a safe integer.
export function requiredDiskBytes({ espBytes, rootMinimumBytes, swapfileMib }) {
  const swapBytes = swapfileMib === undefined ? 0 : swapfileMib * MEBIBYTE;
  const total = espBytes + rootMinimumBytes + swapBytes;
  return [espBytes, rootMinimumBytes, swapBytes, total].every(Number.isSafeInteger) ? total : undefined;
}

// The kernel command line of the policy is written for enabled hibernation; disabling it removes exactly the
// resume parameters and leaves every other token untouched.
export function kernelCommandLine(policyValue, hibernation) {
  if (hibernation) return policyValue;
  return policyValue
    .split(' ')
    .filter(token => !RESUME_PARAMETERS.some(prefix => token.startsWith(prefix)))
    .join(' ');
}

export function hasResumeParameters(commandLine) {
  const tokens = commandLine.split(' ');
  return RESUME_PARAMETERS.map(prefix => tokens.some(token => token.startsWith(prefix)));
}
