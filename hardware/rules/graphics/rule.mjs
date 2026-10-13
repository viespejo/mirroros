// Graphics rule: classifies the detected graphics devices by vendor. It selects no package: AMD, Intel, and QEMU
// virtual devices use the kernel driver already installed, and NVIDIA devices fall back to the in-kernel
// `nouveau` driver, which is neither blacklisted nor configured. Nothing here blocks installation.

const KERNEL_DRIVER_VENDORS = ['amd', 'intel', 'qemu_virtual'];

export default {
  id: 'graphics',
  fact: 'hardware.graphics',

  // The plan value: the list of vendor classes of the detected devices, or `unknown` when none was observed.
  observe(raw) {
    return Array.isArray(raw) ? raw.map(device => device?.vendor ?? 'unknown') : 'unknown';
  },

  evaluate(value) {
    const vendors = Array.isArray(value) ? value : [];
    const named = vendors.length === 0 ? 'none observed' : [...new Set(vendors)].join(', ');
    if (vendors.length === 0 || vendors.some(vendor => !KERNEL_DRIVER_VENDORS.includes(vendor) && vendor !== 'nvidia')) {
      return {
        outcome: 'vendor_not_recognized',
        explanation: `Graphics vendors: ${named}. MirrorOS does not recognize the graphics hardware, so nothing is selected for it.`,
        packages: [],
        warnings: [{
          code: 'graphics_vendor_unknown',
          message: 'MirrorOS does not recognize the graphics hardware (or observed none) and installs nothing for it.',
          next_step: 'The kernel generic display support is used; drivers may be installed after installation.',
        }],
      };
    }
    if (vendors.includes('nvidia')) {
      return {
        outcome: 'nvidia_nouveau_fallback',
        explanation: `Graphics vendors: ${named}. MirrorOS installs no NVIDIA driver, so the in-kernel nouveau driver is used.`,
        packages: [],
        warnings: [{
          code: 'graphics_nvidia_nouveau',
          message: 'An NVIDIA graphics device was detected. MirrorOS does not install its driver; the in-kernel nouveau driver will be used.',
          next_step: 'You may install the NVIDIA driver after installation, without a MirrorOS guarantee; MirrorOS does not blacklist nouveau.',
        }],
      };
    }
    return {
      outcome: 'kernel_driver_only',
      explanation: `Graphics vendors: ${named}. The kernel driver and linux-firmware already installed are enough; nothing additional is selected.`,
      packages: [],
      warnings: [],
    };
  },
};
