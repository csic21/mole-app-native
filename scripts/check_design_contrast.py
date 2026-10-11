#!/usr/bin/env python3
"""Check Qili's opaque text/surface palette; does not replace native visual QA."""
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "Sources/MoleApp/Theme.swift"
colors = {name: value for name, value in re.findall(
    r"static let (\w+) = Color\(hex: 0x([0-9A-Fa-f]{6})\)", SOURCE.read_text()
)}


def luminance(value):
    channels = [int(value[index:index + 2], 16) / 255 for index in (0, 2, 4)]
    channels = [v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4 for v in channels]
    return sum(v * weight for v, weight in zip(channels, (0.2126, 0.7152, 0.0722)))


def ratio(foreground, background):
    values = sorted((luminance(colors[foreground]), luminance(colors[background])))
    return (values[1] + 0.05) / (values[0] + 0.05)


results = []
for foreground in ("star", "dim2", "dim3", "accent", "warm", "danger"):
    for background in ("canvas", "surface", "sidebar", "card", "cardHover", "selection"):
        value = ratio(foreground, background)
        results.append({"foreground": foreground, "background": background, "ratio": round(value, 3)})
        if value < 4.5:
            raise SystemExit(f"Contrast below 4.5:1: {foreground}/{background} = {value:.3f}")
value = ratio("sidebar", "accent")
assert value >= 4.5, "Primary button text must meet normal-size text contrast"
results.append({"foreground": "sidebar", "background": "accent", "ratio": round(value, 3)})
print(json.dumps({"scope": "Opaque palette only; excludes disabled controls, alpha composites and native controls",
                  "minimum_required": 4.5, "minimum_measured": min(r["ratio"] for r in results),
                  "pairs": results}, ensure_ascii=False, indent=2))
