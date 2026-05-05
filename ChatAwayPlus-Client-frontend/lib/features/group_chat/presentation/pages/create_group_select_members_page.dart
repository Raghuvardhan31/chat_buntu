import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chataway_plus/core/themes/colors/app_colors.dart';
import 'package:chataway_plus/features/contacts/presentation/providers/contacts_management.dart';
import 'package:chataway_plus/features/contacts/data/models/contact_local.dart';
import 'package:chataway_plus/features/shared/widgets/avatars/cached_circle_avatar.dart';

/// Step 1: Select members to add to the group (WhatsApp style)
class CreateGroupSelectMembersPage extends ConsumerStatefulWidget {
  const CreateGroupSelectMembersPage({super.key});

  @override
  ConsumerState<CreateGroupSelectMembersPage> createState() =>
      _CreateGroupSelectMembersPageState();
}

class _CreateGroupSelectMembersPageState
    extends ConsumerState<CreateGroupSelectMembersPage> {
  final Set<String> _selectedUserIds = {};
  final Map<String, ContactLocal> _selectedContacts = {};
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggleContact(ContactLocal contact) {
    final userId = contact.userDetails?.userId;
    if (userId == null) return;
    setState(() {
      if (_selectedUserIds.contains(userId)) {
        _selectedUserIds.remove(userId);
        _selectedContacts.remove(userId);
      } else {
        _selectedUserIds.add(userId);
        _selectedContacts[userId] = contact;
      }
    });
  }

  void _proceed() {
    if (_selectedUserIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one contact')),
      );
      return;
    }
    Navigator.pushNamed(
      context,
      '/group-create-details',
      arguments: {
        'selectedUserIds': _selectedUserIds.toList(),
        'selectedContacts': _selectedContacts.values.toList(),
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final contacts = ref.watch(contactsListProvider);

    // Filter contacts that have linked users
    final linkedContacts = contacts
        .where((c) => c.userDetails?.userId != null && c.userDetails!.userId.isNotEmpty)
        .toList();

    final filtered = _searchQuery.isEmpty
        ? linkedContacts
        : linkedContacts
            .where((c) =>
                c.preferredDisplayName
                    .toLowerCase()
                    .contains(_searchQuery.toLowerCase()) ||
                c.mobileNo.contains(_searchQuery))
            .toList();

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF111B21) : Colors.white,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1F2C34) : AppColors.primary,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('New Group',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white)),
            Text('${_selectedUserIds.length} of ${linkedContacts.length} selected',
                style: const TextStyle(fontSize: 12, color: Colors.white70)),
          ],
        ),
        actions: [
          if (_selectedUserIds.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.arrow_forward_rounded, color: Colors.white),
              onPressed: _proceed,
              tooltip: 'Next',
            ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Container(
            color: isDark ? const Color(0xFF1F2C34) : const Color(0xFFEDEDED),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: TextField(
              controller: _searchController,
              style: TextStyle(color: isDark ? Colors.white : Colors.black),
              decoration: InputDecoration(
                hintText: 'Search contacts...',
                hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.grey[500]),
                prefixIcon: Icon(Icons.search, color: isDark ? Colors.white38 : Colors.grey),
                filled: true,
                fillColor: isDark ? const Color(0xFF2A3942) : Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),

          // Selected chips strip (WhatsApp style)
          if (_selectedContacts.isNotEmpty)
            SizedBox(
              height: 90,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                itemCount: _selectedContacts.length,
                itemBuilder: (context, index) {
                  final contact = _selectedContacts.values.elementAt(index);
                  final userId = _selectedContacts.keys.elementAt(index);
                  return Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Column(
                      children: [
                        Stack(
                          children: [
                            CachedCircleAvatar(
                              chatPictureUrl: contact.userDetails?.chatPictureUrl,
                              radius: 28,
                              backgroundColor: AppColors.lighterGrey,
                              iconColor: AppColors.colorGrey,
                              contactName: contact.preferredDisplayName,
                            ),
                            Positioned(
                              right: 0,
                              top: 0,
                              child: GestureDetector(
                                onTap: () => _toggleContact(contact),
                                child: Container(
                                  width: 18,
                                  height: 18,
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.close, size: 12, color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        SizedBox(
                          width: 56,
                          child: Text(
                            contact.preferredDisplayName.split(' ').first,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

          if (_selectedContacts.isNotEmpty)
            Divider(height: 1, color: isDark ? Colors.white12 : Colors.grey[300]),

          // Contacts list
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text(
                      'No contacts found',
                      style: TextStyle(color: isDark ? Colors.white38 : Colors.grey),
                    ),
                  )
                : ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final contact = filtered[index];
                      final userId = contact.userDetails?.userId ?? '';
                      final isSelected = _selectedUserIds.contains(userId);
                      return ListTile(
                        leading: CachedCircleAvatar(
                          chatPictureUrl: contact.userDetails?.chatPictureUrl,
                          radius: 24,
                          backgroundColor: AppColors.lighterGrey,
                          iconColor: AppColors.colorGrey,
                          contactName: contact.preferredDisplayName,
                        ),
                        title: Text(
                          contact.preferredDisplayName,
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        subtitle: Text(
                          contact.mobileNo,
                          style: TextStyle(
                            color: isDark ? Colors.white54 : Colors.grey[600],
                            fontSize: 13,
                          ),
                        ),
                        trailing: isSelected
                            ? CircleAvatar(
                                radius: 14,
                                backgroundColor: AppColors.primary,
                                child: const Icon(Icons.check, size: 16, color: Colors.white),
                              )
                            : CircleAvatar(
                                radius: 14,
                                backgroundColor: isDark ? Colors.white12 : Colors.grey[200],
                                child: Icon(Icons.add, size: 16,
                                    color: isDark ? Colors.white38 : Colors.grey),
                              ),
                        onTap: () => _toggleContact(contact),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: _selectedUserIds.isNotEmpty
          ? FloatingActionButton(
              backgroundColor: AppColors.primary,
              onPressed: _proceed,
              child: const Icon(Icons.arrow_forward_rounded, color: Colors.white),
            )
          : null,
    );
  }
}
