<svg xmlns="http://www.w3.org/2000/svg" width="512" height="512" viewBox="0 0 512 512">
  <title>Software Token</title>
  <desc>Original MirrorOS design study. A physical security token with a key loop, a six-place code display and one activation button. Papercraft-inspired palette and hard shadows; not an upstream Papercraft icon.</desc>
  <defs><linearGradient id="main" x1="0" y1="0" x2="1" y2="1"><stop stop-color="{{ icon_main_end }}"/><stop offset="1" stop-color="{{ icon_main }}"/></linearGradient></defs>
  <g transform="translate(256 256) scale(1.1) translate(-256 -256)">
    <circle cx="256" cy="90" r="38" fill="none" stroke="{{ icon_edge }}" stroke-width="18"/>
    <rect x="106" y="124" width="300" height="296" rx="48" fill="{{ icon_shadow }}"/>
    <rect x="106" y="116" width="300" height="296" rx="48" fill="{{ icon_body }}"/>
    <rect x="106" y="116" width="300" height="296" rx="48" fill="none" stroke="{{ icon_edge }}" stroke-width="4"/>
    <rect x="132" y="180" width="248" height="92" rx="16" fill="url(#main)"/>
    <path d="M160 204V248M198 204V248M236 204V248M274 204V248M312 204V248M350 204V248" stroke="{{ icon_shadow }}" stroke-width="14" stroke-linecap="round"/>
    <circle cx="256" cy="340" r="28" fill="{{ icon_shadow }}" transform="translate(0 7)"/>
    <circle cx="256" cy="340" r="28" fill="{{ icon_mark }}"/>
  </g>
</svg>
