#!/usr/bin/env python3
import os
import random
import re
import string
import sys

RENAME = ["JcksCrypto", "JcksAC"]


def long_bracket_level(src, i):
    m = re.match(r"\[(=*)\[", src[i:])
    return len(m.group(1)) if m else -1


def tokens(src):
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
