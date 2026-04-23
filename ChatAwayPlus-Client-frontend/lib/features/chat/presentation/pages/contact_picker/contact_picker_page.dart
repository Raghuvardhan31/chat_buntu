import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chataway_plus/core/responsive_layout/responsive_layout_builder.dart';
import 'package:chataway_plus/core/themes/app_text_styles.dart';
import 'package:chataway_plus/core/themes/colors/app_colors.dart';
import 'package:chataway_plus/features/contacts/data/models/contact_local.dart';
import 'package:chataway_plus/features/contacts/presentation/providers/contacts_management.dart';
import 'package:chataway_plus/features/shared/widgets/avatars/cached_circle_avatar.dart';

/// Contact picker page for sharing contacts in chat
class ContactPickerPage extends ConsumerStatefulWidget {
  const ContactPickerPage({super.key});

  @override
  ConsumerState<ContactPickerPage> createState() => _ContactPickerPageState();
}

class _ContactPickerPageState extends ConsumerState<ContactPickerPage> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _searchQuery = '';
  bool _isSearching = false;

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  List<ContactLocal> _filterContacts(List<ContactLocal> contacts) {
    if (_searchQuery.isEmpty) return contacts;

    return contacts.where((contact) {
      final name = contact.preferredDisplayName.toLowerCase();
      final phone = contact.mobileNo.toLowerCase();
      final query = _searchQuery.toLowerCase();
      return name.contains(query) || phone.contains(query);
    }).toList();
  }

  void _onContactSelected(ContactLocal contact) {
    // Return the selected contact data with backend-compatible field names
    final contactData = {
      'contact_name': contact.preferredDisplayName,
      'contact_mobile_number': contact.mobileNo,
      'name': contact.preferredDisplayName, // Keep for UI display
      'phone': contact.mobileNo, // Keep for UI display
      'contactName': contact.name, // Keep for backward compatibility
      'mobile': contact.mobileNo, // Keep for backward compatibility
    };

    Navigator.of(context).pop(contactData);
  }

  Widget _buildSearchField(bool isDark) {
    return TextField(
      controller: _searchController,
      autofocus: false,
      focusNode: _searchFocusNode,
      onChanged: (value) => setState(() => _searchQuery = value),
      cursorColor: isDark ? Colors.white : AppColors.colorBlack,
      style: AppTextSizes.regular(
        context,
      ).copyWith(color: isDark ? Colors.white : AppColors.iconPrimary),
      decoration: InputDecoration(
        hintText: 'Search contacts',
        hintStyle: AppTextSizes.regular(
          context,
        ).copyWith(color: isDark ? Colors.white54 : AppColors.colorGrey),
        filled: false,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        contentPadding: EdgeInsets.zero,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveLayoutBuilder(
      builder: (context, constraints, breakpoint) {
        final responsive = ResponsiveSize(
          context: context,
          constraints: constraints,
          breakpoint: breakpoint,
        );
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return Scaffold(
          appBar: AppBar(
            backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
            elevation: 0,
            scrolledUnderElevation: 0.0,
            toolbarHeight: responsive.size(68),
            centerTitle: false,
            titleSpacing: 0,
            leadingWidth: responsive.size(50),
            leading: IconButton(
              icon: Icon(
                Icons.arrow_back,
                color: AppColors.primary,
                size: responsive.size(24),
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: _isSearching
                ? _buildSearchField(isDark)
                : Text(
                    'Contacts Share Hub',
                    style: AppTextSizes.large(context).copyWith(
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : AppColors.iconPrimary,
                    ),
                  ),
            actions: [
              IconButton(
                icon: Icon(
                  _isSearching ? Icons.close : Icons.search,
                  color: isDark ? Colors.white : AppColors.iconPrimary,
                  size: responsive.size(24),
                ),
                onPressed: () {
                  setState(() {
                    if (_isSearching) {
                      if (_searchController.text.isNotEmpty) {
                        _searchController.clear();
                        _searchQuery = '';
                      } else {
                        _isSearching = false;
                      }
                    } else {
                      _isSearching = true;
                    }
                  });

                  // Focus when opening search
                  if (_isSearching) {
                    Future.delayed(const Duration(milliseconds: 120), () async {
                      if (!mounted) return;
                      FocusScope.of(context).requestFocus(_searchFocusNode);
                    });
                  } else {
                    _searchFocusNode.unfocus();
                  }
                },
              ),
            ],
          ),
          body: Consumer(
            builder: (context, ref, child) {
              final contactsState = ref.watch(
                contactsManagementNotifierProvider,
              );

              return contactsState.when(
                data: (state) {
                  final allContacts = state.allContacts;
                  final filteredContacts = _filterContacts(allContacts);

                  if (filteredContacts.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.contact_phone_outlined,
                            size: responsive.size(64),
                            color: isDark
                                ? Colors.white38
                                : Colors.grey.shade400,
                          ),
                          SizedBox(height: responsive.spacing(16)),
                          Text(
                            _searchQuery.isNotEmpty
                                ? 'No contacts found'
                                : 'No contacts available',
                            style: AppTextSizes.regular(context).copyWith(
                              color: isDark
                                  ? Colors.white60
                                  : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: EdgeInsets.symmetric(
                      vertical: responsive.spacing(8),
                    ),
                    itemCount: filteredContacts.length,
                    itemBuilder: (context, index) {
                      final contact = filteredContacts[index];
                      return _ContactTile(
                        contact: contact,
                        onTap: () => _onContactSelected(contact),
                        responsive: responsive,
                        isDark: isDark,
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: responsive.size(64),
                        color: Colors.red,
                      ),
                      SizedBox(height: responsive.spacing(16)),
                      Text(
                        'Failed to load contacts',
                        style: AppTextSizes.regular(
                          context,
                        ).copyWith(color: Colors.red),
                      ),
                      SizedBox(height: responsive.spacing(8)),
                      ElevatedButton(
                        onPressed: () {
                          ref
                              .read(contactsManagementNotifierProvider.notifier)
                              .loadFromCache();
                        },
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _ContactTile extends StatelessWidget {
  const _ContactTile({
    required this.contact,
    required this.onTap,
    required this.responsive,
    required this.isDark,
  });

  final ContactLocal contact;
  final VoidCallback onTap;
  final ResponsiveSize responsive;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: responsive.spacing(16),
          vertical: responsive.spacing(12),
        ),
        child: Row(
          children: [
            CachedCircleAvatar(
              chatPictureUrl: contact.userDetails?.chatPictureUrl,
              chatPictureVersion: contact.userDetails?.chatPictureVersion,
              radius: responsive.size(24),
              backgroundColor: AppColors.lighterGrey,
              iconColor: AppColors.colorGrey,
              contactName: contact.preferredDisplayName,
            ),
            SizedBox(width: responsive.spacing(12)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    contact.preferredDisplayName,
                    style: AppTextSizes.regular(context).copyWith(
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (contact.mobileNo.isNotEmpty) ...[
                    SizedBox(height: responsive.spacing(4)),
                    Text(
                      contact.mobileNo,
                      style: AppTextSizes.small(context).copyWith(
                        color: isDark ? Colors.white60 : Colors.grey.shade600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              Icons.share,
              size: responsive.size(20),
              color: AppColors.primary,
            ),
          ],
        ),
      ),
    );
  }
}
