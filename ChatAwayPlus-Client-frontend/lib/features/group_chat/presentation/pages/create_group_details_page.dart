import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chataway_plus/core/themes/colors/app_colors.dart';
import 'package:chataway_plus/features/contacts/data/models/contact_local.dart';
import 'package:chataway_plus/features/group_chat/presentation/providers/group_providers.dart';
import 'package:chataway_plus/features/group_chat/models/group_models.dart';
import 'package:chataway_plus/core/routes/route_names.dart';

/// Step 2: Set group name, description, and permissions
class CreateGroupDetailsPage extends ConsumerStatefulWidget {
  final List<String> selectedUserIds;
  final List<ContactLocal> selectedContacts;

  const CreateGroupDetailsPage({
    super.key,
    required this.selectedUserIds,
    required this.selectedContacts,
  });

  @override
  ConsumerState<CreateGroupDetailsPage> createState() =>
      _CreateGroupDetailsPageState();
}

class _CreateGroupDetailsPageState extends ConsumerState<CreateGroupDetailsPage> {
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isRestricted = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _createGroup() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final notifier = ref.read(createGroupProvider.notifier);
      final group = await notifier.createGroup(
        name: _nameController.text.trim(),
        memberIds: widget.selectedUserIds,
        description: _descController.text.trim().isEmpty
            ? null
            : _descController.text.trim(),
        isRestricted: _isRestricted,
      );

      if (!mounted) return;
      // Navigate to the new group chat, removing the create flow from stack
      Navigator.of(context).pushNamedAndRemoveUntil(
        RouteNames.groupChat,
        (route) => route.settings.name == RouteNames.mainNavigation,
        arguments: {
          'groupId': group.id,
          'groupName': group.name,
          'groupIcon': group.icon,
        },
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to create group: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF111B21) : Colors.white,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1F2C34) : AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text('New Group',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white)),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Group icon placeholder
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 48,
                      backgroundColor: AppColors.primary.withOpacity(0.2),
                      child: Icon(Icons.groups_rounded,
                          size: 52, color: AppColors.primary),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Group name
              Text('Group Name *',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                    fontSize: 14,
                  )),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameController,
                style: TextStyle(color: isDark ? Colors.white : Colors.black),
                maxLength: 64,
                decoration: _inputDecoration('Enter group name', isDark),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Group name is required';
                  if (v.trim().length < 2) return 'Name must be at least 2 characters';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Description
              Text('Description (optional)',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                    fontSize: 14,
                  )),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descController,
                style: TextStyle(color: isDark ? Colors.white : Colors.black),
                maxLines: 3,
                maxLength: 256,
                decoration: _inputDecoration('Group description...', isDark),
              ),
              const SizedBox(height: 20),

              // Permissions section
              Text('Permissions',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                    fontSize: 14,
                  )),
              const SizedBox(height: 8),
              _buildPermissionTile(
                isDark: isDark,
                title: 'Restrict messaging',
                subtitle: 'Only admins can send messages',
                value: _isRestricted,
                onChanged: (v) => setState(() => _isRestricted = v),
              ),
              const SizedBox(height: 24),

              // Members preview
              Text('Members (${widget.selectedContacts.length + 1})',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                    fontSize: 14,
                  )),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  _memberChip('You (Admin)', isDark, isAdmin: true),
                  ...widget.selectedContacts.map(
                    (c) => _memberChip(c.preferredDisplayName, isDark),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Create button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _createGroup,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text(
                          'Create Group',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPermissionTile({
    required bool isDark,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F2C34) : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: SwitchListTile(
        title: Text(title, style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
        subtitle:
            Text(subtitle, style: TextStyle(color: isDark ? Colors.white54 : Colors.grey[600])),
        value: value,
        activeColor: AppColors.primary,
        onChanged: onChanged,
      ),
    );
  }

  Widget _memberChip(String name, bool isDark, {bool isAdmin = false}) {
    return Chip(
      avatar: isAdmin
          ? Icon(Icons.star_rounded, size: 16, color: Colors.amber[700])
          : null,
      label: Text(
        name,
        style: TextStyle(
          fontSize: 12,
          color: isDark ? Colors.white : Colors.black87,
        ),
      ),
      backgroundColor: isDark ? const Color(0xFF2A3942) : Colors.grey[200],
      padding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }

  InputDecoration _inputDecoration(String hint, bool isDark) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.grey[500]),
      filled: true,
      fillColor: isDark ? const Color(0xFF1F2C34) : Colors.grey[100],
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.primary, width: 2),
      ),
      counterStyle: TextStyle(color: isDark ? Colors.white38 : Colors.grey),
    );
  }
}
