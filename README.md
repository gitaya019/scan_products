# 🚀 Scan Products 📦📲

**Versión 2.0.0** · App de inventario y punto de venta para pequeños comercios en Colombia.

Escanea códigos de barras, administra stock y cobra en segundos. Todo funciona
sin conexión: los datos viven en el dispositivo.

---

## ✨ Funcionalidades

**Inventario**
- 📷 Escaneo de códigos de barras para buscar productos y para crear registros nuevos
- 🔍 Búsqueda en vivo por nombre o código
- ⚠️ Filtro de stock bajo con contador en la barra superior
- ➕ Alta rápida de stock desde la tarjeta del producto
- ✏️ Crear, editar y eliminar productos

**Punto de venta**
- 🛒 Carrito con cantidades por peso/volumen o por unidad
- 💵 Cobro con total en COP y descuento automático de stock
- 🧾 Detalle de cada línea con unidad de medida
- ♻️ Anulación de ventas que repone el stock

**Reportes**
- 📈 Ingresos del día, la semana y el mes
- 🏆 Producto más vendido
- 🗂️ Historial completo de ventas con detalle

**Apariencia**
- 🌌 Interfaz glassmorphism con acentos neón
- 🌗 Tema claro y oscuro con preferencia persistida

---

## 🎨 Sistema de diseño

Todo el sistema visual vive en `lib/theme/app_theme.dart`:

| Elemento | Qué resuelve |
|---|---|
| `AppColors` | Paleta neón (cian, violeta, magenta) + bases oscura y clara |
| `AppShape` | Radios: `xs` 8 → `xl` 32 → `pill` |
| `AppSpacing` | Escala de espaciado 4/8/12/16/24/32/48 |
| `AppDuration` | Duraciones `fast` 180ms, `medium` 320ms, `slow` 620ms |
| `AuroraBackground` | Fondo animado con manchas de color en movimiento |
| `GlassSurface` | Superficie translúcida con blur, borde luminoso y sombra |
| `NeonText` | Texto con degradado neón para cifras destacadas |
| `GlassChip` | Chip de metadatos (marca, unidad, IVA, stock) |
| `NeonButton` / `GlassIconButton` | Botones primario y secundario |
| `AppTheme.dark` / `AppTheme.light` | `ThemeData` completo de cada variante |

Cuando agregues pantallas nuevas, reutiliza estos widgets en lugar de
`Container` con sombras y colores sueltos: así se mantiene la coherencia.

---

## 📦 Instalación

```bash
git clone https://github.com/JACSOFT/scan_products.git
cd scan_products
flutter pub get
flutter run
```

### Requisitos
- Flutter 3.47 o superior (Dart 3.6+)
- Android 5.0 (API 21) o superior, o iOS 12+
- Cámara para escanear (opcional: la app funciona sin ella usando búsqueda)

### Toolchain de Android

El proyecto fija versiones que Flutter 3.47 acepta. Si el build falla con
*"Your project's Gradle version is lower than Flutter's minimum supported
version"* o con un error de `compileSdk` blaming a `:barcode_scan2`:

| Pieza | Versión |
|---|---|
| Gradle wrapper | 8.14 |
| Android Gradle Plugin | 8.13.0 |
| Plugin de Kotlin | 2.2.20 |
| Java (source/target) | 17 |
| `compileSdk` | 36 |

`android/build.gradle` incluye un hook `subprojects` que fuerza `compileSdk 36`
en los módulos de librería. Sin él, `barcode_scan2` (que declara `android-31`)
rompe el build release.

---

## 🧪 Comandos

| Comando | Propósito |
|---|---|
| `flutter pub get` | Instalar dependencias |
| `flutter analyze` | Análisis estático y lints |
| `flutter test` | Correr las pruebas |
| `flutter run` | Ejecutar en un dispositivo |
| `flutter build apk --release` | Build de Android |
| `flutter build ios --release` | Build de iOS |

Las pruebas de base de datos usan `sqflite_common_ffi` porque `sqflite` no
opera en entornos headless. `DatabaseHelper.databasePath = ':memory:'` permite
usar una base en memoria sin tocar disco.

`test/screens_test.dart` monta cada pantalla contra la base sembrada, en tema
oscuro y claro, para cazar desbordamientos de layout y lecturas incorrectas del
`ColorScheme`. No usan `pumpAndSettle`: el fondo animado nunca llega a un estado
estable, así que el pump se hace con un número fijo de frames.

---

## 🗂️ Estructura

```
lib/
├── main.dart                      Raíz de la app, tema y orientación
├── theme/
│   ├── app_theme.dart             Tokens, widgets y ThemeData
│   └── theme_controller.dart      Persistencia del modo claro/oscuro
├── models/                        Producto, Venta, VentaDetalle, CarritoItem
├── services/
│   └── database_helper.dart       SQLite (3 tablas, versión 7)
├── screens/
│   ├── home_screen.dart           Inventario
│   ├── add_producto_screen.dart   Alta de producto
│   ├── edit_producto_screen.dart  Edición y eliminación
│   ├── venta_screen.dart          Punto de venta
│   ├── historial_ventas_screen.dart
│   └── reporte_ventas_screen.dart
├── utils/formatters.dart          Moneda COP, cantidades y fechas
└── widgets/
    ├── sidebar.dart               Menú lateral + toggle de tema
    ├── producto_text_field.dart   Campo base
    └── precio_field.dart          Campo de precio COP
```

---

## 🗄️ Base de datos

SQLite, 3 tablas, versión 7. Las migraciones en `_onUpgrade` van de v3 a v7 con
`ALTER TABLE`; `_createDB` debe mantenerse sincronizada con `_onUpgrade`.

| Tabla | Contenido |
|---|---|
| `productos` | id, nombre, codigo (único), categoria, precio, peso, stock, marca, unidad_medida, iva, venta_por_peso |
| `ventas` | id, total, fecha, estado (`completada` / `anulada`) |
| `venta_detalles` | líneas de cada venta, con nombre/código/precio como snapshot |

---

## 💡 Detalles de negocio

**Venta por peso o volumen.** El interruptor `ventaPorPeso` junto con
`unidadMedida` ajusta el teclado, la etiqueta del campo, el icono y el paso de
incremento del carrito: 0.1 para kg/g/L/mL, 1 para unidades, paquetes y cajas.

**Stock bajo.** El umbral es 5 unidades (`_umbralStockBajo` en
`home_screen.dart`). Los productos por debajo se marcan en la lista y se
pueden filtrar con el botón de alerta.

**IVA.** Se registra y se muestra en la ficha del producto, pero no se aplica
automáticamente al total de la venta.

---

Desarrollado por **JACSOFT** · Colombia 🇨🇴
