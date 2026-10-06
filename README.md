# 🚀 Scan Products 📦📲

**Versión 2.2.0** · App de inventario y punto de venta para pequeños comercios en Colombia.

Escanea códigos de barras, administra stock y cobra en segundos. Todo funciona
sin conexión: los datos viven en el dispositivo.

---

## ✨ Funcionalidades

**Inventario**
- 📷 Escaneo de códigos de barras para buscar productos y para crear registros nuevos
- 🔍 Búsqueda en vivo por nombre o código
- 🗂️ ~80 categorías predeterminadas de tienda de barrio, agrupadas en 10 secciones
- 🏷️ Marcas reutilizables con autocompletado y creación en línea
- 📚 Catálogos de categorías y marcas administrables desde el menú lateral: crear, renombrar (mueve los productos) y borrar
- ⚠️ Filtro de stock bajo con contador en la barra superior
- ➕ Alta rápida de stock desde la tarjeta del producto
- ✏️ Crear, editar y eliminar productos

**Precios**
- 💰 Costo de compra + % de ganancia → precio de venta, con vista previa en vivo
- 🧾 IVA incluido en el precio, desglosado como base gravable + impuesto
- ⚖️ **Precio por libra y venta en gramos**: el total se convierte solo

**Punto de venta**
- 🛒 Carrito con cantidades por peso/volumen o por unidad
- ⚖️ Vista previa del cobro mientras se escribe la cantidad
- 💵 Cobro con total en COP y descuento automático de stock
- 🧮 Redondeo configurable: pesos enteros, múltiplo de 50 o subir a la centena
- 💳 Método de pago (efectivo o Nequi) con billete recibido y vuelto en vivo
- 🧾 Detalle de cada línea con unidad de medida
- ♻️ Anulación de ventas que repone el stock

**Reportes**
- 📈 Ingresos del día, la semana y el mes
- 🧮 Desglose de base gravable e IVA acumulado por periodo
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

**Regla de performance:** todo `GlassSurface` dentro de una lista scrolleable
lleva `blur: false`. Cada `BackdropFilter` es una capa de render propia y con
scroll dozens de ellas bajan los frames en Android de gama media. Las
superficies sueltas (app bars, barra de búsqueda, total del cobro) sí lo llevan.

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
- Android 7.0 (API 24, el piso de `flutter.minSdkVersion`) o superior, o iOS 12+
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
estable, así que el pump se hace a mano y `esperarCarga()` espera a que el
indicador de carga desaparezca en vez de contar vueltas a ciegas.

`test/dialogo_cantidad_test.dart` cubre el diálogo de cantidad con el teclado
abierto: su `TextEditingController` pertenece al `State` del diálogo, no a quien
lo abre. `showDialog` devuelve en el `Navigator.pop`, pero la ruta sigue montada
durante su transición de salida, y si el llamador libera el controller ahí el
`TextField` lo lee ya muerto.

`test/teclado_test.dart` recorre los diálogos con el teclado levantado y verifica
que ninguno lance excepciones. Como `testWidgets` corre en `FakeAsync`, el I/O de
`sqflite` solo avanza alternando `runAsync` y `pump`; `esperarHasta()` reintenta
hasta que un `Finder` encuentra lo que busca en vez de contar vueltas a ciegas.

La matemática de negocio tiene su propia suite, sin widgets:

| Archivo | Cubre |
|---|---|
| `test/precios_test.dart` | IVA incluido, margen, redondeo del cobro |
| `test/unidades_test.dart` | Conversión entre kg, g, lb, L y mL |
| `test/carrito_test.dart` | Total de línea con unidades distintas y redondeo por línea |
| `test/categorias_test.dart` | Búsqueda y normalización de categorías |
| `test/categorias_crud_test.dart` | Catálogo: renombrar en cascada, borrar con productos |
| `test/marcas_crud_test.dart` | El mismo contrato para el catálogo de marcas |
| `test/teclado_test.dart` | Flujos con el teclado abierto, sin excepciones |
| `test/venta_test.dart` | Flujo de venta completo, de punta a punta |
| `test/widgets_test.dart` | Selectores de categoría, marca y unidad |

---

## 🗂️ Estructura

```
lib/
├── main.dart                      Raíz de la app, tema y orientación
├── theme/
│   ├── app_theme.dart             Tokens, widgets y ThemeData
│   └── theme_controller.dart      Persistencia del modo claro/oscuro
├── data/
│   └── categorias.dart            ~80 categorías predeterminadas, en secciones
├── models/                        Producto, Venta, VentaDetalle, CarritoItem, Marca, MetodoPago
├── services/
│   ├── database_helper.dart       SQLite (5 tablas, versión 10)
│   └── cobro_controller.dart      Modo de redondeo del cobro, persistido
├── screens/
│   ├── home_screen.dart           Inventario
│   ├── add_producto_screen.dart   Alta de producto
│   ├── edit_producto_screen.dart  Edición y eliminación
│   ├── venta_screen.dart          Punto de venta
│   ├── historial_ventas_screen.dart
│   ├── reporte_ventas_screen.dart
│   ├── categorias_screen.dart     CRUD del catálogo de categorías
│   ├── marcas_screen.dart         CRUD del catálogo de marcas
│   └── opciones_cobro_screen.dart Modo de redondeo del cobro
├── utils/
│   ├── formatters.dart            Moneda COP, cantidades y fechas
│   ├── precios.dart               IVA incluido y margen de ganancia
│   └── unidades.dart              Conversión entre kg, g, lb, L y mL
└── widgets/
    ├── sidebar.dart               Menú lateral + navegación + toggle de tema
    ├── producto_text_field.dart   Campo base
    ├── precio_field.dart          Campo de precio COP
    ├── precio_panel.dart          Costo + margen + precio + IVA, en vivo
    ├── presentacion_selector.dart Unidades vs peso, y unidad de la balanza
    ├── categoria_selector.dart    Campo de categoría con atajos
    ├── marca_selector.dart        Autocompletado y creación de marcas
    └── vista_previa_cobro.dart    Cuánto se cobra mientras se escribe
```

---

## 🗄️ Base de datos

SQLite, 5 tablas, versión 10. Las migraciones en `_onUpgrade` van de v3 a v10 con
`ALTER TABLE`; `_createDB` debe mantenerse sincronizada con `_onUpgrade`.

| Tabla | Contenido |
|---|---|
| `productos` | id, nombre, codigo (único), categoria, precio, costo, peso, stock, marca, unidad_medida, unidad_venta, iva, venta_por_peso |
| `marcas` | id, nombre (único), created_at — alimenta el autocompletado |
| `categorias` | id, nombre (único), created_at — catálogo administrable |
| `ventas` | id, total, fecha, estado (`completada` / `anulada`), metodo_pago, recibido |
| `venta_detalles` | líneas de cada venta, con nombre/código/precio como snapshot |

`productos.marca` y `productos.categoria` siguen siendo texto a propósito: un
producto escrito a mano no depende de que exista la fila en `marcas` ni en
`categorias`. Esas tablas solo sugieren y evitan escribir lo mismo dos veces.

La diferencia es que `categorias` y `marcas` sí se administran: desde el menú
lateral, en la sección **Catálogo**, se crea, se renombra y se borra. Renombrar
mueve en cascada los productos que la usan (sin distinguir mayúsculas, para que
un producto guardado como "quesos" también se mueva a "Quesos"); borrar está
bloqueado mientras haya productos apuntando a ella, porque su texto quedaría
sin ninguna parte donde aparecer.

---

## 💡 Detalles de negocio

**Dos unidades, no una.** Es la regla que más confunde y la fuente del error más
caro. Un producto tiene:

| Campo | Qué es | Ejemplo |
|---|---|---|
| `unidad_medida` | La unidad en la que está **cotizado** el precio | `lb` |
| `unidad_venta` | La unidad en la que se **pese** y se cuenta el stock | `g` |

Con la libra a 5.000 y una cebolla de 120 g, `120 g → 0,24 lb → $1.200`.
Sin conversión serían 600.000. La conversión vive en `lib/utils/unidades.dart`
y solo aplica cuando tiene sentido físico: masa↔masa y volumen↔volumen. Entre
`paquete` y `caja` (o de masa a volumen) **no** se inventa un factor.

**La libra son 500 gramos.** No la libra exacta (453,59237 g): en el mostrador
"media libra" son 250 g y "1 kg" son dos libras. Con el valor exacto, el tiquete
termina descontando de lo que el cliente cree que está pagando.

**Redondeo al cobrar, no al guardar.** Desde el menú lateral, sección **Cobro**,
se elige entre pesos enteros, múltiplo de 50 (927 → 950) o subir siempre a la
centena (924 → 1.000, 9.823 → 9.900). El ajuste se aplica **por línea** del
carrito, no solo al total, para que la suma de lo impreso sea exactamente lo
cobrado, y si el tendero cambia la opción con la venta abierta se reaplica a
las líneas ya agregadas: una venta con dos reglas distintas no se le puede
explicar a un cliente.

El precio del catálogo **no** se redondea al guardar. El formulario liga precio y
margen, así que redondear el precio almacenaría un producto cuyo margen real no
es el que está en pantalla (30% escrito, 33% guardado). El redondeo es una
decisión del momento de cobro.

**Método de pago y vuelto.** El cobro pregunta el método antes de tocar el stock.
En efectivo pide el billete recibido, avisa si no alcanza ("Faltan 4.400", nunca
un vuelto de cero) y muestra el cambio en vivo. Nequi guarda `recibido` nulo:
"llegó exacto" y "no aplica" son datos distintos, y en un cierre de caja se
necesitan los dos. El vuelto nunca se guarda, se deriva.

**IVA incluido.** El precio de venta ya trae el IVA dentro: el cliente paga
exactamente lo que ve en la etiqueta. El impuesto solo se extrae para
informar y reportar, en la venta, en el historial y en el reporte por periodo.
El total cobrado nunca cambia. La tasa es por línea, así que una venta puede
mezclar tasas 0/5/10/19 sin romper el desglose.

**Costo y margen.** El "precio base" que se ingresa es el **costo de compra**.
El margen se aplica sobre el costo (`costo × (1 + margen/100)`), que es como
piensa el comercio: "gané el 30%" es 30% sobre lo que costó. Si editas el precio
directamente, el margen se recalcula hacia atrás.

**Stock bajo.** El umbral es 5 unidades (`_umbralStockBajo` en
`home_screen.dart`). Los productos por debajo se marcan en la lista y se
pueden filtrar con el botón de alerta.

**Stock en unidad de venta.** El `stock` se cuenta en `unidad_venta`, que es lo
que marca la balanza. Al anular una venta se repone la misma cantidad, así que
el round-trip cuadra aunque el producto cambie de unidad después.

---

Desarrollado por **JACSOFT** · Colombia 🇨🇴
