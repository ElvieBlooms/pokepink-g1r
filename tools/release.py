#!/usr/bin/env python3
"""Build every mod in mods/ as one lockstep release.

    python3 tools/release.py 0.3.0 [--engine PATH] [--stamp] [--out dist]

For each mods/<id>/:
  - checks manifest.json's version equals VERSION (or rewrites it with
    --stamp, which is how you bump the whole collection at once),
  - runs the engine's modkit `validate --strict` and `lint` (pack runs them
    again at strict level and refuses on any finding: no ROM content gets out),
  - packs dist/<id>-<VERSION>.zip with the mod files at the archive root.
Then writes dist/sha256sums.txt, which cartkit reads to pin each mod.

The engine checkout comes from --engine, else $G1R_ROOT, else
~/dev/gen1recomp-dev. modkit needs python3 and luajit.
"""
import argparse, hashlib, json, os, re, subprocess, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MODS = os.path.join(ROOT, "mods")

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("version")
    ap.add_argument("--engine", default=os.environ.get("G1R_ROOT") or os.path.expanduser("~/dev/gen1recomp-dev"))
    ap.add_argument("--stamp", action="store_true", help="rewrite every manifest to VERSION")
    ap.add_argument("--out", default=os.path.join(ROOT, "dist"))
    a = ap.parse_args()

    if not re.fullmatch(r"\d+\.\d+\.\d+", a.version):
        sys.exit("release: version must be X.Y.Z, got %r" % a.version)
    modkit = os.path.join(a.engine, "tools", "modkit.py")
    if not os.path.isfile(modkit):
        sys.exit("release: no engine checkout at %s (pass --engine or set G1R_ROOT)" % a.engine)

    ids = sorted(d for d in os.listdir(MODS) if os.path.isfile(os.path.join(MODS, d, "manifest.json")))
    if not ids:
        sys.exit("release: no mods under mods/")

    wrong = []
    for mid in ids:
        path = os.path.join(MODS, mid, "manifest.json")
        with open(path, encoding="utf-8") as fh:
            manifest = json.load(fh)
        if manifest.get("id") != mid:
            sys.exit("release: mods/%s/manifest.json has id %r; the folder and id must match" % (mid, manifest.get("id")))
        if manifest.get("version") != a.version:
            if a.stamp:
                manifest["version"] = a.version
                with open(path, "w", encoding="utf-8") as fh:
                    json.dump(manifest, fh, indent=2, ensure_ascii=False)
                    fh.write("\n")
            else:
                wrong.append("%s is %s" % (mid, manifest.get("version")))
    if wrong:
        sys.exit("release: every mod must be at %s (%s); rerun with --stamp to bump them all"
                 % (a.version, ", ".join(wrong)))

    os.makedirs(a.out, exist_ok=True)
    sums = []
    for mid in ids:
        src = os.path.join(MODS, mid)
        zpath = os.path.join(a.out, "%s-%s.zip" % (mid, a.version))
        if os.path.exists(zpath):
            os.remove(zpath)
        for cmd in (["validate", src, "--strict"], ["lint", src], ["pack", src, "-o", zpath]):
            print("==> modkit", " ".join(cmd[:1] + [mid] + cmd[2:]).replace(src, mid), flush=True)
            r = subprocess.run([sys.executable, modkit] + cmd, cwd=a.engine)
            if r.returncode:
                sys.exit("release: modkit %s failed for %s" % (cmd[0], mid))
        with open(zpath, "rb") as fh:
            sums.append("%s  %s" % (hashlib.sha256(fh.read()).hexdigest(), os.path.basename(zpath)))

    with open(os.path.join(a.out, "sha256sums.txt"), "w") as fh:
        fh.write("\n".join(sums) + "\n")
    print("\nreleased %d mods at %s into %s" % (len(ids), a.version, a.out))
    for line in sums:
        print("  " + line)

if __name__ == "__main__":
    main()
