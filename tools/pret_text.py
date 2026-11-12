#!/usr/bin/env python3
"""Convert pret text blocks (text/line/cont/para/done) to the engine's strings.

    from pret_text import load_labels
    labels = load_labels("path/to/disasm")   # {"_LabelText": "engine string"}

    python3 pret_text.py <disasm_root> <imported_generated_dir>   # selftest

The selftest converts every label in the disassembly and compares it with the
same label in the player's imported text.lua; on vanilla pokeyellow every
comparable label must match.
"""
import os, re, subprocess, sys

# pret charmap names -> what the engine's imported strings use
REPLACE = [
    ("#MON", "POKéMON"), ("#", "POKé"),
    ("<PLAYER>", "{PLAYER}"), ("<RIVAL>", "{RIVAL}"),
    ("<PK><MN>", "<PKMN>"), ("<……>", "……"),
]


def convert_line(s):
    for a, b in REPLACE:
        s = s.replace(a, b)
    return s


def parse_block(lines):
    """lines: the asm lines of one label, without the label line.
    Returns the engine string, or None for blocks this doesn't handle."""
    out, after_at = "", False
    for raw in lines:
        line = raw.split(";", 1)[0].strip()
        if not line:
            continue
        m = re.match(r'(text|line|cont|para|next)\s+"(.*)"$', line)
        if m:
            kind, body = m.group(1), convert_line(m.group(2))
            # after "...@" + text_ram, a "text" command carries on in place
            if kind == "text" or (after_at and kind == "text"):
                out += body
            elif kind in ("line", "next"):
                out += "\n" + body
            elif kind == "cont":
                out += "\x0b" + body  # the engine's scroll marker
            else:  # para
                out += "\f" + body
            after_at = out.endswith("@")
            if after_at:
                out = out[:-1]
            continue
        m = re.match(r"text_ram\s+(\w+)", line)
        if m:
            out += "{RAM:%s}" % m.group(1)
            after_at = False
            continue
        if line == "done":
            return out + "{DONE}"
        if line == "prompt":
            return out + "{PROMPT}"
        if line == "text_end":
            return out + ("{DONE}" if after_at else "")
        return None  # other macros (decimals, jumps, sounds): leave to the engine
    return out + ("{DONE}" if after_at else "")


def load_labels(root):
    labels = {}
    tdir = os.path.join(root, "text")
    for fn in sorted(os.listdir(tdir)):
        if not fn.endswith(".asm"):
            continue
        cur, buf = None, []
        for raw in open(os.path.join(tdir, fn)):
            m = re.match(r"(_\w+)::", raw)
            if m:
                if cur:
                    labels[cur] = parse_block(buf)
                cur, buf = m.group(1), []
            elif cur:
                buf.append(raw)
        if cur:
            labels[cur] = parse_block(buf)
    return {k: v for k, v in labels.items() if v is not None}


def selftest(root, gen_dir):
    import json
    p = subprocess.run(["luajit", "-e", r'''
local t = dofile(%r)
for k, v in pairs(t) do
  if type(v) == "string" then
    io.write(k, "\0", v, "\1")
  end
end''' % (gen_dir + "/text.lua")], capture_output=True, text=True)
    imported = dict(x.split("\0", 1) for x in p.stdout.split("\1") if "\0" in x)
    mine = load_labels(root)
    both = [k for k in mine if k in imported]
    bad = [k for k in both if mine[k] != imported[k]]
    print("selftest: %d labels converted, %d also in the import, %d differ" % (len(mine), len(both), len(bad)))
    for k in bad[:6]:
        print("  %s\n    mine: %r\n    imp:  %r" % (k, mine[k][:120], imported[k][:120]))
    return not bad


if __name__ == "__main__":
    sys.exit(0 if selftest(sys.argv[1], sys.argv[2]) else 1)
