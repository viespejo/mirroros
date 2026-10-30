import { readFileSync, writeFileSync, appendFileSync } from 'node:fs';

const args = process.argv.slice(2);
appendFileSync(process.env.UEFI_TEST_CALLS, `${JSON.stringify(args)}\n`);
const file = process.env.UEFI_TEST_STATE;
const state = JSON.parse(readFileSync(file, 'utf8'));
if (process.env.UEFI_TEST_FAIL === args[0]) {
  console.error('synthetic efibootmgr failure');
  process.exit(1);
}
const value = (name) => args[args.indexOf(name) + 1];
if (args.join(' ') === '-v') {
  if (state.raw !== undefined) {
    console.log(state.raw);
    process.exit(0);
  }
  console.log(`BootOrder: ${state.order.join(',')}`);
  for (const entry of state.entries) {
    const path = entry.guid
      ? `HD(1,GPT,${entry.guid},0x800,0x100000)/File(${entry.path})`
      : 'PciRoot(0x0)/VenHw(firmware)';
    console.log(`Boot${entry.id}* ${entry.label}\t${path}`);
  }
} else if (args[0] === '--create-only' && args.length === 9) {
  let number = 0;
  while (state.entries.some((entry) => entry.id === number.toString(16).toUpperCase().padStart(4, '0'))) number++;
  const id = number.toString(16).toUpperCase().padStart(4, '0');
  state.entries.push({ id, guid: process.env.UEFI_TEST_ESP_GUID, path: value('--loader'), label: value('--label') });
  if (process.env.UEFI_TEST_BAD_CREATE) state.order.unshift(id);
} else if (args[0] === '--bootorder' && args.length === 2) {
  if (!process.env.UEFI_TEST_IGNORE_ORDER) state.order = args[1].split(',');
} else if (args[0] === '--bootnum' && args[2] === '--delete-bootnum' && args.length === 3) {
  state.entries = state.entries.filter((entry) => entry.id !== args[1]);
  state.order = state.order.filter((id) => id !== args[1]);
} else {
  console.error(`forbidden efibootmgr invocation: ${JSON.stringify(args)}`);
  process.exit(99);
}
writeFileSync(file, JSON.stringify(state));
