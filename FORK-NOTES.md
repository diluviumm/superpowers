# FORK-NOTES — diluviumm/superpowers

Fork pribadi dari [`obra/superpowers`](https://github.com/obra/superpowers) (MIT),
diintegrasikan sebagai **plugin native Hermes Agent** di setup Mael.
Sumber divergensi: `git diff upstream/main..main` (selalu berisi HANYA item di bawah).
Panduan pemakaian sehari-hari (arsitektur, verifikasi, troubleshooting): [docs/USAGE.md](docs/USAGE.md).

> Repo ini adalah **fork konsumen** — kami tidak membuka PR fork-specific ke upstream
> (kebijakan AGENTS.md upstream melarangnya, dan divergensi kita memang disengaja).
> Perbaikan hulu yang layak (mis. menambah `.muse-plugin` ke skip-list Hermes)
> ditujukan ke repo Hermes, bukan ke obra.

## Divergensi dari upstream

| # | File | Ubahan | Alasan |
|---|---|---|---|
| 1 | `.muse-plugin/plugin.json` | **dihapus** | Hermes `plugins_discovery._FOREIGN_HARNESS_MANIFEST_DIRS` tidak mencantumkan `.muse-plugin` (daftar skip berisi claude/codex/cursor/devin/kimi saja, lihat komentar `#101962`). Tanpa penghapusan, file diparse sebagai portable package → warning `plugin.json declares an unsupported or missing Agent Plugins schema` setiap discovery pass. **Jangan dipulihkan** — dijaga `scripts/fork-guard.py` + CI. File asli tetap utuh di upstream. |
| 2 | `skills/hermes-plugin-dev/` | **skill baru** | Distilasi lokal cara menulis/memodifikasi plugin Hermes (manifest, kontrak `register()`, injeksi `pre_llm_call`, jalur update/rollback). Folder baru → konflik merge nol. |
| 3 | `.github/workflows/regresi.yml` + `scripts/fork-guard.py` | **CI + guard baru** | Upstream tidak punya CI sama sekali. Workflow ini khusus fork: pytest `tests/hermes/` + guard divergensi + lint frontmatter. |
| 4 | `skills/brainstorming/scripts/start-server.sh` | +2 baris default env | `export SUPERPOWERS_DISABLE_TELEMETRY="${SUPERPOWERS_DISABLE_TELEMETRY:-true}"` — telemetry (logo primeradiant.com, bawa versi) OFF by default di fork ini; nilai eksplisit tetap dihormati (dibaca `server.cjs` via `isTruthyEnv`). |
| 5 | `README.md` | banner 4 baris di atas + badge CI/Lisensi + tautan USAGE | Penanda fork + tautan ke dokumen ini. |
| 6 | `tests/brainstorm-server/branding.test.js` | test strip var opt-out telemetry dari env ambien (1 Okt 2026) | Sebelumnya 3 test "by default" gagal palsu di sesi dengan `SUPERPOWERS_DISABLE_TELEMETRY=true` (env bleed). Kini deterministik di CI & lokal; override eksplisit per-test tetap dihormati. |
| 7 | `scripts/package-codex-plugin.sh` + `tests/codex/test-package-codex-plugin.sh` | zip jadi opsional + fallback `python3 zipfile` deterministik (timestamp 1980-01-01, mode kanonik, urutan ARCHIVE_LIST) + jalur `zip` dibungkus `TZ=UTC` | Host tanpa binari `zip` (sebagian besar minimal/container) kini tetap bisa packaging; path Info-ZIP asli kebal selisih timezone. Fixture test ikut fallback serupa. |
| 8 | `.hermes-plugin/__init__.py` | pesan reinstall menunjuk `diluviumm/superpowers --enable --force` | Pesan `obra/superpowers` menyesatkan di konteks fork (bisa memasang versi upstream dan menghilangkan fix). |
| 9 | `.github/workflows/regresi.yml` | (lanjutan baris 3) job `harness-suites` ditambahkan; komentar env-bleed diperbarui | 9 suite harness ringan (opencode/kimi/devin/antigravity/codex/pi) kini ikut CI — 5 job total. |
| 10 | `docs/USAGE.md` (baru) | panduan penggunaan lengkap + 2 diagram mermaid (arsitektur, sequence sync) | Tata cara pakai, tabel field monitor, troubleshooting, batasan yang diketahui. |
| 11 | `scripts/fork-check.sh` (baru) | baterai verifikasi lokal satu perintah (23 checks, exit 0/1) — diperluas 1 Okt: +3 suite claude-code statis + smoke `test-helpers`; log suite dipertahankan saat gagal (transient langsung terdiagnosis) | Jalur bukti cepat sebelum push / setelah sync; lint otomatis oleh `lint-shell.sh --all`. |
| 12 | `skills/brainstorming/scripts/server.cjs` + `tests/brainstorm-server/lifecycle.test.js` | `touchActivity()` di `onListen()` + margin test idle 200→600ms | **Fix race nyata**: `lastActivity` di-set saat evaluasi modul → boot node (250-400ms) memakan budget idle → server bisa `idle timeout` SEBELUM/bareng koneksi pertama (ter-reproduksi: WS ECONNREFUSED/ECONNRESET saat handshake). Idle kini dihitung dari server siap; test 6/6 hijau (sebelumnya flaky ~1/3). |
| 13 | `skills/subagent-driven-development/scripts/sdd-workspace`, `tests/claude-code/{test-helpers.sh,test-subagent-driven-development-integration.sh,test-worktree-path-policy.sh}` | bersih-bersih baseline shellcheck (13 warning → 0) | `CDPATH=''` (idiom eksplisit), pisah `local x=$(…)` (SC2155), trap single-quote (SC2064), directive SC2088 (tilde literal disengaja), dan **fix bug nyata**: pesan `exit code: $?` di blok `||` selalu melaporkan 0 karena `$?` sudah terlanjur di-`echo` (kini `pipeline_status=$?` ditangkap di baris pertama). |
| 14 | `.github/workflows/regresi.yml` + `.github/dependabot.yml` (baru) | semua `uses:` di-pin ke commit SHA + komentar versi (checkout 11d5960/v4.4.0, setup-python a26af69/v5.6.0, setup-node 49933ea/v4.4.0) + blok `concurrency` (batal run lama) + Dependabot `github-actions` mingguan | Hardening supply-chain (panduan resmi GitHub: mutable tag bisa diracuni); Dependabot PR otomatis diuji CI (trigger `pull_request`) — fork nol dependensi paket, actions = satu-satunya dependensi eksternal. |
| 15 | `scripts/fork-check.sh` + `.github/workflows/regresi.yml` | +2 check: `version-bump` & `writing-skills` (fork-check 21→23) + langkah CI: yq pin+checksum & graphviz apt | Suite dulunya dikecualikan kini AKTIF — yq v4.54.1 dipasang user-level (sha256 diverifikasi terhadap `checksums` resmi) dan graphviz 16.1.0 diekstrak user-level (`~/.local/graphviz` + wrapper `dot`, config regen `dot -c`); blocker asli (tool tak terinstall) bukan gagal test. |

## Kebijakan sync dengan upstream

- **Fetch + merge, JANGAN force-push**: `git fetch upstream && git merge --no-edit upstream/main`.
- Konflik di `.muse-plugin/plugin.json` → **versi kita MENANG (tetap dihapus)**; file lain ikut upstream.
- Setiap merge wajib lolos, sebelum push:
  ```bash
  python3 scripts/fork-guard.py
  uv run --no-project --with pytest python -m pytest tests/hermes/ -q   # 19 test
  ```
- Identitas komit repo ini sudah dikunci lokal: `Mael <diluviumm@users.noreply.github.com>`
  (JANGAN memakai email global pribadi).

## Otomatisasi (berjalan tanpa sentuhan)

| Komponen | Peran |
|---|---|
| Cron `superpowers-fork-sync` (`8a2efee68286`, harian 05:15) | Sync upstream → guard+pytest → push → reinstall plugin → verifikasi 8 butir (a–h, termasuk baterai `fork-check.sh`) + laporan wajib per-butir |
| Monitor `~/.hermes/scripts/superpowers-fork-monitor.sh` | Output deterministik `behind=… fork_tip=… installed=… muse_repo=… muse_installed=…` — agent hanya terbangun saat status BERUBAH |
| Hook `pre_llm_call` plugin | Inject bootstrap `using-superpowers` otomatis turn pertama tiap sesi Hermes baru |

## Perintah operasi penting

```bash
# status & kesehatan
hermes plugins doctor superpowers
hermes plugins list | grep superpowers
bash ~/.hermes/scripts/superpowers-fork-monitor.sh

# baterai verifikasi lokal penuh (23 checks — guard, pytest, semua suite)
bash ~/me/github/superpowers/scripts/fork-check.sh

# update dari fork (install --force; subcommand 'update' diblokir security scan)
env -u LD_LIBRARY_PATH -u LD_PRELOAD hermes plugins install diluviumm/superpowers --enable --force

# ROLLBACK ke revisi tertentu (40-char sha)
env -u LD_LIBRARY_PATH -u LD_PRELOAD hermes plugins install diluviumm/superpowers --enable --force --ref <sha>
```

> ⚠️ **Jebakan pin `--ref` (terpuji 26 Sep 2026 lewat uji rollback):** `--ref` men-set
> **pin permanen** di `~/.hermes/plugins/.install-metadata.json` (`pinned: true`, revisi
> dikunci). Install biasa berikutnya akan **menahan sha lama** — retention logic
> `hermes_cli/plugins_cmd_install.py:308` ("Reinstalling the same pinned source retains
> its pin") — sehingga update cron bisa terkunci diam-diam. Tidak ada perintah `unpin`;
> jalur resminya **hapus + pasang ulang**:
>
> ```bash
> cp ~/.hermes/plugins/.install-metadata.json ~/.hermes/plugins/.install-metadata.json.bak
> hermes plugins remove superpowers
> hermes plugins install diluviumm/superpowers --enable --force
> ```
>
> Verifikasi selesai: metadata `pinned: false` **dan** `installed == fork_tip`
> (`bash ~/.hermes/scripts/superpowers-fork-monitor.sh`).

## Catatan lingkungan

- Dari sesi Termic: bungkus `git`/`hermes` dengan `env -u LD_LIBRARY_PATH` (LD leak AppImage).
- Keterbatasan upstream yang diketahui: Hermes tidak punya post-compaction hook —
  sesi yang mengalami kompaksi setelah turn pertama kehilangan bootstrap → sesi baru.
- Keterbatasan hulu #2 (terverifikasi di kode v0.21.5, 1 Okt 2026): `hermes serve`
  / `dashboard` tidak menjalankan plugin discovery saat startup
  (`_AGENT_COMMANDS` tanpa `serve`; `start_server()` tanpa `discover_plugins()`)
  → hook `pre_llm_call` plugin tidak fire di giliran web/desktop-backend
  (NousResearch/hermes-agent#102592). TUI/`hermes chat` normal. Perbaikannya milik
  repo Hermes, bukan fork ini.
