import 'package:flutter/material.dart';
import 'package:excel/excel.dart'; // Importar el paquete excel
import 'package:path_provider/path_provider.dart'; // Para obtener la ruta de almacenamiento
import 'dart:io';
import 'database_helper.dart';
import 'producto_model.dart';

class Sidebar extends StatelessWidget {
  final Function onExportExcel;

  Sidebar({required this.onExportExcel});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: Colors.black87,
            ),
            child: Text(
              'Menú',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
              ),
            ),
          ),
          ListTile(
            leading: Icon(Icons.import_export),
            title: Text('Exportar a Excel'),
            onTap: () {
              onExportExcel();
              Navigator.pop(context); // Cerrar el drawer después de la acción
            },
          ),
        ],
      ),
    );
  }
}

Future<void> exportToExcel() async {
  // Obtener los productos de la base de datos
  final data = await DatabaseHelper.instance.getProductos();
  List<Producto> productos = data.map((e) => Producto.fromMap(e)).toList();

  // Crear un nuevo archivo Excel
  var excel = Excel.createExcel();
  var sheet = excel['Productos'];

  // Agregar encabezados
  sheet.appendRow([
    TextCellValue('Nombre'),
    TextCellValue('Código'),
    TextCellValue('Precio'),
    TextCellValue('Stock'),
  ]);

  // Agregar datos de los productos
  for (var producto in productos) {
    sheet.appendRow([
      TextCellValue(producto.nombre),
      TextCellValue(producto.codigo),
      TextCellValue(producto.precio.toString()),
      TextCellValue(producto.stock.toString()),
    ]);
  }

  // Guardar el archivo Excel
  final directory = await getApplicationDocumentsDirectory();
  final filePath = '${directory.path}/productos.xlsx';
  File(filePath)
    ..createSync(recursive: true)
    ..writeAsBytesSync(excel.encode()!);

  print('Archivo Excel guardado en: $filePath');
}