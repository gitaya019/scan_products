import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/cobro_controller.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../utils/precios.dart';
import 'producto_text_field.dart';

/// Valores que el [PrecioPanel] mantiene sincronizados.
class PrecioValores {
  final double costo;
  final double precio;
  final double iva;

  const PrecioValores({
    required this.costo,
    required this.precio,
    required this.iva,
  });

  double get margen => Precios.margenDesdePrecios(costo, precio);
}

/// Bloque de precios de un producto: costo, margen, precio de venta e IVA,
/// con una vista previa que se actualiza con cada tecla.
///
/// Los tres numeros estan conectados en las dos direcciones: escribes el costo
/// y el % de ganancia y el precio de venta se calcula solo, pero si escribes el
/// precio de venta el margen se recalcula hacia atras. Asi el usuario elige
/// segun lo que tenga a la mano (el costo del proveedor o el precio de venta
/// que quiere poner) sin tener que hacer cuentas de memoria.
///
/// ## Convencion de IVA
///
/// El precio de venta **ya incluye** el IVA. La vista previa lo desglosa para
/// que se vea cuanto de ese precio es impuesto y cuanto es base gravable, pero
/// el total que paga el cliente es el precio de venta, sin cambios.
class PrecioPanel extends StatefulWidget {
  final double costoInicial;
  final double precioInicial;
  final double ivaInicial;

  /// Se invoca en cada cambio con los valores ya sincronizados, para que la
  /// pantalla pueda armar el `Producto` al guardar.
  final ValueChanged<PrecioValores> onCambio;

  /// Abre la pantalla de opciones de cobro desde la fila "Al cobrar".
  ///
  /// Lo pasan las pantallas y no el propio panel: un widget de `lib/widgets/`
  /// no debe saber de pantallas. Si es `null` la fila es solo informacion.
  final VoidCallback? onEditarCobro;

  const PrecioPanel({
    super.key,
    required this.costoInicial,
    required this.precioInicial,
    required this.ivaInicial,
    required this.onCambio,
    this.onEditarCobro,
  });

  @override
  State<PrecioPanel> createState() => _PrecioPanelState();
}

class _PrecioPanelState extends State<PrecioPanel> {
  /// Costo de compra. Se guarda aparte del texto para poder distinguir "0" de
  /// "vacio", aunque los dos produzcan el mismo precio.
  double _costo = 0;
  double _iva = 0;

  late final TextEditingController _costoController;
  late final TextEditingController _margenController;
  late final TextEditingController _precioController;

  /// Guarda True mientras el panel escribe en un controlador por su cuenta, de
  /// modo que los listeners no se disparen en cascada y el cursor del campo que
  /// el usuario esta editando no salte.
  bool _sincronizando = false;

  @override
  void initState() {
    super.initState();

    // Los controladores se crean aqui y no como inicializadores de campo:
    // un inicializador de campo no puede leer `widget`.
    final costoInicial = widget.costoInicial;
    final precioInicial = widget.precioInicial;

    _costo = costoInicial;
    _iva = widget.ivaInicial;

    _costoController = TextEditingController(
      text: costoInicial > 0 ? costoInicial.toStringAsFixed(0) : '',
    );
    _margenController = TextEditingController(
      text: Precios.margenDesdePrecios(costoInicial, precioInicial)
          .toStringAsFixed(0),
    );
    _precioController = TextEditingController(
      text: precioInicial > 0 ? formatCurrency(precioInicial) : '',
    );

    _costoController.addListener(_alEditarCosto);
    _margenController.addListener(_alEditarMargen);
    _precioController.addListener(_alEditarPrecio);
    _notificar();
  }

  @override
  void dispose() {
    _costoController
      ..removeListener(_alEditarCosto)
      ..dispose();
    _margenController
      ..removeListener(_alEditarMargen)
      ..dispose();
    _precioController
      ..removeListener(_alEditarPrecio)
      ..dispose();
    super.dispose();
  }

  double get _precio => parseCurrency(_precioController.text);

  void _escribirPrecio(double valor) {
    _precioController.text =
        valor > 0 ? formatCurrency(Precios.redondearMoneda(valor)) : '';
  }

  void _escribirMargen(double valor) {
    _margenController.text = valor.toStringAsFixed(0);
  }

  /// Costo o margen cambiados -> el precio sale del costo + margen.
  void _alEditarCosto() {
    if (_sincronizando) return;
    _sincronizando = true;
    _costo = parseCurrency(_costoController.text);
    _escribirPrecio(Precios.precioDesdeCosto(_costo, _margenActual()));
    _sincronizando = false;
    _actualizar();
  }

  void _alEditarMargen() {
    if (_sincronizando) return;
    _sincronizando = true;
    _escribirPrecio(Precios.precioDesdeCosto(_costo, _margenActual()));
    _sincronizando = false;
    _actualizar();
  }

  /// Precio cambiado -> el margen se recalcula hacia atras.
  void _alEditarPrecio() {
    if (_sincronizando) return;
    _sincronizando = true;
    final precio = _precio;
    // Con el precio vacio se deja el margen como estaba: si no, al borrar el
    // precio a medio escribir el margen saltaria a 0 y despues el usuario
    // tendria que recalcularlo a mano.
    if (precio > 0) {
      _escribirMargen(Precios.margenDesdePrecios(_costo, precio));
    }
    _sincronizando = false;
    _actualizar();
  }

  double _margenActual() => Precios.parsePorcentaje(_margenController.text);

  void _actualizar() {
    setState(() {});
    _notificar();
  }

  void _notificar() {
    widget.onCambio(
      PrecioValores(costo: _costo, precio: _precio, iva: _iva),
    );
  }

  @override
  Widget build(BuildContext context) {
    final precio = _precio;
    final margen = _margenActual();

    // El redondeo no se guarda en el producto —el panel liga precio y margen y
    // redondear aqui dejaria un producto cuyo margen real no es el de la
    // pantalla—, asi que lo que se muestra es una **simulacion** de como se
    // cobra con la opcion elegida. El panel se entera solo cuando el modo
    // cambia: `CobroScope` no notifica de eso, asi que hay que escuchar el
    // controller.
    final cobro = CobroScope.of(context);

    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ProductoTextField(
                controller: _costoController,
                label: 'Costo de compra',
                icon: Icons.production_quantity_limits_rounded,
                keyboardType: TextInputType.number,
                helperText: 'Lo que te costo',
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: ProductoTextField(
                controller: _margenController,
                label: 'Ganancia',
                icon: Icons.trending_up_rounded,
                keyboardType: TextInputType.number,
                suffixText: '%',
                helperText: 'Sobre el costo',
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        ProductoTextField(
          controller: _precioController,
          label: 'Precio de venta',
          icon: Icons.sell_rounded,
          keyboardType: TextInputType.number,
          helperText: 'Es lo que paga el cliente. Se calcula solo.',
          validator: (v) =>
              (v == null || parseCurrency(v) <= 0) ? 'Ingresa un precio' : null,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
          ],
          suffixText: 'COP',
        ),
        const SizedBox(height: AppSpacing.md),
        SelectorIVA(
          valor: _iva,
          onChanged: (tasa) {
            setState(() => _iva = tasa);
            _notificar();
          },
        ),
        const SizedBox(height: AppSpacing.md),
        ValueListenableBuilder<RedondeoCobro>(
          valueListenable: cobro,
          builder: (context, modo, _) => _VistaPrevia(
            costo: _costo,
            precio: precio,
            margen: margen,
            iva: _iva,
            redondeo: modo,
            onEditarCobro: widget.onEditarCobro,
          ),
        ),
      ],
    );
  }
}

/// Desglose en vivo de como queda el precio.
class _VistaPrevia extends StatelessWidget {
  final double costo;
  final double precio;
  final double margen;
  final double iva;
  final RedondeoCobro redondeo;
  final VoidCallback? onEditarCobro;

  const _VistaPrevia({
    required this.costo,
    required this.precio,
    required this.margen,
    required this.iva,
    required this.redondeo,
    this.onEditarCobro,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sinIVA = Precios.precioSinIVA(precio, iva);
    final impuesto = Precios.ivaIncluido(precio, iva);
    final ganancia = Precios.ganancia(costo, precio);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AppShape.sm),
        border: Border.all(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.10),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.calculate_rounded,
                size: 15,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              const SizedBox(width: 6),
              Text(
                'COMO QUEDA EL PRECIO',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          _Fila(
            etiqueta: 'Costo de compra',
            valor: formatCurrency(costo),
          ),
          _Fila(
            etiqueta: 'Ganancia',
            valor:
                '${formatCurrency(ganancia)}  (${margen.toStringAsFixed(margen % 1 == 0 ? 0 : 1)}%)',
            color: ganancia < 0 ? AppColors.danger : AppColors.success,
          ),
          const Divider(height: AppSpacing.lg),
          _Fila(
            etiqueta: 'Base gravable (sin IVA)',
            valor: formatCurrency(sinIVA),
          ),
          _Fila(
            etiqueta: 'IVA incluido ($iva%)',
            valor: formatCurrency(impuesto),
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  'Precio de venta',
                  style: theme.textTheme.titleSmall,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              NeonText(
                text: formatCurrency(precio),
                style: theme.textTheme.titleLarge,
              ),
            ],
          ),
          if (iva > 0) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Este precio ya incluye el IVA, asi que el cliente paga '
              'exactamente ${formatCurrency(precio)} COP.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                fontSize: 11.5,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          _FilaCobro(
            precio: precio,
            redondeo: redondeo,
            onEditar: onEditarCobro,
          ),
        ],
      ),
    );
  }
}

/// Quanto se cobra realmente con la opcion de redondeo elegida.
///
/// No es un campo mas del formulario: el precio que se guarda sigue siendo el
/// de arriba. Es la respuesta a "¿cuanto me van a dar por este producto?", que
/// con redondeo al alza no es el numero que esta escrito en la etiqueta.
///
/// Va **debajo** del precio y no en la misma fila porque los dos numeros no
/// significan lo mismo: uno es el precio del catalogo y este el importe cobrado.
/// Juntarlos invita a compararlos.
class _FilaCobro extends StatelessWidget {
  final double precio;
  final RedondeoCobro redondeo;
  final VoidCallback? onEditar;

  const _FilaCobro({
    required this.precio,
    required this.redondeo,
    this.onEditar,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cobrado = Precios.redondearCobro(precio, redondeo);
    final diferencia = cobrado - precio;

    final nota = switch (redondeo) {
      RedondeoCobro.sinRedondeo => 'Se cobra el precio tal cual.',
      _ when diferencia == 0 => 'Esta opcion no cambia este precio.',
      _ when diferencia > 0 =>
        'Esta opcion suma ${formatCurrency(diferencia)} al cobro.',
      _ => 'Esta opcion descuenta ${formatCurrency(-diferencia)} del cobro.',
    };

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onEditar,
        borderRadius: BorderRadius.circular(AppShape.xs),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                Icons.tune_rounded,
                size: 15,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'AL COBRAR',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      nota,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.55),
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  NeonText(
                    text: formatCurrency(cobrado),
                    style: theme.textTheme.titleMedium,
                  ),
                  Text(
                    redondeo.etiqueta,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color:
                          theme.colorScheme.onSurface.withValues(alpha: 0.55),
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
              if (onEditar != null) ...[
                const SizedBox(width: 2),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Fila extends StatelessWidget {
  final String etiqueta;
  final String valor;
  final Color? color;

  const _Fila({required this.etiqueta, required this.valor, this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              etiqueta,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            valor,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: color ?? theme.colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Selector de tasa de IVA del producto.
///
/// El precio siempre incluye el IVA, asi que la tasa no cambia lo que paga el
/// cliente: define cuanto de ese precio es impuesto y se usa para el desglose
/// y los reportes.
class SelectorIVA extends StatelessWidget {
  final double valor;
  final ValueChanged<double> onChanged;

  const SelectorIVA({
    super.key,
    required this.valor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final color = isDark ? AppColors.neonAmber : AppColors.amberDeep;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.receipt_long_rounded, size: 16, color: color),
            const SizedBox(width: 6),
            Text('IVA', style: theme.textTheme.labelLarge),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                'ya incluido en el precio',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                  fontSize: 11.5,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: Precios.tasasIVA.map((tasa) {
            final seleccionado = valor == tasa;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                    right: tasa == Precios.tasasIVA.last ? 0 : 6),
                child: Semantics(
                  button: true,
                  selected: seleccionado,
                  label: 'IVA $tasa por ciento',
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(AppShape.sm),
                      onTap: () => onChanged(tasa),
                      child: AnimatedContainer(
                        duration: AppDuration.fast,
                        height: 42,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: seleccionado
                              ? color.withValues(alpha: 0.22)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(AppShape.sm),
                          border: Border.all(
                            color: seleccionado
                                ? color.withValues(alpha: 0.7)
                                : color.withValues(alpha: 0.2),
                            width: seleccionado ? 1.6 : 1,
                          ),
                        ),
                        child: Text(
                          tasa == 0 ? '0%' : '$tasa%',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: seleccionado
                                ? (isDark ? Colors.white : color)
                                : color.withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
