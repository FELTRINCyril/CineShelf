import SwiftUI

// MARK: - Icônes
//
// SF Symbols uniquement, correspondance de la section 8 du handoff. Aucune icône
// d'interface n'a été dessinée : partout où un prototype montre une pastille
// carrée ou un caractère typographique, c'est le symbole d'ici qu'il faut.
//
// Rendu : `.regular` partout, `hierarchical` quand le symbole accompagne du
// texte, `monochrome` dans les barres. **Un seul symbole prend l'ambre : celui de
// l'élément actif.** Deux exceptions nommées par le handoff — `delete` est toujours
// en `danger`, et `error` n'est jamais en ambre.
//
// Tout est en `String` ici, comme la table du handoff. Les états pleins (`.fill`)
// sont l'affaire du composant qui les rend, pas du token : c'est pour ça que
// `SymbolPair` n'appartient plus à ce niveau et vit avec l'ancienne direction.

public enum Icon {

    // Navigation
    public static let home = "house"
    public static let titles = "film.stack"
    /// Jamais `person.crop.circle`, qui est réservé aux profils.
    public static let people = "person.2"
    public static let collections = "rectangle.stack"
    public static let gallery = "photo.on.rectangle.angled"
    public static let search = "magnifyingglass"
    /// Plein quand le titre y est.
    public static let myList = "heart"
    /// Plein quand marqué.
    public static let bookmarks = "bookmark"
    /// Un journal daté, pas un flux social.
    public static let feed = "clock.arrow.circlepath"

    // Actions
    /// Jamais `plus.circle` dans une barre.
    public static let addTitle = "plus"
    public static let edit = "pencil"
    /// Toujours rendu en `danger`.
    public static let delete = "trash"
    public static let importItem = "square.and.arrow.down"
    public static let exportItem = "square.and.arrow.up"
    public static let merge = "arrow.triangle.merge"
    public static let crop = "crop"
    public static let replaceImage = "arrow.2.squarepath"

    // Affichage
    public static let sort = "arrow.up.arrow.down"
    /// Ambre si un filtre est actif.
    public static let filter = "line.3.horizontal.decrease"
    /// Sélecteur de la matrice.
    public static let layoutPortrait = "rectangle.portrait"
    /// Sélecteur de la matrice.
    public static let layoutLandscape = "rectangle"
    /// Menu compact / medium / large.
    public static let thumbnailSize = "square.grid.2x2"

    // États d'une fiche
    //
    // Nommés `…Star` et `…Mark` parce que `rating` et `watched` désignent encore
    // les `SymbolPair` de l'ancienne direction, que le banc d'essai lit. Les deux
    // noms courts redeviendront libres quand `Legacy/` partira, avec `V12`.

    /// Plein pour les crans remplis.
    public static let ratingStar = "star"
    /// Jamais `eye`.
    public static let watchedMark = "checkmark"
    /// Sur la vignette masquée.
    public static let isPrivate = "eye.slash"

    // Profils et système
    /// `lockFallback` en secours si Face ID n'est pas disponible.
    public static let lockedProfile = "faceid"
    public static let lockFallback = "lock.fill"
    public static let settings = "gearshape"
    /// Unique usage de `person.crop.circle`.
    public static let profiles = "person.crop.circle"

    // Bandeaux d'interruption
    public static let offline = "wifi.slash"
    /// En rotation pendant la tâche.
    public static let sync = "arrow.triangle.2.circlepath"
    public static let diskSpace = "externaldrive"
    /// Jamais en ambre.
    public static let error = "exclamationmark.triangle"

    // Chrome
    /// Dialogues et visionneuse.
    public static let close = "xmark"
    public static let moreActions = "ellipsis"
    /// Lignes de liste.
    public static let navigateForward = "chevron.right"
    /// Visionneuse.
    public static let fullScreen = "arrow.up.left.and.arrow.down.right"
    /// Image précédente et suivante dans la visionneuse — bloc `6c`, les deux cibles de 44.
    ///
    /// **Deux noms, et l'un des deux est un alias**, pas une constante neuve : `nextImage` et
    /// `selectionMark` portent le glyphe de `navigateForward` et de `watchedMark`. La garde
    /// « aucun doublon dans `Icon.all` » a mordu quand je les avais écrits en clair, et elle a
    /// raison — `all` sert à vérifier qu'un symbole **existe** dans SF Symbols, et le vérifier
    /// deux fois ne prouve rien de plus. L'alias garde le nom lisible à l'appel sans doubler
    /// la liste.
    public static let previousImage = "chevron.left"
    public static let nextImage = navigateForward
    /// La pastille de sélection multiple du bloc `6f`.
    public static let selectionMark = watchedMark

    /// Tous les symboles de la correspondance, pour le catalogue et les tests.
    ///
    /// Écrit à la main plutôt que par réflexion : Swift n'énumère pas les membres
    /// statiques d'un `enum` sans cas. `IconTests` échoue si l'un d'eux n'existe
    /// pas dans SF Symbols sur la plateforme courante — un nom de symbole faux ne
    /// casse pas la compilation, il rend un carré vide.
    public static let all: [String] = [
        home, titles, people, collections, gallery, search, myList, bookmarks, feed,
        addTitle, edit, delete, importItem, exportItem, merge, crop, replaceImage,
        sort, filter, layoutPortrait, layoutLandscape, thumbnailSize,
        ratingStar, watchedMark, isPrivate,
        lockedProfile, lockFallback, settings, profiles,
        offline, sync, diskSpace, error,
        close, moreActions, navigateForward, fullScreen,
        previousImage
    ]
}

// MARK: - Confort

extension Image {
    /// Symbole du design system, rendu hiérarchique par défaut.
    public static func ds(_ symbol: String) -> some View {
        Image(systemName: symbol).symbolRenderingMode(.hierarchical)
    }
}

extension View {
    /// Remplacement animé d'un symbole d'état, sous réserve de Reduce Motion.
    public func dsSymbolReplace<V: Equatable>(value: V) -> some View {
        contentTransition(.symbolEffect(.replace))
            .dsAnimation(Motion.fast, value: value)
    }
}
