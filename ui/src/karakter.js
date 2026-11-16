// Halaman pratinjau karakter: menampilkan setiap tokoh dalam semua ekspresi dan ukuran.
import "./style.css";
import { CHARACTERS, EXPRESSIONS, characterSvg } from "./characters.js";

const rows = Object.entries(CHARACTERS).map(([id, character]) => {
  const expressions = EXPRESSIONS.map((expression) => `<td>${characterSvg(id, { expression, size: 104 })}</td>`).join("");
  return `<tr>
    <th scope="row">
      <span class="sheet-name">${character.name}</span>
      <span class="sheet-role">${character.role}</span>
      <span class="sheet-note">${character.note}</span>
    </th>
    ${expressions}
    <td class="sheet-small">
      ${characterSvg(id, { size: 32 })}
      ${characterSvg(id, { size: 24 })}
    </td>
  </tr>`;
});

document.getElementById("sheet").innerHTML = rows.join("");
