// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title LegacyVault
/// @notice Brankas ETH yang bisa diwariskan. Selama pemilik aktif, hanya pemilik yang menguasai dana.
///         Jika pemilik tidak aktif cukup lama, ahli waris bisa mengajukan klaim yang harus disetujui
///         guardian dan melewati masa tunggu (timelock) sebelum dana dibagikan.
/// @dev Desain lengkap ada di SPEC.md. Kontrak hanya tahu pemilik "tidak aktif", bukan "meninggal";
///      guardian, timelock, dan cancelClaim adalah lapisan untuk mencegah klaim keliru.
contract LegacyVault is ReentrancyGuard {
    // ---------------------------------------------------------------------
    // Tipe data
    // ---------------------------------------------------------------------

    /// @notice Tahap kehidupan vault. Hanya bisa bergerak sesuai diagram di SPEC.md bagian 3.
    enum State {
        Active,
        Claiming,
        Distributed
    }

    /// @notice Ringkasan status dalam satu panggilan, supaya UI tidak perlu memanggil banyak getter.
    struct Status {
        State state;
        uint256 balance;
        uint256 lastCheckIn;
        uint256 activeUntil;
        uint256 claimId;
        uint256 approvals;
        uint256 threshold;
        uint256 unlockTime;
    }

    // ---------------------------------------------------------------------
    // Konstanta
    // ---------------------------------------------------------------------

    /// @dev Batas panjang daftar agar loop di finalizeClaim dan updateHeirs tidak kehabisan gas.
    uint256 public constant MAX_HEIRS = 10;
    uint256 public constant MAX_GUARDIANS = 10;

    /// @dev 10000 basis point = 100%. Memakai bps (bukan persen) supaya porsi seperti 33,33% bisa dinyatakan.
    uint256 public constant TOTAL_BPS = 10000;

    /// @dev Periode minimal 1 hari supaya pergeseran block.timestamp beberapa detik tidak berarti.
    uint256 public constant MIN_PERIOD = 1 days;

    // ---------------------------------------------------------------------
    // Konfigurasi (tetap sejak deploy)
    // ---------------------------------------------------------------------

    address public immutable owner;
    uint256 public immutable threshold;
    uint256 public immutable inactivityPeriod;
    uint256 public immutable timelockPeriod;

    /// @dev Guardian tidak bisa diganti setelah deploy (disederhanakan, lihat SPEC.md bagian 7).
    address[] public guardians;
    mapping(address => bool) public isGuardian;

    // ---------------------------------------------------------------------
    // Ahli waris (bisa diganti owner selama Active)
    // ---------------------------------------------------------------------

    /// @dev Dua array sejajar: sharesBps[i] adalah porsi milik heirs[i].
    address[] public heirs;
    uint256[] public sharesBps;
    mapping(address => bool) public isHeir;

    // ---------------------------------------------------------------------
    // Status berjalan
    // ---------------------------------------------------------------------

    State public state;
    uint256 public lastCheckIn;

    /// @dev Nomor klaim. Naik setiap startClaim, sehingga persetujuan klaim lama tidak ikut terhitung.
    uint256 public claimId;
    uint256 public approvalCount;

    /// @dev Bernilai 0 selama persetujuan belum mencapai threshold.
    uint256 public unlockTime;

    /// @dev claimId => guardian => sudah menyetujui. Terikat claimId agar persetujuan dari klaim
    ///      yang dibatalkan tidak terbawa ke klaim berikutnya (invariant 6).
    mapping(uint256 => mapping(address => bool)) public hasApproved;

    /// @notice Saldo vault yang dibagikan saat finalizeClaim.
    uint256 public snapshot;

    /// @notice Bagian warisan setiap heir yang belum ditarik.
    mapping(address => uint256) public inheritanceOf;

    // ---------------------------------------------------------------------
    // Event
    // ---------------------------------------------------------------------

    event Deposited(address indexed from, uint256 amount);
    event Withdrawn(address indexed to, uint256 amount);
    event CheckedIn(uint256 timestamp);
    event HeirsUpdated();
    event ClaimStarted(uint256 indexed claimId, address indexed initiator);
    event ClaimApproved(uint256 indexed claimId, address indexed guardian, uint256 approvals);
    event ClaimUnlockScheduled(uint256 indexed claimId, uint256 unlockTime);
    event ClaimCancelled(uint256 indexed claimId);
    event ClaimFinalized(uint256 indexed claimId, uint256 snapshot);
    event InheritanceWithdrawn(address indexed heir, uint256 amount);

    // ---------------------------------------------------------------------
    // Error
    // ---------------------------------------------------------------------

    // Peran
    error NotOwner();
    error NotGuardian();
    error NotHeir();
    error NotHeirOrGuardian();

    // State
    error InvalidState(State expected, State current);

    // Waktu dan klaim
    error OwnerStillActive(uint256 activeUntil);
    error AlreadyApproved(uint256 claimId);
    error NotEnoughApprovals(uint256 approvals, uint256 threshold);
    error TimelockNotExpired(uint256 unlockTime);

    // Dana
    error InsufficientBalance(uint256 requested, uint256 available);
    error NothingToWithdraw();
    error TransferFailed();

    // Validasi konfigurasi
    error ZeroAddress();
    error DuplicateAddress(address account);
    error OwnerCannotHaveRole();
    error GuardianCannotBeHeir(address account);
    error InvalidHeirCount(uint256 count);
    error InvalidGuardianCount(uint256 count);
    error LengthMismatch(uint256 heirs, uint256 shares);
    error ZeroShare(address heir);
    error InvalidSharesTotal(uint256 total);
    error InvalidThreshold(uint256 threshold, uint256 guardianCount);
    error PeriodTooShort(uint256 period);

    // ---------------------------------------------------------------------
    // Modifier
    // ---------------------------------------------------------------------

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier onlyGuardian() {
        if (!isGuardian[msg.sender]) revert NotGuardian();
        _;
    }

    modifier onlyHeir() {
        if (!isHeir[msg.sender]) revert NotHeir();
        _;
    }

    modifier onlyHeirOrGuardian() {
        if (!isHeir[msg.sender] && !isGuardian[msg.sender]) revert NotHeirOrGuardian();
        _;
    }

    modifier inState(State expected) {
        if (state != expected) revert InvalidState(expected, state);
        _;
    }

    // ---------------------------------------------------------------------
    // Constructor dan penerimaan ETH
    // ---------------------------------------------------------------------

    /// @param initialHeirs Daftar ahli waris (1 sampai 10 alamat).
    /// @param initialSharesBps Porsi setiap ahli waris dalam basis point; totalnya harus tepat 10000.
    /// @param initialGuardians Daftar guardian (1 sampai 10 alamat), tidak boleh sekaligus ahli waris.
    /// @param requiredApprovals Jumlah persetujuan guardian minimal agar klaim bisa cair.
    /// @param inactivityDuration Lama pemilik boleh tidak check-in sebelum klaim boleh dimulai.
    /// @param timelockDuration Masa tunggu setelah persetujuan cukup, memberi waktu pemilik membatalkan.
    constructor(
        address[] memory initialHeirs,
        uint256[] memory initialSharesBps,
        address[] memory initialGuardians,
        uint256 requiredApprovals,
        uint256 inactivityDuration,
        uint256 timelockDuration
    ) payable {
        if (inactivityDuration < MIN_PERIOD) revert PeriodTooShort(inactivityDuration);
        if (timelockDuration < MIN_PERIOD) revert PeriodTooShort(timelockDuration);
        if (requiredApprovals == 0 || requiredApprovals > initialGuardians.length) {
            revert InvalidThreshold(requiredApprovals, initialGuardians.length);
        }

        owner = msg.sender;
        threshold = requiredApprovals;
        inactivityPeriod = inactivityDuration;
        timelockPeriod = timelockDuration;

        // Guardian disimpan lebih dulu karena validasi heir memeriksa bahwa heir bukan guardian.
        _setGuardians(initialGuardians);
        _setHeirs(initialHeirs, initialSharesBps);

        state = State.Active;
        _checkIn();

        if (msg.value > 0) {
            emit Deposited(msg.sender, msg.value);
        }
    }

    /// @notice Menerima ETH yang dikirim langsung ke alamat kontrak.
    /// @dev Ditolak di luar Active supaya ETH tidak masuk setelah pembagian dan terkunci selamanya.
    receive() external payable inState(State.Active) {
        _deposit();
    }

    /// @notice Menyetor ETH ke vault. Jika penyetor adalah owner, sekaligus dihitung sebagai check-in.
    function deposit() external payable inState(State.Active) {
        _deposit();
    }

    // ---------------------------------------------------------------------
    // Fungsi owner
    // ---------------------------------------------------------------------

    /// @notice Owner menarik sebagian atau seluruh saldo vault.
    function withdraw(uint256 amount) external nonReentrant onlyOwner inState(State.Active) {
        uint256 available = address(this).balance;
        if (amount > available) revert InsufficientBalance(amount, available);

        _checkIn();
        emit Withdrawn(owner, amount);

        // Memakai call (bukan transfer) karena transfer membatasi gas 2300 dan bisa gagal untuk
        // penerima berupa smart contract wallet. Hasilnya wajib dicek agar kegagalan tidak diam-diam.
        (bool success,) = owner.call{value: amount}("");
        if (!success) revert TransferFailed();
    }

    /// @notice Owner menyatakan dirinya masih aktif, sehingga masa tidak aktif dihitung ulang dari sekarang.
    function checkIn() external onlyOwner inState(State.Active) {
        _checkIn();
    }

    /// @notice Owner mengganti seluruh daftar ahli waris dan porsinya.
    /// @dev Validasinya sama dengan constructor. Jika satu aturan dilanggar, seluruh perubahan dibatalkan.
    function updateHeirs(address[] calldata newHeirs, uint256[] calldata newSharesBps)
        external
        onlyOwner
        inState(State.Active)
    {
        // Hapus tanda isHeir milik daftar lama, supaya heir yang dikeluarkan kehilangan perannya.
        // Ini juga wajib sebelum _setHeirs, karena _setHeirs memakai isHeir untuk mendeteksi duplikat.
        // Perubahan ini diumumkan lewat event HeirsUpdated di akhir fungsi.
        for (uint256 i = 0; i < heirs.length; i++) {
            // forge-lint: disable-next-line(missing-events-access-control)
            isHeir[heirs[i]] = false;
        }

        _setHeirs(newHeirs, newSharesBps);
        _checkIn();
        emit HeirsUpdated();
    }

    /// @notice Owner membatalkan klaim yang sedang berjalan, misalnya karena ia ternyata masih hidup.
    /// @dev Persetujuan lama tidak perlu dihapus satu per satu: klaim berikutnya memakai claimId baru,
    ///      sehingga isi hasApproved untuk claimId lama tidak lagi dibaca.
    function cancelClaim() external onlyOwner inState(State.Claiming) {
        uint256 cancelledId = claimId;

        state = State.Active;
        approvalCount = 0;
        unlockTime = 0;
        _checkIn();

        emit ClaimCancelled(cancelledId);
    }

    // ---------------------------------------------------------------------
    // Alur klaim
    // ---------------------------------------------------------------------

    /// @notice Heir atau guardian memulai klaim setelah owner tidak aktif selama inactivityPeriod.
    function startClaim() external onlyHeirOrGuardian inState(State.Active) {
        uint256 activeUntil = lastCheckIn + inactivityPeriod;
        // Validator hanya bisa menggeser timestamp beberapa detik, sedangkan periode minimal 1 hari.
        // forge-lint: disable-next-line(block-timestamp)
        if (block.timestamp < activeUntil) revert OwnerStillActive(activeUntil);

        claimId += 1;
        approvalCount = 0;
        unlockTime = 0;
        state = State.Claiming;

        emit ClaimStarted(claimId, msg.sender);
    }

    /// @notice Guardian menyetujui klaim yang sedang berjalan. Satu guardian satu suara per klaim.
    /// @dev Timelock dijadwalkan tepat saat persetujuan mencapai threshold. Persetujuan tambahan
    ///      tetap dicatat, tetapi tidak menggeser unlockTime agar timelock tidak bisa diperpanjang terus.
    function approveClaim() external onlyGuardian inState(State.Claiming) {
        if (hasApproved[claimId][msg.sender]) revert AlreadyApproved(claimId);

        hasApproved[claimId][msg.sender] = true;
        approvalCount += 1;
        emit ClaimApproved(claimId, msg.sender, approvalCount);

        if (approvalCount == threshold) {
            unlockTime = block.timestamp + timelockPeriod;
            emit ClaimUnlockScheduled(claimId, unlockTime);
        }
    }

    /// @notice Menutup klaim dan menghitung bagian setiap heir. Siapa saja boleh memanggil,
    ///         karena semua syaratnya sudah diperiksa di dalam fungsi.
    /// @dev Fungsi ini tidak mengirim ETH. Heir menarik sendiri lewat withdrawInheritance (pull payment),
    ///      sehingga satu heir yang menolak ETH tidak bisa menggagalkan pembagian untuk heir lain.
    function finalizeClaim() external inState(State.Claiming) {
        if (approvalCount < threshold) revert NotEnoughApprovals(approvalCount, threshold);
        // Sama seperti di startClaim: pergeseran beberapa detik tidak berarti untuk timelock harian.
        // forge-lint: disable-next-line(block-timestamp)
        if (block.timestamp < unlockTime) revert TimelockNotExpired(unlockTime);

        uint256 total = address(this).balance;
        snapshot = total;
        state = State.Distributed;

        // Pembagian dengan bilangan bulat selalu membulatkan ke bawah. Sisanya diberikan ke heir
        // terakhir, sehingga jumlah semua bagian tepat sama dengan snapshot (invariant 2).
        uint256 lastIndex = heirs.length - 1;
        uint256 allocated = 0;
        for (uint256 i = 0; i < lastIndex; i++) {
            uint256 amount = (total * sharesBps[i]) / TOTAL_BPS;
            inheritanceOf[heirs[i]] = amount;
            allocated += amount;
        }
        inheritanceOf[heirs[lastIndex]] = total - allocated;

        emit ClaimFinalized(claimId, total);
    }

    /// @notice Heir menarik bagian warisannya sendiri.
    /// @dev Saldo bagian di-nol-kan sebelum ETH dikirim (Checks-Effects-Interactions), ditambah
    ///      nonReentrant, sehingga heir tidak bisa menarik dua kali lewat serangan reentrancy.
    function withdrawInheritance() external nonReentrant onlyHeir inState(State.Distributed) {
        uint256 amount = inheritanceOf[msg.sender];
        if (amount == 0) revert NothingToWithdraw();

        inheritanceOf[msg.sender] = 0;
        emit InheritanceWithdrawn(msg.sender, amount);

        // ETH hanya dikirim ke pemanggil sendiri, sebesar bagian yang sudah dihitung di finalizeClaim.
        (bool success,) = msg.sender.call{value: amount}("");
        if (!success) revert TransferFailed();
    }

    // ---------------------------------------------------------------------
    // Fungsi baca
    // ---------------------------------------------------------------------

    /// @notice Ringkasan status vault untuk ditampilkan di UI.
    function getStatus() external view returns (Status memory) {
        return Status({
            state: state,
            balance: address(this).balance,
            lastCheckIn: lastCheckIn,
            activeUntil: lastCheckIn + inactivityPeriod,
            claimId: claimId,
            approvals: approvalCount,
            threshold: threshold,
            unlockTime: unlockTime
        });
    }

    // ---------------------------------------------------------------------
    // Fungsi internal
    // ---------------------------------------------------------------------

    function _deposit() private {
        // Setoran dari owner adalah bukti bahwa owner masih aktif.
        if (msg.sender == owner) {
            _checkIn();
        }
        emit Deposited(msg.sender, msg.value);
    }

    function _checkIn() private {
        lastCheckIn = block.timestamp;
        emit CheckedIn(block.timestamp);
    }

    /// @dev Revert di dalam loop disengaja: satu alamat yang tidak valid harus membatalkan deploy.
    // forge-lint: disable-next-item(require-revert-in-loop)
    function _setGuardians(address[] memory newGuardians) private {
        uint256 count = newGuardians.length;
        if (count == 0 || count > MAX_GUARDIANS) revert InvalidGuardianCount(count);

        for (uint256 i = 0; i < count; i++) {
            address guardian = newGuardians[i];
            if (guardian == address(0)) revert ZeroAddress();
            if (guardian == owner) revert OwnerCannotHaveRole();
            if (isGuardian[guardian]) revert DuplicateAddress(guardian);

            isGuardian[guardian] = true;
        }

        guardians = newGuardians;
    }

    /// @dev Pemeriksaan duplikat memakai isHeir: jika alamat sudah ditandai di putaran sebelumnya,
    ///      berarti alamat itu muncul dua kali. Karena itu tanda lama harus dihapus lebih dulu.
    ///      Revert di dalam loop disengaja: satu alamat yang tidak valid harus membatalkan seluruh daftar.
    // forge-lint: disable-next-item(require-revert-in-loop)
    function _setHeirs(address[] memory newHeirs, uint256[] memory newSharesBps) private {
        uint256 count = newHeirs.length;
        if (count == 0 || count > MAX_HEIRS) revert InvalidHeirCount(count);
        if (newSharesBps.length != count) revert LengthMismatch(count, newSharesBps.length);

        uint256 totalBps = 0;
        for (uint256 i = 0; i < count; i++) {
            address heir = newHeirs[i];
            uint256 share = newSharesBps[i];

            if (heir == address(0)) revert ZeroAddress();
            if (heir == owner) revert OwnerCannotHaveRole();
            if (isGuardian[heir]) revert GuardianCannotBeHeir(heir);
            if (isHeir[heir]) revert DuplicateAddress(heir);
            if (share == 0) revert ZeroShare(heir);

            isHeir[heir] = true;
            totalBps += share;
        }

        if (totalBps != TOTAL_BPS) revert InvalidSharesTotal(totalBps);

        heirs = newHeirs;
        sharesBps = newSharesBps;
    }
}
