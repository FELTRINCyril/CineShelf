# CineShelf — Audit technique de l'existant

> Basé sur le clone de `FELTRINCyril/CineShelf` @ `main` (1 commit, 355 fichiers, ~58 500 lignes de code).
> Cet audit sert de **point de départ factuel** à la refonte. Chaque constat est chiffré.

---

## 1. Vue d'ensemble

| Zone | Fichiers | Lignes | Rôle |
|---|---:|---:|---|
| `src/` (frontend React) | 190 | **35 458** | SPA React 19 + Vite 7 + Tailwind 3 + shadcn/ui |
| `server/` (API Express) | 40 | **12 465** | Express 4 + better-sqlite3 / libsql (Turso) |
| `worker/` (API Cloudflare) | 46 | **10 512** | Réimplémentation TypeScript de la même API |
| `docs/performance/` | 7 | — | Plan perf en 4 lots, tous cochés ✅ |

**Stack** : React 19 · Vite 7 · TypeScript 5.9 · Tailwind 3.3 · shadcn/ui (Radix) · TanStack Query 5 · TanStack Virtual 3 · React Router 7 · react-hook-form + Zod · framer-motion · sonner · Express 4 · SQLite/libSQL · JWT · multer · exceljs/xlsx · Cloudflare Workers + R2 + Turso.

**Ce qui est déjà bien fait** (à conserver dans la refonte) :

- Code splitting par route (`React.lazy` sur les 21 pages) et `manualChunks` Vite bien pensés.
- Virtualisation des grilles (`VirtualizedCatalogGrid`, `useVirtualGrid`, `@tanstack/react-virtual`).
- Recherche FTS5 avec `remove_diacritics 2` — bon choix pour du contenu francophone.
- Pagination serveur avec `page_size` et garde-fou `rejectUnauthenticatedFullList`.
- Migration des médias base64 → fichiers disque + R2 déjà faite (la DB était à 192 Mo).
- Un vrai modèle de visibilité (privé / caché / view-all / view-own-only) et des profils liés / sandbox.
- Documentation perf existante et honnête (`docs/performance/`).

---

## 2. Les 6 problèmes structurels majeurs

### 2.1 🔴 Backend écrit **deux fois**

`server/` (Express, 12 465 l.) et `worker/` (Cloudflare, 10 512 l.) implémentent le **même contrat d'API**. On retrouve les mêmes modules dupliqués :

```
server/actorSocialLink.js   (352 l.)  ↔  worker/src/lib/actorSocialLink.ts   (375 l.)
server/entityMerge.js       (434 l.)  ↔  worker/src/lib/entityMerge.ts       (265 l.)
server/dataTransfer*.js    (2719 l.)  ↔  worker/src/lib/dataTransfer/*     (~1500 l.)
server/catalogVisibility.js           ↔  worker/src/lib/catalog/visibility.ts (329 l.)
server/movieFields.js                 ↔  worker/src/lib/catalog/movieFields.ts
… et 15 autres paires
```

Il existe même un script `worker/scripts/compare-api-parity.mjs` : la preuve que la divergence est un problème connu et surveillé manuellement.

**Coût** : chaque nouvelle fonctionnalité doit être écrite, testée et déboguée deux fois. C'est la première chose à supprimer.

### 2.2 🔴 `SettingsPage.tsx` : 6 487 lignes, 100 `useState`

Un seul composant `SettingsPage()` couvre **10 onglets** (`movies`, `actors`, `collections`, `genres`, `social`, `medias`, `saved-links`, `links`, `relations`, `users`), avec :

- **100** appels `useState` dans le même scope
- 6 `useQuery`
- des sous-composants déclarés dans le même fichier (`DraftLinksEditor`, `GenrePicker`)
- des types métier locaux (`MovieDetailData`, `ActorDetailData`, `DraftMedia`…) qui devraient être partagés

Chaque frappe clavier dans un champ re-rend l'intégralité de l'écran. C'est la cause principale du « 400 % CPU » documenté dans `docs/performance/README.md`.

### 2.3 🔴 Trois systèmes de couleurs concurrents

| Système | Où | Exemples |
|---|---|---|
| Variables HSL shadcn | `src/index.css` `:root` + `.dark` | `--primary: 345 84% 55%` |
| Skin « noir » | `src/noir/noir.css` (1 871 l., 197 classes) | `[data-skin='noir'] { --background: 0 0% 0% }` |
| Hex en dur | partout dans le TSX | `text-[#e11d48]`, `bg-[#111827]` |

Comptage sur `src/` :

| Mesure | Occurrences |
|---|---:|
| Valeurs hex en dur | **655** |
| Classes Tailwind arbitraires `[#xxxxxx]` | **~490** |
| dont `[#e11d48]` (le rouge accent) | **248** |
| `rgba()` en dur | **129** |
| Variables CSS déclarées dans `noir.css` | **14** seulement |

Deux palettes incompatibles cohabitent : la palette « slate » (`#111827`, `#1a222e`, `#0d1117`, `#0f172a` — famille Tailwind gray/slate) héritée du design d'origine, et la palette « noir » (`#000`, `#0a0a0a`, `#141414`, `#181818`, `#191919`) ajoutée ensuite. Les deux sont visibles simultanément à l'écran.

Conséquence directe : **impossible de changer une couleur sans un rechercher/remplacer sur 490 occurrences**, et le dark mode « n'est pas un mode », c'est le seul état possible (`.dark` a exactement les mêmes valeurs que `:root`).

### 2.4 🟠 Échelle typographique cassée

| Taille | Occurrences | Verdict |
|---|---:|---|
| `text-xs` (12px) | 235 | OK |
| `text-sm` (14px) | 188 | OK |
| **`text-[10px]`** | **73** | ⚠️ sous le plancher de lisibilité |
| `text-[11px]` | 12 | ⚠️ |
| `text-[9px]` | 2 | 🔴 illisible |
| `text-[0.8rem]` | 4 | valeur arbitraire hors échelle |

423 des ~560 usages typographiques sont dans les deux plus petites tailles : l'interface est **uniformément trop dense**, sans hiérarchie. Il n'y a que 6 usages de `text-3xl` et 1 de `text-4xl` sur toute l'app.

Même problème sur les rayons : `rounded-sm/md/lg/xl/2xl/3xl/full` + `rounded-[2px]` + `rounded-[calc(var(--radius)-5px)]` = 8 valeurs pour un besoin de 5.

### 2.5 🟠 36 composants shadcn sur 58 ne sont jamais importés

`src/components/ui/` contient **58** fichiers. **36 ne sont référencés nulle part** :

```
accordion, aspect-ratio, breadcrumb, button-group, calendar, carousel, chart,
collapsible, context-menu, drawer, dropdown-menu, empty, field, form, hover-card,
input-group, input-otp, item, kbd, menubar, multi-select, navigation-menu,
pagination, progress, radio-group, resizable, scroll-area, sidebar, slider,
spinner, table, toast, toaster, toggle, toggle-group, tooltip
```

Notable : `dropdown-menu`, `tooltip`, `table` et `pagination` sont inutilisés **alors que l'app a des menus déroulants, des infobulles, des tableaux et de la pagination** — réimplémentés à la main ailleurs (`ListPagination.tsx`, `ListDisplayMenu.tsx`, `SettingsDataGrid.tsx`, `FormCommandPopoverContent.tsx`). C'est la définition d'un design system non appliqué.

Les 22 réellement utilisés : `button` (40 fichiers), `label`, `input`, `badge`, `image-with-fallback`, `image`, `popover`, `switch`, `select`, `dialog`, `skeleton`, `sheet`, `command`, `card`, `textarea`, `tabs`, `avatar`, `separator`, `checkbox`, `alert-dialog`, `alert`, `sonner`.

### 2.6 🟠 Schéma SQLite : 46 colonnes ajoutées par `ALTER TABLE` au démarrage

`server/db.js` contient 19 `CREATE TABLE` puis une fonction `migrateColumns()` qui exécute **46 `ALTER TABLE … ADD COLUMN`** conditionnels à chaque boot, sans table de versions de schéma. Plus une migration FTS5 entière dans un `try/catch` silencieux (`console.warn('[db] FTS5 migration skipped')`).

Dettes de modélisation identifiées (détail complet dans `02-BASE-DE-DONNEES.md`) :

- **21 colonnes de recadrage** `*_position_x/_y/_zoom` éparpillées sur `movies`, `actors`, `collections`.
- `actors` et `social_profiles` sont **deux tables quasi identiques** liées 1:1 → d'où 786 lignes de code de fusion (`entityMerge.js` + `actorSocialLink.js`) et 2 pages d'UI dédiées.
- `movies` stocke films **et** séries via `duration_kind='series'` + `duration_seasons` + `duration_episodes` : le type n'est pas explicite.
- FK polymorphes non contraintes : `medias` a 4 FK nullables (`movie_id`, `actor_id`, `social_profile_id`, `collection_id`), `links` en a 3. Rien n'empêche d'en remplir zéro ou quatre.
- **Aucune colonne `updated_at`** nulle part → pas d'ETag, pas de cache conditionnel, pas de « modifié récemment ».
- Index manquants : `movie_actor(actor_id)`, `movie_genre(genre_id)`, `actor_genre(genre_id)`. Le `UNIQUE(movie_id, actor_id)` n'indexe que le premier terme — toute requête « les films de cet acteur » fait un scan complet.
- `genres` sans contrainte d'unicité sur `(name, target_type, created_by)` → doublons garantis.
- `created_at TEXT DEFAULT (datetime('now'))` : format `YYYY-MM-DD HH:MM:SS` sans fuseau, non ISO-8601.

---

## 3. Sécurité — à corriger avant toute mise en ligne

| # | Constat | Fichier | Gravité |
|---|---|---|---|
| S1 | JWT stocké en `localStorage` → vol par XSS | `src/lib/api.ts:44` | 🔴 |
| S2 | `JWT_SECRET` a une valeur par défaut en dur (`'cineshelf-dev-secret-change-me'`) | `server/index.js:107` | 🔴 |
| S3 | `cors({ origin: true, credentials: true })` si `CORS_ORIGIN` absent → toute origine acceptée avec credentials | `server/index.js:137` | 🔴 |
| S4 | Aucun rate limiting sur `/api/auth/login` | — | 🔴 |
| S5 | Comptes seed `admin@cineshelf.local` / `admin123` créés automatiquement au premier boot, y compris en prod | `server/db.js` `seedIfEmpty()` | 🔴 |
| S6 | `xlsx@0.18.5` — CVE-2023-30533 (prototype pollution) + CVE-2024-22363 (ReDoS), paquet non maintenu sur npm | `package.json` (front **et** serveur) | 🟠 |
| S7 | Le handler d'erreur renvoie `err.message` brut au client (messages `SqliteError` avec du SQL). `api.ts` a même une fonction `extractServerErrorFromHtmlBody()` pour les parser. | `server/index.js:3279` | 🟠 |
| S8 | `express.json({ limit: '50mb' })` + multer 100 Mo sans quota utilisateur → DoS mémoire trivial | `server/index.js:99,149` | 🟠 |
| S9 | Aucune validation de schéma côté serveur (Zod est une dépendance… du front uniquement) | tout `server/` | 🟠 |
| S10 | Ni `helmet`, ni CSP, ni `X-Content-Type-Options` | — | 🟡 |
| S11 | `bcryptjs` (implémentation JS pure, ~10× plus lente que native) avec `rounds: 10` | `server/db.js` | 🟡 |

---

## 4. Performance — ce qui reste après les 4 lots déjà faits

Les lots 1→4 de `docs/performance/` ont réglé le gros (base64 sorti de la DB, pagination, lazy routes, virtualisation). Ce qui reste :

| # | Constat | Impact |
|---|---|---|
| P1 | `/api/medias/:id/file` sert **l'original** dans tous les contextes. Une vignette 128 px et un hero 1920 px téléchargent le même JPEG. Pas de dérivés, pas d'AVIF/WebP, pas de `Cache-Control: immutable`. | 🔴 Le plus gros gain restant |
| P2 | `xlsx` (~600 Ko non compressé) est importé **statiquement** par `src/lib/exportBundleClientSide.ts` ← `src/lib/dataTransferApi.ts` → il finit dans le bundle principal de tous les visiteurs, même ceux qui n'exportent jamais. | 🔴 |
| P3 | Pagination `LIMIT/OFFSET` : `OFFSET 5000` fait scanner 5 000 lignes à chaque page. Pas de pagination par curseur. | 🟠 |
| P4 | `/api/gallery` : 4 sous-requêtes corrélées par ligne (`actor_entity_photo_url`, etc.) + 5 `LEFT JOIN` + un `COUNT(*)` sur la même clause. | 🟠 |
| P5 | Aucun ETag / `If-None-Match` sur le JSON. Chaque navigation retélécharge tout. | 🟠 |
| P6 | 36 composants morts + `framer-motion` (~50 Ko gzip) pour 3 fichiers seulement. | 🟡 |
| P7 | Trois familles de polices chargées via `@import url(fonts.googleapis.com)` en tête de `index.css` — bloque le rendu, pas de `preconnect`, pas de `font-display: swap` explicite, pas de subsetting. | 🟠 |
| P8 | `staleTime: 60_000` global mais aucune `queryKey factory` : les invalidations restent larges (problème déjà signalé dans leur propre audit : « `invalidateQueries()` globales → tempêtes réseau »). | 🟠 |

---

## 5. Qualité & outillage — inventaire du vide

| Outil | Présent ? |
|---|---|
| ESLint | ❌ |
| Prettier | ❌ |
| Tests unitaires (Vitest/Jest) | ❌ |
| Tests E2E (Playwright) | ❌ |
| CI (GitHub Actions) | ❌ |
| Husky / lint-staged | ❌ |
| Dependabot / audit | ❌ |
| Smoke tests maison | ✅ (`smoke-api.mjs`, `smoke-full.mjs`, `compare-api-parity.mjs`) |

Le seul filet de sécurité actuel, ce sont les scripts de smoke — qui sont bien faits, mais lancés à la main.

Autres points : 3 `any` seulement (bien), 119 `useEffect` et 106 `useMemo` sur 190 fichiers (beaucoup d'état dérivé qui pourrait remonter dans les query keys), ~157 chaînes françaises en dur dans les pages (pas d'i18n — acceptable si l'app reste mono-langue, mais à décider explicitement).

Accessibilité : 59 `aria-label`, 30 `aria-hidden`, mais seulement **1** `aria-live`, **1** `aria-pressed`, **2** `aria-current`. Les toggles d'affichage, la pagination et les toasts ne sont pas annoncés aux lecteurs d'écran.

---

## 6. Synthèse : où va l'effort

```
                        Effort    Impact
Backend unifié            ●●●●○    ●●●●●   -10 500 lignes, 1 seule source de vérité
Design tokens             ●●○○○    ●●●●●   -655 hex, thèmes possibles, cohérence
Découpe SettingsPage      ●●●○○    ●●●●○   -6 487 l. monolithiques, CPU divisé
Dérivés d'images          ●●○○○    ●●●●●   le plus gros gain perf restant
Refonte schéma DB         ●●●○○    ●●●●○   -21 colonnes, -786 l. de fusion
Sécurité (S1→S5)          ●○○○○    ●●●●●   bloquant pour une mise en ligne
Outillage (lint/CI/tests) ●●○○○    ●●●○○   condition de survie du reste
```

**Ordre recommandé** → voir `05-ROADMAP.md`.
