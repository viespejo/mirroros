<svg xmlns="http://www.w3.org/2000/svg" width="512" height="512" viewBox="0 0 512 512">
  <title>Node Editor</title>
  <desc>Original MirrorOS design study. Three raised nodes joined by two clear connections, expressing a small editable graph. Papercraft-inspired palette and hard shadows; not an upstream Papercraft icon.</desc>
  <defs><linearGradient id="main" x1="0" y1="0" x2="1" y2="1"><stop stop-color="{{ icon_main_end }}"/><stop offset="1" stop-color="{{ icon_main }}"/></linearGradient></defs>
  <g transform="translate(256 256) scale(1.1) translate(-256 -256)">
    <path d="M256 176V240H144V296M256 240H368V296" fill="none" stroke="{{ icon_edge }}" stroke-width="16" stroke-linecap="round" stroke-linejoin="round"/>
    <rect x="208" y="96" width="96" height="100" rx="18" fill="{{ icon_shadow }}"/>
    <rect x="208" y="88" width="96" height="100" rx="18" fill="{{ icon_mark }}"/>
    <rect x="88" y="300" width="112" height="112" rx="20" fill="{{ icon_shadow }}"/>
    <rect x="88" y="292" width="112" height="112" rx="20" fill="url(#main)"/>
    <rect x="312" y="300" width="112" height="112" rx="20" fill="{{ icon_shadow }}"/>
    <rect x="312" y="292" width="112" height="112" rx="20" fill="{{ icon_ink }}"/>
  </g>
</svg>
