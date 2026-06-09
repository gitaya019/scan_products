import 'package:flutter/material.dart';
import '../services/database_helper.dart';
import '../models/venta_model.dart';
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
                                    "${d.cantidad} x \$${formatCurrency(d.precioUnitario)}",
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
                        backgroundColor: Colors.black87,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
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
                      return Card(
                        elevation: 0,
                        color: Colors.grey.shade100,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        margin: EdgeInsets.symmetric(vertical: 4),
                        child: ListTile(
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 16, vertical: 4),
                          title: Text(
                            _formatearFecha(venta.fecha),
                            style: TextStyle(
                                fontWeight: FontWeight.w500, fontSize: 14),
                          ),
                          subtitle: Text(
                            "Total: \$${formatCurrency(venta.total)}",
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Colors.black87),
                          ),
                          trailing: Icon(Icons.chevron_right,
                              color: Colors.black54),
                          onTap: () => _verDetalle(venta),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
