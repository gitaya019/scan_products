# Scan Products — AGENTS.md

## Project

Flutter inventory + point-of-sale app (Spanish, Colombian market, COP).

- **Entrypoint:** `lib/main.dart` → `ScanProductsApp` → `HomeScreen`
- **Database:** SQLite via `sqflite`, **version 7**, 3 tables:
  - `productos` (id, nombre, codigo UNIQUE, categoria, precio, peso, stock, marca, unidad_medida, iva, venta_por_peso)
  - `ventas` (id, total, fecha ISO, estado `completada`|`anulada`)
  - `venta_detalles` (venta_id FK CASCADE, producto_id, nombre, codigo, precio_unitario, cantidad, subtotal, unidad_medida, venta_por_peso)
- **Orientation:** portrait only
- **Theme:** light + dark, persisted with `shared_preferences`, toggle in the sidebar. Defaults to **dark**.
- **Default theme mode:** dark

## Design System

All visual tokens live in `lib/theme/app_theme.dart`. Read this file before
adding UI.

| Symbol | Purpose |
|---|---|
| `AppColors` | Neon palette: `neonCyan`, `neonViolet`, `neonMagenta`, `neonAmber`, `neonLime`, plus dark bases `inkDeep`/`inkMid`/`inkSoft` and `paper` |
| `AppColors.violetDeep` / `cyanDeep` / `amberDeep` | Legible-on-light counterparts of the neons. Prefer reading `ColorScheme.primary`/`secondary` over hardcoding these |
| `accentGradient(scheme)` | `[primary, secondary]` of the active theme, for `LinearGradient` and `NeonText` |
| `AppColors.inkText` | Body text on light surfaces (same value as `ColorScheme.onSurface` in light mode) |
| `AppShape` | Radii: `xs` 8, `sm` 12, `md` 18, `lg` 24, `xl` 32, `pill` 999 + ready-made `BorderRadius` |
| `AppSpacing` | 4 / 8 / 12 / 16 / 24 / 32 / 48 |
| `AppDuration` | `fast` 180ms, `medium` 320ms, `slow` 620ms |
| `AuroraBackground` | Animated gradient background, every screen wraps its `Scaffold` in it. Auto-stops when `MediaQuery.disableAnimations` is set; pass `animate: false` for a static backdrop |
| `GlassSurface` | Frosted surface: backdrop blur, luminous border, soft shadow. Optional `onTap`, `glow`, `tint`, `blur` |
| `NeonText` | Gradient-filled text for prices and totals. `colors` is optional — omitted it resolves to `accentGradient(theme.colorScheme)` |
| `GlassChip` | Compact metadata pill (marca, unidad, IVA, stock) |
| `NeonButton` | Primary gradient button with glow; `compact` and `expand` props |
| `GlassIconButton` | Secondary frosted icon button |
| `AppTheme.dark` / `.light` | Full `ThemeData` per variant, incl. component themes |

**Performance rule:** every `GlassSurface` inside a scrollable list must pass
`blur: false`. A `BackdropFilter` is a separate render layer; a list of them
drops frames on mid-range Android. Single surfaces (app bars, search bars, the
checkout total bar) keep the blur.

**Rule:** never hardcode colors, radii, or spacing in a screen. Use the tokens
above so light/dark stay coherent.

## Architecture

- **`lib/main.dart`** — app root, portrait lock, `ValueListenableBuilder` on `ThemeController`
- **`lib/theme/app_theme.dart`** — tokens + shared widgets (largest file, ~800 lines)
- **`lib/theme/theme_controller.dart`** — `ValueNotifier<ThemeMode>`, loads/saves the preference
- **`lib/screens/home_screen.dart`** — product list, search, stock-low filter + badge, swipe-to-delete, quick-add stock
- **`lib/screens/add_producto_screen.dart`** — create form in 3 sections; scanning detects duplicates and offers to add stock instead
- **`lib/screens/edit_producto_screen.dart`** — edit form + "Valor en inventario" panel + delete
- **`lib/screens/venta_screen.dart`** — POS: scan/search, cart, quantity dialog, checkout
- **`lib/screens/historial_ventas_screen.dart`** — sale history, detail dialog, void (restores stock)
- **`lib/screens/reporte_ventas_screen.dart`** — day/week/month totals + best-selling product
- **`lib/models/`** — `Producto`, `Venta`, `VentaDetalle`, `CarritoItem` (all with `toMap()`/`fromMap()`)
- **`lib/services/database_helper.dart`** — singleton, lazy init, cached `Database`
- **`lib/utils/formatters.dart`** — `formatCurrency()`, `parseCurrency()`, `formatCantidad()`, `labelCantidad()`, `labelStock()`, `formatFecha()`
- **`lib/widgets/sidebar.dart`** — drawer + theme switch
- **`lib/widgets/producto_text_field.dart`** — base text field
- **`lib/widgets/precio_field.dart`** — COP price field, reformats on focus loss

## Business Rules

- **Umbral stock bajo = 5** (`_HomeScreenState._umbralStockBajo`)
- **Venta por peso/volumen:** `ventaPorPeso` + `unidadMedida` drive keyboard, field label, icon, and cart increment step (0.1 for kg/g/L/mL, 1 for unidad/paquete/caja)
- **Unidades:** `['unidad', 'kg', 'g', 'lb', 'L', 'mL', 'paquete', 'caja']`
- **IVA:** stored and displayed but **not applied** to sale totals
- **Currency:** COP, `NumberFormat.decimalPattern('es_CO')`, rounded, no symbol — `currency()` with `symbol: ''` leaves a trailing space

## Conventions

- All UI text, comments, and identifiers in **Spanish** (no accents in identifiers)
- Model `fromMap` normalizes `int` → `double` via a private `_aDoble` helper (SQLite returns `int` for whole numbers)
- Screens are `StatefulWidget` with a private `_XState`
- Private widget classes are prefixed with `_`

## Android Toolchain

Gradle, AGP and Kotlin are pinned to a combination supported by Flutter 3.47:

| Piece | Version | Why |
|---|---|---|
| Gradle wrapper | 8.14 | Flutter 3.47 rejects anything below 8.14 |
| AGP | 8.13.0 | Latest 8.x; AGP 9 requires the new DSL and breaks this Groovy setup |
| Kotlin plugin | 2.2.20 | Required by AGP 8.13 |
| Java source/target | 17 | Local JDK is 17 |
| `compileSdk` | 36 (hardcoded, plus a `subprojects` hook in `android/build.gradle`) | `barcode_scan2` declares `compileSdkVersion 31` but its androidx deps need ≥ 34. Setting it only in `app/build.gradle` is not enough — the library module itself has to be overridden, otherwise the release build fails with "compile against version 34 or later" attributed to `:barcode_scan2` |

- `namespace` and `applicationId` are both `com.jacsoft.scan_products`; `MainActivity.kt` lives under `android/app/src/main/kotlin/com/jacsoft/scan_products/` and must match the namespace.
- Release builds enable R8 (`minifyEnabled`, `shrinkResources` — Groovy DSL names, **not** `isMinifyEnabled`) with rules in `android/app/proguard-rules.pro` (Flutter engine, ZXing for `barcode_scan2`, sqflite fields).
- `proguard-rules.pro` needs `-dontwarn com.google.android.play.core.**`. Flutter's engine references Play Core for deferred components (App Bundles with on-demand modules); this app ships a full APK and never uses them, so the dependency is absent and R8 otherwise aborts with *"Missing classes detected"*.
- **Still signing with debug keys.** Configure a real signing config before publishing.
- If Gradle versions need bumping, check the matrix below.

### Version validation and the three `flutter run` warnings

Flutter 3.47 validates the build-time dependencies via its Gradle plugin
(`packages/flutter_tools/gradle/src/main/kotlin/DependencyVersionChecker.kt`). Each one has
a *warn* threshold that prints "will soon be dropped" and an *error* threshold that
fails the build:

| Dependency | Warn (noise) | Error (build fails) | This project |
|---|---|---|---|
| Gradle | 9.1.0 | **8.14.0** | 8.14.0 — at the floor |
| AGP | 9.0.1 | **8.11.1** | 8.13.0 |
| Kotlin (KGP) | 2.3.20 | **2.2.20** | 2.2.20 — at the floor |
| Java | 17 | **17** | 17 |
| minSdk | 24 | **23** | 24 (`flutter.minSdkVersion`) |

So the three warnings on every `flutter run` are **advisory**: both Gradle and
Kotlin sit exactly on the error floor, so there is zero headroom below but plenty
above. Clearing the noise means moving all three to Gradle 9.1 / AGP 9.0.1 /
Kotlin 2.3.20 together, and AGP 9 is **not** a drop-in — it only reads the new
Kotlin DSL, so all three gradle files would have to be rewritten as `.kts`.
Not worth it until Flutter raises the error thresholds.

The remaining warnings are expected and not ours to fix:

- `sqflite_android 2.4.0` compiles with three `[deprecation]` javac warnings
  (`Locale(String,String,String)`, `Thread.getId()`) from its own Java sources in
  the pub cache. We have no Java of our own, so these can only be fixed upstream.

## Commands

| Command | Purpose |
|---|---|
| `flutter pub get` | Install dependencies |
| `flutter analyze` | Must stay at **0 issues**. `analysis_options.yaml` adds 10 extra lints beyond `flutter_lints` |
| `flutter test` | 51 tests |
| `flutter run` | Run on device |
| `flutter build apk --release` | Android release build |
| `flutter build ios` | iOS release build |
| `flutter pub run flutter_launcher_icons` | Regenerate launcher icons |

## Tests

| File | Covers |
|---|---|
| `test/formatters_test.dart` | Currency, quantities, labels, dates |
| `test/modelos_test.dart` | `toMap`/`fromMap` round-trips, defaults, null handling |
| `test/database_test.dart` | CRUD, search, stock deltas, sales, void, summary — against in-memory FFI |
| `test/widget_test.dart` | App boots, both themes build |
| `test/screens_test.dart` | Every screen renders against a seeded DB in both themes — catches layout overflows and bad `ColorScheme` reads |

**Critical:** `sqflite` does not work headless. Use `sqflite_common_ffi` via
`inicializarBaseDeDatosDePrueba()` from `test/helpers/test_database.dart`, and
set `DatabaseHelper.databasePath = ':memory:'`.

**Critical:** never use `pumpAndSettle` in a widget test. `AuroraBackground`
runs a repeating `AnimationController`, so there is no settled frame and
`pumpAndSettle` blocks until it times out. Pump a fixed number of frames
instead — see `montar()` in `test/screens_test.dart`.

**Critical:** `_createDB` and `_onUpgrade` must stay in sync. A fresh install
fails if `CREATE TABLE` is missing a column that `_onUpgrade` adds via
`ALTER TABLE` (this already happened once with `venta_detalles.unidad_medida`).

## Dependencies

Runtime: `sqflite`, `path`, `barcode_scan2`, `flutter_animate`, `intl`, `shared_preferences`.

Dev: `flutter_test`, `flutter_lints 5`, `sqflite_common_ffi`, `flutter_launcher_icons`.

Removed as unused: `excel`, `open_file`, `share_plus`, `permission_handler`, `file_picker`, `path_provider`, `cupertino_icons`.

## Quirks

- Android `minSdk = flutter.minSdkVersion` (API 24 in Flutter 3.47 — **not** 21; `barcode_scan2` only needs 21, so Flutter's floor is the binding one), `applicationId = com.jacsoft.scan_products`
- Android `local.properties` is gitignored but present locally
- Launch splash uses `@color/launch_background` (`#07060F` = `AppColors.inkDeep`) in **both** `values/` and `values-night/` so the dark default does not flash white
- `barcode_scan2` needs no extra iOS config beyond `NSCameraUsageDescription` (already in `Info.plist`)
- Only Android has native code (`MainActivity.kt`); other platforms are stock Flutter scaffolding
- No CI/CD in the repo

## Editing gotcha

Do **not** bulk-edit Dart files with PowerShell `Get-Content -Raw` + `Set-Content`.
Windows PowerShell 5.1 rewrites the file in the system ANSI codepage, which turns
multi-byte UTF-8 characters (`·`, accented text) into invalid byte sequences. The
analyzer then reports the whole file as missing ("Target of URI doesn't exist")
with no hint about encoding. Use the editor tools, or `[System.IO.File]::WriteAllText`
with an explicit UTF-8 encoding.
