# Scan Products — AGENTS.md

## Project

Flutter inventory app (Spanish). Scans barcodes, stores products in SQLite, exports to Excel.

- **Entrypoint:** `lib/main.dart` → `MyApp` → `HomeScreen`
- **Database:** SQLite via `sqflite`, single table `productos` (id, nombre, codigo, categoria, precio, peso, stock, marca, unidad_medida, iva). DB version 3; migration at `_onUpgrade` adds columns via ALTER TABLE.
- **Orientation:** locked to portrait only
- **App icon:** configured in `pubspec.yaml` under `flutter_icons:`; regenerate with `flutter pub run flutter_launcher_icons`
- **Assets:** `assets/stock.png`, `assets/app_icon_foreground.png`

## Commands

| Command | Purpose |
|---|---|
| `flutter pub get` | Install dependencies |
| `flutter analyze` | Lint + static analysis |
| `flutter test` | Run tests |
| `flutter run` | Run on connected device/emulator |
| `flutter build apk` | Android release build |
| `flutter build ios` | iOS release build |
| `flutter pub run flutter_launcher_icons` | Regenerate app launcher icons |

## Tests

The existing `test/widget_test.dart` is a **default Flutter counter stub** — not relevant to the app. Needs replacement.

`sqflite` does not work in headless/test environments. Use `sqflite_common_ffi` for any test that touches the database.

## Architecture

- **`lib/main.dart`** — App root, portrait lock, Material 3 theme (light blue seed, light mode)
- **`lib/screens/home_screen.dart`** — Main screen: product list with search + barcode scan FAB + swipe-to-delete + drawer
- **`lib/screens/add_producto_screen.dart`** — Form to add product; scans barcode and detects duplicates; dropdowns for unidad_medida and IVA
- **`lib/screens/edit_producto_screen.dart`** — Edit existing product + delete button
- **`lib/models/producto_model.dart`** — `Producto` data class with `toMap()` / `fromMap()` (marca, unidadMedida, iva)
- **`lib/services/database_helper.dart`** — Singleton `DatabaseHelper` (lazy-init, cached, DB v3)
- **`lib/widgets/sidebar.dart`** — Drawer menu + `exportToExcel()` standalone function
- **`lib/widgets/producto_text_field.dart`** — Reusable text field widget
- **`lib/widgets/precio_field.dart`** — Price field with COP formatting on focus loss
- **`lib/utils/formatters.dart`** — `formatCurrency()` / `parseCurrency()` for COP

## Conventions

- All UI text, comments, and variable names are in **Spanish**
- Currency is COP (Colombian Peso), formatted with `intl` `NumberFormat.currency(locale: 'es_CO')`, no decimals
- The price field uses a custom formatter/unformatter on focus loss
- `flutter_lints` package with default `flutter.yaml` rules (no custom overrides in `analysis_options.yaml`)

## Quirks

- `pubspec.yaml` contains `flutter_icons:` config inline (not in a separate file) — do not duplicate
- Barcode scanning depends on device camera; `barcode_scan2` needs platform-specific setup
- Excel export requires storage permission on Android (`permission_handler`)
- No CI/CD config present in repo
