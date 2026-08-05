#!/bin/bash
#
# Resout une destination xcodebuild en une destination sure sur un runner partage.
#
#     scripts/ci-destination.sh 'platform=iOS Simulator,name=iPhone 17,OS=latest'
#     -> id=8A1F...   (un simulateur iPhone qui existe vraiment)
#
#     scripts/ci-destination.sh 'platform=macOS'
#     -> platform=macOS   (inchangee)
#
# POURQUOI CE SCRIPT EXISTE
#
# Les runners `macos-latest` arrivent parfois sans **aucun** appareil simule cree.
# `xcodebuild` sort alors en 70 sur « Unable to find a device matching the provided
# destination specifier », et la liste des destinations disponibles qu'il imprime ne
# contient que des placeholders : ni iPhone 17, ni aucun autre modele. Ce n'est ni le
# schema ni le specificateur — le runtime iOS est la, les appareils ne sont pas crees.
#
# Mesure le 2026-08-05 : deux occurrences en une heure, sur deux jobs differents
# (`Catalogue iOS` puis `Build iOS`). Sous ce seuil c'etait une anecdote a surveiller ;
# au-dela, un rouge intermittent apprend a ignorer le signal, ce qui est pire que pas
# de CI du tout.
#
# CE QU'IL FAIT, ET CE QU'IL NE FAIT PAS
#
# Il resout par **identifiant** au lieu de nom + version, et cree l'appareil s'il
# manque. Il ne masque aucun echec : un runtime iOS reellement absent le fait sortir en
# erreur, avec la liste de ce qui existe.

set -euo pipefail

destination="${1:?usage: ci-destination.sh <destination xcodebuild>}"

# Une destination qui ne nomme pas d'appareil n'a rien a resoudre. C'est le cas de
# `platform=macOS` et de `generic/platform=iOS Simulator`, que les builds utilisent :
# compiler pour le simulateur ne demande aucun appareil, seulement un SDK.
if [[ "$destination" != *"name=iPhone"* ]]; then
    echo "$destination"
    exit 0
fi

# Le modele demande, tel qu'il est ecrit dans la destination.
model="$(sed -E 's/.*name=([^,]+).*/\1/' <<<"$destination")"

udid="$(
    xcrun simctl list devices available --json |
        python3 -c '
import json, sys
model = sys.argv[1]
devices = json.load(sys.stdin)["devices"]
flat = [d for runtime in devices.values() for d in runtime]
# Le modele exact dabord, nimporte quel iPhone ensuite : un runner qui na pas
# liPhone 17 mais un iPhone 16 doit faire tourner la suite, pas echouer.
exact = [d for d in flat if d["name"] == model]
any_phone = [d for d in flat if "iPhone" in d["name"]]
print((exact or any_phone or [{"udid": ""}])[0]["udid"])
' "$model"
)"

if [[ -n "$udid" ]]; then
    echo "id=$udid"
    exit 0
fi

# Aucun appareil : on en cree un sur le runtime iOS le plus recent disponible.
echo "Aucun simulateur iPhone disponible, creation en cours." >&2
runtime="$(
    xcrun simctl list runtimes available --json |
        python3 -c '
import json, sys
runtimes = [r for r in json.load(sys.stdin)["runtimes"] if r["platform"] == "iOS"]
if not runtimes:
    sys.exit("Aucun runtime iOS disponible sur ce runner.")
print(sorted(runtimes, key=lambda r: r["version"])[-1]["identifier"])
'
)"

device_type="$(
    xcrun simctl list devicetypes --json |
        python3 -c '
import json, sys
model = sys.argv[1]
types = json.load(sys.stdin)["devicetypes"]
exact = [t for t in types if t["name"] == model]
any_phone = [t for t in types if t["name"].startswith("iPhone")]
if not (exact or any_phone):
    sys.exit("Aucun type dappareil iPhone sur ce runner.")
print((exact or sorted(any_phone, key=lambda t: t["name"]))[0]["identifier"])
' "$model"
)"

echo "id=$(xcrun simctl create "CI $model" "$device_type" "$runtime")"
