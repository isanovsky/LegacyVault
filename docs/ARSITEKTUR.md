# Arsitektur LegacyVault

Dokumen ini menggambarkan bagian-bagian sistem dan hubungannya. Aturan desain lengkapnya ada di [SPEC.md](../SPEC.md).

## 1. Diagram komponen

```mermaid
flowchart LR
    subgraph Browser
        UI["UI simulasi<br/>ui/index.html + ui/src/main.js"]
        ETH["ethers v6<br/>ui/src/chain.js"]
        CJ[("ui/src/contract.json<br/>alamat + ABI")]
    end

    subgraph Blockchain["Blockchain (Anvil lokal, chainId 31337)"]
        RPC["JSON-RPC<br/>http://127.0.0.1:8545"]
        EVM["EVM"]
        LV["Kontrak LegacyVault<br/>src/LegacyVault.sol"]
        RG["ReentrancyGuard<br/>(OpenZeppelin)"]
    end

    subgraph Pengembangan["Alat pengembangan (Foundry)"]
        SRC["src/LegacyVault.sol"]
        FB["forge build"]
        FS["forge script<br/>Deploy.s.sol / SeedDemo.s.sol"]
        EX["script/export-contract.mjs"]
    end

    UI -->|"panggil fungsi, baca status"| ETH
    CJ -->|"alamat dan ABI"| ETH
    ETH -->|"eth_call, eth_sendTransaction,<br/>evm_increaseTime"| RPC
    RPC --> EVM
    EVM -->|"menjalankan bytecode"| LV
    LV -.->|"mewarisi"| RG
    LV -->|"event: Deposited, ClaimStarted, ..."| ETH

    SRC --> FB
    FB -->|"bytecode + ABI di out/"| FS
    FS -->|"transaksi deploy"| RPC
    FS -->|"catatan broadcast/"| EX
    FB -->|"ABI"| EX
    EX --> CJ
```

| Komponen | Peran |
|---|---|
| UI simulasi | Halaman web untuk memilih tokoh dan menjalankan aksi. Tombol dinonaktifkan sesuai peran, tetapi aturan waktu dan state tetap ditegakkan kontrak. |
| ethers v6 (`chain.js`) | Mengubah klik tombol menjadi panggilan JSON-RPC. Setiap transaksi dicoba dulu dengan `staticCall`, supaya penolakan dari kontrak bisa diterjemahkan menjadi pesan yang mudah dibaca sebelum transaksi dikirim. |
| `contract.json` | Alamat kontrak dan ABI, ditulis otomatis setelah deploy lokal. ABI adalah "daftar menu" fungsi kontrak, sehingga UI tahu cara menyusun panggilan. |
| Anvil | Blockchain lokal untuk pengembangan. Akun-akunnya sudah terbuka, jadi UI tidak memerlukan private key. Waktu bisa dimajukan dengan `evm_increaseTime`. |
| LegacyVault | Seluruh aturan bisnis: peran, state, waktu, persetujuan, pembagian. |
| ReentrancyGuard | Satu-satunya pustaka luar yang dipakai, untuk modifier `nonReentrant`. |

Di Sepolia, susunannya sama tetapi Anvil diganti node Sepolia (melalui RPC URL dari penyedia seperti Alchemy atau Infura), dan transaksi ditandatangani dengan private key wallet testnet. UI simulasi tidak dipakai di Sepolia karena sengaja dibatasi ke chainId 31337.

## 2. Diagram state

```mermaid
stateDiagram-v2
    [*] --> Active: deploy
    Active --> Active: deposit / receive / withdraw / checkIn / updateHeirs
    Active --> Claiming: startClaim (heir atau guardian, setelah masa tidak aktif)
    Claiming --> Claiming: approveClaim (guardian)
    Claiming --> Active: cancelClaim (owner)
    Claiming --> Distributed: finalizeClaim (siapa saja, persetujuan cukup + timelock lewat)
    Distributed --> Distributed: withdrawInheritance (heir)
```

| State | Arti | Yang bisa terjadi |
|---|---|---|
| `Active` | Pemilik dianggap aktif dan menguasai penuh dana | Setor, tarik, check-in, ubah heir, mulai klaim (jika masa tidak aktif lewat) |
| `Claiming` | Klaim warisan sedang berjalan | Guardian menyetujui, owner membatalkan, siapa saja memfinalkan jika syarat terpenuhi. Setor, tarik, check-in, dan ubah heir ditolak. |
| `Distributed` | Final, tidak bisa kembali | Heir menarik bagiannya. Setoran baru ditolak. |

Setiap fungsi memeriksa state dengan modifier `inState(...)`. Jika state tidak sesuai, kontrak membatalkan transaksi dengan error `InvalidState(expected, current)`.

## 3. Flowchart proses klaim

```mermaid
flowchart TD
    A([Pemilik terakhir check-in]) --> B{"Sudah lewat<br/>inactivityPeriod?"}
    B -- "Belum" --> B1["startClaim ditolak:<br/>OwnerStillActive(activeUntil)"]
    B -- "Sudah" --> C["Heir atau guardian memanggil startClaim<br/>State: Claiming, claimId bertambah,<br/>approvalCount = 0"]

    C --> D["Guardian memanggil approveClaim"]
    D --> D1{"Sudah menyetujui<br/>klaim ini?"}
    D1 -- "Ya" --> D2["Ditolak: AlreadyApproved(claimId)"]
    D1 -- "Tidak" --> E{"approvalCount<br/>mencapai threshold?"}
    E -- "Belum" --> D
    E -- "Ya" --> F["unlockTime = sekarang + timelockPeriod<br/>Event ClaimUnlockScheduled"]

    F --> G{"Pemilik membatalkan<br/>selama timelock?"}
    G -- "Ya" --> H["cancelClaim: State kembali Active,<br/>dihitung sebagai check-in.<br/>Persetujuan lama tidak berlaku<br/>karena terikat claimId lama."]
    H --> A

    G -- "Tidak" --> I{"Sekarang >= unlockTime?"}
    I -- "Belum" --> I1["finalizeClaim ditolak:<br/>TimelockNotExpired(unlockTime)"]
    I -- "Sudah" --> J["Siapa saja memanggil finalizeClaim<br/>snapshot = saldo vault<br/>Bagian heir = snapshot x bps / 10000<br/>Sisa pembulatan ke heir terakhir<br/>State: Distributed"]
    J --> K["Setiap heir memanggil withdrawInheritance<br/>dan menerima bagiannya sendiri"]
```

Catatan:

- Pemilik juga bisa membatalkan **sebelum** threshold tercapai, karena `cancelClaim` berlaku selama state `Claiming`.
- `finalizeClaim` sebelum threshold tercapai ditolak dengan `NotEnoughApprovals(approvals, threshold)`.
- Persetujuan tambahan setelah threshold tercapai tetap dihitung, tetapi tidak menggeser `unlockTime`.

## 4. Tabel fungsi dan peran

Tanda ✓ berarti peran itu boleh memanggil fungsi tersebut. Peran yang salah ditolak dengan error di kolom terakhir.

| Fungsi | Owner | Heir | Guardian | Siapa saja | State | Error jika peran salah |
|---|---|---|---|---|---|---|
| `constructor(...)` payable | (deployer menjadi owner) | | | | - | - |
| `receive()` / `deposit()` payable | ✓ (juga check-in) | ✓ | ✓ | ✓ | `Active` | - |
| `withdraw(amount)` | ✓ (juga check-in) | | | | `Active` | `NotOwner()` |
| `checkIn()` | ✓ | | | | `Active` | `NotOwner()` |
| `updateHeirs(heirs, sharesBps)` | ✓ (juga check-in) | | | | `Active` | `NotOwner()` |
| `startClaim()` | | ✓ | ✓ | | `Active` | `NotHeirOrGuardian()` |
| `approveClaim()` | | | ✓ | | `Claiming` | `NotGuardian()` |
| `cancelClaim()` | ✓ (juga check-in) | | | | `Claiming` | `NotOwner()` |
| `finalizeClaim()` | ✓ | ✓ | ✓ | ✓ | `Claiming` | - |
| `withdrawInheritance()` | | ✓ | | | `Distributed` | `NotHeir()` |
| `getStatus()` view | ✓ | ✓ | ✓ | ✓ | semua | - |

Kenapa beberapa pilihan desainnya begitu:

- **`finalizeClaim` boleh dipanggil siapa saja.** Semua syaratnya (threshold dan timelock) sudah dicek kontrak, jadi siapa pun yang memanggilnya tidak bisa mengubah hasil. Ini mencegah klaim macet hanya karena tidak ada yang mau membayar gas.
- **Guardian boleh memulai klaim.** Heir mungkin tidak tahu cara memakai wallet atau belum tahu pemilik sudah tiada. Guardian tetap tidak bisa menerima dana, karena guardian tidak boleh sekaligus menjadi heir.
- **Setoran dari selain owner tidak dihitung sebagai check-in.** Kalau dihitung, siapa saja bisa menunda klaim selamanya dengan menyetor 1 wei.

### Event

| Event | Dipancarkan oleh |
|---|---|
| `Deposited(from, amount)` | `receive`, `deposit`, constructor yang membawa ETH |
| `Withdrawn(to, amount)` | `withdraw` |
| `CheckedIn(timestamp)` | Constructor, `checkIn`, dan setiap aksi owner yang dihitung sebagai check-in (setor, `withdraw`, `updateHeirs`, `cancelClaim`) |
| `HeirsUpdated()` | `updateHeirs` |
| `ClaimStarted(claimId, initiator)` | `startClaim` |
| `ClaimApproved(claimId, guardian, approvals)` | `approveClaim` |
| `ClaimUnlockScheduled(claimId, unlockTime)` | `approveClaim` saat threshold tercapai |
| `ClaimCancelled(claimId)` | `cancelClaim` |
| `ClaimFinalized(claimId, snapshot)` | `finalizeClaim` |
| `InheritanceWithdrawn(heir, amount)` | `withdrawInheritance` |

UI membaca event-event ini untuk mengisi buku catatan.
