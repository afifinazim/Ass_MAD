import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:vibration/vibration.dart';
import '../models/activity.dart';
import '../services/api_services.dart';
import '../helpers/database_helper.dart';
import '../helpers/notification_helper.dart';
import '../helpers/preferences_helper.dart';

class AddActivityScreen extends StatefulWidget {
  final Activity? activityToEdit;

  const AddActivityScreen({super.key, this.activityToEdit});

  @override
  State<AddActivityScreen> createState() =>
      _AddActivityScreenState();
}

class _AddActivityScreenState extends State<AddActivityScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _hoursCtrl = TextEditingController();

  String _selectedCategory = 'Sports';
  DateTime _selectedDate = DateTime.now();
  bool _isCompleted = false;
  bool _isLoadingApi = false;
  bool _isSaving = false;
  String? _imagePath;

  bool get _isEditMode => widget.activityToEdit != null;

  final List<String> _categories = [
    'Sports', 'Academic', 'Arts',
    'Volunteer', 'Leadership', 'Other',
  ];

  final Map<String, IconData> _categoryIcons = {
    'Sports': Icons.sports_soccer,
    'Academic': Icons.school,
    'Arts': Icons.palette,
    'Volunteer': Icons.volunteer_activism,
    'Leadership': Icons.star,
    'Other': Icons.category,
  };

  @override
  void initState() {
    super.initState();
    if (_isEditMode) {
      final a = widget.activityToEdit!;
      _titleCtrl.text = a.title;
      _descCtrl.text = a.description;
      _hoursCtrl.text = a.hours.toString();
      _selectedCategory = a.category;
      _selectedDate = a.date;
      _isCompleted = a.isCompleted;
      _imagePath = a.imagePath;
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _hoursCtrl.dispose();
    super.dispose();
  }

  Future<void> _vibrate() async {
    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(duration: 40);
    }
  }

  // ─── Gallery Picker ───────────────────────────────────────
  Future<void> _pickImage() async {
    await _vibrate();
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 1024,
      maxHeight: 1024,
    );
    if (image != null) {
      setState(() => _imagePath = image.path);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🖼️ Image attached!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _removeImage() {
    setState(() => _imagePath = null);
  }

  // ─── API Suggestion ───────────────────────────────────────
  Future<void> _fetchApiSuggestion() async {
    await _vibrate();
    setState(() => _isLoadingApi = true);
    try {
      final suggestion = await ApiService.fetchActivityByCategory(
          _selectedCategory);
      setState(() {
        _titleCtrl.text = suggestion.title;
        _descCtrl.text =
        'Suggested for ${suggestion.participants} participant(s). '
            'Difficulty: ${suggestion.accessibilityLabel}.';
        _hoursCtrl.text = '1';
        _isCompleted = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Activity suggestion loaded!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingApi = false);
    }
  }

  // ─── Date Picker ──────────────────────────────────────────
  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
              primary: Color(0xFF6A11CB)),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  // ─── Submit ───────────────────────────────────────────────
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await _vibrate();
    setState(() => _isSaving = true);

    try {
      final activity = Activity(
        id: widget.activityToEdit?.id,
        title: _titleCtrl.text.trim(),
        category: _selectedCategory,
        date: _selectedDate,
        hours: int.parse(_hoursCtrl.text.trim()),
        description: _descCtrl.text.trim(),
        isCompleted: _isCompleted,
        imagePath: _imagePath,
        sourceUrl: widget.activityToEdit?.sourceUrl,
        steps: widget.activityToEdit?.steps,
      );

      if (_isEditMode) {
        await DatabaseHelper.instance.updateActivity(activity);
      } else {
        await DatabaseHelper.instance.insertActivity(activity);
      }

      // Notification on save (if enabled)
      final notifEnabled = await PreferencesHelper.instance
          .getNotificationsEnabled();
      if (notifEnabled) {
        await NotificationHelper.instance
            .showActivitySavedNotification(activity.title);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditMode
                ? '✅ Activity updated!'
                : '✅ Activity saved!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Edit Activity' : 'Add Activity'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (!_isEditMode)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton.icon(
                onPressed:
                _isLoadingApi ? null : _fetchApiSuggestion,
                icon: _isLoadingApi
                    ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white),
                )
                    : const Icon(Icons.lightbulb_outline,
                    color: Colors.white, size: 18),
                label: const Text('Suggest',
                    style: TextStyle(
                        color: Colors.white, fontSize: 13)),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // API hint banner
              if (!_isEditMode) _buildApiBanner(),
              const SizedBox(height: 4),

              // Image section
              _buildImageSection(),
              const SizedBox(height: 16),

              // Title
              TextFormField(
                controller: _titleCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: _inputDecoration(
                    'Activity Title *', Icons.title),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Please enter a title';
                  }
                  if (v.trim().length < 3) {
                    return 'Title must be at least 3 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),

              // Category
              _buildCategorySelector(),
              const SizedBox(height: 14),

              // Date
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(10),
                child: InputDecorator(
                  decoration: _inputDecoration(
                      'Date *', Icons.calendar_today),
                  child: Row(
                    mainAxisAlignment:
                    MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${_selectedDate.day.toString().padLeft(2, '0')}/'
                            '${_selectedDate.month.toString().padLeft(2, '0')}/'
                            '${_selectedDate.year}',
                        style: const TextStyle(fontSize: 15),
                      ),
                      const Icon(Icons.arrow_drop_down,
                          color: Colors.grey),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Hours
              TextFormField(
                controller: _hoursCtrl,
                keyboardType: TextInputType.number,
                decoration: _inputDecoration(
                    'Hours Spent *', Icons.access_time),
                validator: (v) {
                  if (v == null || v.isEmpty) {
                    return 'Please enter hours';
                  }
                  final n = int.tryParse(v);
                  if (n == null || n <= 0 || n > 24) {
                    return 'Enter a valid number (1–24)';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),

              // Description
              TextFormField(
                controller: _descCtrl,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: 'Description',
                  alignLabelWithHint: true,
                  prefixIcon: const Padding(
                    padding: EdgeInsets.only(bottom: 64),
                    child: Icon(Icons.description),
                  ),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 14),

              // Completed toggle
              Card(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                child: SwitchListTile(
                  title: const Text('Mark as Completed'),
                  subtitle:
                  const Text('Has this activity been done?'),
                  value: _isCompleted,
                  activeColor: const Color(0xFF6A11CB),
                  secondary: Icon(
                    _isCompleted
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    color: _isCompleted
                        ? Colors.green
                        : Colors.grey,
                  ),
                  onChanged: (v) async {
                    await _vibrate();
                    setState(() => _isCompleted = v);
                  },
                ),
              ),
              const SizedBox(height: 24),

              // Save button
              ElevatedButton(
                onPressed: _isSaving ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6A11CB),
                  foregroundColor: Colors.white,
                  padding:
                  const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 3,
                ),
                child: _isSaving
                    ? const SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2),
                )
                    : Row(
                  mainAxisAlignment:
                  MainAxisAlignment.center,
                  children: [
                    Icon(_isEditMode
                        ? Icons.save
                        : Icons.add_circle),
                    const SizedBox(width: 8),
                    Text(
                      _isEditMode
                          ? 'Update Activity'
                          : 'Save Activity',
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Widgets ──────────────────────────────────────────────
  Widget _buildApiBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF6A11CB).withOpacity(0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: const Color(0xFF6A11CB).withOpacity(0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.lightbulb,
              color: Color(0xFF6A11CB), size: 18),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Tap "Suggest" to auto-fill from API based on your selected category',
              style: TextStyle(
                  fontSize: 12, color: Color(0xFF6A11CB)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Activity Photo',
            style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        if (_imagePath != null && File(_imagePath!).existsSync())
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  File(_imagePath!),
                  height: 160,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius:
                          BorderRadius.circular(20),
                        ),
                        child: const Icon(Icons.edit,
                            color: Colors.white, size: 18),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _removeImage,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.8),
                          borderRadius:
                          BorderRadius.circular(20),
                        ),
                        child: const Icon(Icons.close,
                            color: Colors.white, size: 18),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          )
        else
          GestureDetector(
            onTap: _pickImage,
            child: Container(
              height: 110,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: Colors.grey[300]!,
                    style: BorderStyle.solid),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.photo_library,
                      size: 36, color: Colors.grey[400]),
                  const SizedBox(height: 8),
                  Text('Tap to pick from gallery',
                      style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 13)),
                  Text('Optional',
                      style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 11)),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCategorySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Category *',
            style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _categories.map((cat) {
            final isSelected = _selectedCategory == cat;
            final color = _categoryColor(cat);
            return GestureDetector(
              onTap: () async {
                await _vibrate();
                setState(() => _selectedCategory = cat);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? color
                      : color.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: isSelected
                          ? color
                          : color.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _categoryIcons[cat] ?? Icons.category,
                      size: 15,
                      color: isSelected
                          ? Colors.white
                          : color,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      cat,
                      style: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : color,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(
      String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10)),
      contentPadding: const EdgeInsets.symmetric(
          horizontal: 16, vertical: 14),
    );
  }

  Color _categoryColor(String cat) {
    switch (cat.toLowerCase()) {
      case 'sports': return Colors.blue;
      case 'academic': return Colors.green;
      case 'arts': return Colors.purple;
      case 'volunteer': return Colors.orange;
      case 'leadership': return Colors.teal;
      default: return Colors.grey;
    }
  }
}
