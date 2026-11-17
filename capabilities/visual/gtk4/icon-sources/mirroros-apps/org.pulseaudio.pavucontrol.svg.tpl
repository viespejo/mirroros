<svg xmlns="http://www.w3.org/2000/svg" width="512" height="512" viewBox="0 0 512 512">
  <title>Volume Control</title>
  <desc>Original MirrorOS study: a compact audio mixer with three raised fader caps. Papercraft-inspired hard shadows and palette roles; not an upstream Papercraft icon.</desc>
  <defs>
    <linearGradient id="fader" x1="0" y1="0" x2="1" y2="1">
      <stop stop-color="{{ icon_main_end }}"/>
      <stop offset="1" stop-color="{{ icon_main }}"/>
    </linearGradient>
  </defs>
  <g transform="translate(256 256) scale(1.1) translate(-256 -256)">
    <!-- Mixer enclosure and its single hard shadow. -->
    <rect x="64" y="88" width="384" height="336" rx="28" fill="{{ icon_shadow }}" transform="translate(0 10)"/>
    <rect x="64" y="88" width="384" height="336" rx="28" fill="{{ icon_body }}" stroke="{{ icon_edge }}" stroke-width="4"/>
    <!-- Three independent channel rails, with different gain settings. -->
    <path d="M144 136V376M256 136V376M368 136V376" stroke="{{ icon_edge }}" stroke-width="12" stroke-linecap="round"/>
    <path d="M144 248V376M256 182V376M368 314V376" stroke="{{ icon_main }}" stroke-width="12" stroke-linecap="round"/>
    <!-- Raised fader caps: one deliberately highlighted channel. -->
    <rect x="109" y="224" width="70" height="48" rx="10" fill="{{ icon_shadow }}" transform="translate(0 7)"/>
    <rect x="109" y="224" width="70" height="48" rx="10" fill="url(#fader)"/>
    <path d="M123 248H165" stroke="{{ icon_shadow }}" stroke-width="7" stroke-linecap="round" opacity=".55"/>
    <rect x="221" y="158" width="70" height="48" rx="10" fill="{{ icon_shadow }}" transform="translate(0 7)"/>
    <rect x="221" y="158" width="70" height="48" rx="10" fill="{{ icon_mark }}"/>
    <path d="M235 182H277" stroke="{{ icon_shadow }}" stroke-width="7" stroke-linecap="round" opacity=".55"/>
    <rect x="333" y="290" width="70" height="48" rx="10" fill="{{ icon_shadow }}" transform="translate(0 7)"/>
    <rect x="333" y="290" width="70" height="48" rx="10" fill="url(#fader)"/>
    <path d="M347 314H389" stroke="{{ icon_shadow }}" stroke-width="7" stroke-linecap="round" opacity=".55"/>
  </g>
</svg>
