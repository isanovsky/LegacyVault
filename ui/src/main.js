// Mengatur tampilan: membaca keadaan vault dari chain.js lalu mengisi tiga kolom.
// Tombol, input, dan pemilih tokoh dibuat sekali saja. Setiap blok baru hanya mengubah
// teks dan status tombol, supaya fokus keyboard dan isian pengguna tidak hilang.
import "./style.css";
import * as chain from "./chain.js";
import { DEMO_ACCOUNTS, nameOf } from "./demo-accounts.js";
import { describeError } from "./errors.js";
import {
  STATE_DESCRIPTIONS,
  STATE_NAMES,
  formatDate,
  formatDateShort,
  formatDuration,
  formatEth,
  formatEthApprox,
  formatPercent,
  parseEthInput,
  shortAddress,
  shortHash,
} from "./format.js";

const ACTIVE = 0;
const CLAIMING = 1;
const DISTRIBUTED = 2;

const ROLE_LABELS = {
  owner: "pemilik",
  heir: "ahli waris",
  guardian: "guardian",
  other: "bukan pihak vault",
};

// Daftar aksi. `roles` menentukan siapa yang boleh menekan tombol; `denied` adalah alasan
// singkat jika tidak boleh. Syarat waktu dan tahap tidak diperiksa di UI: kontraklah yang
// menolak, dan alasannya ditampilkan dari custom error.
const ACTIONS = [
  {
    id: "deposit",
    label: "Setor ETH",
    method: "deposit",
    roles: ["owner", "heir", "guardian", "other"],
    amount: "1",
    hint: "Tahap Active. Setoran dari pemilik sekaligus dihitung check-in.",
  },
  {
    id: "withdraw",
    label: "Tarik ETH dari vault",
    method: "withdraw",
    roles: ["owner"],
    amount: "1",
    denied: "Hanya pemilik yang dapat menarik dana vault.",
    hint: "Tahap Active. Sekaligus dihitung check-in.",
  },
  {
    id: "checkIn",
    label: "Check-in",
    method: "checkIn",
    roles: ["owner"],
    denied: "Hanya pemilik yang dapat check-in.",
    hint: "Tahap Active. Menandai pemilik masih aktif.",
  },
  {
    id: "startClaim",
    label: "Mulai klaim warisan",
    method: "startClaim",
    roles: ["heir", "guardian"],
    denied: "Hanya ahli waris atau guardian yang dapat memulai klaim.",
    hint: "Tahap Active, setelah masa tidak aktif pemilik lewat.",
  },
  {
    id: "approveClaim",
    label: "Setujui klaim",
    method: "approveClaim",
    roles: ["guardian"],
    denied: "Hanya guardian yang dapat menyetujui.",
    hint: "Tahap Claiming. Satu guardian satu suara per klaim.",
  },
  {
    id: "cancelClaim",
    label: "Batalkan klaim",
    method: "cancelClaim",
    roles: ["owner"],
    denied: "Hanya pemilik yang dapat membatalkan klaim.",
    hint: "Tahap Claiming. Vault kembali ke Active.",
  },
  {
    id: "finalizeClaim",
    label: "Finalisasi klaim",
    method: "finalizeClaim",
    roles: ["owner", "heir", "guardian", "other"],
    hint: "Tahap Claiming, setelah persetujuan cukup dan timelock selesai. Siapa saja boleh.",
  },
  {
    id: "withdrawInheritance",
    label: "Tarik bagian warisan",
    method: "withdrawInheritance",
    roles: ["heir"],
    denied: "Hanya ahli waris yang dapat menarik warisan.",
    hint: "Tahap Distributed. Setiap ahli waris menarik bagiannya sendiri.",
  },
];

const ui = {
  selected: DEMO_ACCOUNTS[0].address,
  testMode: false,
  busy: false,
  fatal: null,
  data: null,
};

const actionControls = new Map();
const personaControls = new Map();
const $ = (id) => document.getElementById(id);

/** Membuat elemen DOM. Teks selalu dimasukkan sebagai teks, bukan HTML. */
function el(tag, attrs = {}, ...children) {
  const node = document.createElement(tag);
  for (const [key, value] of Object.entries(attrs)) {
    if (value === false || value == null) continue;
    if (key === "class") node.className = value;
    else node.setAttribute(key, value === true ? "" : value);
  }
  for (const child of children.flat()) {
    if (child == null || child === false) continue;
    node.append(child instanceof Node ? child : String(child));
  }
  return node;
}

const stamp = (text) => el("span", { class: "stamp" }, text);
const mono = (text) => el("span", { class: "mono" }, text);

// ---------------------------------------------------------------------------
// Membuat kontrol sekali di awal
// ---------------------------------------------------------------------------

function buildPersonas() {
  const container = $("personas");
  for (const account of DEMO_ACCOUNTS) {
    const id = `persona-${account.address}`;
    const input = el("input", {
      type: "radio",
      name: "persona",
      id,
      value: account.address,
      checked: account.address === ui.selected,
    });
    const role = el("span", { class: "persona-role" }, "…");
    const label = el("label", { for: id, class: "persona" }, input, el("span", { class: "persona-name" }, account.name), role);
    input.addEventListener("change", () => {
      ui.selected = account.address;
      render();
    });
    personaControls.set(account.address, { role });
    container.append(label);
  }
}

function buildActions() {
  const container = $("actions");
  for (const action of ACTIONS) {
    const reasonId = `reason-${action.id}`;
    const button = el("button", { type: "button", class: "action-button", "aria-describedby": reasonId }, action.label);
    let input = null;
    if (action.amount) {
      input = el("input", {
        type: "text",
        inputmode: "decimal",
        class: "amount mono",
        value: action.amount,
        "aria-label": `Jumlah ETH untuk ${action.label}`,
      });
    }
    const reason = el("p", { class: "reason", id: reasonId });
    const row = el(
      "div",
      { class: "action" },
      el("div", { class: "action-line" }, button, input ? el("span", { class: "amount-wrap" }, input, " ETH") : null),
      reason,
    );
    button.addEventListener("click", () => runAction(action, input));
    actionControls.set(action.id, { row, button, reason, input });
    container.append(row);
  }
}

function buildTimeTravel() {
  for (const button of document.querySelectorAll(".time-buttons button")) {
    button.addEventListener("click", () => runTimeTravel(Number(button.dataset.seconds), button.textContent));
  }
}

// ---------------------------------------------------------------------------
// Menjalankan aksi
// ---------------------------------------------------------------------------

function showResult(kind, text) {
  const labels = { busy: "MENGIRIM", ok: "BERHASIL", rejected: "DITOLAK" };
  $("result").replaceChildren(el("p", { class: `result-line ${kind}` }, stamp(labels[kind]), " ", text));
}

// Selama transaksi berjalan semua tombol dinonaktifkan, dan browser melepas fokus dari tombol
// yang nonaktif. Fokus dikembalikan ke tombol semula supaya pengguna keyboard tidak harus
// menekan Tab dari awal halaman.
let focusBeforeBusy = null;

function setBusy(busy) {
  if (busy) focusBeforeBusy = document.activeElement;
  ui.busy = busy;
  render();
  if (!busy && focusBeforeBusy?.isConnected && !focusBeforeBusy.disabled) {
    focusBeforeBusy.focus();
    focusBeforeBusy = null;
  }
}

async function runAction(action, input) {
  const actorName = nameOf(ui.selected);
  let args = [];
  let value = 0n;

  if (action.amount) {
    let amount;
    try {
      amount = parseEthInput(input.value);
    } catch (err) {
      showResult("rejected", err.message);
      return;
    }
    if (action.id === "deposit") value = amount;
    else args = [amount];
  }

  setBusy(true);
  showResult("busy", `${action.label} atas nama ${actorName}…`);
  try {
    const receipt = await chain.sendAction(ui.selected, action.method, args, value);
    showResult("ok", `${action.label} oleh ${actorName}. Blok #${receipt.blockNumber}, transaksi ${shortHash(receipt.hash)}.`);
  } catch (err) {
    const message = err instanceof chain.WrongNetworkError ? err.message : describeError(err, chain.vault.interface);
    showResult("rejected", message);
  } finally {
    setBusy(false);
    await refresh();
  }
}

async function runTimeTravel(seconds, label) {
  setBusy(true);
  try {
    await chain.advanceTime(seconds);
    await refresh();
    showResult("ok", `Waktu blockchain dimajukan ${label.replace("+", "")}. Sekarang ${formatDate(ui.data.now)}.`);
  } catch (err) {
    showResult("rejected", err instanceof chain.WrongNetworkError ? err.message : describeError(err, chain.vault.interface));
  } finally {
    setBusy(false);
  }
}

// ---------------------------------------------------------------------------
// Membaca ulang data dari blockchain
// ---------------------------------------------------------------------------

let refreshing = false;
let refreshAgain = false;

async function refresh() {
  if (refreshing) {
    refreshAgain = true;
    return;
  }
  refreshing = true;
  try {
    const chainId = await chain.getChainId();
    if (chainId !== chain.ANVIL_CHAIN_ID) {
      ui.fatal = `Jaringan di ${chain.RPC_URL} memiliki chainId ${chainId}, bukan 31337. Simulasi ini hanya berjalan di Anvil lokal, jadi semua aksi dinonaktifkan.`;
    } else if (!(await chain.isVaultDeployed())) {
      ui.fatal = `Tidak ada kontrak di ${chain.VAULT_ADDRESS}. Anvil mungkin baru dinyalakan ulang. Jalankan npm run seed di folder proyek, lalu muat ulang halaman ini.`;
    } else {
      ui.data = await chain.readVault(DEMO_ACCOUNTS);
      ui.fatal = null;
    }
  } catch {
    ui.fatal = `Tidak bisa terhubung ke Anvil di ${chain.RPC_URL}. Jalankan npm run anvil lalu npm run seed di folder proyek.`;
  } finally {
    refreshing = false;
  }
  render();
  if (refreshAgain) {
    refreshAgain = false;
    await refresh();
  }
}

// ---------------------------------------------------------------------------
// Menggambar ulang bagian-bagian yang berubah
// ---------------------------------------------------------------------------

function render() {
  const fatal = $("fatal");
  fatal.hidden = !ui.fatal;
  fatal.textContent = ui.fatal ?? "";

  for (const button of document.querySelectorAll(".time-buttons button")) {
    button.disabled = ui.busy || Boolean(ui.fatal);
  }

  renderActions();
  if (!ui.data) return;

  renderNetwork();
  renderPersonas();
  renderStateDiagram();
  renderConditions();
  renderClaimHistory();
  renderBalances();
  renderHeirs();
  renderGuardians();
  renderEventLog();
}

function renderNetwork() {
  const { data } = ui;
  $("network-name").textContent = "Anvil lokal, chainId 31337";
  $("network-block").textContent = `#${data.blockNumber}`;
  $("network-time").textContent = formatDate(data.now);
  $("network-contract").textContent = shortAddress(chain.VAULT_ADDRESS);
  $("network-contract").title = chain.VAULT_ADDRESS;
}

function renderPersonas() {
  for (const [address, { role }] of personaControls) {
    role.textContent = ROLE_LABELS[ui.data.roles.get(address) ?? "other"];
  }
}

function renderActions() {
  const role = ui.data?.roles.get(ui.selected) ?? "other";
  const actorName = nameOf(ui.selected);
  $("actor-line").replaceChildren(
    "Bertindak sebagai ",
    el("strong", {}, actorName),
    ` (${ROLE_LABELS[role]}). `,
    "Syarat waktu dan tahap diperiksa oleh kontrak, bukan oleh tampilan ini.",
  );

  for (const action of ACTIONS) {
    const { row, button, reason, input } = actionControls.get(action.id);
    const allowed = action.roles.includes(role);
    button.disabled = ui.busy || Boolean(ui.fatal) || !ui.data || (!allowed && !ui.testMode);
    if (input) input.disabled = button.disabled;
    row.classList.toggle("denied", !allowed);

    if (allowed) {
      reason.textContent = action.hint;
    } else if (ui.testMode) {
      reason.textContent = `${action.denied} Mode uji aktif: tombol tetap bisa ditekan, dan kontrak akan menolaknya.`;
    } else {
      reason.textContent = action.denied;
    }
  }
}

function renderStateDiagram() {
  const current = ui.data.status.state;
  const items = [];
  STATE_NAMES.forEach((name, index) => {
    const isCurrent = index === current;
    items.push(
      el(
        "li",
        { class: `state-node${isCurrent ? " current" : ""}`, "aria-current": isCurrent ? "step" : false },
        el("span", { class: "state-name" }, name),
        isCurrent ? stamp("SEKARANG") : null,
        el("span", { class: "state-desc" }, STATE_DESCRIPTIONS[index]),
      ),
    );
    if (index === 0) items.push(el("li", { class: "state-arrow", "aria-hidden": "true" }, "↓ startClaim"));
    if (index === 1) items.push(el("li", { class: "state-arrow", "aria-hidden": "true" }, "↓ finalizeClaim"));
  });
  $("state-diagram").replaceChildren(...items);
}

function condition(met, title, detail) {
  return el(
    "li",
    { class: `condition ${met ? "met" : "unmet"}` },
    el("span", { class: "marker", "aria-hidden": "true" }),
    el("span", { class: "condition-status" }, met ? "TERPENUHI" : "BELUM"),
    el("span", { class: "condition-title" }, title),
    el("span", { class: "condition-detail" }, detail),
  );
}

function renderConditions() {
  const { status, now, guardians } = ui.data;
  const list = [];

  // 1. Masa tidak aktif
  const inactivityMet = status.state !== ACTIVE || now >= status.activeUntil;
  let inactivityDetail;
  if (status.state === ACTIVE && !inactivityMet) {
    inactivityDetail = `Pemilik aktif sampai ${formatDate(status.activeUntil)}, sisa ${formatDuration(status.activeUntil - now)}.`;
  } else if (status.state === ACTIVE) {
    inactivityDetail = `Batas ${formatDate(status.activeUntil)} sudah lewat. Klaim boleh dimulai.`;
  } else {
    inactivityDetail = "Terpenuhi saat klaim dimulai.";
  }
  list.push(condition(inactivityMet, "Masa tidak aktif lewat", inactivityDetail));

  // 2. Persetujuan guardian
  const approvalsMet = status.state === DISTRIBUTED || (status.state === CLAIMING && status.approvals >= status.threshold);
  let approvalDetail;
  if (status.state === ACTIVE) {
    approvalDetail = "Belum ada klaim berjalan.";
  } else if (status.state === CLAIMING) {
    const approvers = guardians.filter((g) => g.approved).map((g) => nameOf(g.address));
    approvalDetail = approvers.length ? `Sudah menyetujui: ${approvers.join(", ")}.` : "Belum ada guardian yang menyetujui.";
  } else {
    approvalDetail = "Terpenuhi sebelum finalisasi.";
  }
  const shownApprovals = status.state === ACTIVE ? 0n : status.approvals;
  list.push(condition(approvalsMet, `Persetujuan ${shownApprovals}/${status.threshold}`, approvalDetail));

  // 3. Timelock
  let timelockMet = false;
  let timelockDetail;
  if (status.state === DISTRIBUTED) {
    timelockMet = true;
    timelockDetail = "Selesai sebelum finalisasi.";
  } else if (status.state === ACTIVE || status.unlockTime === 0n) {
    timelockDetail = "Belum dijadwalkan. Dimulai saat persetujuan mencapai threshold.";
  } else if (now >= status.unlockTime) {
    timelockMet = true;
    timelockDetail = `Selesai sejak ${formatDate(status.unlockTime)}. Klaim bisa difinalisasi.`;
  } else {
    timelockDetail = `Selesai pada ${formatDate(status.unlockTime)}, sisa ${formatDuration(status.unlockTime - now)}.`;
  }
  list.push(condition(timelockMet, "Timelock selesai", timelockDetail));

  $("conditions").replaceChildren(...list);
}

function renderClaimHistory() {
  const claims = new Map();
  for (const event of ui.data.events) {
    const id = event.args?.claimId;
    if (event.name === "ClaimStarted") claims.set(id, { initiator: event.args.initiator, status: "BERJALAN" });
    if (event.name === "ClaimCancelled" && claims.has(id)) claims.get(id).status = "DIBATALKAN";
    if (event.name === "ClaimFinalized" && claims.has(id)) claims.get(id).status = "FINAL";
  }
  const items = [...claims.entries()]
    .reverse()
    .map(([id, claim]) =>
      el("li", {}, mono(`#${id}`), " ", stamp(claim.status), " ", `dimulai oleh ${nameOf(claim.initiator)}`),
    );
  $("claim-history").replaceChildren(...(items.length ? items : [el("li", { class: "empty" }, "Belum pernah ada klaim.")]));
}

function renderBalances() {
  const { status, balances } = ui.data;
  $("balances").replaceChildren(
    el("div", {}, el("dt", {}, "Saldo vault"), el("dd", { class: "mono figure" }, formatEth(status.balance))),
    el(
      "div",
      {},
      el("dt", {}, `Dompet ${nameOf(ui.selected)}`),
      el("dd", { class: "mono figure" }, formatEthApprox(balances.get(ui.selected) ?? 0n)),
    ),
  );
}

/** Perhitungan sama dengan finalizeClaim: dibulatkan ke bawah, sisa ke ahli waris terakhir. */
function computeShares(total, heirs) {
  let allocated = 0n;
  return heirs.map((heir, index) => {
    if (index === heirs.length - 1) return total - allocated;
    const amount = (total * heir.bps) / 10000n;
    allocated += amount;
    return amount;
  });
}

function renderHeirs() {
  const { status, heirs, snapshot } = ui.data;
  const distributed = status.state === DISTRIBUTED;
  $("heir-amount-head").textContent = distributed ? "Bagian (dari snapshot)" : "Perkiraan jika dibagi sekarang";

  const shares = computeShares(distributed ? snapshot : status.balance, heirs);
  const rows = heirs.map((heir, index) => {
    let statusCell;
    if (!distributed) statusCell = el("span", { class: "muted" }, "belum dibagi");
    else if (heir.inheritance > 0n) statusCell = stamp("BELUM DITARIK");
    else statusCell = stamp("SUDAH DITARIK");
    return el(
      "tr",
      {},
      el("td", {}, nameOf(heir.address)),
      el("td", { class: "mono num" }, formatPercent(heir.bps)),
      el("td", { class: "mono num" }, formatEth(shares[index])),
      el("td", {}, statusCell),
    );
  });
  $("heir-table").tBodies[0].replaceChildren(...rows);
}

function renderGuardians() {
  const { status, guardians } = ui.data;
  const rows = guardians.map((guardian) => {
    let cell;
    if (status.state !== CLAIMING) cell = el("span", { class: "muted" }, "tidak ada klaim berjalan");
    else if (guardian.approved) cell = stamp("MENYETUJUI");
    else cell = el("span", { class: "muted" }, "belum menyetujui");
    return el("tr", {}, el("td", {}, nameOf(guardian.address)), el("td", { class: "mono" }, shortAddress(guardian.address)), el("td", {}, cell));
  });
  $("guardian-table").tBodies[0].replaceChildren(...rows);
}

/** Kalimat untuk setiap event kontrak. `stampText` diisi untuk event yang perlu ditandai cap. */
function describeEvent(event) {
  const a = event.args;
  switch (event.name) {
    case "Deposited":
      return { text: `${nameOf(a.from)} menyetor ${formatEth(a.amount)} ke vault.` };
    case "Withdrawn":
      return { text: `${nameOf(a.to)} menarik ${formatEth(a.amount)} dari vault.` };
    case "CheckedIn":
      return { text: "Check-in pemilik: masa tidak aktif dihitung ulang.", minor: true };
    case "HeirsUpdated":
      return { text: "Daftar ahli waris diubah oleh pemilik." };
    case "ClaimStarted":
      return { text: `Klaim #${a.claimId} dimulai oleh ${nameOf(a.initiator)}.`, stampText: "KLAIM" };
    case "ClaimApproved":
      return {
        text: `${nameOf(a.guardian)} menyetujui klaim #${a.claimId}. Persetujuan ${a.approvals}/${ui.data.status.threshold}.`,
      };
    case "ClaimUnlockScheduled":
      return { text: `Persetujuan cukup. Klaim #${a.claimId} bisa difinalisasi mulai ${formatDate(a.unlockTime)}.` };
    case "ClaimCancelled":
      return { text: `Klaim #${a.claimId} dibatalkan oleh pemilik.`, stampText: "DIBATALKAN" };
    case "ClaimFinalized":
      return { text: `Klaim #${a.claimId} final. ${formatEth(a.snapshot)} dibagikan ke ahli waris.`, stampText: "FINAL" };
    case "InheritanceWithdrawn":
      return { text: `${nameOf(a.heir)} menarik bagian warisan ${formatEth(a.amount)}.`, stampText: "DITARIK" };
    default:
      return { text: event.name };
  }
}

function renderEventLog() {
  const events = [...ui.data.events].sort((x, y) => y.blockNumber - x.blockNumber || y.logIndex - x.logIndex);
  const items = events.map((event) => {
    const { text, stampText, minor } = describeEvent(event);
    return el(
      "li",
      { class: `log-entry${minor ? " minor" : ""}` },
      el(
        "div",
        { class: "log-meta mono" },
        el("time", { datetime: new Date(Number(event.timestamp) * 1000).toISOString() }, formatDateShort(event.timestamp)),
        ` · blok #${event.blockNumber} · `,
        el("span", { title: event.txHash }, shortHash(event.txHash)),
      ),
      el("p", { class: "log-text" }, stampText ? [stamp(stampText), " "] : null, text),
    );
  });
  $("event-log").replaceChildren(...(items.length ? items : [el("li", { class: "empty" }, "Belum ada event.")]));
}

// ---------------------------------------------------------------------------
// Mulai
// ---------------------------------------------------------------------------

buildPersonas();
buildActions();
buildTimeTravel();
$("test-mode").addEventListener("change", (event) => {
  ui.testMode = event.target.checked;
  render();
});
render();
refresh();
// Anvil membuat blok baru setiap ada transaksi. Data dibaca ulang setiap blok baru,
// termasuk transaksi yang dikirim dari terminal dengan cast.
chain.provider.on("block", () => refresh());
// Anvil yang mati tidak menghasilkan blok baru, jadi kejadian itu tidak terdeteksi lewat event
// "block". Setiap 3 detik koneksi dan chainId diperiksa. Jika ada masalah, atau masalah
// sebelumnya sudah beres, data dibaca ulang.
setInterval(async () => {
  if (ui.fatal) {
    refresh();
    return;
  }
  try {
    if ((await chain.getChainId()) !== chain.ANVIL_CHAIN_ID) refresh();
  } catch {
    refresh();
  }
}, 3000);
