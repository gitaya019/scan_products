import 'package:flutter/material.dart';
import '../services/database_helper.dart';
import '../models/producto_model.dart';
import '../widgets/producto_text_field.dart';
import '../widgets/precio_field.dart';
import '../utils/formatters.dart';

class EditProductoScreen extends StatefulWidget {
  final Producto producto;

  EditProductoScreen({required this.producto});

  @override
  _EditProductoScreenState createState() => _EditProductoScreenState();
}

class _EditProductoScreenState extends State<EditProductoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _codigoController = TextEditingController();
  final _categoriaController = TextEditingController();
  final _precioController = TextEditingController();
  final _pesoController = TextEditingController();
  final _stockController = TextEditingController();
  final _marcaController = TextEditingController();

  late String _unidadMedida;
  late bool _ventaPorPeso;
  final _ivaController = TextEditingController();

  final _unidades = ['kg', 'g', 'lb', 'L', 'mL', 'unidad', 'paquete', 'caja'];


  @override
  void initState() {
    super.initState();
    _nombreController.text = widget.producto.nombre;
    _codigoController.text = widget.producto.codigo ?? '';
    _categoriaController.text = widget.producto.categoria;
    _precioController.text = formatCurrency(widget.producto.precio);
    _pesoController.text = widget.producto.peso.toString();
    _stockController.text = widget.producto.stock == widget.producto.stock.roundToDouble()
        ? widget.producto.stock.toInt().toString()
        : widget.producto.stock.toString();
    _marcaController.text = widget.producto.marca ?? '';
    _unidadMedida = widget.producto.unidadMedida ?? _unidades.first;
    _ventaPorPeso = widget.producto.ventaPorPeso;
    _ivaController.text = widget.producto.iva.toStringAsFixed(0);
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _codigoController.dispose();
    _categoriaController.dispose();
    _precioController.dispose();
    _pesoController.dispose();
    _stockController.dispose();
    _marcaController.dispose();
    _ivaController.dispose();
    super.dispose();
  }

  String _pesoLabel() {
    switch (_unidadMedida) {
      case 'kg':
        return 'Peso (kg)';
      case 'g':
        return 'Peso (g)';
      case 'lb':
        return 'Peso (lb)';
      case 'L':
        return 'Volumen (L)';
      case 'mL':
        return 'Volumen (mL)';
      default:
        return 'Cantidad';
    }
  }

  IconData _pesoIcon() {
    switch (_unidadMedida) {
      case 'L':
      case 'mL':
        return Icons.water_drop_outlined;
      case 'unidad':
      case 'paquete':
      case 'caja':
        return Icons.inventory_2_outlined;
      default:
        return Icons.monitor_weight_outlined;
    }
  }
  Future<void> _updateProducto() async {
    if (_formKey.currentState!.validate()) {
      final producto = Producto(
        id: widget.producto.id,
        nombre: _nombreController.text,
        codigo: _codigoController.text,
        categoria: _categoriaController.text,
        precio: parseCurrency(_precioController.text),
        peso: double.parse(_pesoController.text),
        stock: double.parse(_stockController.text),
        marca: _marcaController.text.isEmpty ? null : _marcaController.text,
        unidadMedida: _unidadMedida,
        iva: double.tryParse(_ivaController.text) ?? 0.0,
        ventaPorPeso: _ventaPorPeso,
      );

      await DatabaseHelper.instance.updateProducto(producto.toMap());
      Navigator.pop(context);
    }
  }

  Future<void> _deleteProducto() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Eliminar Producto"),
        content: const Text("¿Estás seguro de que deseas eliminar este producto?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text("Cancelar", style: TextStyle(color: Colors.green)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text("Eliminar", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true && widget.producto.id != null) {
      await DatabaseHelper.instance.deleteProducto(widget.producto.id!);
      Navigator.pop(context);
    }
  }

  String _stockLabel() {
    if (_ventaPorPeso) return 'Stock ($_unidadMedida)';
    return 'Stock (unidades)';
  }

  Widget _seccionHeader(String titulo) {
    return Text(
      titulo,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Theme.of(context).colorScheme.primary,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildDropdown(String label, IconData icon, String value, List<String> items, ValueChanged<String?> onChanged) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.black54),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        contentPadding:
            const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        labelStyle: const TextStyle(color: Colors.black54),
      ),
      items: items.map((v) {
        return DropdownMenuItem(
          value: v,
          child: Text(v),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: Text(
          "Editar Producto",
          style: TextStyle(
              color: Colors.black87, fontWeight: FontWeight.w300, fontSize: 22),
        ),
        iconTheme: IconThemeData(color: Colors.black54),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _seccionHeader("Información del Producto"),
                SizedBox(height: 12),
                ProductoTextField(
                  controller: _nombreController,
                  label: "Nombre del Producto",
                  icon: Icons.shopping_basket_outlined,
                  validator: (value) =>
                      value!.isEmpty ? "Ingrese un nombre" : null,
                ),
                SizedBox(height: 14),
                ProductoTextField(
                  controller: _codigoController,
                  label: "Código de Barras (opcional)",
                  icon: Icons.barcode_reader,
                ),
                SizedBox(height: 14),
                ProductoTextField(
                  controller: _categoriaController,
                  label: "Categoría",
                  icon: Icons.category_outlined,
                  validator: (value) =>
                      value!.isEmpty ? "Ingrese una categoría" : null,
                ),
                SizedBox(height: 24),
                _seccionHeader("Detalles del Producto"),
                SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ProductoTextField(
                        controller: _marcaController,
                        label: "Marca",
                        icon: Icons.branding_watermark_outlined,
                      ),
                    ),
                    SizedBox(width: 14),
                    Expanded(
                      child: _buildDropdown(
                        "Unidad", Icons.scale_outlined,
                        _unidadMedida, _unidades, (v) {
                          if (v != null) setState(() => _unidadMedida = v);
                        },
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: SwitchListTile(
                    title: const Text("Vender por peso",
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                    subtitle: Text(
                      _ventaPorPeso
                          ? "Se vende en $_unidadMedida (decimal)"
                          : "Se vende por unidad (entero)",
                      style: const TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                    value: _ventaPorPeso,
                    onChanged: (v) => setState(() => _ventaPorPeso = v),
                    secondary: Icon(
                      _ventaPorPeso ? Icons.scale : Icons.inventory_2_outlined,
                      color: Colors.black54,
                    ),
                    activeColor: Theme.of(context).colorScheme.primary,
                  ),
                ),
                SizedBox(height: 24),
                _seccionHeader("Precio y Stock"),
                SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: PrecioField(
                        controller: _precioController,
                        validator: (value) =>
                            value!.isEmpty ? "Ingrese un precio" : null,
                      ),
                    ),
                    SizedBox(width: 14),
                    Expanded(
                      child: ProductoTextField(
                        controller: _pesoController,
                        label: _pesoLabel(),
                        icon: _pesoIcon(),
                        keyboardType:
                            TextInputType.numberWithOptions(decimal: true),
                        validator: (value) =>
                            value!.isEmpty ? "Ingrese un peso" : null,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: ProductoTextField(
                        controller: _stockController,
                        label: _stockLabel(),
                        icon: Icons.inventory,
                        keyboardType: TextInputType.numberWithOptions(decimal: _ventaPorPeso),
                        validator: (value) =>
                            value!.isEmpty ? "Ingrese un stock" : null,
                      ),
                    ),
                    SizedBox(width: 14),
                    Expanded(
                      child: ProductoTextField(
                        controller: _ivaController,
                        label: "IVA",
                        icon: Icons.receipt_long_outlined,
                        keyboardType: TextInputType.number,
                        suffixText: "%",
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _updateProducto,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  child: Text(
                    "Guardar Cambios",
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500),
                  ),
                ),
                SizedBox(height: 12),
                ElevatedButton(
                  onPressed: _deleteProducto,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade500,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    "Eliminar Producto",
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
