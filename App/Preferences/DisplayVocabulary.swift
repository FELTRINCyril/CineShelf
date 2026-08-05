import DesignSystem
import Foundation

/// La persistance du réglage d'affichage, par profil et par contexte.
///
/// **Porte un `PosterSetting`, pas un `CardDisplaySetting`.** Le premier est le couple
/// `disposition × taille` de la matrice (`I1`), le second appartient à l'ancienne
/// direction et part avec `Legacy/`. Les deux stockent la même chose ; changer de type
/// change la **clé**, sans quoi un ancien instantané se décoderait de travers.
///
/// Ce que le store porte, et rien d'autre : `docs/02` §3.10 décrit
/// `{layout, size, pageSize, sort, dir}`, mais `pageSize` est abandonné (la grille charge
/// à la demande) et `sort`/`dir` appartiennent à `TitleFilter`, que `NavigationModel`
/// sérialise déjà. Les mettre ici créerait deux sources de vérité.
enum PosterSettingStore {

    static func setting(profileID: UUID?, context: PosterContext) -> PosterSetting {
        guard let data = UserDefaults.standard.data(forKey: key(profileID, context)),
            let decoded = try? JSONDecoder().decode(PosterSetting.self, from: data)
        else { return context.defaultSetting }
        return decoded
    }

    static func save(_ setting: PosterSetting, profileID: UUID?, context: PosterContext) {
        guard let data = try? JSONEncoder().encode(setting) else { return }
        UserDefaults.standard.set(data, forKey: key(profileID, context))
    }

    /// Le préfixe `poster.` distingue ces clés de celles de `display.`, écrites par
    /// l'ancien store. Les anciennes ne sont pas migrées : elles portaient un réglage de
    /// l'ancienne direction, et le défaut du contexte est une meilleure réponse qu'une
    /// conversion approximative.
    private static func key(_ profileID: UUID?, _ context: PosterContext) -> String {
        "poster.\(profileID?.uuidString ?? "none").\(context.rawValue)"
    }
}
