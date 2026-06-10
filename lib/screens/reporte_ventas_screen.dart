import 'package:flutter/material.dart';
import '../services/database_helper.dart';
import '../utils/formatters.dart';

class ReporteVentasScreen extends StatefulWidget {
  @override
  _ReporteVentasScreenState createState() => _ReporteVentasScreenState();
}

class _ReporteVentasScreenState extends State<ReporteVentasScreen> {
  Map<String, dynamic>? _resumen;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    final resumen = await DatabaseHelper.instance.getResumenVentas();
    setState(() {
      _resumen = resumen;
      _cargando = false;
    });
  }

  Widget _tarjeta(String titulo, String subtitulo, IconData icono, Color color) {
    return Card(
      elevation: 2,
      color: Colors.white,
      shadowColor: Colors.black.withValues(alpha: 0.05),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.15),
          child: Icon(icono, color: color),
        ),
        title: Text(titulo,
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
        subtitle: Text(subtitulo,
            style: TextStyle(color: Colors.black54, fontSize: 13)),
      ),
    );
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
          "Reporte de Ventas",
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w300,
            fontSize: 22,
          ),
        ),
      ),
      body: _cargando
          ? Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _cargar,
              child: ListView(
                padding: EdgeInsets.symmetric(vertical: 8),
                children: [
                  _tarjeta(
                    "Ventas Hoy",
                    "\$${formatCurrency((_resumen?['total_hoy'] ?? 0).toDouble())} — ${_resumen?['cantidad_hoy'] ?? 0} producto(s)",
                    Icons.today,
                    Colors.blue,
                  ),
                  _tarjeta(
                    "Ventas Esta Semana",
                    "\$${formatCurrency((_resumen?['total_semana'] ?? 0).toDouble())} — ${_resumen?['cantidad_semana'] ?? 0} producto(s)",
                    Icons.date_range,
                    Colors.green,
                  ),
                  _tarjeta(
                    "Ventas Este Mes",
                    "\$${formatCurrency((_resumen?['total_mes'] ?? 0).toDouble())} — ${_resumen?['cantidad_mes'] ?? 0} producto(s)",
                    Icons.calendar_month,
                    Colors.indigo,
                  ),
                  if (_resumen?['producto_top'] != null)
                    _tarjeta(
                      "Producto Más Vendido",
                      "${_resumen!['producto_top']} — ${_resumen!['producto_top_cantidad']} vendido(s)",
                      Icons.emoji_events,
                      Colors.amber.shade700,
                    ),
                ],
              ),
            ),
    );
  }
}
