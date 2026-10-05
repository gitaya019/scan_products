import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../utils/formatters.dart';
import 'producto_text_field.dart';

/// Campo de precio en COP.
///
/// While typing shows the raw digits; on focus loss reformats with thousand
/// separators so the user always reads a familiar currency format.
class PrecioField extends StatefulWidget {
  final TextEditingController controller;
  final String? Function(String?)? validator;

  const PrecioField({
    super.key,
    required this.controller,
    this.validator,
  });

  @override
  State<PrecioField> createState() => _PrecioFieldState();
}

class _PrecioFieldState extends State<PrecioField> {
  late final FocusNode _focusNode = FocusNode()..addListener(_onFocusChange);

  @override
  void dispose() {
    _focusNode
      ..removeListener(_onFocusChange)
      ..dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus && widget.controller.text.isNotEmpty) {
      final value = parseCurrency(widget.controller.text);
      widget.controller.text = formatCurrency(value);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ProductoTextField(
      controller: widget.controller,
      label: 'Precio',
      icon: Icons.attach_money_rounded,
      keyboardType: TextInputType.number,
      validator: widget.validator,
      focusNode: _focusNode,
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9]')),
      ],
      suffixText: 'COP',
    );
  }
}
