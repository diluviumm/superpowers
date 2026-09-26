---
name: hermes-plugin-dev
description: "Author, fork, and debug native Hermes Agent plugins — manifest layout, register() pitfalls, first-turn hook injection, doctor/CI/rollback. Use when building, modifying, or troubleshooting a Hermes plugin (plugin.yaml, __init__.py, register_skill, pre_llm_call, plugin security scan)."
version: 1.0.0
author: Mael (distilasi sesi integrasi obra/superpowers, 26 Sep 2026)
tags: [hermes, plugin, development, hooks, skills]
---

# Hermes Plugin Development

Distilasi dari integrasi fork `obra/superpowers` → `diluviumm/superpowers` (v6.4.2).
Untuk CLI operasional umum (install/enable/list) lihat skill `hermes-agent`; skill ini
fokus ke **menulis/memodifikasi plugin** dan jebakan yang mematikan plugin secara diam-diam.

## Layout manifest (dua bentuk yang didukung)

```
<repo>/
├── .hermes-plugin/
│   ├── plugin.yaml      # name, version, description, provides_hooks: [pre_llm_call]
│   └── __init__.py      # def register(ctx): ... — SATU-satunya entri plugin
├── skills/<nama>/SKILL.md     # otomatis terdaftar bila di-loop oleh register()
└── hooks/…                    # milik harness LAIN (claude/codex/muse) — Hermes TIDAK membaca ini
```

- Installer kadang memperingatkan `has no plugin.yaml / __init__.py` saat instal — **kosmetik**:
  installer mengecek root, sedangkan manifest memang hidup di subdirektori `.hermes-plugin/`.
  `hermes plugins doctor` adalah otoritasnya, bukan peringatan instal itu.
- Repo multi-harness membawa `.<harness>-plugin/plugin.json` untuk harness lain.
  Hermes men-skip daftar tetap `_FOREIGN_HARNESS_MANIFEST_DIRS` (claude/codex/cursor/devin/kimi)
  — **`.muse-plugin` tidak ada di daftar itu**, jadi `plugin.json`-nya diparse sebagai portable
  package → warning `unsupported or missing Agent Plugins schema` tiap discovery pass.
  Fix di fork kita: file itu DIHUSUS; guard regresi: `python3 scripts/fork-guard.py`.

## Kontrak `register(ctx)` — dua bug yang mematikan diam-diam

1. **`ctx.register_skill(name, path)` WAJIB `pathlib.Path`** — string → `AttributeError` →
   Hermes menonaktifkan SELURUH plugin senyap (bug asli 2026-07-23; dijaga oleh
   `tests/hermes/conftest.py` yang sengaja melempar error untuk str).
2. **Hook injeksi: hanya `pre_llm_call` yang berfungsi.** Return `{"context": ...}` saat
   `is_first_turn=True` → konteks disuntik ke pesan turn pertama (terverifikasi empiris
   2026-07-23: return `on_session_start` diabaikan; `ctx.inject_message` menolak dari hook itu).
   Konsekuensi: bootstrap hilang bila sesi mengalami kompaksi setelah turn pertama
   (Hermes belum punya post-compaction hook) → resolusi: sesi baru / muat router ulang.

## Namespace skill & bentrok nama

- Plugin mendaftarkan skill sebagai `superpowers:<nama>` → `skill_view("superpowers:brainstorming")`.
- Lookup **polos** (`skill_view("systematic-debugging")`) menyelesaikan ke skill milik USER
  (`~/.hermes/skills/…`), bukan plugin → skill lokal yang diperkaya menang tanpa ambiguitas.
  Karena itu skill lokal cukup memberi catatan `Source relationship` — tidak perlu dihapus.

## Perintah yang benar (urut dari yang aman)

```bash
hermes plugins doctor <name>          # validasi runtime: manifest+import+registration
hermes plugins show <name>            # key manifest, status
hermes plugins list / check-updates   # status + versi upstream
hermes plugins install <owner>/<repo> --enable        # instal dari Git/owner-repo
hermes plugins install <own-fork> --enable --force    # reinstall (scan CAUTION → --force sah utk fork sendiri)
hermes plugins install <own-fork> --enable --force --ref <40sha>   # ROLLBACK ke sha tertentu
```

- **`hermes plugins update <name>` untuk sumber non-katalog diblokir security scan
  (229 findings, community tier) dan TIDAK punya flag `--force`** → jalur resmi update
  fork sendiri = `install … --enable --force`.
- Skan keamanan wajib di-review dulu sebelum `--force`: baca surface eksekusi
  (`.hermes-plugin/__init__.py`, `index.js`) — grep `curl|wget|base64|eval|exec|subprocess`.
  99% findings di `docs/`+`tests/` = false positive heuristik.

## Verifikasi wajib setiap perubahan plugin

```bash
hermes plugins doctor superpowers                          # OK … 1 hook
python3 scripts/fork-guard.py                              # guard regresi fork
uv run --no-project --with pytest python -m pytest tests/hermes/ -q   # 19 test bootstrap/registrasi
# lalu sesi nyata (bootstrap first-turn + skill namespace):
hermes chat -Q --oneshot --yolo -q "…verifikasi marker bootstrap + skill_view(superpowers:…)…"
```

## Jebakan lingkungan

- AppImage Termic membocorkan `LD_LIBRARY_PATH` → semua `git`/`hermes` dari sesi terminal
  WAJIB `env -u LD_LIBRARY_PATH` (gejala: `libpcre2-8.so.0 no version information`).
- Telemetry visual companion (brainstorm) dibaca `server.cjs` dari env proses;
  fork kita menyetel default OFF di `start-server.sh`
  (`SUPERPOWERS_DISABLE_TELEMETRY:-true`).
