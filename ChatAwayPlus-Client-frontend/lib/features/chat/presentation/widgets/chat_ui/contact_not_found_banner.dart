// lib/features/chat/presentation/pages/individual_chat/widgets/contact_not_found_banner.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chataway_plus/core/responsive_layout/responsive_layout_builder.dart';
import 'package:chataway_plus/core/routes/navigation_service.dart';
import 'package:chataway_plus/features/contacts/presentation/providers/contacts_management.dart';

/// Banner shown when the chat receiver is not in user's contacts list
/// Prompts user to refresh contacts from Contacts Hub
class ContactNotFoundBanner extends ConsumerWidget {
  const ContactNotFoundBanner({
    super.key,
    required this.receiverId,
    this.onRefreshTap,
  });

  final String receiverId;

  /// Optional callback when refresh is tapped. Defaults to NavigationService.goToContactsHub()
  final VoidCallback? onRefreshTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allContacts = ref.watch(contactsListProvider);
    final isReceiverInContacts = allContacts.any((contact) {
      return contact.userDetails?.userId == receiverId;
    });
    if (isReceiverInContacts) return const SizedBox.shrink();

    return ResponsiveLayoutBuilder(
      builder: (context, constraints, breakpoint) {
        final responsive = ResponsiveSize(
          context: context,
          constraints: constraints,
          breakpoint: breakpoint,
        );

        return Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            horizontal: responsive.spacing(16),
            vertical: responsive.spacing(12),
          ),
          decoration: BoxDecoration(
            color: Colors.amber.shade50,
            border: Border(
              bottom: BorderSide(
                color: Colors.amber.shade200,
                width: responsive.size(1),
              ),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.info_outline,
                color: Colors.amber.shade700,
                size: responsive.size(20),
              ),
              SizedBox(width: responsive.spacing(12)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'This user is not in your contacts',
                      style: TextStyle(
                        fontSize: responsive.size(13),
                        fontWeight: FontWeight.w600,
                        color: Colors.amber.shade900,
                      ),
                    ),
                    SizedBox(height: responsive.spacing(2)),
                    Text(
                      'Go to Contacts Hub → Tap three dots (⋮) → Press Refresh to see full user information',
                      style: TextStyle(
                        fontSize: responsive.size(12),
                        color: Colors.amber.shade800,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: responsive.spacing(8)),
              TextButton(
                onPressed:
                    onRefreshTap ?? () => NavigationService.goToContactsHub(),
                style: TextButton.styleFrom(
                  backgroundColor: Colors.amber.shade600,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(
                    horizontal: responsive.spacing(12),
                    vertical: responsive.spacing(6),
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'Refresh',
                  style: TextStyle(
                    fontSize: responsive.size(12),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
