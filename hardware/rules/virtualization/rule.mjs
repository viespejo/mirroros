// Virtualization rule: informational only. It records whether the machine is virtual or physical and selects no
// package and no warning; guest integration belongs to a later story.

export default {
  id: 'virtualization',
  fact: 'hardware.virtualization',

  // The plan value: the detected virtualization string (`none` for physical hardware), or `unknown`.
  observe(raw) {
    return typeof raw === 'string' && raw !== '' ? raw : 'unknown';
  },

  evaluate(value) {
    if (value === 'unknown' || typeof value !== 'string' || value === '') {
      return { outcome: 'not_observed', explanation: 'Virtualization was not observed. Nothing is selected.', packages: [], warnings: [] };
    }
    if (value === 'none') {
      return { outcome: 'physical_machine', explanation: 'No virtualization was detected: this is a physical machine. Nothing is selected.', packages: [], warnings: [] };
    }
    return {
      outcome: 'virtual_machine',
      explanation: `Virtualization ${value} was detected. Nothing is selected for it in this version.`,
      packages: [],
      warnings: [],
    };
  },
};
