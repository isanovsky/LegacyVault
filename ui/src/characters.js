// Ilustrasi enam tokoh demo dalam gaya "tinta notaris": garis tinta gelap dan sedikit warna
// lembut yang serasi dengan latar kertas. Semua digambar dengan SVG biasa, tanpa file gambar luar.
//
// Setiap tokoh punya empat ekspresi supaya gambar ikut memberi informasi:
//   netral  : keadaan biasa
//   senang  : misalnya ahli waris menerima bagian
//   lega    : misalnya pemilik membatalkan klaim yang keliru
//   cemas   : misalnya transaksi ditolak atau klaim dimulai terhadap pemilik
//
// Pemakaian: characterSvg("icanov", { expression: "senang", size: 96 })
// menghasilkan teks <svg> yang bisa dimasukkan ke halaman.

const INK = "#1c1a17";
const SKIN = "#f1d9bf";
const SKIN_SHADE = "#e3c3a3";
const BLUSH = "#e7aaa0";
const ACCENT = "#7a1f26";
const PAPER = "#f6f3ec";
const FRAME = "#ece7dc";

export const EXPRESSIONS = ["netral", "senang", "lega", "cemas"];

const EXPRESSION_LABELS = {
  netral: "biasa",
  senang: "senang",
  lega: "lega",
  cemas: "cemas",
};

// ---------------------------------------------------------------------------
// Bagian wajah yang dipakai bersama
// ---------------------------------------------------------------------------

/** Mata, alis, pipi, dan mulut sesuai ekspresi. `browStyle` "tebal" untuk alis tebal. */
function face(expression, { browStyle = "biasa", eyeY = 53 } = {}) {
  const browWidth = browStyle === "tebal" ? 3 : 1.8;
  let brows;
  if (expression === "cemas") {
    // Alis naik di tengah: tanda khawatir.
    brows = `<path d="M45 ${eyeY - 9} L55 ${eyeY - 11}" /><path d="M65 ${eyeY - 11} L75 ${eyeY - 9}" />`;
  } else {
    brows = `<path d="M45 ${eyeY - 9} Q50 ${eyeY - 12} 55 ${eyeY - 9}" /><path d="M65 ${eyeY - 9} Q70 ${eyeY - 12} 75 ${eyeY - 9}" />`;
  }

  let eyes;
  if (expression === "lega") {
    // Mata terpejam melengkung: tersenyum lega.
    eyes = `<path d="M47 ${eyeY} Q50.5 ${eyeY - 3.5} 54 ${eyeY}" fill="none" />` +
      `<path d="M66 ${eyeY} Q69.5 ${eyeY - 3.5} 73 ${eyeY}" fill="none" />`;
  } else {
    eyes = `<circle cx="50.5" cy="${eyeY}" r="2.3" fill="${INK}" stroke="none" />` +
      `<circle cx="69.5" cy="${eyeY}" r="2.3" fill="${INK}" stroke="none" />`;
  }

  const mouths = {
    netral: `<path d="M55 66 Q60 67.5 65 66" fill="none" />`,
    senang: `<path d="M52.5 63.5 Q60 72 67.5 63.5 Z" fill="${ACCENT}" fill-opacity="0.85" />`,
    lega: `<path d="M54 65 Q60 69.5 66 65" fill="none" />`,
    cemas: `<path d="M54.5 68 Q60 63.5 65.5 68" fill="none" />`,
  };

  const blush =
    expression === "senang" || expression === "lega"
      ? `<ellipse cx="45" cy="61" rx="4" ry="2.4" fill="${BLUSH}" stroke="none" opacity="0.8" />` +
        `<ellipse cx="75" cy="61" rx="4" ry="2.4" fill="${BLUSH}" stroke="none" opacity="0.8" />`
      : "";

  const sweat =
    expression === "cemas"
      ? `<path d="M80 40 Q83 46 80 48 Q77 46 80 40 Z" fill="#c7d7e3" stroke="${INK}" stroke-width="1" />`
      : "";

  return `<g fill="none" stroke="${INK}" stroke-linecap="round" stroke-width="1.8">
    <g stroke-width="${browWidth}">${brows}</g>
    ${eyes}
    ${blush}
    <path d="M60 56 Q62.5 60 59.5 61" fill="none" stroke-width="1.5" />
    ${mouths[expression] ?? mouths.netral}
    ${sweat}
  </g>`;
}

/** Bahu dan badan; `clothes` warna baju. */
function torso(clothes) {
  // Badan dibuat memanjang melewati bingkai; bagian yang keluar lingkaran terpotong otomatis.
  return `<path d="M14 140 L16 118 C18 96 34 84 60 84 C86 84 102 96 104 118 L106 140 Z" fill="${clothes}" stroke="${INK}" stroke-width="1.8" />`;
}

/** Leher, telinga, dan kepala. */
function head() {
  return `
    <path d="M52 72 L52 86 Q60 90 68 86 L68 72 Z" fill="${SKIN_SHADE}" stroke="${INK}" stroke-width="1.6" />
    <ellipse cx="37" cy="56" rx="4.5" ry="6" fill="${SKIN}" stroke="${INK}" stroke-width="1.6" />
    <ellipse cx="83" cy="56" rx="4.5" ry="6" fill="${SKIN}" stroke="${INK}" stroke-width="1.6" />
    <ellipse cx="60" cy="53" rx="23" ry="25" fill="${SKIN}" stroke="${INK}" stroke-width="1.8" />`;
}

function squareGlasses() {
  return `<g fill="none" stroke="${INK}" stroke-width="1.8">
    <rect x="43" y="47" width="15" height="12" rx="1.5" fill="${PAPER}" fill-opacity="0.25" />
    <rect x="62" y="47" width="15" height="12" rx="1.5" fill="${PAPER}" fill-opacity="0.25" />
    <path d="M58 52 L62 52" /><path d="M43 51 L38 49" /><path d="M77 51 L82 49" />
  </g>`;
}

function roundGlasses() {
  return `<g fill="none" stroke="${INK}" stroke-width="1.7">
    <circle cx="50.5" cy="53" r="7" fill="${PAPER}" fill-opacity="0.25" />
    <circle cx="69.5" cy="53" r="7" fill="${PAPER}" fill-opacity="0.25" />
    <path d="M57.5 52 Q60 50 62.5 52" /><path d="M43.5 52 L38 50" /><path d="M76.5 52 L82 50" />
  </g>`;
}

/** Kemeja putih berkerah V dengan dasi marun, dipakai di atas jas. */
function shirtAndTie(withTie = true) {
  const tie = withTie
    ? `<path d="M60 89 L56.5 94 L60 116 L63.5 94 Z" fill="${ACCENT}" stroke="${INK}" stroke-width="1.4" />`
    : "";
  return `<path d="M48 86 L60 104 L72 86 Q60 92 48 86 Z" fill="#fbf9f4" stroke="${INK}" stroke-width="1.5" />${tie}`;
}

// ---------------------------------------------------------------------------
// Enam tokoh
// ---------------------------------------------------------------------------

const DRAWINGS = {
  // Pemilik: topi fedora, kacamata kotak, kumis, jas cokelat, kunci brankas di saku.
  icanov: (expression) => `
    ${torso("#b39468")}
    <path d="M36 90 L50 124 M84 90 L70 124" stroke="${INK}" stroke-width="1.4" fill="none" />
    ${shirtAndTie()}
    <g transform="translate(74 98) rotate(-30)">
      <circle cx="0" cy="0" r="6" fill="#e2c46e" stroke="${INK}" stroke-width="1.6" />
      <circle cx="0" cy="0" r="2.2" fill="#b39468" stroke="${INK}" stroke-width="1.2" />
      <rect x="5.5" y="-1.8" width="16" height="3.6" rx="1" fill="#e2c46e" stroke="${INK}" stroke-width="1.4" />
      <path d="M16 1.8 L16 6 L19 6 L19 1.8 M12 1.8 L12 4.5 L14.5 4.5 L14.5 1.8" fill="#e2c46e" stroke="${INK}" stroke-width="1.3" stroke-linejoin="round" />
    </g>
    ${head()}
    <path d="M37.5 50 Q37 40 42 36 L44 46 Z" fill="#9b968c" stroke="${INK}" stroke-width="1.4" />
    <path d="M82.5 50 Q83 40 78 36 L76 46 Z" fill="#9b968c" stroke="${INK}" stroke-width="1.4" />
    ${face(expression)}
    <path d="M51 62.5 Q55.5 59.5 60 61.5 Q64.5 59.5 69 62.5 Q64.5 64.5 60 63 Q55.5 64.5 51 62.5 Z" fill="#8f897f" stroke="${INK}" stroke-width="1.3" />
    ${squareGlasses()}
    <path d="M40 35 Q41 17 60 16 Q79 17 80 35 Z" fill="#6d5843" stroke="${INK}" stroke-width="1.8" />
    <path d="M52 19 Q60 23 68 19" stroke="${INK}" stroke-width="1.4" fill="none" />
    <rect x="40.5" y="29" width="39" height="5" fill="${ACCENT}" stroke="${INK}" stroke-width="1.4" />
    <ellipse cx="60" cy="35" rx="31" ry="5" fill="#6d5843" stroke="${INK}" stroke-width="1.8" />`,

  // Ahli waris: rambut jabrik, hoodie hijau sage, tali tas selempang.
  kevin: (expression) => `
    ${torso("#b5c6a6")}
    <path d="M44 86 Q60 98 76 86" fill="none" stroke="${INK}" stroke-width="1.5" />
    <path d="M55 93 L54 104 M65 93 L66 104" stroke="${INK}" stroke-width="1.4" fill="none" stroke-linecap="round" />
    <path d="M30 94 L86 124" stroke="#8a6b46" stroke-width="5" stroke-linecap="round" />
    <path d="M30 94 L86 124" stroke="${INK}" stroke-width="0.9" stroke-dasharray="2 3" />
    ${head()}
    <path d="M36 50 L37 38 L42 41 L44 29 L50 35 L54 25 L60 33 L65 24 L69 33 L75 28 L77 39 L83 37 L84 50
             Q80 38 60 37 Q40 38 36 50 Z" fill="#3d3027" stroke="${INK}" stroke-width="1.6" stroke-linejoin="round" />
    ${face(expression)}`,

  // Ahli waris: rambut belah samping bergelombang, kemeja biru lembut, tas kecil.
  murni: (expression) => `
    ${torso("#b8c8d7")}
    <path d="M47 86 L54 96 L60 88 L66 96 L73 86" fill="none" stroke="${INK}" stroke-width="1.5" stroke-linejoin="round" />
    <path d="M60 96 L60 124" stroke="${INK}" stroke-width="1.2" />
    <circle cx="60" cy="104" r="1.2" fill="${INK}" /><circle cx="60" cy="114" r="1.2" fill="${INK}" />
    <path d="M90 94 L34 124" stroke="#7d5f3f" stroke-width="5" stroke-linecap="round" />
    ${head()}
    <path d="M35 54 Q33 30 54 27 Q76 25 84 44 Q86 52 84 56 Q80 42 70 40 Q62 46 46 42 Q40 46 38 56 Z"
          fill="#4b3a2c" stroke="${INK}" stroke-width="1.6" stroke-linejoin="round" />
    <path d="M50 30 Q58 34 70 31" stroke="#6d5644" stroke-width="1.4" fill="none" />
    ${face(expression)}`,

  // Guardian: rambut cepak, alis tebal, jaket abu-abu, tangan bersedekap.
  barrok: (expression) => `
    ${torso("#8f9ba4")}
    <path d="M46 85 L54 100 L60 90 L66 100 L74 85" fill="#6f7a83" stroke="${INK}" stroke-width="1.5" stroke-linejoin="round" />
    <path d="M28 110 L80 97" stroke="${INK}" stroke-width="14" stroke-linecap="round" />
    <path d="M28 110 L80 97" stroke="#7d8992" stroke-width="11" stroke-linecap="round" />
    <circle cx="82" cy="96.5" r="5" fill="${SKIN}" stroke="${INK}" stroke-width="1.5" />
    <path d="M92 110 L40 97" stroke="${INK}" stroke-width="14" stroke-linecap="round" />
    <path d="M92 110 L40 97" stroke="#86929b" stroke-width="11" stroke-linecap="round" />
    <circle cx="38" cy="96.5" r="5" fill="${SKIN}" stroke="${INK}" stroke-width="1.5" />
    ${head()}
    <path d="M37.5 48 Q38 29 60 28 Q82 29 82.5 48 Q78 36 60 35 Q42 36 37.5 48 Z" fill="#2e2823" stroke="${INK}" stroke-width="1.5" />
    ${face(expression, { browStyle: "tebal" })}`,

  // Guardian: notaris berkacamata bulat, jas biru tua, dasi, memegang stempel.
  budi: (expression) => `
    ${torso("#5f6d7c")}
    <path d="M36 90 L50 124 M84 90 L70 124" stroke="${INK}" stroke-width="1.4" fill="none" />
    ${shirtAndTie()}
    <g transform="translate(82 94)">
      <rect x="-4" y="-2" width="8" height="12" rx="2" fill="#8a6b46" stroke="${INK}" stroke-width="1.4" />
      <circle cx="0" cy="-5" r="5" fill="#8a6b46" stroke="${INK}" stroke-width="1.4" />
      <rect x="-8" y="10" width="16" height="5" rx="1" fill="${ACCENT}" stroke="${INK}" stroke-width="1.4" />
    </g>
    ${head()}
    <path d="M37 54 Q35 42 41 37 Q42 46 45 50 Z" fill="#a7a197" stroke="${INK}" stroke-width="1.4" />
    <path d="M83 54 Q85 42 79 37 Q78 46 75 50 Z" fill="#a7a197" stroke="${INK}" stroke-width="1.4" />
    <path d="M53 31 Q60 29 67 31" stroke="${INK}" stroke-width="1.2" fill="none" />
    ${face(expression)}
    ${roundGlasses()}`,

  // Guardian: Pak RT berpeci, kumis tebal, baju batik, memegang papan pengumuman.
  wowo: (expression) => `
    ${torso("#d8b678")}
    <g stroke="${INK}" stroke-width="1.1" fill="none">
      <path d="M28 104 q4 -4 8 0 q4 4 8 0" /><path d="M76 104 q4 -4 8 0 q4 4 8 0" />
      <path d="M46 116 q4 -4 8 0 q4 4 8 0 q4 -4 8 0" />
    </g>
    <circle cx="40" cy="96" r="1.6" fill="${ACCENT}" /><circle cx="80" cy="96" r="1.6" fill="${ACCENT}" />
    <path d="M50 86 L60 94 L70 86" fill="none" stroke="${INK}" stroke-width="1.5" />
    <g transform="translate(24 92) rotate(-8)">
      <rect x="0" y="0" width="24" height="18" rx="1.5" fill="#fbf9f4" stroke="${INK}" stroke-width="1.5" />
      <path d="M4 6 L20 6 M4 10 L17 10 M4 14 L14 14" stroke="${INK}" stroke-width="1.2" />
      <circle cx="12" cy="1" r="1.6" fill="${ACCENT}" stroke="${INK}" stroke-width="0.8" />
    </g>
    ${head()}
    ${face(expression)}
    <path d="M48.5 62 Q54 57.5 60 60.5 Q66 57.5 71.5 62 Q66 66 60 63 Q54 66 48.5 62 Z" fill="#2e2823" stroke="${INK}" stroke-width="1.2" />
    <path d="M40 38 L42 21 Q60 17 78 21 L80 38 Q60 34 40 38 Z" fill="#26221d" stroke="${INK}" stroke-width="1.6" />
    <path d="M42 23 Q60 19.5 78 23" stroke="#5a544b" stroke-width="1" fill="none" />`,
};

export const CHARACTERS = {
  icanov: { name: "Pak Icanov", role: "pemilik", note: "Topi, kacamata kotak, kunci brankas" },
  kevin: { name: "Mas Kevin", role: "ahli waris 60%", note: "Rambut jabrik, hoodie, tas selempang" },
  murni: { name: "Mas Murni", role: "ahli waris 40%", note: "Rambut belah samping, kemeja, tas selempang" },
  barrok: { name: "Mas Barrok", role: "guardian", note: "Rambut cepak, jaket, tangan bersedekap" },
  budi: { name: "Notaris Budi", role: "guardian", note: "Kacamata bulat, jas, stempel" },
  wowo: { name: "Pak RT Wowo", role: "guardian", note: "Peci, kumis tebal, batik, papan pengumuman" },
};

let uniqueId = 0;

/**
 * Teks SVG untuk satu tokoh.
 * @param {string} id kunci di CHARACTERS
 * @param {{expression?: string, size?: number, decorative?: boolean}} options
 *   decorative: true jika nama tokoh sudah tertulis di sebelahnya, supaya pembaca layar tidak
 *   membacakannya dua kali.
 */
export function characterSvg(id, { expression = "netral", size = 96, decorative = false } = {}) {
  const draw = DRAWINGS[id];
  if (!draw) throw new Error(`Tokoh tidak dikenal: ${id}`);
  const clipId = `frame-${id}-${uniqueId++}`;
  const label = `${CHARACTERS[id].name}, ekspresi ${EXPRESSION_LABELS[expression] ?? expression}`;
  const a11y = decorative ? `aria-hidden="true"` : `role="img" aria-label="${label}"`;

  return `<svg class="character" viewBox="0 0 120 120" width="${size}" height="${size}" ${a11y} xmlns="http://www.w3.org/2000/svg">
    <defs><clipPath id="${clipId}"><circle cx="60" cy="60" r="57" /></clipPath></defs>
    <circle cx="60" cy="60" r="57" fill="${FRAME}" />
    <g clip-path="url(#${clipId})">
      <g transform="translate(60 57) scale(0.9) translate(-60 -60)">${draw(expression)}</g>
    </g>
    <circle cx="60" cy="60" r="57" fill="none" stroke="${INK}" stroke-width="2" />
  </svg>`;
}
