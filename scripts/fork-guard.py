#!/usr/bin/env python3
"""Fork guard — regression checks for diluviumm/superpowers (fork of obra/superpowers).

Dijalankan di tiga tempat yang sama:
  - lokal / cron superpowers-fork-sync :  python3 scripts/fork-guard.py
  - CI GitHub Actions                   :  .github/workflows/regresi.yml
Exit 0 = lulus. Exit 1 = regresi terdeteksi (setiap kegagalan dicetak ber-"- ").
Cek:
  1. .muse-plugin/plugin.json tetap ABSENT (fork fix: Hermes discovery
     _FOREIGN_HARNESS_MANIFEST_DIRS tidak mencantumkan .muse-plugin, sehingga
     file ini diparse sebagai portable package dan memicu warning
     "plugin.json declares an unsupported or missing Agent Plugins schema").
  2. Manifest Hermes utuh (.hermes-plugin/plugin.yaml + __init__.py).
  3. Frontmatter semua skill: ada name+description, name == nama folder.
  4. File yang dibutuhkan bootstrap tetap ada (using-superpowers + hermes-tools.md).
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
fails = []

# 1) Larangan file .muse-plugin/plugin.json ---------------------------------
muse = ROOT / ".muse-plugin" / "plugin.json"
if muse.exists():
    fails.append(
        "REGRESI: .muse-plugin/plugin.json ADA LAGI — warning Hermes "
        "'unsupported or missing Agent Plugins schema' akan muncul tiap discovery "
        "(fork fix dari e586dbd/5288c37 dilanggar; jangan dipulihkan)"
    )

# 2) Manifest Hermes utuh ----------------------------------------------------
hermes_dir = ROOT / ".hermes-plugin"
manifest = hermes_dir / "plugin.yaml"
if not manifest.is_file():
    fails.append("REGRESI: .hermes-plugin/plugin.yaml hilang — plugin tidak akan terdaftar")
else:
    text = manifest.read_text(encoding="utf-8")
    if not re.search(r"^name:\s*superpowers\s*$", text, re.M):
        fails.append("plugin.yaml: baris 'name: superpowers' tidak ditemukan")
    if not re.search(r"^version:\s*\S", text, re.M):
        fails.append("plugin.yaml: version kosong")
if not (hermes_dir / "__init__.py").is_file():
    fails.append("REGRESI: .hermes-plugin/__init__.py hilang — register(hook+skill) mati")

# 3) Frontmatter semua skill -------------------------------------------------
skills_dir = ROOT / "skills"
if not skills_dir.is_dir():
    fails.append("REGRESI: direktori skills/ hilang")
else:
    for d in sorted(p for p in skills_dir.iterdir() if p.is_dir()):
        f = d / "SKILL.md"
        if not f.is_file():
            fails.append(f"{d.name}: SKILL.md hilang")
            continue
        raw = f.read_text(encoding="utf-8", errors="replace")
        m = re.match(r"^---\n([\s\S]*?)\n---\n", raw)
        if not m:
            fails.append(f"{d.name}: frontmatter tidak valid (tidak diawali blok ---)")
            continue
        fm = m.group(1)
        nm = re.search(r"^name:\s*(\S+)", fm, re.M)
        if not nm:
            fails.append(f"{d.name}: name kosong")
        elif nm.group(1) != d.name:
            fails.append(f"{d.name}: name frontmatter '{nm.group(1)}' tidak sama nama folder")
        if not re.search(r"^description:\s*\S", fm, re.M):
            fails.append(f"{d.name}: description kosong")

# 4) File kritis bootstrap ----------------------------------------------------
for req in (
    "skills/using-superpowers/SKILL.md",
    "skills/using-superpowers/references/hermes-tools.md",
):
    if not (ROOT / req).is_file():
        fails.append(f"REGRESI: {req} hilang — bootstrap first-turn akan RuntimeError")

if fails:
    print("FORK GUARD: GAGAL")
    for f in fails:
        print(" -", f)
    sys.exit(1)

n = len([p for p in skills_dir.iterdir() if p.is_dir()]) if skills_dir.is_dir() else 0
print(
    "FORK GUARD: LULUS — .muse-plugin/plugin.json absent, manifest Hermes utuh, "
    f"{n} skill frontmatter valid, file bootstrap lengkap"
)
