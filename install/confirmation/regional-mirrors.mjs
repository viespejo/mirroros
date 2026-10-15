import { chmodSync, readFileSync, renameSync, statSync, unlinkSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';

// Regional selection of the live mirrorlist (ADR 0013). The plan's time zone gives a country through zone.tab;
// that country's section is moved first, the Worldwide section second, and the active servers of every other
// section are commented out. Nothing is uncommented and no line is dropped. Every doubt leaves the file unchanged.

export const SELECTION_MARKER = '## MirrorOS regional selection (ADR 0013)';
const WORLDWIDE = 'Worldwide';
// pacman-mirrorlist section names that differ from the iso3166.tab country names.
const SECTION_ALIASES = { CZ: 'Czechia', GB: 'United Kingdom', KR: 'South Korea', TR: 'Türkiye' };
const SECTION_LINE = /^## (.+)$/;
const SERVER_LINE = /^#?\s*Server\s*=/;
const ACTIVE_SERVER_LINE = /^\s*Server\s*=/;

function tableRows(text) {
  return text.split('\n').filter(line => line !== '' && !line.startsWith('#')).map(line => line.split('\t'));
}

export function countryCodeForTimezone(zoneTab, timezone) {
  return tableRows(zoneTab).find(fields => fields[2] === timezone)?.[0] ?? null;
}

export function sectionNameForCountry(isoTab, code) {
  return SECTION_ALIASES[code] ?? tableRows(isoTab).find(fields => fields[0] === code)?.[1] ?? null;
}

// A section starts at a "## Name" line directly followed by a server line; everything before the first one is the
// header. Trailing blank lines of each block are dropped and restored as one separator.
function parseMirrorlist(text) {
  const lines = text.split('\n');
  const header = [];
  const sections = [];
  lines.forEach((line, index) => {
    const name = SECTION_LINE.exec(line)?.[1];
    if (name !== undefined && SERVER_LINE.test(lines[index + 1] ?? '')) sections.push({ name, lines: [line] });
    else if (sections.length === 0) header.push(line);
    else sections.at(-1).lines.push(line);
  });
  const trim = block => {
    while (block.length > 0 && block.at(-1).trim() === '') block.pop();
    return block;
  };
  return { header: trim(header), sections: sections.map(section => ({ ...section, lines: trim(section.lines) })) };
}

const activeServers = section => section.lines.filter(line => ACTIVE_SERVER_LINE.test(line)).length;
const commentOut = section => section.lines.map(line => (ACTIVE_SERVER_LINE.test(line) ? `#${line.trimStart()}` : line));

// Returns { status: 'selected', text, servers } or { status: 'unchanged', reason }.
export function selectRegion(text, sectionName) {
  if (text.includes(SELECTION_MARKER)) return { status: 'unchanged', reason: 'the mirrorlist is already selected' };
  const { header, sections } = parseMirrorlist(text);
  const chosen = sections.find(section => section.name === sectionName);
  if (chosen === undefined) return { status: 'unchanged', reason: `the mirrorlist has no section ${sectionName}` };
  const servers = activeServers(chosen);
  if (servers === 0) return { status: 'unchanged', reason: `the section ${sectionName} has no active server` };
  const worldwide = sectionName === WORLDWIDE ? undefined : sections.find(section => section.name === WORLDWIDE);
  const others = sections.filter(section => section !== chosen && section !== worldwide);
  const blocks = [
    [...header, SELECTION_MARKER, `## ${sectionName} first, then ${WORLDWIDE}; other active servers are commented out.`],
    chosen.lines,
    ...(worldwide === undefined ? [] : [worldwide.lines]),
    ...others.map(commentOut),
  ];
  return { status: 'selected', text: `${blocks.map(block => block.join('\n')).join('\n\n')}\n`, servers };
}

// Applies the selection to <root>/etc/pacman.d/mirrorlist, replacing it atomically with its mode preserved.
export function applyRegionalMirrors(root, timezone) {
  const path = join(root, 'etc/pacman.d/mirrorlist');
  let zoneTab;
  let isoTab;
  let text;
  try {
    zoneTab = readFileSync(join(root, 'usr/share/zoneinfo/zone.tab'), 'utf8');
    isoTab = readFileSync(join(root, 'usr/share/zoneinfo/iso3166.tab'), 'utf8');
    text = readFileSync(path, 'utf8');
  } catch {
    return { status: 'unchanged', reason: 'the mirrorlist or the time zone tables could not be read' };
  }
  const code = countryCodeForTimezone(zoneTab, timezone);
  if (code === null) return { status: 'unchanged', reason: `the time zone ${timezone} maps to no country` };
  const sectionName = sectionNameForCountry(isoTab, code);
  if (sectionName === null) return { status: 'unchanged', reason: `the country ${code} has no name` };
  const result = selectRegion(text, sectionName);
  if (result.status !== 'selected') return result;
  const temporary = `${path}.mirroros-tmp`;
  try {
    writeFileSync(temporary, result.text);
    // The installer's umask 077 would otherwise make the live mirrorlist unreadable for ordinary users.
    chmodSync(temporary, statSync(path).mode & 0o7777);
    renameSync(temporary, path);
  } catch {
    try { unlinkSync(temporary); } catch { /* nothing was written */ }
    return { status: 'unchanged', reason: 'the selected mirrorlist could not be written' };
  }
  return { status: 'selected', section: sectionName, servers: result.servers };
}
