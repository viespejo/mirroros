<svg xmlns="http://www.w3.org/2000/svg" width="512" height="512" viewBox="0 0 512 512">
  <title>Widget Factory</title>
  <desc>Original MirrorOS design study. A small widget showcase: one checked box, one text field and one raised toggle. Papercraft-inspired palette and hard shadows; not an upstream Papercraft icon.</desc>
  <defs><linearGradient id="main" x1="0" y1="0" x2="1" y2="1"><stop stop-color="{{ icon_main_end }}"/><stop offset="1" stop-color="{{ icon_main }}"/></linearGradient></defs>
  <g transform="translate(256 256) scale(1.1) translate(-256 -256)">
    <rect x="64" y="88" width="384" height="336" rx="28" fill="{{ icon_shadow }}" transform="translate(0 10)"/>
    <rect x="64" y="88" width="384" height="336" rx="28" fill="{{ icon_body }}" stroke="{{ icon_edge }}" stroke-width="4"/>
    <rect x="106" y="144" width="72" height="72" rx="14" fill="{{ icon_shadow }}"/>
    <rect x="106" y="136" width="72" height="72" rx="14" fill="{{ icon_mark }}"/>
    <path d="M122 170L138 186L164 156" fill="none" stroke="{{ icon_shadow }}" stroke-width="10" stroke-linecap="round" stroke-linejoin="round"/>
    <rect x="204" y="148" width="196" height="48" rx="12" fill="{{ icon_edge }}"/>
    <rect x="106" y="248" width="294" height="20" rx="10" fill="{{ icon_ink }}"/>
    <rect x="106" y="306" width="180" height="62" rx="31" fill="url(#main)"/>
    <circle cx="253" cy="337" r="23" fill="{{ icon_paper }}"/>
    <rect x="314" y="316" width="86" height="42" rx="12" fill="{{ icon_edge }}"/>
  </g>
</svg>
