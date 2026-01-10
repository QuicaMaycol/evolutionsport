import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TemplateFormScreen extends StatefulWidget {
  final Map<String, dynamic>? template;

  const TemplateFormScreen({super.key, this.template});

  @override
  State<TemplateFormScreen> createState() => _TemplateFormScreenState();
}

class _TemplateFormScreenState extends State<TemplateFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _priceController = TextEditingController();

  String _selectedType = 'microcycle';
  bool _isForSale = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.template != null) {
      _titleController.text = widget.template!['title'] ?? '';
      _descController.text = widget.template!['description'] ?? '';
      _priceController.text = (widget.template!['price'] ?? 0).toString();
      _selectedType = widget.template!['type'] ?? 'microcycle';
      _isForSale = widget.template!['is_for_sale'] ?? false;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      final price = _isForSale ? double.tryParse(_priceController.text) ?? 0.0 : 0.0;

      final data = {
        'title': _titleController.text.trim(),
        'description': _descController.text.trim(),
        'type': _selectedType,
        'is_for_sale': _isForSale,
        'price': price,
        'creator_id': userId,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (widget.template == null) {
        // Create new
        await Supabase.instance.client.from('templates').insert(data);
      } else {
        // Update existing
        await Supabase.instance.client
            .from('templates')
            .update(data)
            .eq('id', widget.template!['id']);
      }

      if (mounted) {
        Navigator.pop(context, true); // Return success
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.template != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Editar Plantilla' : 'Nueva Plantilla'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Título de la Plantilla',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.title),
                ),
                validator: (val) => val == null || val.isEmpty ? 'Ingresa un título' : null,
              ),
              const SizedBox(height: 16),
              
              DropdownButtonFormField<String>(
                value: _selectedType,
                decoration: const InputDecoration(
                  labelText: 'Tipo de Planificación',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.category),
                ),
                items: const [
                  DropdownMenuItem(value: 'session', child: Text('Sesión Única')),
                  DropdownMenuItem(value: 'microcycle', child: Text('Microciclo (Semana)')),
                  DropdownMenuItem(value: 'mesocycle', child: Text('Mesociclo (Mes)')),
                  DropdownMenuItem(value: 'season', child: Text('Temporada (Año)')),
                ],
                onChanged: (val) => setState(() => _selectedType = val!),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _descController,
                decoration: const InputDecoration(
                  labelText: 'Descripción (Opcional)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.description),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 24),

              // Sección de Venta
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _isForSale ? Colors.amber.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _isForSale ? Colors.amber : Colors.grey.withOpacity(0.3)),
                ),
                child: Column(
                  children: [
                    SwitchListTile(
                      title: const Text('Poner a la Venta', style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: const Text('Disponible para otros entrenadores en el Marketplace'),
                      value: _isForSale,
                      onChanged: (val) => setState(() => _isForSale = val),
                      activeColor: Colors.amber,
                    ),
                    if (_isForSale) ...[
                      const Divider(),
                      TextFormField(
                        controller: _priceController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                        decoration: const InputDecoration(
                          labelText: 'Precio (USD)',
                          prefixIcon: Icon(Icons.attach_money),
                          border: OutlineInputBorder(),
                        ),
                        validator: (val) {
                          if (!_isForSale) return null;
                          if (val == null || val.isEmpty) return 'Ingresa un precio';
                          if (double.tryParse(val) == null) return 'Precio inválido';
                          return null;
                        },
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isSaving ? null : _save,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: const Color(0xFF4CAF50),
                ),
                child: _isSaving 
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Guardar Plantilla', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
