<svg xmlns="http://www.w3.org/2000/svg" width="512" height="512" viewBox="0 0 512 512">
  <title>GTK Demo</title>
  <desc>Original MirrorOS design study. A simple three-faced demonstration cube, referencing GTK Demo's familiar cube without importing its packaged artwork. Papercraft-inspired palette and hard shadows; not an upstream Papercraft icon.</desc>
  <defs><linearGradient id="main" x1="0" y1="0" x2="1" y2="1"><stop stop-color="{{ icon_main_end }}"/><stop offset="1" stop-color="{{ icon_main }}"/></linearGradient></defs>
  <g transform="translate(256 256) scale(1.1) translate(-256 -256)">
    <path d="M256 82L422 168V346L256 434L90 346V168Z" fill="{{ icon_shadow }}" transform="translate(0 10)"/>
    <path d="M256 82L422 168L256 258L90 168Z" fill="{{ icon_paper }}"/>
    <path d="M90 168L256 258V434L90 346Z" fill="url(#main)"/>
    <path d="M256 258L422 168V346L256 434Z" fill="{{ icon_mark }}"/>
    <path d="M90 168L256 258L422 168M256 258V434" fill="none" stroke="{{ icon_shadow }}" stroke-width="6" stroke-linejoin="round"/>
  </g>
</svg>
