import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'database_helper.dart';
import 'producto_model.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';

class Sidebar extends StatelessWidget {
  final Function onExportExcel;

  const Sidebar({Key? key, required this.onExportExcel}) : super(key: key);

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
                        'v1.0.0',
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
                Icons.import_export,
                color: Colors.black87,
              ),
              title: Text(
                'Exportar a Excel',
                style: TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.w500,
                ),
              ),
              onTap: () {
                onExportExcel();
                Navigator.pop(context);
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

Future<void> exportToExcel() async {
  // Verificar permisos de almacenamiento
  var status = await Permission.storage.status;
  if (!status.isGranted) {
    await Permission.storage.request();
  }

  // Obtener los productos de la base de datos
  final data = await DatabaseHelper.instance.getProductos();
  List<Producto> productos = data.map((e) => Producto.fromMap(e)).toList();

  // Crear un nuevo archivo Excel
  var excel = Excel.createExcel();
  var sheet = excel['Productos'];

  // Agregar encabezados con todos los campos
  sheet.appendRow([
    TextCellValue('ID'),
    TextCellValue('Nombre'),
    TextCellValue('Código'),
    TextCellValue('Categoría'),
    TextCellValue('Precio'),
    TextCellValue('Peso'),
    TextCellValue('Stock'),
  ]);

  // Agregar datos de los productos
  for (var producto in productos) {
    sheet.appendRow([
      TextCellValue(producto.id.toString()), // ID
      TextCellValue(producto.nombre), // Nombre
      TextCellValue(producto.codigo), // Código
      TextCellValue(producto.categoria), // Categoría
      TextCellValue(producto.precio.toString()), // Precio
      TextCellValue(producto.peso.toString()), // Peso
      TextCellValue(producto.stock.toString()), // Stock
    ]);
  }

  // Convertir el archivo Excel a bytes
  List<int>? excelBytesList = excel.encode();

  if (excelBytesList == null) {
    print('Error al generar el archivo Excel.');
    return;
  }

  // Convertir List<int> a Uint8List
  Uint8List excelBytes = Uint8List.fromList(excelBytesList);

  // Guardar el archivo en el almacenamiento privado de la aplicación
  final directory = await getApplicationDocumentsDirectory();
  final filePath = '${directory.path}/productos.xlsx';
  File(filePath).writeAsBytesSync(excelBytes);

  print('Archivo Excel guardado en: $filePath');

  // Compartir el archivo Excel
  await Share.shareXFiles([XFile(filePath)],
      text: 'Aquí está el archivo Excel');
}
