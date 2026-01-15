import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/objective_selector_modal.dart';

class TemplateFormScreen extends StatefulWidget {
  final Map<String, dynamic>? template;

  const TemplateFormScreen({super.key, this.template});

  @override
  State<TemplateFormScreen> createState() => _TemplateFormScreenState();
}

class _TemplateFormScreenState extends State<TemplateFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _notesController = TextEditingController();
  final _priceController = TextEditingController(text: '0.0');

  String _selectedType = 'session';
  String _stimulusType = 'Campo';
  double _rpeLoad = 5.0;
  Map<String, dynamic>? _selectedObjective;
  
  bool _isForSale = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.template != null) {
      _titleController.text = widget.template!['title'] ?? '';
      _notesController.text = widget.template!['description'] ?? '';
      _priceController.text = (widget.template!['price'] ?? 0).toString();
      _selectedType = widget.template!['type'] ?? 'session';
      _isForSale = widget.template!['is_for_sale'] ?? false;
      _stimulusType = widget.template!['stimulus_type'] ?? 'Campo';
      _rpeLoad = (widget.template!['rpe_load'] ?? 5.0).toDouble();
      
      if (widget.template!['objective_id'] != null) {
        _loadObjective(widget.template!['objective_id']);
      }
    }
  }

  Future<void> _loadObjective(String id) async {
    try {
      final resp = await Supabase.instance.client
          .schema('evolutionsport')
          .from('objectives')
          .select()
          .eq('id', id)
          .single();
      setState(() {
        _selectedObjective = resp;
      });
    } catch (e) {
      debugPrint('Error loading objective: $e');
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedObjective == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, selecciona un objetivo principal')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      final price = _isForSale ? double.tryParse(_priceController.text) ?? 0.0 : 0.0;

      final data = {
        'title': _titleController.text.trim(),
        'description': _notesController.text.trim(),
        'type': _selectedType,
        'is_for_sale': _isForSale,
        'price': price,
        'creator_id': userId,
        'objective_id': _selectedObjective!['id'],
        'stimulus_type': _stimulusType,
        'rpe_load': _rpeLoad,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (widget.template == null) {
        await Supabase.instance.client.from('templates').insert(data);
      } else {
        await Supabase.instance.client
            .from('templates')
            .update(data)
            .eq('id', widget.template!['id']);
      }

      if (mounted) Navigator.pop(context, true);
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
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: Text(isEditing ? 'Editar Plantilla' : 'Nueva Plantilla Táctica'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Nombre de la Plantilla', style: TextStyle(color: Colors.grey, fontSize: 14)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  hintText: 'Ej: Posesión y Transición Ofensiva',
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
                validator: (v) => v == null || v.isEmpty ? 'Requerido' : null,
              ),
              const SizedBox(height: 24),

              const Text('Objetivo Principal', style: TextStyle(color: Colors.grey, fontSize: 14)),
              const SizedBox(height: 8),
              InkWell(
                onTap: () async {
                  final result = await showModalBottomSheet<Map<String, dynamic>>(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (context) => const ObjectiveSelectorModal(),
                  );
                  if (result != null) setState(() => _selectedObjective = result);
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _selectedObjective != null ? Colors.green.withOpacity(0.3) : Colors.transparent),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.track_changes, color: _selectedObjective != null ? Colors.green : Colors.grey),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _selectedObjective != null ? _selectedObjective!['name'] : 'Seleccionar objetivo...',
                          style: TextStyle(color: _selectedObjective != null ? Colors.white : Colors.grey, fontSize: 16),
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: Colors.grey),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              const Text('Tipo de Estímulo', style: TextStyle(color: Colors.grey, fontSize: 14)),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: ['Campo', 'Físico/Gym', 'Partido', 'Recuperación', 'Video'].map((type) {
                    final isSelected = _stimulusType == type;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(type),
                        selected: isSelected,
                        onSelected: (val) => setState(() => _stimulusType = type),
                        selectedColor: Colors.green.withOpacity(0.2),
                        labelStyle: TextStyle(color: isSelected ? Colors.green : Colors.grey),
                        backgroundColor: Colors.white.withOpacity(0.05),
                        side: BorderSide(color: isSelected ? Colors.green.withOpacity(0.5) : Colors.transparent),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 24),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Carga (RPE)', style: TextStyle(color: Colors.grey, fontSize: 14)),
                  Text('${_rpeLoad.toInt()}', style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 18)),
                ],
              ),
              Slider(
                value: _rpeLoad,
                min: 1,
                max: 10,
                divisions: 9,
                activeColor: Colors.amber,
                inactiveColor: Colors.white.withOpacity(0.1),
                onChanged: (val) => setState(() => _rpeLoad = val),
              ),
              const SizedBox(height: 24),

              const Text('Notas / Observaciones', style: TextStyle(color: Colors.grey, fontSize: 14)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _notesController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Detalles técnicos, variantes, recordatorios...',
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 32),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.withOpacity(0.2)),
                ),
                child: Column(
                  children: [
                    SwitchListTile(
                      title: const Text('Publicar en Marketplace', style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: const Text('Permite que otros entrenadores compren esta plantilla'),
                      value: _isForSale,
                      onChanged: (val) => setState(() => _isForSale = val),
                      activeColor: Colors.blue,
                    ),
                    if (_isForSale) ...[
                      const Divider(),
                      TextFormField(
                        controller: _priceController,
                        decoration: const InputDecoration(
                          labelText: 'Precio de venta (\$)',
                          prefixIcon: Icon(Icons.attach_money),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 48),

              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isSaving
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(isEditing ? 'Actualizar Plantilla' : 'Crear Plantilla', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
