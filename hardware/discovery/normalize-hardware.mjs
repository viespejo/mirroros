const VENDOR_CLASSES = {
  '1002': 'amd',
  '8086': 'intel',
  '10de': 'nvidia',
  '1af4': 'qemu_virtual',
  '1234': 'qemu_virtual',
};

function text(value) {
  return typeof value === 'string' && value.trim().length > 0 ? value.trim() : undefined;
}

function count(value) {
  const number = typeof value === 'string' && /^\d+$/.test(value) ? Number(value) : value;
  return Number.isSafeInteger(number) && number >= 0 ? number : undefined;
}

function pciId(value) {
  const id = text(value)?.toLowerCase().replace(/^0x/, '');
  return id !== undefined && /^[0-9a-f]{1,4}$/.test(id) ? id.padStart(4, '0') : undefined;
}

function compact(object) {
  return Object.fromEntries(Object.entries(object).filter(([, value]) => value !== undefined));
}

function normalizeGraphics(device) {
  const vendorId = pciId(device?.vendor_id);
  if (vendorId === undefined) return undefined;
  return compact({
    vendor: VENDOR_CLASSES[vendorId] ?? 'unknown',
    vendor_id: vendorId,
    device_id: pciId(device.device_id),
    driver: text(device.driver),
    boot_vga: typeof device.boot_vga === 'boolean' ? device.boot_vga : undefined,
  });
}

export function normalizeHardware(raw) {
  const source = raw !== null && typeof raw === 'object' ? raw : {};
  const missing = [];
  const architecture = text(source.architecture);
  const virtualization = text(source.virtualization);
  if (architecture === undefined) missing.push('hardware.architecture');
  if (virtualization === undefined) missing.push('hardware.virtualization');

  const cpuSource = source.cpu !== null && typeof source.cpu === 'object' ? source.cpu : {};
  const cpu = compact({
    vendor: text(cpuSource.vendor_id),
    model: text(cpuSource.model_name),
    cores: count(cpuSource.cores),
  });
  const memoryKib = count(source.memory_total_kib);
  const graphics = (Array.isArray(source.display_devices) ? source.display_devices : [])
    .map(normalizeGraphics)
    .filter(device => device !== undefined);

  const facts = compact({
    architecture,
    cpu: Object.keys(cpu).length > 0 ? cpu : undefined,
    memory_total_bytes: memoryKib === undefined ? undefined : memoryKib * 1024,
    graphics,
    battery_present: typeof source.battery_present === 'boolean' ? source.battery_present : undefined,
    virtualization,
    wifi_reference: 'network.wifi_present',
  });
  return { facts, missing };
}
