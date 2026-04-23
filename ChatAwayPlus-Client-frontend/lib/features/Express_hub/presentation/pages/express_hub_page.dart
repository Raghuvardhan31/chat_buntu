import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chataway_plus/core/themes/app_text_styles.dart';
import 'package:chataway_plus/features/chat/data/services/chat_engine/index.dart';
import 'package:chataway_plus/core/themes/colors/app_colors.dart';
import 'package:chataway_plus/core/routes/navigation_service.dart';
import 'package:chataway_plus/features/contacts/data/models/contact_local.dart';
import 'package:chataway_plus/features/contacts/presentation/providers/contacts_management.dart';
import 'package:chataway_plus/features/shared/widgets/avatars/cached_circle_avatar.dart';
import 'package:chataway_plus/core/responsive_layout/responsive_layout_builder.dart';
import 'package:chataway_plus/core/storage/token_storage.dart';
import 'package:chataway_plus/core/sync/authenticated_image_cache_manager.dart';
import 'package:chataway_plus/core/constants/api_url/api_urls.dart';
import 'package:chataway_plus/core/connectivity/connectivity_service.dart';
import 'package:chataway_plus/core/snackbar/app_snackbar.dart';
import 'package:chataway_plus/features/chat/presentation/providers/chat_list_providers/chat_list_provider.dart';
import 'package:chataway_plus/core/constants/assets/image_assets.dart';
import '../../data/models/emoji_update_model.dart';
import 'package:chataway_plus/features/chat/data/services/business/status_likes_service.dart';
import 'package:chataway_plus/features/chat/presentation/pages/media_viewer/app_user_chat_picture_view.dart';

/// Helper class to pair emoji update with contact
class _EmojiWithContact {
  final EmojiUpdateModel emoji;
  final ContactLocal contact;

  _EmojiWithContact({required this.emoji, required this.contact});
}

class VoiceHubPage extends ConsumerStatefulWidget {
  const VoiceHubPage({super.key});

  @override
  ConsumerState<VoiceHubPage> createState() => _VoiceHubPageState();
}

class _VoiceHubPageState extends ConsumerState<VoiceHubPage>
    with SingleTickerProviderStateMixin {
  // Responsive
  ResponsiveSize _responsiveFor(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return ResponsiveSize(
      context: context,
      constraints: BoxConstraints(maxWidth: width),
      breakpoint: DeviceBreakpoint.fromWidth(width),
    );
  }

  // UI State
  late TabController _tabController;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = true;
  bool _isManualRefresh = false;
  String _errorMessage = '';
  DateTime? _lastAvatarPrefetch;
  bool _avatarPrefetchInProgress = false;

  // Emoji caption / selection state
  String? _showingCaptionForEmojiId; // Which emoji's caption is visible
  String?
  _selectedEmojiForActionsId; // Which emoji is selected for bottom actions

  // Voice Text Sharings selection state
  String?
  _selectedVoiceContactHash; // Which voice-sharing contact is highlighted

  // Data
  final List<ContactLocal> _voiceSharingUsers = [];
  List<ContactLocal> _filteredVoiceSharingUsers = [];
  final Map<String, ContactLocal> _contactsMap = {}; // userId -> contact
  final List<_EmojiWithContact> _emojiWithContacts = [];
  List<_EmojiWithContact> _filteredEmojiWithContacts = [];
  StreamSubscription? _profileUpdateSub; // WhatsApp-style profile updates

  String _voiceSharingText(ContactLocal contact) {
    return (contact.userDetails?.recentStatus?.content ?? '').trim();
  }

  String _emojiUpdatesEmoji(ContactLocal contact) {
    final data = contact.userDetails?.recentEmojiUpdate;
    if (data == null) return '';
    return (data['emojis_update'] ??
            data['emoji_updates'] ??
            data['emojis_updates'] ??
            data['emoji'] ??
            data['emojisUpdate'] ??
            data['emoji_update'] ??
            '')
        .toString()
        .trim();
  }

  String? _emojiUpdatesCaption(ContactLocal contact) {
    final data = contact.userDetails?.recentEmojiUpdate;
    if (data == null) return null;
    final c =
        (data['emojis_caption'] ??
                data['emoji_captions'] ??
                data['emojis_captions'] ??
                data['emoji_caption'] ??
                data['caption'] ??
                data['emojisCaption'] ??
                '')
            .toString();
    return c.trim().isEmpty ? null : c;
  }

  DateTime? _emojiUpdatesCreatedAt(ContactLocal contact) {
    final data = contact.userDetails?.recentEmojiUpdate;
    if (data == null) return null;
    final raw = data['createdAt'] ?? data['created_at'] ?? data['timestamp'];
    if (raw == null) return null;
    if (raw is String && raw.trim().isNotEmpty) {
      return DateTime.tryParse(raw.trim());
    }
    if (raw is int) {
      try {
        return DateTime.fromMillisecondsSinceEpoch(raw);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!mounted) return;
      setState(() {});
    });
    _loadContactsThenAutoRefreshIfEmpty();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _prefetchAvatarsIfOnline();
    });

    // WHATSAPP-STYLE: Listen for profile updates from contacts
    _profileUpdateSub = ChatEngineService.instance.profileUpdateStream.listen((
      update,
    ) async {
      if (kDebugMode) {
        debugPrint(' [ExpressHub] Profile update from: ${update.userId}');
      }
      // Refresh from DB and reload UI
      if (mounted) {
        // Wait for notifier to reload from database
        await ref
            .read(contactsManagementNotifierProvider.notifier)
            .loadFromCache();
        // Then refresh UI silently (no loading indicator)
        if (mounted) {
          _loadContacts(silent: true);
        }
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _profileUpdateSub?.cancel();
    super.dispose();
  }

  /// Filter out current user's own contact from the list
  Future<List<ContactLocal>> _excludeCurrentUser(
    List<ContactLocal> contacts,
  ) async {
    try {
      final currentUserPhone = await TokenSecureStorage.instance
          .getPhoneNumber();
      final currentUserId = await TokenSecureStorage.instance
          .getCurrentUserIdUUID();
      if (currentUserPhone == null || currentUserPhone.isEmpty) {
        return contacts;
      }

      // Normalize phone number: remove all non-digits and get last 10 digits
      String normalizePhone(String phone) {
        final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
        return digits.length > 10
            ? digits.substring(digits.length - 10)
            : digits;
      }

      final normalizedCurrentPhone = normalizePhone(currentUserPhone);

      // Remove contacts matching current user's phone number
      return contacts.where((contact) {
        if (currentUserId != null && currentUserId.isNotEmpty) {
          if ((contact.appUserId != null &&
                  contact.appUserId == currentUserId) ||
              (contact.userDetails?.userId != null &&
                  contact.userDetails!.userId == currentUserId)) {
            return false;
          }
        }
        final normalizedContactPhone = normalizePhone(contact.mobileNo);

        // Exclude if normalized phone numbers match (last 10 digits)
        if (normalizedContactPhone.isNotEmpty &&
            normalizedCurrentPhone.isNotEmpty &&
            normalizedContactPhone == normalizedCurrentPhone) {
          return false;
        }

        return true;
      }).toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint(' Express Hub: Error filtering current user: $e');
      }
      return contacts; // Return unfiltered on error
    }
  }

  /// Load from cache first; if voice sharing users are empty, auto-refresh
  /// from API so data appears without requiring manual refresh.
  Future<void> _loadContactsThenAutoRefreshIfEmpty() async {
    await _loadContacts();
    // If cache was empty, silently fetch from API in background
    if (_voiceSharingUsers.isEmpty && _emojiWithContacts.isEmpty) {
      try {
        await ref
            .read(contactsManagementNotifierProvider.notifier)
            .refreshAppUsersStatusFromApi();
        if (mounted) {
          await _loadContacts(silent: true);
          _prefetchAvatarsIfOnline();
        }
      } catch (_) {}
    }
  }

  Future<void> _loadContacts({bool silent = false}) async {
    if (!mounted) return;
    if (!silent) {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });
    }

    try {
      // Ensure contacts are loaded from cache first (for offline support)
      await ref
          .read(contactsManagementNotifierProvider.notifier)
          .loadFromCache();

      // Load Voice Sharing from contacts table
      final List<ContactLocal> allAppUsers = ref.read(appUserContactsProvider);

      // Exclude current user from the list
      final List<ContactLocal> filteredAppUsers = await _excludeCurrentUser(
        allAppUsers,
      );

      final voiceUsers = filteredAppUsers;

      // Create contacts map for quick lookup by userId (use filtered list)
      _contactsMap.clear();
      for (final contact in filteredAppUsers) {
        if (contact.userDetails?.userId != null) {
          _contactsMap[contact.userDetails!.userId] = contact;
        }
      }

      // Emoji Updates from contacts table (recentEmojiUpdate stored in user_details)
      final List<_EmojiWithContact> emojiWithContacts = [];
      for (final contact in filteredAppUsers) {
        final userId = contact.userDetails?.userId;
        if (userId == null || userId.isEmpty) continue;
        final emoji = _emojiUpdatesEmoji(contact);
        if (emoji.isEmpty) continue;

        emojiWithContacts.add(
          _EmojiWithContact(
            emoji: EmojiUpdateModel(
              id: userId,
              userId: userId,
              emoji: emoji,
              caption: _emojiUpdatesCaption(contact),
              createdAt: _emojiUpdatesCreatedAt(contact),
              updatedAt: null,
              userFirstName: null,
              userLastName: null,
              userProfilePic: null,
            ),
            contact: contact,
          ),
        );
      }

      if (!mounted) return;

      setState(() {
        _voiceSharingUsers.clear();
        _voiceSharingUsers.addAll(voiceUsers);
        _filteredVoiceSharingUsers = List<ContactLocal>.from(voiceUsers);
        _emojiWithContacts.clear();
        _emojiWithContacts.addAll(emojiWithContacts);
        _filteredEmojiWithContacts = List<_EmojiWithContact>.from(
          _emojiWithContacts,
        );
        _isLoading = false;
        _isManualRefresh = false;
      });
      // Background prefetch of avatars
      Future.microtask(_prefetchAvatarsIfOnline);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isManualRefresh = false;
        _errorMessage = e.toString();
      });
    }
  }

  void _filterContacts(String query) {
    if (query.isEmpty) {
      setState(() {
        _filteredVoiceSharingUsers = List<ContactLocal>.from(
          _voiceSharingUsers,
        );
        _filteredEmojiWithContacts = List<_EmojiWithContact>.from(
          _emojiWithContacts,
        );
      });
      return;
    }
    final lower = query.toLowerCase();
    setState(() {
      _filteredVoiceSharingUsers = _voiceSharingUsers
          .where(
            (u) =>
                u.preferredDisplayName.toLowerCase().contains(lower) ||
                u.mobileNo.contains(query),
          )
          .toList();
      _filteredEmojiWithContacts = _emojiWithContacts
          .where(
            (e) => e.contact.preferredDisplayName.toLowerCase().contains(lower),
          )
          .toList();
    });
  }

  // ============================================
  // BUILD METHODS
  // ============================================

  @override
  Widget build(BuildContext context) {
    // Force responsive to be computed early for consistency
    _responsiveFor(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;

        if (_isSearching) {
          if (_searchController.text.isNotEmpty) {
            setState(() {
              _searchController.clear();
              _filterContacts('');
            });
          } else {
            setState(() {
              _isSearching = false;
            });
            FocusScope.of(context).unfocus();
          }
          return;
        }

        NavigationService.goToChatList();
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: _buildAppBar(),
        body: _isLoading ? _buildLoadingState() : _buildTabContent(),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final responsive = _responsiveFor(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AppBar(
      backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
      elevation: 0,
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
        onPressed: () => NavigationService.goToChatList(),
      ),
      title: _isSearching ? _buildSearchField() : _buildTitle(),
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
                  _filterContacts('');
                } else {
                  _isSearching = false;
                }
              } else {
                _isSearching = true;
              }
            });
          },
        ),
        PopupMenuButton<String>(
          icon: Icon(
            Icons.more_vert,
            color: isDark ? Colors.white : AppColors.iconPrimary,
            size: responsive.size(24),
          ),
          offset: Offset(0, responsive.size(100)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(responsive.size(8)),
          ),
          elevation: 8.0,
          padding: EdgeInsets.zero,
          color: Theme.of(context).colorScheme.surface,
          onSelected: (String value) {
            switch (value) {
              case 'profile':
                NavigationService.goToCurrentUserProfile();
                break;
              case 'block_contacts':
                NavigationService.goToBlockContacts();
                break;
            }
          },
          itemBuilder: (BuildContext context) => [
            PopupMenuItem<String>(
              value: 'profile',
              height: responsive.size(48),
              padding: EdgeInsets.symmetric(
                horizontal: responsive.spacing(24),
                vertical: responsive.spacing(12),
              ),
              child: Text(
                'Profile',
                style: AppTextSizes.regular(
                  context,
                ).copyWith(color: Theme.of(context).colorScheme.onSurface),
              ),
            ),
            PopupMenuItem<String>(
              value: 'block_contacts',
              height: responsive.size(48),
              padding: EdgeInsets.symmetric(
                horizontal: responsive.spacing(24),
                vertical: responsive.spacing(12),
              ),
              child: Text(
                'Block contacts',
                style: AppTextSizes.regular(
                  context,
                ).copyWith(color: Theme.of(context).colorScheme.onSurface),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTitle() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Text(
      'Express Hub',
      style: AppTextSizes.large(context).copyWith(
        fontWeight: FontWeight.bold,
        color: isDark ? Colors.white : AppColors.iconPrimary,
      ),
    );
  }

  Widget _buildSearchField() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextField(
      controller: _searchController,
      autofocus: true,
      onChanged: _filterContacts,
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

  Widget _buildTabContent() {
    final responsive = _responsiveFor(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        Container(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: TabBar(
            controller: _tabController,
            indicatorColor: AppColors.primary,
            labelColor: isDark ? Colors.white : AppColors.primary,
            unselectedLabelColor: isDark ? Colors.white54 : AppColors.colorGrey,
            tabs: [
              Tab(
                icon: Icon(Icons.mic, size: responsive.size(20)),
                text: 'Voice Text Sharings',
              ),
              Tab(
                icon: Icon(
                  Icons.add_reaction_rounded,
                  size: responsive.size(20),
                ),
                text: 'Emoji Updates',
              ),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [_buildVoiceSharingTab(), _buildEmojiUpdatesTab()],
          ),
        ),
      ],
    );
  }

  Widget _buildVoiceSharingTab() {
    if (_errorMessage.isNotEmpty) return _buildErrorState();
    if (_filteredVoiceSharingUsers.isEmpty) {
      return _buildEmptyState(
        icon: Icons.mic,
        title: 'No contacts found',
        subtitle: 'ChatAway+ users will appear here',
      );
    }
    return _buildContactList(_filteredVoiceSharingUsers);
  }

  Widget _buildEmojiUpdatesTab() {
    if (_errorMessage.isNotEmpty) return _buildErrorState();

    if (_filteredEmojiWithContacts.isEmpty) {
      // Check if we're in search mode
      final isSearching = _searchController.text.isNotEmpty;

      if (isSearching) {
        // Show "No results found" when searching
        return _buildEmptyState(
          icon: Icons.search_off,
          title: 'No contacts found',
          subtitle: 'No contacts match your search',
        );
      } else {
        // Show empty state with button when there's genuinely no emoji data
        return _buildEmojiEmptyStateWithButton();
      }
    }

    return _buildEmojiUpdatesList(_filteredEmojiWithContacts);
  }

  Widget _buildEmojiEmptyStateWithButton() {
    final responsive = _responsiveFor(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: responsive.spacing(32)),
        child: Text(
          'From your contacts no one updated emojis yet',
          textAlign: TextAlign.center,
          style: AppTextSizes.regular(context).copyWith(
            color: isDark ? Colors.white54 : AppColors.colorGrey,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildContactList(List<ContactLocal> users) {
    final responsive = _responsiveFor(context);
    return ListView.builder(
      padding: EdgeInsets.only(
        top: responsive.spacing(4),
        bottom: responsive.spacing(110),
      ),
      itemCount: users.length,
      itemBuilder: (context, index) => _buildContactTile(users[index]),
    );
  }

  Widget _buildEmojiUpdatesList(List<_EmojiWithContact> emojiWithContacts) {
    final responsive = _responsiveFor(context);
    return ListView.builder(
      padding: EdgeInsets.only(
        top: responsive.spacing(4),
        bottom: responsive.spacing(110),
      ),
      itemCount: emojiWithContacts.length,
      itemBuilder: (context, index) =>
          _buildEmojiUpdateTile(emojiWithContacts[index]),
    );
  }

  Widget _buildContactTile(ContactLocal contact) {
    final responsive = _responsiveFor(context);
    final bool isSelected = _selectedVoiceContactHash == contact.contactHash;

    return InkWell(
      onTap: () {
        setState(() {
          // Toggle selection: single tap shows icon, second tap hides it.
          if (isSelected) {
            _selectedVoiceContactHash = null;
          } else {
            _selectedVoiceContactHash = contact.contactHash;
          }
        });
      },
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: responsive.spacing(16),
          vertical: responsive.spacing(11),
        ),
        child: Row(
          children: [
            _buildContactAvatar(contact),
            SizedBox(width: responsive.spacing(12)),
            Expanded(child: _buildContactContent(contact)),
            if (isSelected) ...[
              // ── Reply icon (opens chat with quoted SYVT) ──
              if (_voiceSharingText(contact).isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(left: responsive.spacing(8)),
                  child: GestureDetector(
                    onTap: () {
                      _openChatWithContactReply(
                        contact,
                        replyText: _voiceSharingText(contact),
                        replyType: 'voice',
                      );
                    },
                    child: Image.asset(
                      ImageAssets.replyMessageIcon,
                      width: responsive.size(24),
                      height: responsive.size(24),
                    ),
                  ),
                ),
              // ── Chat icon (plain chat) ──
              Padding(
                padding: EdgeInsets.only(left: responsive.spacing(6)),
                child: GestureDetector(
                  onTap: () {
                    _openChatWithContact(contact);
                  },
                  child: Image.asset(
                    ImageAssets.goingInsideChatIcon,
                    width: responsive.size(24),
                    height: responsive.size(24),
                    color: const Color(0xFF66BB6A),
                  ),
                ),
              ),
              // ── Love / Like icon (server-backed, same as Connection Insight Hub) ──
              Padding(
                padding: EdgeInsets.only(left: responsive.spacing(6)),
                child: _VoiceLikeButton(
                  key: ValueKey(
                    'voice_like_${contact.userDetails?.userId ?? contact.appUserId ?? contact.contactHash}',
                  ),
                  statusOwnerId:
                      contact.userDetails?.userId ?? contact.appUserId ?? '',
                  statusId: contact.userDetails?.recentStatus?.statusId,
                  voiceText: _voiceSharingText(contact),
                  responsive: responsive,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildContactContent(ContactLocal contact) {
    final responsive = _responsiveFor(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final status = _voiceSharingText(contact);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          contact.preferredDisplayName,
          style: AppTextSizes.regular(
            context,
          ).copyWith(color: isDark ? Colors.white : AppColors.colorBlack),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        SizedBox(height: responsive.spacing(4)),
        Text(
          status.isNotEmpty ? status : 'Share your voice',
          style: AppTextSizes.small(
            context,
          ).copyWith(color: isDark ? Colors.white70 : AppColors.colorGrey),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildContactAvatar(ContactLocal contact) {
    final responsive = _responsiveFor(context);
    final avatarSize = responsive.size(48);
    return GestureDetector(
      onTap: () {
        Navigator.of(context, rootNavigator: true).push(
          MaterialPageRoute(
            builder: (_) => AppUserChatPictureView(
              displayName: contact.preferredDisplayName,
              chatPictureUrl: contact.userDetails?.chatPictureUrl,
              chatPictureVersion: contact.userDetails?.chatPictureVersion,
              showLikeButton: false,
            ),
          ),
        );
      },
      child: CachedCircleAvatar(
        chatPictureUrl: contact.userDetails?.chatPictureUrl,
        chatPictureVersion: contact.userDetails?.chatPictureVersion,
        radius: avatarSize / 2,
        backgroundColor: AppColors.lighterGrey,
        iconColor: AppColors.iconPrimary,
        contactName: contact.name,
      ),
    );
  }

  Widget _buildEmojiUpdateTile(_EmojiWithContact emojiWithContact) {
    final responsive = _responsiveFor(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSelected = _selectedEmojiForActionsId == emojiWithContact.emoji.id;
    final isShowingCaption =
        _showingCaptionForEmojiId == emojiWithContact.emoji.id;

    return Column(
      children: [
        InkWell(
          onTap: () {
            setState(() {
              if (isSelected) {
                _hideCaption();
              } else {
                _selectedEmojiForActionsId = emojiWithContact.emoji.id;
                _showingCaptionForEmojiId = null;
              }
            });
          },
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: responsive.spacing(16),
              vertical: responsive.spacing(11),
            ),
            child: Row(
              children: [
                _buildEmojiAvatar(emojiWithContact.contact),
                SizedBox(width: responsive.spacing(12)),
                Expanded(
                  child: _buildEmojiUpdateContent(
                    emojiWithContact,
                    showCaption: isShowingCaption,
                  ),
                ),
                // ── Inline action icons when selected ──
                if (isSelected) ...[
                  // Reply icon (no color tint — same as Voice Text Sharings)
                  Padding(
                    padding: EdgeInsets.only(left: responsive.spacing(8)),
                    child: GestureDetector(
                      onTap: () {
                        _hideCaption();
                        final emojiText = emojiWithContact.emoji.emoji.trim();
                        final caption =
                            emojiWithContact.emoji.caption?.trim() ?? '';
                        final replyContent = caption.isNotEmpty
                            ? '$emojiText — $caption'
                            : emojiText;
                        _openChatWithContactReply(
                          emojiWithContact.contact,
                          replyText: replyContent,
                          replyType: 'emoji',
                        );
                      },
                      child: Image.asset(
                        ImageAssets.replyMessageIcon,
                        width: responsive.size(24),
                        height: responsive.size(24),
                      ),
                    ),
                  ),
                  // Going inside chat icon
                  Padding(
                    padding: EdgeInsets.only(left: responsive.spacing(8)),
                    child: GestureDetector(
                      onTap: () {
                        _hideCaption();
                        _openChatWithContact(emojiWithContact.contact);
                      },
                      child: Image.asset(
                        ImageAssets.goingInsideChatIcon,
                        width: responsive.size(24),
                        height: responsive.size(24),
                        color: const Color(0xFF66BB6A),
                      ),
                    ),
                  ),
                  // Read more text icon (only if caption exists)
                  if (emojiWithContact.emoji.hasCaption)
                    Padding(
                      padding: EdgeInsets.only(left: responsive.spacing(8)),
                      child: GestureDetector(
                        onTap: () {
                          _toggleCaptionDisplay(emojiWithContact.emoji.id);
                        },
                        child: Image.asset(
                          ImageAssets.readMoreTextIcon,
                          width: responsive.size(24),
                          height: responsive.size(24),
                          color: const Color(0xFFFFA726),
                        ),
                      ),
                    ),
                  // Close icon (always visible)
                  Padding(
                    padding: EdgeInsets.only(left: responsive.spacing(8)),
                    child: GestureDetector(
                      onTap: _hideCaption,
                      child: Icon(
                        Icons.close_rounded,
                        size: responsive.size(24),
                        color: isDark ? Colors.white : AppColors.iconSecondary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmojiUpdateContent(
    _EmojiWithContact emojiWithContact, {
    bool showCaption = false,
  }) {
    final responsive = _responsiveFor(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final emoji = emojiWithContact.emoji.emoji.trim();
    final caption = emojiWithContact.emoji.caption?.trim() ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          emojiWithContact.contact.preferredDisplayName,
          style: AppTextSizes.regular(
            context,
          ).copyWith(color: isDark ? Colors.white : AppColors.colorBlack),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        SizedBox(height: responsive.spacing(4)),
        Text(
          emoji,
          style: TextStyle(
            fontSize: responsive.size(16),
            color: isDark ? Colors.white : AppColors.colorBlack,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (showCaption && caption.isNotEmpty) ...[
          SizedBox(height: responsive.spacing(4)),
          Text(
            caption,
            style: AppTextSizes.small(context).copyWith(
              color: isDark ? Colors.white70 : AppColors.colorGrey,
              height: 1.4,
            ),
            textAlign: TextAlign.left,
          ),
        ],
      ],
    );
  }

  Widget _buildEmojiAvatar(ContactLocal contact) {
    final responsive = _responsiveFor(context);
    final avatarSize = responsive.size(48);
    return GestureDetector(
      onTap: () {
        Navigator.of(context, rootNavigator: true).push(
          MaterialPageRoute(
            builder: (_) => AppUserChatPictureView(
              displayName: contact.preferredDisplayName,
              chatPictureUrl: contact.userDetails?.chatPictureUrl,
              chatPictureVersion: contact.userDetails?.chatPictureVersion,
              showLikeButton: false,
            ),
          ),
        );
      },
      child: CachedCircleAvatar(
        chatPictureUrl: contact.userDetails?.chatPictureUrl,
        chatPictureVersion: contact.userDetails?.chatPictureVersion,
        radius: avatarSize / 2,
        backgroundColor: AppColors.lighterGrey,
        iconColor: AppColors.iconPrimary,
        contactName: contact.name,
      ),
    );
  }

  Future<void> _prefetchAvatarsIfOnline() async {
    if (_avatarPrefetchInProgress) return;
    final online = ref
        .read(internetStatusStreamProvider)
        .maybeWhen(data: (v) => v, orElse: () => false);
    if (!online) return;
    final now = DateTime.now();
    if (_lastAvatarPrefetch != null &&
        now.difference(_lastAvatarPrefetch!) < const Duration(minutes: 15)) {
      return;
    }
    _avatarPrefetchInProgress = true;
    try {
      // Prefetch from voice-sharing users first
      final List<ContactLocal> list = _filteredVoiceSharingUsers.isNotEmpty
          ? _filteredVoiceSharingUsers
          : _voiceSharingUsers;
      if (list.isEmpty) return;
      final maxCount = 30;
      int count = 0;
      for (final c in list) {
        if (count >= maxCount) break;
        final url = c.userDetails?.chatPictureUrl;
        if (url == null || url.isEmpty) continue;
        final fullUrl = url.startsWith('http')
            ? url
            : '${ApiUrls.mediaBaseUrl}$url';
        try {
          final cached = await AuthenticatedImageCacheManager.instance
              .getFileFromCache(fullUrl);
          if (cached?.file == null) {
            await AuthenticatedImageCacheManager.instance.getSingleFile(
              fullUrl,
            );
          }
          count++;
        } catch (_) {}
      }
    } finally {
      _lastAvatarPrefetch = DateTime.now();
      _avatarPrefetchInProgress = false;
    }
  }

  Widget _buildLoadingState() {
    final responsive = _responsiveFor(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: AppColors.primary),
          SizedBox(height: responsive.spacing(16)),
          Text(
            'Loading....',
            style: AppTextSizes.regular(
              context,
            ).copyWith(color: isDark ? Colors.white : AppColors.colorGrey),
          ),
          if (_isManualRefresh) ...[
            SizedBox(height: responsive.spacing(8)),
            Text(
              "Please don't press until it finishes (few seconds)",
              textAlign: TextAlign.center,
              style: AppTextSizes.small(
                context,
              ).copyWith(color: isDark ? Colors.white54 : AppColors.colorGrey),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    final responsive = _responsiveFor(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: responsive.size(64),
            color: AppColors.error,
          ),
          SizedBox(height: responsive.spacing(16)),
          Text(
            'Error loading updates',
            style: AppTextSizes.large(context).copyWith(
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : AppColors.iconPrimary,
            ),
          ),
          SizedBox(height: responsive.spacing(8)),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: responsive.spacing(32)),
            child: Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: AppTextSizes.regular(
                context,
              ).copyWith(color: isDark ? Colors.white54 : AppColors.colorGrey),
            ),
          ),
          SizedBox(height: responsive.spacing(24)),
          ElevatedButton(
            onPressed: _loadContacts,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: Text(
              'Retry',
              style: AppTextSizes.regular(
                context,
              ).copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    String title = 'No voice contacts found',
    String subtitle = 'ChatAway+ users will appear here for voice features',
  }) {
    final responsive = _responsiveFor(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: responsive.spacing(24)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: responsive.size(80),
              color: isDark ? Colors.white54 : AppColors.iconSecondary,
            ),
            SizedBox(height: responsive.spacing(24)),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTextSizes.large(context).copyWith(
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : AppColors.iconPrimary,
                height: 1.3,
              ),
            ),
            SizedBox(height: responsive.spacing(12)),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: responsive.spacing(16)),
              child: Text(
                subtitle,
                textAlign: TextAlign.center,
                style: AppTextSizes.small(context).copyWith(
                  color: isDark ? Colors.white54 : AppColors.colorGrey,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Hide caption and bottom actions, restoring normal list state
  void _hideCaption() {
    setState(() {
      _showingCaptionForEmojiId = null;
      _selectedEmojiForActionsId = null;
    });
  }

  /// Open individual chat with the contact
  Future<void> _openChatWithContact(ContactLocal contact) async {
    try {
      // Resolve receiver (contact) user ID from contact details
      final receiverId = contact.userDetails?.userId ?? contact.appUserId ?? '';
      if (receiverId.isEmpty) {
        if (kDebugMode) {
          debugPrint(' VoiceHub: Cannot open chat, missing receiverId');
        }
        return;
      }

      // Current logged-in user id
      final currentUserId = await TokenSecureStorage.instance
          .getCurrentUserIdUUID();
      if (currentUserId == null || currentUserId.isEmpty) {
        if (mounted) {
          AppSnackbar.showError(
            context,
            'Please login first',
            bottomPosition: 120,
          );
        }
        return;
      }

      await NavigationService.goToIndividualChat(
        contactName: contact.preferredDisplayName,
        receiverId: receiverId,
        currentUserId: currentUserId,
      );

      // WHATSAPP-STYLE: Force refresh chat list so new conversation appears immediately
      try {
        await ref
            .read(chatListNotifierProvider.notifier)
            .forceRefreshContacts();
        if (kDebugMode) {
          debugPrint(
            ' Chat list refreshed after returning from voice hub chat',
          );
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('Error refreshing chat list: $e');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint(' VoiceHub: Failed to open chat: $e');
      }
    }
  }

  /// Open chat with quoted Express Hub content (SYVT or emoji reply)
  Future<void> _openChatWithContactReply(
    ContactLocal contact, {
    required String replyText,
    required String replyType,
  }) async {
    try {
      final receiverId = contact.userDetails?.userId ?? contact.appUserId ?? '';
      if (receiverId.isEmpty) {
        if (kDebugMode) {
          debugPrint(' VoiceHub: Cannot open chat, missing receiverId');
        }
        return;
      }

      final currentUserId = await TokenSecureStorage.instance
          .getCurrentUserIdUUID();
      if (currentUserId == null || currentUserId.isEmpty) {
        if (mounted) {
          AppSnackbar.showError(
            context,
            'Please login first',
            bottomPosition: 120,
          );
        }
        return;
      }

      await NavigationService.goToIndividualChat(
        contactName: contact.preferredDisplayName,
        receiverId: receiverId,
        currentUserId: currentUserId,
        expressHubReplyText: replyText,
        expressHubReplyType: replyType,
      );

      try {
        await ref
            .read(chatListNotifierProvider.notifier)
            .forceRefreshContacts();
      } catch (_) {}
    } catch (e) {
      if (kDebugMode) {
        debugPrint(' VoiceHub: Failed to open reply chat: $e');
      }
    }
  }

  /// Toggle caption display for an emoji
  void _toggleCaptionDisplay(String emojiId) {
    setState(() {
      if (_showingCaptionForEmojiId == emojiId) {
        // Hide caption if already showing
        _showingCaptionForEmojiId = null;
      } else {
        // Show caption for this emoji
        _showingCaptionForEmojiId = emojiId;
      }
    });
  }
}

/// Server-backed like button for Voice Text Sharings in Express Hub.
/// Mirrors the exact same logic and styling as ShareYourVoiceTile
/// in Connection Insight Hub — same color, same icon, same StatusLikesService.
class _VoiceLikeButton extends StatefulWidget {
  const _VoiceLikeButton({
    super.key,
    required this.statusOwnerId,
    required this.voiceText,
    required this.responsive,
    this.statusId,
  });

  final String statusOwnerId;
  final String? statusId;
  final String voiceText;
  final ResponsiveSize responsive;

  @override
  State<_VoiceLikeButton> createState() => _VoiceLikeButtonState();
}

class _VoiceLikeButtonState extends State<_VoiceLikeButton> {
  static const Color _likeColor = Color(0xFFFF6D00);

  bool _isLiked = false;
  bool _isLoading = false;
  String? _lastStatusKey;

  String get _statusId {
    if (widget.statusId != null && widget.statusId!.isNotEmpty) {
      return widget.statusId!;
    }
    throw Exception('Status ID is required to toggle status like');
  }

  String get _statusKey =>
      '${widget.statusOwnerId}_${widget.statusId ?? ''}_${widget.voiceText}';

  @override
  void initState() {
    super.initState();
    _lastStatusKey = _statusKey;
    _initializeService();
  }

  @override
  void didUpdateWidget(covariant _VoiceLikeButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newKey = _statusKey;
    if (_lastStatusKey != newKey) {
      _lastStatusKey = newKey;
      _isLiked = false;
      _loadCachedLikeState();
    }
  }

  Future<void> _initializeService() async {
    final currentUserId = await TokenSecureStorage.instance
        .getCurrentUserIdUUID();
    if (currentUserId != null && currentUserId.isNotEmpty) {
      StatusLikesService.instance.initialize(currentUserId: currentUserId);
      await _loadCachedLikeState();
    }
  }

  Future<void> _loadCachedLikeState() async {
    if (widget.statusOwnerId.isEmpty || widget.voiceText.isEmpty) return;
    if (widget.statusId == null || widget.statusId!.isEmpty) return;

    try {
      final cachedNullable = await StatusLikesService.instance
          .getCachedLikeStateNullable(statusId: _statusId);

      debugPrint(
        '❤️ [ExpressHub/_VoiceLikeButton] Loaded cached like state: statusId=${widget.statusId}, isLiked=$cachedNullable',
      );

      if (cachedNullable != null && mounted && cachedNullable != _isLiked) {
        setState(() => _isLiked = cachedNullable);
        debugPrint(
          '✅ [ExpressHub/_VoiceLikeButton] Updated UI: isLiked=$_isLiked',
        );
      }
      // No server call here — avoids flicker on widget creation.
      // The toggle itself reconciles with the server.
    } catch (e) {
      debugPrint(
        '⚠️ [ExpressHub/_VoiceLikeButton] Error loading like state: $e',
      );
    }
  }

  Future<void> _toggleLike() async {
    if (_isLoading) return;
    if (!ConnectivityCache.instance.isOnline) {
      if (mounted) {
        AppSnackbar.showOfflineWarning(context, "You're offline");
      }
      return;
    }
    if (widget.statusOwnerId.isEmpty || widget.voiceText.isEmpty) return;

    if (widget.statusId == null || widget.statusId!.isEmpty) {
      if (mounted) {
        AppSnackbar.showTopInfo(context, 'Unable to like status at this time');
      }
      return;
    }

    final canToggle = await StatusLikesService.instance.canToggle(
      statusId: _statusId,
    );
    if (!canToggle) {
      if (mounted) {
        AppSnackbar.showTopInfo(
          context,
          'Limit reached. New status = new chance!',
        );
      }
      return;
    }

    final previousState = _isLiked;
    setState(() {
      _isLiked = !_isLiked;
      _isLoading = true;
    });

    try {
      final result = await StatusLikesService.instance.toggle(
        statusId: _statusId,
        statusOwnerId: widget.statusOwnerId,
      );

      StatusLikesService.instance.incrementToggleCount(statusId: _statusId);

      if (mounted) {
        setState(() {
          if (result.isLiked != _isLiked) {
            _isLiked = result.isLiked;
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ [ExpressHub/_VoiceLikeButton] Error: $e');
      if (mounted) {
        setState(() {
          _isLiked = previousState;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasStatus = widget.voiceText.isNotEmpty;
    final canLike =
        hasStatus && widget.statusId != null && widget.statusId!.isNotEmpty;

    if (!hasStatus) {
      return Image.asset(
        ImageAssets.syvlIcon,
        width: widget.responsive.size(24),
        height: widget.responsive.size(24),
        color: isDark ? Colors.white : null,
        fit: BoxFit.contain,
      );
    }

    if (!canLike) {
      return Tooltip(
        message: 'Status ID unavailable',
        child: Opacity(
          opacity: 0.3,
          child: Image.asset(
            ImageAssets.syvlIcon,
            width: widget.responsive.size(24),
            height: widget.responsive.size(24),
            color: isDark ? Colors.white : null,
            fit: BoxFit.contain,
          ),
        ),
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _isLoading ? null : _toggleLike,
      child: SizedBox(
        width: widget.responsive.size(44),
        height: widget.responsive.size(44),
        child: Center(
          child: _isLoading
              ? SizedBox(
                  width: widget.responsive.size(22),
                  height: widget.responsive.size(22),
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: _likeColor,
                  ),
                )
              : _isLiked
              ? Icon(
                  Icons.favorite,
                  size: widget.responsive.size(22),
                  color: _likeColor,
                )
              : Image.asset(
                  ImageAssets.syvlIcon,
                  width: widget.responsive.size(22),
                  height: widget.responsive.size(22),
                  color: isDark ? Colors.white : null,
                  fit: BoxFit.contain,
                ),
        ),
      ),
    );
  }
}
