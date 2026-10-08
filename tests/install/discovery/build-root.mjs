import { mkdirSync, readFileSync, symlinkSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';

// Turns a raw fixture of tests/fixtures/discovery/raw/ into a fake system root for the collectors
// (MIRROROS_DISCOVERY_ROOT) and the state files read by the PATH doubles. Planted sensitive values
// are written where a careless collector could read them.
const [fixturePath, root, state] = process.argv.slice(2);
const raw = JSON.parse(readFileSync(fixturePath, 'utf8'));

function put(base, relative, content) {
  const path = join(base, relative);
  mkdirSync(dirname(path), { recursive: true });
  writeFileSync(path, content);
}

function putRoot(relative, content) {
  put(root, relative, content);
}

function putState(name, content) {
  put(state, name, `${content}\n`);
}

const firmware = raw.firmware ?? {};
if (firmware.boot_mode === 'uefi') {
  mkdirSync(join(root, 'sys/firmware/efi'), { recursive: true });
  if (firmware.fw_platform_size !== undefined) putRoot('sys/firmware/efi/fw_platform_size', `${firmware.fw_platform_size}\n`);
  if (firmware.efivars_available) {
    putRoot('sys/firmware/efi/efivars/Dummy-00000000-0000-0000-0000-000000000000', Buffer.from([7, 0, 0, 0, 0]));
    if (firmware.secure_boot === 'enabled' || firmware.secure_boot === 'disabled') {
      putRoot(
        'sys/firmware/efi/efivars/SecureBoot-8be4df61-93ca-11d2-aa0d-00e098032b8c',
        Buffer.from([6, 0, 0, 0, firmware.secure_boot === 'enabled' ? 1 : 0]),
      );
    }
  }
}
for (const [field, value] of Object.entries(firmware.dmi ?? {})) putRoot(`sys/class/dmi/id/${field}`, `${value}\n`);

const network = raw.network ?? {};
for (const item of network.interfaces ?? []) {
  const base = `sys/class/net/${item.name}`;
  putRoot(`${base}/operstate`, `${item.state}\n`);
  if (item.kind === 'wireless') {
    mkdirSync(join(root, base, 'wireless'), { recursive: true });
  } else if (item.kind === 'wired') {
    putRoot(`${base}/type`, '1\n');
    mkdirSync(join(root, base, 'device'), { recursive: true });
  }
  if (item.address !== undefined) putRoot(`${base}/address`, `${item.address}\n`);
  if (item.ssid !== undefined) putRoot(`var/lib/iwd/${item.ssid}.psk`, `${item.iwd_state ?? ''}\n`);
  if (item.has_global_ipv4) putState(`addr4.${item.name}`, `2: ${item.name}    inet 10.0.2.15/24 scope global ${item.name}`);
  if (item.has_global_ipv6) putState(`addr6.${item.name}`, `2: ${item.name}    inet6 2001:db8::2/64 scope global ${item.name}`);
}
if (network.default_route) putState('route4', 'default via 10.0.2.2 dev enp0s2');
putState('dns_status', network.dns?.resolved ? 0 : 2);
putState('curl_status', network.https?.ok ? 0 : 28);

const storage = raw.storage ?? {};
writeFileSync(join(state, 'lsblk.json'), `${JSON.stringify({ blockdevices: storage.blockdevices ?? [] }, null, 2)}\n`);
for (const link of storage.by_id ?? []) {
  putRoot(`dev${link.target.slice('/dev'.length)}`, '');
  mkdirSync(join(root, 'dev/disk/by-id'), { recursive: true });
  symlinkSync(`../..${link.target.slice('/dev'.length)}`, join(root, 'dev/disk/by-id', link.name));
}
putRoot('proc/self/mounts', storage.live_medium_device
  ? `${storage.live_medium_device} /run/archiso/bootmnt iso9660 ro,relatime 0 0\nproc /proc proc rw 0 0\n`
  : 'proc /proc proc rw 0 0\n');

const hardware = raw.hardware ?? {};
putState('architecture', hardware.architecture ?? '');
putState('virtualization', hardware.virtualization ?? 'none');
const cpu = hardware.cpu ?? {};
putRoot('proc/cpuinfo', Array.from({ length: cpu.cores ?? 1 }, (_, index) => (
  `processor\t: ${index}\nvendor_id\t: ${cpu.vendor_id}\nmodel name\t: ${cpu.model_name}\n`
)).join('\n'));
putRoot('proc/meminfo', `MemTotal:       ${hardware.memory_total_kib} kB\nMemFree:         1024 kB\n`);
for (const [index, device] of (hardware.display_devices ?? []).entries()) {
  const base = `sys/bus/pci/devices/0000:00:0${index + 1}.0`;
  putRoot(`${base}/class`, '0x030000\n');
  putRoot(`${base}/vendor`, `${device.vendor_id}\n`);
  putRoot(`${base}/device`, `${device.device_id}\n`);
  putRoot(`${base}/boot_vga`, device.boot_vga ? '1\n' : '0\n');
  if (device.driver) symlinkSync(`../../../bus/pci/drivers/${device.driver}`, join(root, base, 'driver'));
}
putRoot('sys/bus/pci/devices/0000:00:1f.0/class', '0x060100\n');
putRoot('sys/class/power_supply/AC/type', 'Mains\n');
if (hardware.battery_present) {
  putRoot('sys/class/power_supply/BAT0/type', 'Battery\n');
  if (hardware.battery_serial !== undefined) putRoot('sys/class/power_supply/BAT0/serial_number', `${hardware.battery_serial}\n`);
}
