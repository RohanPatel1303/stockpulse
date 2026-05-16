import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:stockpulse/core/theme.dart';
import 'package:stockpulse/main.dart';
import 'package:stockpulse/models/item.dart';
import 'package:stockpulse/providers/auth_provider.dart';
import 'package:stockpulse/providers/inventory_provider.dart';

class AddItemScreen extends StatefulWidget {
  final Item? existingItem; // null = add mode, non-null = edit mode

  const AddItemScreen({super.key, this.existingItem});

  @override
  State<AddItemScreen> createState() => _AddItemScreenState();
}

class _AddItemScreenState extends State<AddItemScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _quantityController = TextEditingController(text: '0');
  final _thresholdController = TextEditingController(text: '5');
  final _locationController = TextEditingController();

  bool _isLoading = false;
  String? _imageUrl;
  bool _isUploadingImage = false;

  bool get _isEditMode => widget.existingItem != null;

  @override
  void initState() {
    super.initState();
    // Pre-fill if editing
    if (_isEditMode) {
      final item = widget.existingItem!;
      _nameController.text = item.name;
      _descriptionController.text = item.description ?? '';
      _quantityController.text = '${item.quantity}';
      _thresholdController.text = '${item.lowStockThreshold}';
      _locationController.text = item.location ?? '';
      _imageUrl = item.imageUrl;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _quantityController.dispose();
    _thresholdController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      imageQuality: 80,
    );

    if (file == null) return;

    setState(() => _isUploadingImage = true);

    try {
      final bytes = await file.readAsBytes();
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final path = 'items/$fileName';

      await supabase.storage.from('item-images').uploadBinary(
        path,
        bytes,
        fileOptions: const FileOptions(contentType: 'image/jpeg'),
      );

      final url = supabase.storage.from('item-images').getPublicUrl(path);
      setState(() => _imageUrl = url);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Image upload failed: $e'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isUploadingImage = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();
    final inventory = context.read<InventoryProvider>();

    if (auth.profile == null) return;

    setState(() => _isLoading = true);

    String? error;

    if (_isEditMode) {
      error = await inventory.updateItem(
        item: widget.existingItem!,
        updates: {
          'name': _nameController.text.trim(),
          'description': _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          'quantity': int.parse(_quantityController.text),
          'low_stock_threshold': int.parse(_thresholdController.text),
          'location': _locationController.text.trim().isEmpty
              ? null
              : _locationController.text.trim(),
          'image_url': _imageUrl,
        },
        currentUser: auth.profile!,
      );
    } else {
      error = await inventory.addItem(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        quantity: int.parse(_quantityController.text),
        lowStockThreshold: int.parse(_thresholdController.text),
        location: _locationController.text.trim().isEmpty
            ? null
            : _locationController.text.trim(),
        imageUrl: _imageUrl,
        currentUser: auth.profile!,
      );
    }

    setState(() => _isLoading = false);

    if (mounted) {
      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error), backgroundColor: Colors.red),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
            Text(_isEditMode ? 'Item updated!' : 'Item added successfully!'),
            backgroundColor: AppTheme.success,
          ),
        );
        context.pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Edit Item' : 'Add New Item'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image picker
              GestureDetector(
                onTap: _isUploadingImage ? null : _pickImage,
                child: Container(
                  width: double.infinity,
                  height: 160,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: const Color(0xFFBFDBFE), width: 2),
                    image: _imageUrl != null
                        ? DecorationImage(
                      image: NetworkImage(_imageUrl!),
                      fit: BoxFit.cover,
                    )
                        : null,
                  ),
                  child: _isUploadingImage
                      ? const Center(child: CircularProgressIndicator())
                      : _imageUrl == null
                      ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.add_photo_alternate_rounded,
                          size: 40, color: AppTheme.primary),
                      const SizedBox(height: 8),
                      Text('Tap to add photo',
                          style: TextStyle(
                              color: Colors.grey[600])),
                    ],
                  )
                      : Align(
                    alignment: Alignment.topRight,
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: CircleAvatar(
                        radius: 16,
                        backgroundColor: Colors.black54,
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          icon: const Icon(Icons.close,
                              color: Colors.white, size: 16),
                          onPressed: () =>
                              setState(() => _imageUrl = null),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Name
              _SectionLabel(label: 'Item Name *'),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(hintText: 'e.g. Laptop Dell XPS 15'),
                validator: (v) =>
                v!.trim().isEmpty ? 'Item name is required' : null,
              ),
              const SizedBox(height: 16),

              // Description
              _SectionLabel(label: 'Description'),
              TextFormField(
                controller: _descriptionController,
                maxLines: 2,
                decoration: const InputDecoration(
                    hintText: 'Optional description...'),
              ),
              const SizedBox(height: 16),

              // Location
              _SectionLabel(label: 'Location'),
              TextFormField(
                controller: _locationController,
                decoration: const InputDecoration(
                    hintText: 'e.g. Warehouse A - Shelf 2'),
              ),
              const SizedBox(height: 16),

              // Quantity and threshold in a row
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SectionLabel(label: 'Initial Quantity *'),
                        TextFormField(
                          controller: _quantityController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(hintText: '0'),
                          validator: (v) {
                            final n = int.tryParse(v ?? '');
                            if (n == null || n < 0) return 'Enter a valid number';
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SectionLabel(label: 'Low Stock Alert *'),
                        TextFormField(
                          controller: _thresholdController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(hintText: '5'),
                          validator: (v) {
                            final n = int.tryParse(v ?? '');
                            if (n == null || n < 1) return 'Min value is 1';
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // Submit button
              ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                child: _isLoading
                    ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
                    : Text(_isEditMode ? 'Save Changes' : 'Add Item'),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;

  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
    );
  }
}