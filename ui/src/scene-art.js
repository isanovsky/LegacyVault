// Gambar pendukung untuk halaman penjelasan, dalam gaya yang sama dengan karakter:
// garis tinta gelap, sedikit warna lembut, latar kertas. Setiap fungsi mengembalikan teks SVG
// yang diletakkan di dalam satu <svg> adegan (viewBox 0 0 960 440).
import { characterSvg } from "./characters.js";

export const INK = "#1c1a17";
export const MUTED = "#57524a";
export const ACCENT = "#7a1f26";
export const SHADE = "#ece7dc";
export const SOFT = "#fbf9f4";
const GOLD = "#e2c46e";
const STEEL = "#b9c0c4";

const escapeXml = (text) =>
  String(text).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");

/** Teks. `kind`: "title" (serif), "body" (sans), "mono" (alamat dan angka). */
export function label(x, y, text, { size = 14, anchor = "middle", kind = "body", color = INK, id = "", weight = "" } = {}) {
  const idAttr = id ? `id="${id}"` : "";
  const weightAttr = weight ? `font-weight="${weight}"` : "";
  return `<text ${idAttr} x="${x}" y="${y}" font-size="${size}" text-anchor="${anchor}" class="t-${kind}" fill="${color}" ${weightAttr}>${escapeXml(text)}</text>`;
}

/** Sekelompok bagian adegan yang bisa disorot atau disembunyikan per langkah. */
export function part(name, inner, { optional = false } = {}) {
  return `<g data-part="${name}" ${optional ? "data-optional" : ""}>${inner}</g>`;
}

/** Benda yang berpindah antarlangkah (pesan, koin, amplop). Digambar di sekitar titik 0,0. */
export function token(id, inner) {
  return `<g data-part="${id}" data-optional class="token"><g id="${id}" class="token-move">${inner}</g></g>`;
}

/** Penanda kepala panah. Satu adegan cukup memanggilnya sekali di dalam <defs>. */
export function arrowMarker(id) {
  return `<marker id="${id}" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7" orient="auto-start-reverse">
    <path d="M0 0 L10 5 L0 10 Z" fill="${INK}" />
  </marker>`;
}

export function arrow(x1, y1, x2, y2, markerId, { dashed = false } = {}) {
  const dash = dashed ? `stroke-dasharray="5 4"` : "";
  return `<line x1="${x1}" y1="${y1}" x2="${x2}" y2="${y2}" stroke="${INK}" stroke-width="1.6" ${dash} marker-end="url(#${markerId})" />`;
}

/** Kotak berjudul. Judul dan keterangan bisa diganti per langkah lewat id. */
export function box(x, y, w, h, { title, sub = "", fill = SOFT, dashed = false, titleId = "", subId = "", titleTop = false } = {}) {
  const dash = dashed ? `stroke-dasharray="6 5"` : "";
  const ty = titleTop ? y + 24 : y + h / 2 - (sub ? 4 : -5);
  return `<rect x="${x}" y="${y}" width="${w}" height="${h}" rx="3" fill="${fill}" stroke="${INK}" stroke-width="1.6" ${dash} />
    ${label(x + w / 2, ty, title, { size: 17, kind: "title", id: titleId })}
    ${sub ? label(x + w / 2, ty + 20, sub, { size: 12, color: MUTED, id: subId }) : ""}`;
}

/** Kartu kecil seperti lembar catatan. */
export function card(x, y, w, h, title, sub = "") {
  return `<rect x="${x}" y="${y}" width="${w}" height="${h}" rx="2" fill="${SOFT}" stroke="${INK}" stroke-width="1.6" />
    <path d="M${x} ${y + 6} L${x + w} ${y + 6}" stroke="${ACCENT}" stroke-width="3" />
    ${label(x + w / 2, y + h / 2 + 2, title, { size: 16, kind: "title" })}
    ${sub ? label(x + w / 2, y + h / 2 + 22, sub, { size: 12, color: MUTED }) : ""}`;
}

/** Jendela browser sederhana dengan bilah alamat. */
export function browserWindow(x, y, w, h, url) {
  return `<rect x="${x}" y="${y}" width="${w}" height="${h}" rx="4" fill="${SOFT}" stroke="${INK}" stroke-width="1.8" />
    <path d="M${x} ${y + 24} L${x + w} ${y + 24}" stroke="${INK}" stroke-width="1.4" />
    <circle cx="${x + 12}" cy="${y + 12}" r="3.5" fill="${SHADE}" stroke="${INK}" stroke-width="1" />
    <circle cx="${x + 24}" cy="${y + 12}" r="3.5" fill="${SHADE}" stroke="${INK}" stroke-width="1" />
    <rect x="${x + 36}" y="${y + 5}" width="${w - 46}" height="14" rx="2" fill="#fff" stroke="${MUTED}" stroke-width="0.8" />
    ${label(x + 42, y + 16, url, { size: 10, anchor: "start", kind: "mono", color: MUTED })}`;
}

/** Tokoh di dalam adegan. `slot` adalah id agar ekspresinya bisa diganti per langkah. */
export function character(id, x, y, size, slot) {
  return `<g id="${slot}" data-character="${id}" data-size="${size}" transform="translate(${x} ${y})">${characterSvg(id, {
    size,
    decorative: true,
  })}</g>`;
}

/** Brankas: kotak baja dengan roda kombinasi dan pegangan. */
export function vault(x, y, scale = 1) {
  return `<g transform="translate(${x} ${y}) scale(${scale})">
    <rect x="0" y="0" width="130" height="118" rx="6" fill="${STEEL}" stroke="${INK}" stroke-width="2" />
    <rect x="10" y="10" width="110" height="98" rx="3" fill="#cfd5d8" stroke="${INK}" stroke-width="1.6" />
    <circle cx="58" cy="59" r="24" fill="${SOFT}" stroke="${INK}" stroke-width="1.8" />
    <circle cx="58" cy="59" r="6" fill="${ACCENT}" stroke="${INK}" stroke-width="1.4" />
    <path d="M58 37 L58 43 M58 75 L58 81 M36 59 L42 59 M74 59 L80 59" stroke="${INK}" stroke-width="1.6" />
    <rect x="96" y="44" width="10" height="30" rx="3" fill="${GOLD}" stroke="${INK}" stroke-width="1.5" />
    <rect x="14" y="118" width="18" height="8" fill="${INK}" /><rect x="98" y="118" width="18" height="8" fill="${INK}" />
  </g>`;
}

/** Landasan tempa (anvil): lambang program Anvil, "bengkel" tempat blok ditempa. */
export function anvilIcon(x, y, scale = 1) {
  return `<g transform="translate(${x} ${y}) scale(${scale})">
    <path d="M0 6 L46 6 Q60 6 64 0 L64 14 Q52 18 44 18 L38 18 L38 26 L46 34 L10 34 L18 26 L18 18 L8 18 Q0 14 0 6 Z"
          fill="#5d5a55" stroke="${INK}" stroke-width="1.6" stroke-linejoin="round" />
    <rect x="6" y="34" width="44" height="6" fill="${INK}" />
  </g>`;
}

/** Deretan blok yang saling terhubung, berlabel nomor. */
export function blocks(x, y, count, { start = 1 } = {}) {
  let out = "";
  for (let i = 0; i < count; i++) {
    const bx = x + i * 52;
    if (i > 0) out += `<path d="M${bx - 18} ${y + 17} L${bx} ${y + 17}" stroke="${INK}" stroke-width="1.6" />`;
    out += `<rect x="${bx}" y="${y}" width="34" height="34" rx="2" fill="${SHADE}" stroke="${INK}" stroke-width="1.6" />`;
    out += label(bx + 17, y + 22, `#${start + i}`, { size: 11, kind: "mono" });
  }
  return out;
}

/** Satu blok tunggal, misalnya blok baru yang muncul. */
export function singleBlock(x, y, number) {
  return `<path d="M${x - 18} ${y + 17} L${x} ${y + 17}" stroke="${INK}" stroke-width="1.6" />
    <rect x="${x}" y="${y}" width="34" height="34" rx="2" fill="${GOLD}" stroke="${INK}" stroke-width="2" />
    ${label(x + 17, y + 22, `#${number}`, { size: 11, kind: "mono" })}`;
}

/** Koin ETH di sekitar titik 0,0. */
export function coin(dx = 0, dy = 0) {
  return `<g transform="translate(${dx} ${dy})">
    <circle r="13" fill="${GOLD}" stroke="${INK}" stroke-width="1.6" />
    <circle r="9" fill="none" stroke="${INK}" stroke-width="0.8" />
    <path d="M0 -6 L4 0 L0 6 L-4 0 Z" fill="${INK}" />
  </g>`;
}

/** Amplop di sekitar titik 0,0, dengan tulisan jumlah. */
export function envelope(text) {
  return `<rect x="-34" y="-20" width="68" height="40" rx="2" fill="${SOFT}" stroke="${INK}" stroke-width="1.6" />
    <path d="M-34 -20 L0 4 L34 -20" fill="none" stroke="${INK}" stroke-width="1.4" />
    <circle cx="0" cy="4" r="5" fill="${ACCENT}" stroke="${INK}" stroke-width="1" />
    ${label(0, 34, text, { size: 13, kind: "mono", weight: "700" })}`;
}

/** Pesan kecil (amplop surat) di sekitar titik 0,0, untuk perjalanan data. */
export function message() {
  return `<rect x="-16" y="-11" width="32" height="22" rx="2" fill="#fff" stroke="${INK}" stroke-width="1.6" />
    <path d="M-16 -11 L0 2 L16 -11" fill="none" stroke="${ACCENT}" stroke-width="1.6" />`;
}

/** Dokumen kode dengan sudut terlipat. */
export function documentIcon(x, y, title) {
  return `<g transform="translate(${x} ${y})">
    <path d="M0 0 L82 0 L104 22 L104 136 L0 136 Z" fill="${SOFT}" stroke="${INK}" stroke-width="1.8" />
    <path d="M82 0 L82 22 L104 22" fill="${SHADE}" stroke="${INK}" stroke-width="1.4" />
    <path d="M12 40 L70 40 M12 54 L88 54 M22 68 L80 68 M22 82 L62 82 M12 96 L84 96 M12 110 L50 110" stroke="${MUTED}" stroke-width="1.6" />
    <path d="M12 40 L30 40" stroke="${ACCENT}" stroke-width="2" />
  </g>
  ${label(x + 52, y + 156, title, { size: 13, kind: "mono" })}`;
}

/** Jam pasir: masa tunggu (timelock). */
export function hourglass(x, y) {
  return `<g transform="translate(${x} ${y})">
    <rect x="0" y="0" width="48" height="6" fill="#8a6b46" stroke="${INK}" stroke-width="1.4" />
    <rect x="0" y="66" width="48" height="6" fill="#8a6b46" stroke="${INK}" stroke-width="1.4" />
    <path d="M6 6 L42 6 Q42 26 26 36 Q42 46 42 66 L6 66 Q6 46 22 36 Q6 26 6 6 Z" fill="${SOFT}" stroke="${INK}" stroke-width="1.6" />
    <path d="M14 14 L34 14 Q30 26 24 30 Q18 26 14 14 Z" fill="${GOLD}" />
    <path d="M12 62 Q24 50 36 62 Z" fill="${GOLD}" />
  </g>`;
}

/** Cap stempel bertuliskan kata, sedikit miring. */
export function stampMark(x, y, text, { rotate = -8 } = {}) {
  const w = text.length * 10 + 18;
  return `<g transform="translate(${x} ${y}) rotate(${rotate})">
    <rect x="${-w / 2}" y="-14" width="${w}" height="28" rx="2" fill="none" stroke="${ACCENT}" stroke-width="2.5" />
    <rect x="${-w / 2 + 4}" y="-10" width="${w - 8}" height="20" rx="1" fill="none" stroke="${ACCENT}" stroke-width="1" />
    ${label(0, 5, text, { size: 13, color: ACCENT, weight: "700" })}
  </g>`;
}

/** Gelembung ucapan dengan ekor di kiri atas, diletakkan di bawah tokoh yang berbicara. */
export function bubble(x, y, w, h, lines, { tone = "biasa" } = {}) {
  const stroke = tone === "tolak" ? ACCENT : INK;
  const text = lines.map((line, i) => label(x + 14, y + 24 + i * 18, line, { size: 13, anchor: "start" })).join("");
  return `<path d="M${x} ${y} L${x + 40} ${y} L${x + 52} ${y - 14} L${x + 60} ${y} L${x + w} ${y} L${x + w} ${y + h} L${x} ${y + h} Z"
          fill="#fff" stroke="${stroke}" stroke-width="2" stroke-linejoin="round" />
    ${text}`;
}
