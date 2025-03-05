import 'dart:typed_data'; // For Uint8List
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
  await Share.shareXFiles([XFile(filePath)], text: 'Aquí está el archivo Excel');
}