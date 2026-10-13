// Battery rule: informational only. It records whether a battery was detected and selects no package and no
// warning; power management belongs to a later story.

export default {
  id: 'battery',
  fact: 'hardware.battery_present',

  // The plan value: the detected boolean, or `unknown` when it was not observed.
  observe(raw) {
    return typeof raw === 'boolean' ? raw : 'unknown';
  },

  evaluate(value) {
    if (value === true) {
      return { outcome: 'battery_present', explanation: 'A battery was detected. Nothing is selected for it in this version.', packages: [], warnings: [] };
    }
    if (value === false) {
      return { outcome: 'battery_absent', explanation: 'No battery was detected. Nothing is selected.', packages: [], warnings: [] };
    }
    return { outcome: 'not_observed', explanation: 'Battery presence was not observed. Nothing is selected.', packages: [], warnings: [] };
  },
};
