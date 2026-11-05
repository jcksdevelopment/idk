#!/usr/bin/env python3
"""
Build-time hardening for the client Lua (used by scripts/package.sh on dist/ only; sources stay readable).

1. Strips comments and blank lines, so the shipped files carry no explanations of what each check does.
2. Renames the scanner's global tables (Sentinel, SentinelCrypto) to random identifiers chosen per
   build, so an executor can't find them by a well-known name and patch e.g. Sentinel.flag.

A real tokenizer handles '...', "...", long strings [[ ]] / [==[ ]==] and long comments, so code
inside strings is never touched. This is light obfuscation, not protection: a determined attacker
can still read the logic. The heartbeat and server-side checks are what carry the security.

Usage: obfuscate.py <dir> [--seed N]   (rewrites every .lua under <dir> in place)
"""
import os
import random
import re
import string
import sys

RENAME = ["SentinelCrypto", "Sentinel"]  # longest first is irrelevant: we match whole identifiers


def long_bracket_level(src, i):
    """If src[i:] starts a long bracket like [[ or [==[, return its level, else -1."""
    m = re.match(r"\[(=*)\[", src[i:])
    return len(m.group(1)) if m else -1


def tokens(src):
    """Yield (kind, text) with kind in {code, string, comment}."""
    i, n, start = 0, len(src), 0
    while i < n:
        c = src[i]
        if src.startswith("--", i):
            if start < i:
                yield "code", src[start:i]
            lvl = long_bracket_level(src, i + 2)
            if lvl >= 0:
                close = "]" + "=" * lvl + "]"
                end = src.find(close, i)
                end = n if end < 0 else end + len(close)
            else:
                end = src.find("\n", i)
                end = n if end < 0 else end
            yield "comment", src[i:end]
            i = start = end
        elif c in "'\"":
            if start < i:
                yield "code", src[start:i]
            j = i + 1
            while j < n and src[j] != c:
                j += 2 if src[j] == "\\" else 1
            yield "string", src[i:j + 1]
            i = start = j + 1
        elif c == "[" and long_bracket_level(src, i) >= 0:
            lvl = long_bracket_level(src, i)
            if start < i:
                yield "code", src[start:i]
            close = "]" + "=" * lvl + "]"
            end = src.find(close, i)
            end = n if end < 0 else end + len(close)
            yield "string", src[i:end]
            i = start = end
        else:
            i += 1
    if start < n:
        yield "code", src[start:n]


def transform(src, names):
    out = []
    for kind, text in tokens(src):
        if kind == "comment":
            # Keep a line break where a line comment ended so statements stay separated.
            out.append(" ")
            continue
        if kind == "code":
            for old, new in names.items():
                text = re.sub(r"(?<![\w.:])" + old + r"\b", new, text)
        out.append(text)
    lines = [ln.rstrip() for ln in "".join(out).splitlines()]
    return "\n".join(ln for ln in lines if ln.strip()) + "\n"


def random_name(rng):
    return "_" + "".join(rng.choice(string.ascii_letters) for _ in range(11))


def main():
    root = sys.argv[1]
    seed = int(sys.argv[sys.argv.index("--seed") + 1]) if "--seed" in sys.argv else None
    rng = random.SystemRandom() if seed is None else random.Random(seed)
    names = {old: random_name(rng) for old in RENAME}
    count = 0
    for dirpath, _, files in os.walk(root):
        for f in files:
            if f.endswith(".lua") and f != "fxmanifest.lua":
                p = os.path.join(dirpath, f)
                with open(p, encoding="utf-8") as fh:
                    src = fh.read()
                with open(p, "w", encoding="utf-8") as fh:
                    fh.write(transform(src, names))
                count += 1
    print(f"obfuscated {count} files; globals: " + ", ".join(f"{k}->{v}" for k, v in names.items()))


if __name__ == "__main__":
    main()
