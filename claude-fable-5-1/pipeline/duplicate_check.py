#!/usr/bin/env python3
"""Near-duplicate detection between variants of the same dish.

Similarity = Jaccard over (ingredient ids) blended with Jaccard over
(step tokens). Two variants above the threshold are flagged; the
generation loop should then be re-run with feedback.
"""
import json
import re
import sys
from itertools import combinations
from pathlib import Path

THRESHOLD = 0.92
CORPUS = Path(__file__).resolve().parent / "corpus" / "dishes"


def tokens(recipe):
    text = " ".join(s["text"]["en"] for s in recipe["steps"]).lower()
    return set(re.findall(r"[a-zäöüß]{3,}", text))


def jaccard(a, b):
    return len(a & b) / len(a | b) if a | b else 0.0


def similarity(r1, r2):
    ing = jaccard({i["id"] for i in r1["ingredients"]}, {i["id"] for i in r2["ingredients"]})
    steps = jaccard(tokens(r1), tokens(r2))
    return 0.5 * ing + 0.5 * steps


def main(argv):
    files = [CORPUS / f"{d}.json" for d in argv] if argv else sorted(CORPUS.glob("*.json"))
    flagged = 0
    for f in files:
        doc = json.load(open(f, encoding="utf-8"))
        for a, b in combinations(doc["recipes"], 2):
            s = similarity(a, b)
            if s >= THRESHOLD:
                flagged += 1
                print(f"NEAR-DUPLICATE {a['id']} ~ {b['id']} ({s:.2f})")
    print(f"{len(files)} dish files checked, {flagged} near-duplicates")
    return 1 if flagged else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
