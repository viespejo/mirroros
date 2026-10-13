// CPU microcode rule: selects the microcode package of the detected CPU vendor. Any other or undetected vendor
// selects nothing and warns; no package is guessed. The boot configuration is unchanged: the initramfs hook set
// already includes `microcode`, so the installed package ends up in the generated initramfs.

const VENDORS = {
  AuthenticAMD: { outcome: 'amd_microcode', package: 'amd-ucode' },
  GenuineIntel: { outcome: 'intel_microcode', package: 'intel-ucode' },
};

export default {
  id: 'cpu-microcode',
  fact: 'hardware.cpu.vendor',

  // The plan value: the CPU vendor string, or `unknown` when it was not observed.
  observe(raw) {
    return typeof raw === 'string' && raw !== '' ? raw : 'unknown';
  },

  evaluate(value) {
    const entry = typeof value === 'string' && Object.hasOwn(VENDORS, value) ? VENDORS[value] : undefined;
    if (entry !== undefined) {
      return {
        outcome: entry.outcome,
        explanation: `CPU vendor ${value}. The ${entry.package} package is installed so the matching microcode is loaded at boot.`,
        packages: [entry.package],
        warnings: [],
      };
    }
    return {
      outcome: 'vendor_not_recognized',
      explanation: `CPU vendor ${value}. It is not AuthenticAMD or GenuineIntel, so no microcode package is selected.`,
      packages: [],
      warnings: [{
        code: 'cpu_vendor_unknown',
        message: 'The CPU vendor is not AuthenticAMD or GenuineIntel, or was not detected; no microcode package is installed.',
        next_step: 'You may install the microcode package of your CPU vendor after installation.',
      }],
    };
  },
};
