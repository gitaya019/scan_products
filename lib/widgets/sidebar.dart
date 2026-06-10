import 'package:flutter/material.dart';
import '../screens/historial_ventas_screen.dart';
import '../screens/reporte_ventas_screen.dart';

class Sidebar extends StatelessWidget {
  final Function? onVenta;

  const Sidebar({Key? key, this.onVenta}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Container(
        color: Colors.white,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.black87, Colors.black54],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'Scan Products',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Image.network(
                        'https://flagcdn.com/w320/co.png',
                        width: 40,
                        height: 24,
                        fit: BoxFit.cover,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'v2.0.0',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            ListTile(
              leading: Icon(
                Icons.shopping_cart_outlined,
                color: Colors.black87,
              ),
              title: Text(
                'Nueva Venta',
                style: TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.w500,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                onVenta?.call();
              },
              trailing: Icon(
                Icons.chevron_right,
                color: Colors.black54,
              ),
            ),
            ListTile(
              leading: Icon(
                Icons.receipt_long_outlined,
                color: Colors.black87,
              ),
              title: Text(
                'Historial de Ventas',
                style: TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.w500,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => HistorialVentasScreen()),
                );
              },
              trailing: Icon(
                Icons.chevron_right,
                color: Colors.black54,
              ),
            ),
            ListTile(
              leading: Icon(
                Icons.bar_chart_outlined,
                color: Colors.black87,
              ),
              title: Text(
                'Reporte de Ventas',
                style: TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.w500,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => ReporteVentasScreen()),
                );
              },
              trailing: Icon(
                Icons.chevron_right,
                color: Colors.black54,
              ),
            ),
            Divider(
              color: Colors.grey.shade300,
              indent: 16,
              endIndent: 16,
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Desarrollado por JACSOFT',
                style: TextStyle(
                  color: Colors.black54,
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
