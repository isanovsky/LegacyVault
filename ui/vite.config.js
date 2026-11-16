// Tiga halaman HTML: simulasi, penjelasan cara kerja, dan pratinjau karakter.
// Saat `vite` (dev) semua halaman otomatis tersedia; konfigurasi ini dibutuhkan agar
// `vite build` juga menyertakan ketiganya.
import { defineConfig } from "vite";
import { fileURLToPath } from "node:url";

const page = (file) => fileURLToPath(new URL(file, import.meta.url));

export default defineConfig({
  build: {
    rollupOptions: {
      input: {
        main: page("./index.html"),
        penjelasan: page("./penjelasan.html"),
        karakter: page("./karakter.html"),
      },
    },
  },
});
