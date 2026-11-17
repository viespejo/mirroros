<svg xmlns="http://www.w3.org/2000/svg" width="512" height="512" viewBox="0 0 512 512">
  <title>Snapshot Restore</title>
  <desc>Original MirrorOS design study. Two layered snapshot cards and one broad return arrow: recover an earlier system state. Papercraft-inspired palette and hard shadows; not an upstream Papercraft icon.</desc>
  <defs><linearGradient id="main" x1="0" y1="0" x2="1" y2="1"><stop stop-color="{{ icon_main_end }}"/><stop offset="1" stop-color="{{ icon_main }}"/></linearGradient></defs>
  <g transform="translate(256 256) scale(1.1) translate(-256 -256)">
    <rect x="64" y="88" width="384" height="336" rx="28" fill="{{ icon_shadow }}" transform="translate(0 10)"/>
    <rect x="64" y="88" width="384" height="336" rx="28" fill="{{ icon_body }}" stroke="{{ icon_edge }}" stroke-width="4"/>
    <rect x="154" y="146" width="214" height="174" rx="18" fill="{{ icon_edge }}"/>
    <rect x="110" y="202" width="214" height="174" rx="18" fill="{{ icon_shadow }}"/>
    <rect x="110" y="194" width="214" height="174" rx="18" fill="url(#main)"/>
    <path d="M144 232H248M144 264H212" stroke="{{ icon_shadow }}" stroke-width="12" stroke-linecap="round" opacity=".45"/>
    <path d="M292 350C382 350 408 252 350 204" fill="none" stroke="{{ icon_shadow }}" stroke-width="29" stroke-linecap="round" transform="translate(0 8)"/>
    <path d="M292 350C382 350 408 252 350 204" fill="none" stroke="{{ icon_mark }}" stroke-width="25" stroke-linecap="round"/>
    <path d="M346 182L378 232L322 220Z" fill="{{ icon_mark }}"/>
  </g>
</svg>
