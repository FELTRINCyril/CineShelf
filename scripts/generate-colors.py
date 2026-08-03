#!/usr/bin/env python3
"""Genere Colors.xcassets a partir de colors.tokens.json.

Le JSON de tokens est la source de verite : le catalogue est un artefact
regenerable. Toute correction de couleur se fait dans le JSON, jamais dans un
.colorset a la main.

    python3 scripts/generate-colors.py

Les primitives sont des Color Sets universels (apparence Any seule). Les
semantiques portent 4 apparences : Any, Dark, Any + High Contrast,
Dark + High Contrast. Le `/` d'un nom de token devient un dossier a espace de
noms, ce qui permet Color("bg/canvas", bundle: .designSystem).
"""

import json
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SOURCES = ROOT / "Packages/DesignSystem/Sources/DesignSystem"
RES = SOURCES / "Resources"
TOKENS = RES / "colors.tokens.json"
ASSETS = RES / "Colors.xcassets"
GENERATED = SOURCES / "ColorTokens.generated.swift"

INFO = {"author": "xcode", "version": 1}

# Cle du JSON -> attributs d'apparence du .colorset.
APPEARANCES = {
    "any": None,
    "dark": [{"appearance": "luminosity", "value": "dark"}],
    "anyHighContrast": [{"appearance": "contrast", "value": "high"}],
    "darkHighContrast": [
        {"appearance": "luminosity", "value": "dark"},
        {"appearance": "contrast", "value": "high"},
    ],
}


def write_json(path: Path, payload: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2, ensure_ascii=False) + "\n")


def entry(spec: dict, appearances: list | None) -> dict:
    """Une entree `colors[]` : composantes Display P3 en float 0-1."""
    red, green, blue = spec["displayP3"]
    item = {
        "color": {
            "color-space": "display-p3",
            "components": {
                "alpha": f"{spec.get('alpha', 1):.3f}",
                "blue": f"{blue:.4f}",
                "green": f"{green:.4f}",
                "red": f"{red:.4f}",
            },
        },
        "idiom": "universal",
    }
    if appearances:
        item["appearances"] = appearances
    return item


def colorset(name: str, colors: list[dict]) -> None:
    """Ecrit <name>.colorset et les Contents.json des dossiers traverses."""
    *groups, leaf = name.split("/")
    directory = ASSETS
    for group in groups:
        directory = directory / group
        # provides-namespace : c'est ce qui rend le prefixe adressable.
        write_json(
            directory / "Contents.json",
            {"info": INFO, "properties": {"provides-namespace": True}},
        )
    write_json(
        directory / f"{leaf}.colorset" / "Contents.json",
        {"colors": colors, "info": INFO},
    )


def main() -> None:
    tokens = json.loads(TOKENS.read_text())

    if ASSETS.exists():
        shutil.rmtree(ASSETS)
    write_json(ASSETS / "Contents.json", {"info": INFO})

    for primitive in tokens["primitives"]:
        colorset(primitive["name"], [entry(primitive["universal"], None)])

    for semantic in tokens["semantics"]:
        appearances = semantic["appearances"]
        colorset(
            semantic["name"],
            [entry(appearances[key], value) for key, value in APPEARANCES.items()],
        )

    write_token_list(
        [p["name"] for p in tokens["primitives"]],
        [s["name"] for s in tokens["semantics"]],
    )

    count = len(tokens["primitives"]) + len(tokens["semantics"])
    print(f"{count} Color Sets generes dans {ASSETS.relative_to(ROOT)}")
    print(f"Liste des tokens ecrite dans {GENERATED.relative_to(ROOT)}")


def write_token_list(primitives: list[str], semantics: list[str]) -> None:
    """Emet la liste des noms de tokens, pour le catalogue et les tests.

    Une liste generee plutot que recopiee a la main : c'est ce qui garantit
    qu'un token ajoute au JSON ne peut pas etre oublie dans le catalogue, et
    que `ColorAssetTests` verifie bien les 59 jeux et pas 58.
    """

    def swift_array(names: list[str]) -> str:
        # Pas de virgule finale : swiftlint interdit trailing_comma.
        return ",\n".join(f'        "{name}"' for name in names)

    def accessor_name(token: str) -> str:
        head, *tail = token.split("/")
        return head + "".join(part[:1].upper() + part[1:] for part in tail)

    def swift_switch(names: list[str]) -> str:
        return "\n".join(
            f'        case "{name}": Color.{accessor_name(name)}' for name in names
        )

    GENERATED.write_text(
        f'''// Fichier genere par scripts/generate-colors.py — ne pas editer a la main.
// Source de verite : Resources/colors.tokens.json
// Regenerer avec : python3 scripts/generate-colors.py

import SwiftUI

public enum ColorTokens {{

    /// Les {len(primitives)} primitives. Aucune vue de l'app ne doit les lire :
    /// elles ne sont exposees que pour le catalogue et les tests.
    public static let primitives: [String] = [
{swift_array(primitives)}
    ]

    /// Les {len(semantics)} jeux semantiques — le seul niveau que les vues lisent.
    public static let semantics: [String] = [
{swift_array(semantics)}
    ]

    /// Les {len(primitives) + len(semantics)} Color Sets du catalogue.
    public static let all: [String] = primitives + semantics

    /// La couleur d'un token, par son nom. Sert au catalogue, qui parcourt les
    /// listes ci-dessus ; le code d'application passe par les accesseurs types.
    public static func color(for token: String) -> Color {{
        Color(token, bundle: .designSystem)
    }}

    // Un `switch` exhaustif genere n'a pas de complexite au sens ou la regle
    // l'entend : il n'y a rien a y simplifier.
    // swiftlint:disable cyclomatic_complexity

    /// L'accesseur type correspondant a un jeu semantique.
    ///
    /// Ce `switch` est ce qui relie la source de verite JSON aux accesseurs
    /// ecrits a la main dans Colors.swift : ajouter un jeu semantique au JSON
    /// sans lui ecrire son accesseur casse la compilation, pas seulement un test.
    public static func typedAccessor(for token: String) -> Color? {{
        switch token {{
{swift_switch(semantics)}
        default: nil
        }}
    }}

    // swiftlint:enable cyclomatic_complexity
}}
'''
    )


if __name__ == "__main__":
    main()
