import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:vibration/vibration.dart';
import '../helpers/preferences_helper.dart';
import '../helpers/database_helper.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isEditing = false;
  bool _isLoading = true;
  bool _isSaving = false;

  final _nameCtrl = TextEditingController();
  final _idCtrl = TextEditingController();
  final _classCtrl = TextEditingController();
  final _programCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _goalCtrl = TextEditingController();

  String _imagePath = '';
  int _totalActivities = 0;
  int _totalHours = 0;
  double _completionRate = 0;
  int _totalSteps = 0;

  final List<String> _classList = [
    'DCS 5A', 'DCS 5B', 'DCS 5C', 'DCS 5D',
    'DIT 5A', 'DIT 5B', 'DCS 4A', 'DCS 4B',
  ];

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _idCtrl.dispose();
    _classCtrl.dispose();
    _programCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _goalCtrl.dispose();
    super.dispose();
  }

  Future<void> _vibrate() async {
    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(duration: 40);
    }
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    final profile =
    await PreferencesHelper.instance.getProfile();
    final goal =
    await PreferencesHelper.instance.getMonthlyGoal();
    final activities =
    await DatabaseHelper.instance.getAllActivities();
    final hours =
    await DatabaseHelper.instance.getTotalHours();
    final rate =
    await DatabaseHelper.instance.getCompletionRate();
    final steps =
    await DatabaseHelper.instance.getTotalSteps();

    setState(() {
      _nameCtrl.text = profile['name'] ?? '';
      _idCtrl.text = profile['studentId'] ?? '';
      _classCtrl.text = profile['class'] ?? 'DCS 5A';
      _programCtrl.text = profile['program'] ?? '';
      _emailCtrl.text = profile['email'] ?? '';
      _phoneCtrl.text = profile['phone'] ?? '';
      _goalCtrl.text = goal.toString();
      _imagePath = profile['imagePath'] ?? '';
      _totalActivities = activities.length;
      _totalHours = hours;
      _completionRate = rate;
      _totalSteps = steps;
      _isLoading = false;
    });
  }

  // ─── Gallery Image Picker ─────────────────────────────────
  Future<void> _pickProfileImage() async {
    await _vibrate();
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 512,
      maxHeight: 512,
    );
    if (image != null) {
      await PreferencesHelper.instance
          .saveProfileImage(image.path);
      setState(() => _imagePath = image.path);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🖼️ Profile photo updated!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _saveProfile() async {
    await _vibrate();
    setState(() => _isSaving = true);
    try {
      await PreferencesHelper.instance.saveProfile(
        name: _nameCtrl.text.trim(),
        studentId: _idCtrl.text.trim(),
        studentClass: _classCtrl.text.trim(),
        program: _programCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
      );
      final goal =
          int.tryParse(_goalCtrl.text.trim()) ?? 50;
      await PreferencesHelper.instance
          .setMonthlyGoal(goal);

      setState(() {
        _isEditing = false;
        _isSaving = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Profile saved!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (!_isLoading)
            IconButton(
              icon: Icon(
                  _isEditing ? Icons.close : Icons.edit),
              tooltip:
              _isEditing ? 'Cancel' : 'Edit Profile',
              onPressed: () async {
                await _vibrate();
                if (_isEditing) _loadProfile();
                setState(() => _isEditing = !_isEditing);
              },
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
          child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildAvatarSection(),
            const SizedBox(height: 16),
            _buildStatsCard(),
            const SizedBox(height: 16),
            _isEditing
                ? _buildEditForm()
                : _buildViewCard(),
          ],
        ),
      ),
    );
  }

  // ─── Avatar ───────────────────────────────────────────────
  Widget _buildAvatarSection() {
    final hasImage = _imagePath.isNotEmpty &&
        File(_imagePath).existsSync();
    return Column(
      children: [
        Stack(
          alignment: Alignment.bottomRight,
          children: [
            GestureDetector(
              onTap: _pickProfileImage,
              child: CircleAvatar(
                radius: 60,
                backgroundColor: const Color(0xFF6A11CB),
                backgroundImage: hasImage
                    ? FileImage(File(_imagePath))
                    : null,
                child: !hasImage
                    ? const Icon(Icons.person,
                    size: 68, color: Colors.white)
                    : null,
              ),
            ),
            GestureDetector(
              onTap: _pickProfileImage,
              child: Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xFF6A11CB),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: Colors.white, width: 2),
                ),
                child: const Icon(Icons.photo_library,
                    size: 16, color: Colors.white),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (!_isEditing) ...[
          Text(
            _nameCtrl.text.isNotEmpty
                ? _nameCtrl.text
                : 'Your Name',
            style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            _idCtrl.text.isNotEmpty
                ? _idCtrl.text
                : 'Student ID',
            style: TextStyle(
                fontSize: 14, color: Colors.grey[600]),
          ),
          const SizedBox(height: 2),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF6A11CB)
                  .withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _classCtrl.text.isNotEmpty
                  ? _classCtrl.text
                  : 'Class',
              style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF6A11CB),
                  fontWeight: FontWeight.w500),
            ),
          ),
        ],
        const SizedBox(height: 6),
        GestureDetector(
          onTap: _pickProfileImage,
          child: Text(
            'Tap photo to change from gallery',
            style: TextStyle(
                fontSize: 11,
                color: Colors.grey[500]),
          ),
        ),
      ],
    );
  }

  // ─── Stats Card ───────────────────────────────────────────
  Widget _buildStatsCard() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment:
          MainAxisAlignment.spaceAround,
          children: [
            _statItem('Activities',
                '$_totalActivities', Icons.list_alt, Colors.blue),
            _divider(),
            _statItem('Hours', '${_totalHours}h',
                Icons.access_time, Colors.green),
            _divider(),
            _statItem(
                'Completion',
                '${(_completionRate * 100).toInt()}%',
                Icons.check_circle,
                Colors.purple),
            _divider(),
            _statItem('Steps', '$_totalSteps',
                Icons.directions_walk, Colors.pink),
          ],
        ),
      ),
    );
  }

  // ─── View Card ────────────────────────────────────────────
  Widget _buildViewCard() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14)),
      child: Column(
        children: [
          _infoTile(Icons.email, 'Email',
              _emailCtrl.text.isNotEmpty
                  ? _emailCtrl.text
                  : '—'),
          const Divider(height: 0),
          _infoTile(Icons.phone, 'Phone',
              _phoneCtrl.text.isNotEmpty
                  ? _phoneCtrl.text
                  : '—'),
          const Divider(height: 0),
          _infoTile(Icons.school, 'Program',
              _programCtrl.text.isNotEmpty
                  ? _programCtrl.text
                  : '—'),
          const Divider(height: 0),
          _infoTile(Icons.flag, 'Monthly Goal',
              '${_goalCtrl.text} hours'),
        ],
      ),
    );
  }

  // ─── Edit Form ────────────────────────────────────────────
  Widget _buildEditForm() {
    return Column(
      children: [
        _field(_nameCtrl, 'Full Name', Icons.person),
        const SizedBox(height: 12),
        _field(_idCtrl, 'Student ID', Icons.badge),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: _classList.contains(_classCtrl.text)
              ? _classCtrl.text
              : _classList.first,
          decoration: InputDecoration(
            labelText: 'Class',
            prefixIcon: const Icon(Icons.class_),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
          items: _classList
              .map((c) => DropdownMenuItem(
              value: c, child: Text(c)))
              .toList(),
          onChanged: (v) {
            if (v != null) _classCtrl.text = v;
          },
        ),
        const SizedBox(height: 12),
        _field(_programCtrl, 'Program', Icons.school),
        const SizedBox(height: 12),
        _field(_emailCtrl, 'Email', Icons.email,
            type: TextInputType.emailAddress),
        const SizedBox(height: 12),
        _field(_phoneCtrl, 'Phone', Icons.phone,
            type: TextInputType.phone),
        const SizedBox(height: 12),
        _field(_goalCtrl, 'Monthly Goal (hours)',
            Icons.flag,
            type: TextInputType.number),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isSaving ? null : _saveProfile,
            icon: _isSaving
                ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2))
                : const Icon(Icons.save),
            label: Text(
                _isSaving ? 'Saving...' : 'Save Profile'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6A11CB),
              foregroundColor: Colors.white,
              padding:
              const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _field(TextEditingController ctrl, String label,
      IconData icon,
      {TextInputType type = TextInputType.text}) {
    return TextFormField(
      controller: ctrl,
      keyboardType: type,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Widget _infoTile(
      IconData icon, String title, String value) {
    return ListTile(
      leading:
      Icon(icon, color: const Color(0xFF6A11CB)),
      title: Text(title,
          style: const TextStyle(
              fontSize: 12, color: Colors.grey)),
      subtitle: Text(value,
          style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500)),
    );
  }

  Widget _statItem(String label, String value,
      IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold)),
        Text(label,
            style: const TextStyle(
                fontSize: 10, color: Colors.grey)),
      ],
    );
  }

  Widget _divider() => Container(
      height: 36,
      width: 1,
      color: Colors.grey.withOpacity(0.3));
}
