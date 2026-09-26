# FORK-NOTES — diluviumm/superpowers

Fork pribadi dari [`obra/superpowers`](https://github.com/obra/superpowers) (MIT),
diintegrasikan sebagai **plugin native Hermes Agent** di setup Mael.
Sumber divergensi: `git diff upstream/main..main` (selalu berisi HANYA item di bawah).

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
| 5 | `README.md` | banner 4 baris di atas | Penanda fork + tautan ke dokumen ini. |

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
| Cron `superpowers-fork-sync` (`8a2efee68286`, harian 05:15) | Sync upstream → guard+pytest → push → reinstall plugin → verifikasi 6 butir (a–f) + laporan wajib per-butir |
| Monitor `~/.hermes/scripts/superpowers-fork-monitor.sh` | Output deterministik `behind=… fork_tip=… installed=… muse_repo=… muse_installed=…` — agent hanya terbangun saat status BERUBAH |
| Hook `pre_llm_call` plugin | Inject bootstrap `using-superpowers` otomatis turn pertama tiap sesi Hermes baru |

## Perintah operasi penting

```bash
# status & kesehatan
hermes plugins doctor superpowers
hermes plugins list | grep superpowers
bash ~/.hermes/scripts/superpowers-fork-monitor.sh

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
