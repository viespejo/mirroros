#!/usr/bin/env node
// Development-time generator for the native icon theme MirrorOS-<theme>: renders folders, file types and
// devices from the pinned Lucide and Catppuccin sources in this directory with the theme's palette.
// The output is committed under ../icons/<theme> and published by configure; configure never runs this.
// Usage: node capabilities/visual/gtk4/icon-sources/generate.mjs [theme]   (default: default)
import { readFileSync, writeFileSync, mkdirSync, rmSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const gtk4 = resolve(here, '..');
const themes = resolve(gtk4, '../theme');

// Minimum contrast of every drawn color against the window background and against the accent,
// which the theme uses as the selected-row background.
export const MIN_BACKGROUND_CONTRAST = 4.5;
export const MIN_SELECTED_CONTRAST = 1.5;

// Place icon name -> Lucide glyph drawn on a filled folder; null means a plain folder outline.
export const PLACES = {
  folder: ['folder', null], 'inode-directory': ['folder', null],
  'folder-open': ['folder-open', null], 'folder-drag-accept': ['folder-open', null],
  'user-home': ['folder', 'house'], 'user-desktop': ['folder', 'monitor'],
  'folder-documents': ['folder', 'file-text'], 'folder-download': ['folder', 'arrow-down'],
  'folder-music': ['folder', 'music'], 'folder-pictures': ['folder', 'image'],
  'folder-videos': ['folder', 'clapperboard'], 'folder-templates': ['folder', 'layout-template'],
  'folder-publicshare': ['folder', 'share-2'], 'folder-remote': ['folder', 'globe'],
};

// Device icon name -> Lucide outline.
export const DEVICES = {
  'audio-card': 'audio-lines', 'audio-headphones': 'headphones', 'audio-headset': 'headset',
  'audio-input-microphone': 'mic', 'audio-speakers': 'speaker', bluetooth: 'bluetooth', 'camera-web': 'webcam',
  computer: 'computer', 'drive-harddisk': 'hard-drive', 'drive-multidisk': 'server', 'drive-optical': 'disc',
  'drive-removable-media': 'usb', 'ebook-reader': 'book-open', 'input-gaming': 'gamepad-2',
  'input-keyboard': 'keyboard', 'input-mouse': 'mouse', 'input-tablet': 'tablet', 'media-flash': 'memory-stick',
  'media-optical': 'disc', 'media-removable': 'usb', microphone: 'mic', phone: 'smartphone', printer: 'printer',
  'printer-network': 'printer', scanner: 'scan', 'video-display': 'monitor',
};

// Freedesktop MIME icon name -> Catppuccin css-variables icon. Names must be safe publisher paths.
export const MIMETYPES = {
  'application-certificate': 'certificate', 'application-gzip': 'zip', 'application-json': 'json',
  'application-octet-stream': 'binary', 'application-pdf': 'pdf', 'application-x-7z-compressed': 'zip',
  'application-x-compressed-tar': 'zip', 'application-x-executable': 'binary', 'application-x-generic': '_file',
  'application-x-sharedlib': 'lib', 'application-x-shellscript': 'bash', 'application-x-tar': 'zip',
  'application-x-xz-compressed-tar': 'zip', 'application-x-zstd-compressed-tar': 'zip', 'application-zip': 'zip',
  'audio-x-generic': 'audio', 'font-x-generic': 'font', 'image-x-generic': 'image', model: '3d',
  'package-x-generic': 'zip', 'text-html': 'html', 'text-markdown': 'markdown', 'text-plain': 'text',
  'text-x-generic': 'text', 'text-x-log': 'log', 'text-x-script': 'bash', 'video-x-generic': 'video',
  'x-office-document': 'ms-word', 'x-office-presentation': 'ms-powerpoint', 'x-office-spreadsheet': 'ms-excel',
};

// Catppuccin variable -> palette key. Only light tones: the selected-row background is the mid-tone accent.
export const CATPPUCCIN_COLORS = {
  text: 'foreground', overlay1: 'dark_foreground', blue: 'bright_blue', sapphire: 'bright_blue', sky: 'bright_cyan',
  teal: 'cyan', green: 'bright_cyan', yellow: 'bright_yellow', peach: 'bright_yellow', red: 'bright_red',
  maroon: 'bright_red', mauve: 'bright_red', pink: 'bright_red', lavender: 'bright_blue', rosewater: 'light_foreground',
  flamingo: 'bright_red',
};

// Folder and device color, and the folder glyph candidates.
const SHAPE_COLOR = 'bright_blue';
const GLYPH_COLORS = ['darker_background', 'bright_foreground'];

// Composition adapted from Strata v1.2.1 src/assets.rs (MIT): plain folder fill 0.15, decorated fill 0.92,
// glyph at translate(5.5 6.8) scale(.54) with stroke width 2.7.
const PLAIN_FILL = '0.15';
const DECORATED_FILL = '0.92';
const GLYPH_TRANSFORM = 'translate(5.5 6.8) scale(.54)';
const GLYPH_STROKE = '2.7';

export function parseColors(text) {
  return Object.fromEntries([...text.matchAll(/^([a-z_]+)\s*=\s*"(#[0-9a-fA-F]{6})"/gm)]
    .map(([, key, value]) => [key, value.toLowerCase()]));
}

export function luminance(hex) {
  const channels = [1, 3, 5].map(i => parseInt(hex.slice(i, i + 2), 16) / 255)
    .map(v => (v <= 0.03928 ? v / 12.92 : ((v + 0.055) / 1.055) ** 2.4));
  return 0.2126 * channels[0] + 0.7152 * channels[1] + 0.0722 * channels[2];
}

export function contrast(a, b) {
  const [high, low] = [luminance(a), luminance(b)].sort((x, y) => y - x);
  return (high + 0.05) / (low + 0.05);
}

function color(colors, key) {
  if (!colors[key]) throw new Error(`palette has no ${key}`);
  return colors[key];
}

function checkContrast(colors, key) {
  const value = color(colors, key);
  const background = contrast(value, color(colors, 'background'));
  const selected = contrast(value, color(colors, 'accent'));
  if (background < MIN_BACKGROUND_CONTRAST || selected < MIN_SELECTED_CONTRAST) {
    throw new Error(`${key} ${value}: contrast ${background.toFixed(2)} on background, ${selected.toFixed(2)} on accent`);
  }
  return value;
}

const svgBody = svg => svg.replace(/^[\s\S]*?<svg[^>]*>/, '').replace(/<\/svg>\s*$/, '').trim();
const header = (source, license) => `<!-- Generated by capabilities/visual/gtk4/icon-sources/generate.mjs from ${source} (${license}); do not edit. -->\n`;

const INDEX_SECTIONS = [
  ['16x16/status', 'Status', 'Size=16\nType=Fixed'],
  ['scalable/status', 'Status', 'Size=128\nMinSize=8\nMaxSize=512\nType=Scalable'],
  ['symbolic/status', 'Status', 'Size=16\nMinSize=8\nMaxSize=512\nType=Scalable'],
  ['scalable/places', 'Places', 'Size=128\nMinSize=8\nMaxSize=512\nType=Scalable'],
  ['scalable/mimetypes', 'MimeTypes', 'Size=128\nMinSize=8\nMaxSize=512\nType=Scalable'],
  ['scalable/devices', 'Devices', 'Size=128\nMinSize=8\nMaxSize=512\nType=Scalable'],
];

// Returns Map<relative path, content> of every generated file of icons/<theme>; the neutral check is not generated.
export function generate(theme, { read = path => readFileSync(path, 'utf8') } = {}) {
  const colors = parseColors(read(join(themes, theme, 'colors.toml')));
  const lucide = name => read(join(here, 'lucide', `${name}.svg`));
  const catppuccin = name => read(join(here, 'catppuccin', `${name}.svg`));
  const shape = checkContrast(colors, SHAPE_COLOR);
  const glyphKey = GLYPH_COLORS.reduce((best, key) => (contrast(color(colors, key), shape) > contrast(color(colors, best), shape) ? key : best));
  const glyph = color(colors, glyphKey);
  const svg = inner => `<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24">\n${inner}\n</svg>\n`;
  const outline = (body, fill) =>
    `<g fill="${shape}" fill-opacity="${fill}" stroke="${shape}" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">${body}</g>`;
  const out = new Map();

  for (const [name, [folder, decoration]] of Object.entries(PLACES)) {
    const sources = decoration ? `Lucide ${folder}.svg and ${decoration}.svg` : `Lucide ${folder}.svg`;
    const body = decoration
      ? `${outline(svgBody(lucide(folder)), DECORATED_FILL)}\n<g transform="${GLYPH_TRANSFORM}" fill="none" stroke="${glyph}" stroke-width="${GLYPH_STROKE}" stroke-linecap="round" stroke-linejoin="round">${svgBody(lucide(decoration))}</g>`
      : outline(svgBody(lucide(folder)), PLAIN_FILL);
    out.set(`scalable/places/${name}.svg`, header(sources, 'ISC/MIT, see licenses/LICENSE.lucide') + svg(body));
  }
  for (const [name, source] of Object.entries(DEVICES)) {
    out.set(`scalable/devices/${name}.svg`,
      header(`Lucide ${source}.svg`, 'ISC/MIT, see licenses/LICENSE.lucide') + svg(outline(svgBody(lucide(source)), PLAIN_FILL)));
  }
  const resolved = Object.fromEntries(Object.entries(CATPPUCCIN_COLORS).map(([variable, key]) => [variable, checkContrast(colors, key)]));
  for (const [name, source] of Object.entries(MIMETYPES)) {
    const text = catppuccin(source).replace(/var\(--vscode-ctp-([a-z0-9]+)\)/g, (_, variable) => {
      if (!resolved[variable]) throw new Error(`unmapped Catppuccin variable ${variable} in ${source}`);
      return resolved[variable];
    });
    out.set(`scalable/mimetypes/${name}.svg`, header(`Catppuccin ${source}.svg`, 'MIT, see licenses/LICENSE.catppuccin') + text);
  }

  out.set('licenses/LICENSE.lucide', read(join(here, 'lucide/LICENSE')));
  out.set('licenses/LICENSE.catppuccin', read(join(here, 'catppuccin/LICENSE')));
  out.set('licenses/STRATA-LICENSE', read(join(gtk4, 'STRATA-LICENSE')));
  out.set('index.theme', [
    `# Native icon theme MirrorOS-${theme}: the neutral default-device check and palette-colored folders, file types`,
    '# and devices generated by capabilities/visual/gtk4/icon-sources/generate.mjs; every other name from Adwaita.',
    '[Icon Theme]',
    `Name=MirrorOS-${theme}`,
    'Comment=MirrorOS check, folders, file types and devices over Adwaita',
    'Inherits=Adwaita,hicolor',
    `Directories=${INDEX_SECTIONS.map(([dir]) => dir).join(',')}`,
    ...INDEX_SECTIONS.map(([dir, context, rest]) => `\n[${dir}]\nContext=${context}\n${rest}`),
    '',
  ].join('\n'));
  return out;
}

export const GENERATED_DIRECTORIES = ['scalable/places', 'scalable/mimetypes', 'scalable/devices', 'licenses'];

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const theme = process.argv[2] ?? 'default';
  if (!/^[a-z0-9]+(-[a-z0-9]+)*$/.test(theme)) {
    console.error(`Unsupported theme name: ${theme}`);
    process.exit(6);
  }
  const files = generate(theme);
  const target = join(gtk4, 'icons', theme);
  for (const dir of GENERATED_DIRECTORIES) rmSync(join(target, dir), { recursive: true, force: true });
  for (const [path, content] of files) {
    mkdirSync(dirname(join(target, path)), { recursive: true });
    writeFileSync(join(target, path), content);
  }
  console.log(`icons/${theme}: ${files.size} generated files`);
}
