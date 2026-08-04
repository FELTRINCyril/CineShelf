#!/usr/bin/env python3
"""Genere Colors.xcassets a partir des fichiers de tokens.

Le JSON de tokens est la source de verite : le catalogue est un artefact
regenerable. Toute correction de couleur se fait dans le JSON, jamais dans un
.colorset a la main.

    python3 scripts/generate-colors.py

Deux fichiers sont lus, et ils n'ont pas le meme statut :

  - `colors.tokens.json` porte les 19 roles de la direction « 2a Plein cadre »
    (planche 8 du handoff). C'est le systeme, et le seul que du code neuf lit.
  - `colors.legacy.tokens.json` porte l'ancienne direction. Elle ne survit que
    parce que l'interface des prompts 10 et 11 sert de banc d'essai : ses jeux
    rendraient du transparent si on les retirait du catalogue d'assets, ce qui
    est une defaillance silencieuse. Elle meurt en bloc avec `V12`.

La la ou un nom existe dans les deux, **le nouveau gagne** : le banc d'essai prend
la nouvelle valeur, et aucun accesseur n'est declare deux fois. C'est ce qui rend
la bascule un remplacement et non une cohabitation.

Les semantiques portent 4 apparences : Any (clair), Dark, Any + High Contrast,
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
LEGACY_TOKENS = RES / "colors.legacy.tokens.json"
ASSETS = RES / "Colors.xcassets"
GENERATED = SOURCES / "ColorTokens.generated.swift"
LEGACY_GENERATED = SOURCES / "Legacy/LegacyColorTokens.generated.swift"

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

# sRGB (D65) -> XYZ, puis XYZ -> Display P3 lineaire.
SRGB_TO_XYZ = (
    (0.4123907993, 0.3575843394, 0.1804807884),
    (0.2126390059, 0.7151686788, 0.0721923154),
    (0.0193308187, 0.1191947798, 0.9505321522),
)
XYZ_TO_P3 = (
    (2.4934969119, -0.9313836179, -0.4027107845),
    (-0.8294889696, 1.7626640603, 0.0236246858),
    (0.0358458302, -0.0761723893, 0.9568845240),
)


def _linear(channel: float) -> float:
    """Retire la courbe de transfert sRGB (identique pour Display P3)."""
    if channel <= 0.04045:
        return channel / 12.92
    return ((channel + 0.055) / 1.055) ** 2.4


def _encoded(channel: float) -> float:
    """Reapplique la courbe de transfert."""
    if channel <= 0.0031308:
        return 12.92 * channel
    return 1.055 * abs(channel) ** (1 / 2.4) - 0.055


def display_p3(hex_srgb: str) -> tuple[float, float, float]:
    """Convertit un hex sRGB en composantes Display P3.

    Calcule ici plutot que recopie dans le JSON : des composantes ecrites a la
    main peuvent cesser de correspondre a leur propre hex sans que rien ne le
    signale, et c'est le hex qui se relit contre la planche 8. Verifie : cette
    conversion reproduit les 128 composantes de l'ancien fichier, qui avaient ete
    calculees separement, a 0,0002 pres.
    """
    text = hex_srgb.lstrip("#")
    channels = [int(text[i : i + 2], 16) / 255 for i in (0, 2, 4)]
    linear = [_linear(c) for c in channels]
    xyz = [sum(row[i] * linear[i] for i in range(3)) for row in SRGB_TO_XYZ]
    p3 = [sum(row[i] * xyz[i] for i in range(3)) for row in XYZ_TO_P3]
    return tuple(min(1.0, max(0.0, _encoded(c))) for c in p3)


def write_json(path: Path, payload: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2, ensure_ascii=False) + "\n")


def entry(spec: dict, appearances: list | None) -> dict:
    """Une entree `colors[]` : composantes Display P3 en float 0-1."""
    red, green, blue = display_p3(spec["hex"])
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


def semantic_colorset(token: dict) -> None:
    appearances = token["appearances"]
    colorset(
        token["name"],
        [entry(appearances[key], value) for key, value in APPEARANCES.items()],
    )


def main() -> None:
    tokens = json.loads(TOKENS.read_text())
    legacy = json.loads(LEGACY_TOKENS.read_text())

    current = [t["name"] for t in tokens["semantics"]]
    # Un nom present dans les deux directions n'est ecrit qu'une fois, par la
    # nouvelle : sinon deux .colorset se disputent le meme chemin et deux
    # accesseurs Swift portent le meme nom.
    superseded = [t for t in legacy["semantics"] if t["name"] in set(current)]
    retired = [t for t in legacy["semantics"] if t["name"] not in set(current)]

    if ASSETS.exists():
        shutil.rmtree(ASSETS)
    write_json(ASSETS / "Contents.json", {"info": INFO})

    for token in tokens["semantics"]:
        semantic_colorset(token)
    for token in retired:
        semantic_colorset(token)

    write_token_list(current)
    write_legacy_token_list([t["name"] for t in retired])

    print(f"{len(current)} jeux de la direction courante")
    print(f"{len(retired)} jeux legacy conserves pour le banc d'essai")
    print(f"{len(superseded)} jeux legacy remplaces par le nouveau nom : "
          f"{', '.join(t['name'] for t in superseded)}")
    print(f"{len(legacy['primitives'])} primitives legacy abandonnees "
          "(aucune vue ne les lisait)")
    print(f"-> {ASSETS.relative_to(ROOT)}")


# Tokens dont l'accesseur derive collisionnerait avec une API SwiftUI existante.
#
# `ShapeStyle.separator` existe deja dans SwiftUI. Declarer le notre sous le meme
# nom ne casse pas la compilation du package : ca rend `.separator` **ambigu** a
# l'usage, et une vue peut alors prendre la couleur systeme d'Apple au lieu du
# token — silencieusement. Le nom du token reste `separator` dans le JSON, fidele
# a la planche 8 ; seul l'accesseur Swift est desambiguise.
ACCESSOR_OVERRIDES = {
    "separator": "separatorLine",
}


def accessor_name(token: str) -> str:
    if token in ACCESSOR_OVERRIDES:
        return ACCESSOR_OVERRIDES[token]
    head, *tail = token.split("/")
    return head + "".join(part[:1].upper() + part[1:] for part in tail)


def swift_array(names: list[str]) -> str:
    # Pas de virgule finale : swiftlint interdit trailing_comma.
    return ",\n".join(f'        "{name}"' for name in names)


def swift_sources(names: list[str], holder: str) -> str:
    """Le seul endroit ou la chaine d'un token apparait, une fois."""
    return "\n".join(
        f'    static var {accessor_name(name)}: Color {{ {holder}.color(for: "{name}") }}'
        for name in names
    )


def swift_delegates(names: list[str], holder: str) -> str:
    return "\n".join(
        f"    public static var {accessor_name(name)}: Color "
        f"{{ {holder}.{accessor_name(name)} }}"
        for name in names
    )


def write_token_list(semantics: list[str]) -> None:
    """Emet la liste des noms de tokens, pour le catalogue et les tests.

    Une liste generee plutot que recopiee a la main : c'est ce qui garantit
    qu'un token ajoute au JSON ne peut pas etre oublie dans le catalogue, et
    que `ColorAssetTests` verifie bien tous les jeux et pas tous moins un.
    """
    swift_switch = "\n".join(
        f'        case "{name}": Color.{accessor_name(name)}' for name in semantics
    )

    GENERATED.write_text(
        f'''// Fichier genere par scripts/generate-colors.py — ne pas editer a la main.
// Source de verite : Resources/colors.tokens.json
// Regenerer avec : python3 scripts/generate-colors.py

import SwiftUI

public enum ColorTokens {{

    /// Les {len(semantics)} roles de la direction « 2a Plein cadre » — le seul
    /// niveau qu'une vue lit, et le seul que du code neuf a le droit de lire.
    ///
    /// Il n'y a pas de niveau « primitives » : la planche 8 ne fournit aucune
    /// rampe, elle pose directement ces roles avec leurs quatre apparences.
    public static let semantics: [String] = [
{swift_array(semantics)}
    ]

    /// Les {len(semantics)} Color Sets de la direction courante.
    public static let all: [String] = semantics

    /// Le nom d'accesseur Swift de chaque jeu, dans le meme ordre que `semantics`.
    ///
    /// Genere plutot que re-derive dans les tests : c'est ce qui permet a
    /// `ShapeStyleCollisionTests` de verifier les noms **reellement declares**,
    /// y compris ceux desambiguises par `ACCESSOR_OVERRIDES`.
    public static let accessorNames: [String] = [
{swift_array([accessor_name(name) for name in semantics])}
    ]

    /// La couleur d'un token, par son nom. Sert au catalogue, qui parcourt la
    /// liste ci-dessus ; le code d'application passe par les accesseurs types.
    public static func color(for token: String) -> Color {{
        Color(token, bundle: .designSystem)
    }}

    // Un `switch` exhaustif genere n'a pas de complexite au sens ou la regle
    // l'entend : il n'y a rien a y simplifier.
    // swiftlint:disable cyclomatic_complexity

    /// L'accesseur type correspondant a un jeu semantique.
    ///
    /// Ce `switch` relie la source de verite JSON aux accesseurs publics :
    /// il traverse `extension Color`, donc il en verifie le cablage.
    public static func typedAccessor(for token: String) -> Color? {{
        switch token {{
{swift_switch}
        default: nil
        }}
    }}

    // swiftlint:enable cyclomatic_complexity
}}

// MARK: - Source unique des jeux semantiques
//
// La chaine d'un token n'apparait qu'ici, une seule fois. Les deux extensions
// publiques ci-dessous s'y referent : c'est ce qui rend impossible la faute de
// frappe qui existait quand les tokens etaient ecrits a la main deux fois.

extension ColorTokens {{
{swift_sources(semantics, "ColorTokens")}
}}

// MARK: - Acces typé aux jeux semantiques
//
// Aucune couleur litterale n'existe hors de ce package. Clair, sombre et
// contraste eleve sont resolus par les apparences du catalogue d'assets, jamais
// par du code conditionnel.
//
// Deux extensions, parce que les deux chemins d'appel existent et doivent tous
// deux rester ergonomiques :
//
//   - `extension ShapeStyle where Self == Color` sert `.background(.bgCanvas)`,
//     `.foregroundStyle(.textPrimary)` — la forme implicite, celle que les vues
//     ecrivent le plus ;
//   - `extension Color` sert la ou le contexte n'infere pas un `ShapeStyle` :
//     `Color` stocke dans un modele, `.tint(Color)`, interpolations.
//
// Swift prefere le membre du type concret au membre d'extension de protocole :
// `Color.bgCanvas` atteint donc toujours la seconde, et seule la forme implicite
// atteint la premiere. C'est pour ca que ColorAssetTests les couvre separement.

extension ShapeStyle where Self == Color {{
{swift_delegates(semantics, "ColorTokens")}
}}

extension Color {{
{swift_delegates(semantics, "ColorTokens")}
}}
'''
    )


def write_legacy_token_list(semantics: list[str]) -> None:
    """Emet les jeux de l'ancienne direction que le banc d'essai lit encore."""
    LEGACY_GENERATED.parent.mkdir(parents=True, exist_ok=True)
    LEGACY_GENERATED.write_text(
        f'''// Fichier genere par scripts/generate-colors.py — ne pas editer a la main.
// Source de verite : Resources/colors.legacy.tokens.json
// Regenerer avec : python3 scripts/generate-colors.py
//
// ANCIENNE DIRECTION ARTISTIQUE — EN SURSIS.
//
// Ces {len(semantics)} jeux n'existent que pour que l'interface des prompts 10 et 11
// continue de compiler et de s'afficher : elle sert de banc d'essai a la logique.
// Les retirer du catalogue d'assets ne casserait pas la compilation, elle
// rendrait du transparent — une defaillance silencieuse.
//
// Rien de neuf ne doit les lire. Ils disparaissent en bloc avec `V12`, avec
// `Legacy/` en entier et les deux ArchivoSemiExpanded.
// Voir Legacy/README.md et « Arbitrages tranchés » de docs/PROMPTS.md.

import SwiftUI

public enum LegacyColorTokens {{

    /// Les {len(semantics)} jeux de l'ancienne direction encore lus par le banc d'essai.
    /// Les six noms communs avec la direction courante n'y sont pas : ils sont
    /// servis par `ColorTokens`, donc avec les nouvelles valeurs.
    public static let semantics: [String] = [
{swift_array(semantics)}
    ]

    public static func color(for token: String) -> Color {{
        Color(token, bundle: .designSystem)
    }}
}}

extension LegacyColorTokens {{
{swift_sources(semantics, "LegacyColorTokens")}
}}

extension ShapeStyle where Self == Color {{
{swift_delegates(semantics, "LegacyColorTokens")}
}}

extension Color {{
{swift_delegates(semantics, "LegacyColorTokens")}
}}
'''
    )


if __name__ == "__main__":
    main()
