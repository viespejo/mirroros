<svg xmlns="http://www.w3.org/2000/svg" width="512" height="512" viewBox="0 0 512 512">
  <title>CMake</title>
  <desc>Original MirrorOS design study. A three-faced triangular build mark in the MirrorOS palette; a new geometric study referencing the recognizable triangular CMake identity. Papercraft-inspired palette and hard shadows; not an upstream Papercraft icon.</desc>
  <defs><linearGradient id="main" x1="0" y1="0" x2="1" y2="1"><stop stop-color="{{ icon_main_end }}"/><stop offset="1" stop-color="{{ icon_main }}"/></linearGradient></defs>
  <g transform="translate(256 256) scale(1.1) translate(-256 -256)">
    <path d="M256 64L76 434H436Z" fill="{{ icon_shadow }}" transform="translate(0 10)"/>
    <path d="M256 64L76 434L256 302Z" fill="url(#main)"/>
    <path d="M256 64L256 302L436 434Z" fill="{{ icon_mark }}"/>
    <path d="M76 434L256 302L436 434Z" fill="{{ icon_paper }}"/>
    <path d="M256 64V302L76 434M256 302L436 434" fill="none" stroke="{{ icon_shadow }}" stroke-width="6" stroke-linejoin="round"/>
  </g>
</svg>
