import 'package:flutter/material.dart';
import '../services/database_helper.dart';
import '../models/venta_model.dart';
import '../models/venta_detalle.dart';
import '../utils/formatters.dart';

class HistorialVentasScreen extends StatefulWidget {
  @override
  _HistorialVentasScreenState createState() => _HistorialVentasScreenState();
}

class _HistorialVentasScreenState extends State<HistorialVentasScreen> {
  List<Venta> _ventas = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarVentas();
  }

  Future<void> _cargarVentas() async {
    setState(() => _cargando = true);
    final ventas = await DatabaseHelper.instance.getVentas();
    setState(() {
      _ventas = ventas;
      _cargando = false;
    });
  }

  Future<void> _verDetalle(Venta venta) async {
    final detalles =
        await DatabaseHelper.instance.getVentaDetalles(venta.id!);

    if (mounted) {
      showDialog(
        context: context,
        builder: (context) {
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Detalle de Venta",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    _formatearFecha(venta.fecha),
                    style: TextStyle(color: Colors.black54, fontSize: 13),
                  ),
                  SizedBox(height: 16),
                  ...detalles.map((d) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(d.nombre,
                                          style: TextStyle(
                                              fontWeight: FontWeight.w500)),
                                      Text(
                                        _formatearDetalle(d),
                                        style: TextStyle(
                                            color: Colors.black54, fontSize: 13),
                                      ),
                                    ],
                                  ),
                            ),
                            Text(
                              "\$${formatCurrency(d.subtotal)}",
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      )),
                  Divider(thickness: 1),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Total",
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      Text("\$${formatCurrency(venta.total)}",
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                  SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      child: Text("Cerrar"),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    }
  }

  Future<void> _anularVenta(Venta venta) async {
    if (venta.estado == 'anulada') return;

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Anular Venta"),
        content: const Text(
            "¿Estás seguro? Se restaurará el stock de todos los productos."),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text("Cancelar",
                style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text("Anular", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      await DatabaseHelper.instance.anularVenta(venta.id!);
      _cargarVentas();
    }
  }

  String _formatearDetalle(VentaDetalle d) {
    final esPeso = ['kg', 'g', 'lb', 'L', 'mL'].contains(d.unidadMedida);
    final cantidad = esPeso
        ? (d.cantidad == d.cantidad.roundToDouble()
            ? d.cantidad.toInt().toString()
            : d.cantidad.toStringAsFixed(1))
        : d.cantidad.toInt().toString();
    final unidad = d.unidadMedida != null ? ' ${d.unidadMedida}' : '';
    return '$cantidad$unidad x \$${formatCurrency(d.precioUnitario)}';
  }

  String _formatearFecha(String iso) {
    final dt = DateTime.parse(iso);
    final meses = [
      'ene', 'feb', 'mar', 'abr', 'may', 'jun',
      'jul', 'ago', 'sep', 'oct', 'nov', 'dic'
    ];
    final hora = dt.hour.toString().padLeft(2, '0');
    final minuto = dt.minute.toString().padLeft(2, '0');
    return '${dt.day} ${meses[dt.month - 1]} ${dt.year}, $hora:$minuto';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        iconTheme: IconThemeData(color: Colors.black54),
        title: Text(
          "Historial de Ventas",
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w300,
            fontSize: 22,
          ),
        ),
      ),
      body: _cargando
          ? Center(child: CircularProgressIndicator())
          : _ventas.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.receipt_long_outlined,
                          size: 80, color: Colors.black26),
                      SizedBox(height: 16),
                      Text(
                        "No hay ventas registradas",
                        style: TextStyle(
                          color: Colors.black45,
                          fontWeight: FontWeight.w300,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _cargarVentas,
                  child: ListView.builder(
                    padding:
                        EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: _ventas.length,
                    itemBuilder: (context, index) {
                      final venta = _ventas[index];
                      final anulada = venta.estado == 'anulada';
                      return Card(
                        elevation: anulada ? 0 : 2,
                        color: anulada
                            ? Colors.grey.shade100
                            : Colors.white,
                        shadowColor: Colors.black.withValues(alpha: 0.05),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        margin: EdgeInsets.symmetric(vertical: 4),
                        child: Opacity(
                          opacity: anulada ? 0.6 : 1.0,
                          child: ListTile(
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 16, vertical: 4),
                            title: Text(
                              _formatearFecha(venta.fecha),
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                fontSize: 14,
                                decoration: anulada
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            ),
                            subtitle: Row(
                              children: [
                                if (anulada)
                                  Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: Container(
                                      padding: EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.red.shade100,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        "Anulada",
                                        style: TextStyle(
                                          color: Colors.red.shade800,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                Text(
                                  "\$${formatCurrency(venta.total)}",
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: anulada
                                        ? Colors.black38
                                        : Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (!anulada)
                                  IconButton(
                                    icon: Icon(Icons.cancel_outlined,
                                        color: Colors.red.shade400, size: 20),
                                    onPressed: () => _anularVenta(venta),
                                    tooltip: "Anular venta",
                                  ),
                                Icon(Icons.chevron_right,
                                    color: Colors.black54),
                              ],
                            ),
                            onTap: () => _verDetalle(venta),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
