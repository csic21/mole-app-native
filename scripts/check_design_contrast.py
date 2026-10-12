#!/usr/bin/env python3
"""Check Qili's opaque text/surface palette in both appearances; does not replace native visual QA."""
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "Sources/MoleApp/Theme.swift"
LIGHT, DARK = "light", "dark"
colors = {LIGHT: {}, DARK: {}}
for name, light, dark in re.findall(
    r"static let (\w+) = adaptive\(light: 0x([0-9A-Fa-f]{6}), dark: 0x([0-9A-Fa-f]{6})\)",
    SOURCE.read_text(),
):
    colors[LIGHT][name] = light
    colors[DARK][name] = dark
for palette in colors.values():
    if not palette:
        raise SystemExit("No adaptive palette entries found in Theme.swift")


def luminance(value):
    channels = [int(value[index:index + 2], 16) / 255 for index in (0, 2, 4)]
    channels = [v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4 for v in channels]
    return sum(v * weight for v, weight in zip(channels, (0.2126, 0.7152, 0.0722)))


def ratio(palette, foreground, background):
    values = sorted((luminance(colors[palette][foreground]), luminance(colors[palette][background])))
    return (values[1] + 0.05) / (values[0] + 0.05)


report = {}
for palette in (LIGHT, DARK):
    results = []
    for foreground in ("star", "dim2", "dim3", "accent", "warm", "danger"):
        for background in ("canvas", "surface", "sidebar", "card", "cardHover", "selection"):
            value = ratio(palette, foreground, background)
            results.append({"foreground": foreground, "background": background, "ratio": round(value, 3)})
            if value < 4.5:
                raise SystemExit(
                    f"Contrast below 4.5:1 ({palette}): {foreground}/{background} = {value:.3f}"
                )
    value = ratio(palette, "sidebar", "accent")
    assert value >= 4.5, f"Primary button text must meet normal-size text contrast ({palette})"
    results.append({"foreground": "sidebar", "background": "accent", "ratio": round(value, 3)})
    report[palette] = {"minimum_measured": min(r["ratio"] for r in results), "pairs": results}

print(json.dumps({"scope": "Opaque palette only; excludes disabled controls, alpha composites and native controls",
                  "minimum_required": 4.5, "appearances": report}, ensure_ascii=False, indent=2))
