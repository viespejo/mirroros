<svg xmlns="http://www.w3.org/2000/svg" width="512" height="512" viewBox="0 0 512 512">
  <title>Print Editor</title>
  <desc>Original MirrorOS design study. A light page with a folded corner and a raised pencil, using the shared palette roles. Papercraft-inspired palette and hard shadows; not an upstream Papercraft icon.</desc>
  <defs><linearGradient id="main" x1="0" y1="0" x2="1" y2="1"><stop stop-color="{{ icon_main_end }}"/><stop offset="1" stop-color="{{ icon_main }}"/></linearGradient></defs>
  <g transform="translate(256 256) scale(1.1) translate(-256 -256)">
    <path d="M120 76H318L390 148V426H120Z" fill="{{ icon_shadow }}" transform="translate(0 10)"/>
    <path d="M120 76H318L390 148V426H120Z" fill="{{ icon_paper }}"/>
    <path d="M318 76V148H390Z" fill="{{ icon_ink }}"/>
    <path d="M160 184H310M160 222H286M160 260H240" stroke="{{ icon_edge }}" stroke-width="14" stroke-linecap="round"/>
    <g transform="rotate(35 332 314)">
      <rect x="310" y="220" width="44" height="164" rx="8" fill="{{ icon_shadow }}"/>
      <rect x="306" y="210" width="44" height="164" rx="8" fill="url(#main)"/>
      <path d="M306 366H350L328 410Z" fill="{{ icon_mark }}"/>
      <path d="M319 394L328 410L337 394Z" fill="{{ icon_shadow }}"/>
    </g>
  </g>
</svg>
