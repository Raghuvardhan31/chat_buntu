import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chataway_plus/core/themes/colors/app_colors.dart';
import 'package:chataway_plus/core/themes/app_text_styles.dart';
import 'package:chataway_plus/core/snackbar/app_snackbar.dart';
import 'package:chataway_plus/core/responsive_layout/responsive_layout_builder.dart';
import 'package:chataway_plus/features/shared/widgets/avatars/cached_circle_avatar.dart';
import 'package:chataway_plus/features/contacts/presentation/providers/contacts_management.dart';
import 'package:chataway_plus/features/contacts/data/models/contact_local.dart';
import 'package:chataway_plus/features/contacts/utils/contact_display_name_helper.dart';
import 'package:chataway_plus/features/chat/presentation/providers/chat_list_providers/chat_list_stream.dart';
import 'package:chataway_plus/features/chat/models/chat_message_model.dart';
import 'package:chataway_plus/features/chat/data/services/chat_engine/index.dart';
import 'package:chataway_plus/core/constants/api_url/api_urls.dart';

class ForwardMessagePage extends ConsumerStatefulWidget {
  final List<ChatMessageModel> messages;

  const ForwardMessagePage({super.key, required this.messages});

  @override
  ConsumerState<ForwardMessagePage> createState() => _ForwardMessagePageState();
}

class _ForwardMessagePageState extends ConsumerState<ForwardMessagePage> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _searchQuery = '';

  bool _isForwarding = false;
  bool _contactsLoading = true;

  String? _selectedRecipientId;
  String? _selectedRecipientName;
  String? _selectedRecipientChatPictureUrl;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _ensureContactsLoaded();
  }

  /// Ensure contacts are loaded before displaying the list
  Future<void> _ensureContactsLoaded() async {
    try {
      await ref
          .read(contactsManagementNotifierProvider.notifier)
          .loadFromCache();
    } catch (_) {}
    if (mounted) {
      setState(() => _contactsLoading = false);
    }
  }

  void _onSearchChanged() {
    final next = _searchController.text.toLowerCase();
    if (_searchQuery == next) return;
    setState(() {
      _searchQuery = next;
    });
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
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

        // Get recent chats from ChatListStream
        final recentChats = ChatListStream.instance.currentList;

        // Get all app users from contacts provider (filter out contacts without appUserId)
        final appUsers = ref
            .watch(appUserContactsProvider)
            .where((c) => (c.appUserId ?? '').trim().isNotEmpty)
            .toList();

        final allContacts = ref.watch(contactsListProvider);

        // Filter based on search
        final filteredRecent = _filterRecentChats(recentChats);
        final filteredAppUsers = _filterAppUsers(appUsers);

        final hasSelection =
            _selectedRecipientId != null && _selectedRecipientId!.isNotEmpty;

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            surfaceTintColor: Colors.transparent,
            title: Text(
              widget.messages.length > 1
                  ? 'Forward ${widget.messages.length} messages'
                  : 'Forward message',
              style: AppTextSizes.large(context).copyWith(
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : AppColors.iconPrimary,
              ),
            ),
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            elevation: 0,
            scrolledUnderElevation: 0,
            toolbarHeight: responsive.size(68),
            centerTitle: false,
            titleSpacing: 0,
            leadingWidth: responsive.size(50),
            leading: IconButton(
              icon: Icon(
                Icons.arrow_back,
                color: isDark ? Colors.white : Colors.black,
                size: responsive.size(24),
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          bottomNavigationBar: hasSelection
              ? _buildSelectedRecipientBar(
                  responsive: responsive,
                  isDark: isDark,
                )
              : null,
          body: SafeArea(
            top: false,
            bottom: true,
            child: Stack(
              children: [
                Positioned.fill(
                  child: Container(
                    color: Theme.of(context).scaffoldBackgroundColor,
                  ),
                ),
                Column(
                  children: [
                    _buildHeaderSearchArea(responsive, isDark),
                    Expanded(
                      child: ListView(
                        padding: EdgeInsets.only(
                          left: responsive.spacing(16),
                          right: responsive.spacing(16),
                          bottom: hasSelection
                              ? responsive.spacing(20)
                              : responsive.spacing(110),
                        ),
                        children: [
                          if (filteredRecent.isNotEmpty) ...[
                            _buildSectionHeader(
                              responsive,
                              'Recent chats',
                              isDark,
                            ),
                            SizedBox(height: responsive.spacing(8)),
                            ...filteredRecent.map(
                              (chat) => _buildRecentChatTile(
                                responsive,
                                chat,
                                isDark,
                                allContacts,
                              ),
                            ),
                            SizedBox(height: responsive.spacing(16)),
                          ],
                          if (filteredAppUsers.isNotEmpty) ...[
                            _buildSectionHeader(
                              responsive,
                              'All contacts',
                              isDark,
                            ),
                            SizedBox(height: responsive.spacing(8)),
                            ...filteredAppUsers.map(
                              (contact) => _buildContactTile(
                                responsive,
                                contact,
                                isDark,
                              ),
                            ),
                          ],
                          if (_contactsLoading)
                            Padding(
                              padding: EdgeInsets.only(
                                top: responsive.spacing(40),
                              ),
                              child: Center(
                                child: SizedBox(
                                  width: responsive.size(24),
                                  height: responsive.size(24),
                                  child: CircularProgressIndicator(
                                    strokeWidth: responsive.size(2),
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      AppColors.primary,
                                    ),
                                  ),
                                ),
                              ),
                            )
                          else if (filteredRecent.isEmpty &&
                              filteredAppUsers.isEmpty)
                            Padding(
                              padding: EdgeInsets.only(
                                top: responsive.spacing(40),
                              ),
                              child: Center(
                                child: Text(
                                  _searchQuery.isEmpty
                                      ? 'No contacts found'
                                      : 'No results for "$_searchQuery"',
                                  style: TextStyle(
                                    color: Colors.grey[500],
                                    fontSize: responsive.size(14),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeaderSearchArea(ResponsiveSize responsive, bool isDark) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: responsive.spacing(16),
        vertical: responsive.spacing(8),
      ),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        decoration: InputDecoration(
          hintText: 'Search contacts',
          hintStyle: TextStyle(
            color: Colors.grey[500],
            fontSize: responsive.size(14),
          ),
          prefixIcon: Icon(
            Icons.search,
            color: Colors.grey[500],
            size: responsive.size(20),
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(
                    Icons.clear,
                    color: Colors.grey[500],
                    size: responsive.size(20),
                  ),
                  onPressed: () {
                    _searchController.clear();
                    _searchFocusNode.unfocus();
                  },
                )
              : null,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(
            horizontal: responsive.spacing(12),
            vertical: responsive.spacing(12),
          ),
        ),
        style: TextStyle(
          fontSize: responsive.size(14),
          color: isDark ? Colors.white : Colors.black87,
        ),
      ),
    );
  }

  Widget _buildSectionHeader(
    ResponsiveSize responsive,
    String title,
    bool isDark,
  ) {
    return Padding(
      padding: EdgeInsets.only(top: responsive.spacing(8)),
      child: Text(
        title,
        style: TextStyle(
          fontSize: responsive.size(13),
          fontWeight: FontWeight.w600,
          color: AppColors.primary,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _buildRecentChatTile(
    ResponsiveSize responsive,
    ChatContactModel chat,
    bool isDark,
    List<ContactLocal> allContacts,
  ) {
    final isSelected = _selectedRecipientId == chat.user.id;

    final ContactLocal? matchedContact =
        ContactDisplayNameHelper.findByUserIdOrPhone(
          contacts: allContacts,
          userId: chat.user.id,
          mobileNo: chat.user.mobileNo,
        );

    final mergedChatPictureUrl =
        chat.user.chatPictureUrl ?? matchedContact?.userDetails?.chatPictureUrl;
    final chatPictureVersion = matchedContact?.userDetails?.chatPictureVersion;

    final String name = ContactDisplayNameHelper.resolveDisplayName(
      contacts: allContacts,
      userId: chat.user.id,
      mobileNo: chat.user.mobileNo,
      backendDisplayName: chat.user.fullName.trim(),
      fallbackLabel: 'ChatAway user',
    );

    final status = matchedContact?.userDetails?.recentStatus?.content;
    final subtitle = (status != null && status.trim().isNotEmpty)
        ? status
        : 'No status';

    return InkWell(
      onTap: () => _selectRecipient(
        id: chat.user.id,
        name: name,
        chatPictureUrl: mergedChatPictureUrl,
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: responsive.spacing(11)),
        child: Row(
          children: [
            CachedCircleAvatar(
              chatPictureUrl: mergedChatPictureUrl,
              chatPictureVersion: chatPictureVersion,
              radius: responsive.size(24),
              backgroundColor: AppColors.lighterGrey,
              iconColor: AppColors.colorGrey,
              contactName: name,
            ),
            SizedBox(width: responsive.spacing(12)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: responsive.size(16),
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : AppColors.colorBlack,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: responsive.spacing(4)),
                  Text(
                    subtitle,
                    style: AppTextSizes.small(context).copyWith(
                      color: isDark ? Colors.white70 : AppColors.colorGrey,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            SizedBox(width: responsive.spacing(10)),
            _buildSelectionIndicator(
              responsive: responsive,
              isSelected: isSelected,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactTile(
    ResponsiveSize responsive,
    ContactLocal contact,
    bool isDark,
  ) {
    final id = contact.appUserId ?? '';
    final isSelected = id.isNotEmpty && _selectedRecipientId == id;

    final status = contact.userDetails?.recentStatus?.content;
    final subtitle = (status != null && status.trim().isNotEmpty)
        ? status
        : 'No status';

    return InkWell(
      onTap: isSelected
          ? null
          : () => _selectRecipient(
              id: id,
              name: contact.preferredDisplayName,
              chatPictureUrl: contact.userDetails?.chatPictureUrl,
            ),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: responsive.spacing(11)),
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
                    style: TextStyle(
                      fontSize: responsive.size(16),
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : AppColors.colorBlack,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: responsive.spacing(4)),
                  Text(
                    subtitle,
                    style: AppTextSizes.small(context).copyWith(
                      color: isDark ? Colors.white70 : AppColors.colorGrey,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            SizedBox(width: responsive.spacing(10)),
            _buildSelectionIndicator(
              responsive: responsive,
              isSelected: isSelected,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectionIndicator({
    required ResponsiveSize responsive,
    required bool isSelected,
  }) {
    final size = responsive.size(22);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isSelected ? AppColors.primary : Colors.transparent,
        border: Border.all(
          color: isSelected
              ? AppColors.primary
              : (Theme.of(context).brightness == Brightness.dark
                    ? Colors.white24
                    : Colors.grey[400]!),
          width: responsive.size(1.4),
        ),
      ),
      child: isSelected
          ? Icon(Icons.check, size: responsive.size(14), color: Colors.white)
          : null,
    );
  }

  Widget _buildSelectedRecipientBar({
    required ResponsiveSize responsive,
    required bool isDark,
  }) {
    return SafeArea(
      top: false,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: responsive.spacing(16),
          vertical: responsive.spacing(10),
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          border: Border(
            top: BorderSide(
              color: isDark ? Colors.white12 : Colors.black12,
              width: responsive.size(1),
            ),
          ),
        ),
        child: Row(
          children: [
            CachedCircleAvatar(
              chatPictureUrl: _selectedRecipientChatPictureUrl,
              radius: responsive.size(18),
              backgroundColor: isDark
                  ? const Color(0xFF2C2C2C)
                  : Colors.grey[200]!,
              iconColor: isDark ? Colors.white70 : Colors.grey[600]!,
              contactName: _selectedRecipientName,
            ),
            SizedBox(width: responsive.spacing(10)),
            Expanded(
              child: Text(
                _selectedRecipientName ?? '',
                style: TextStyle(
                  fontSize: responsive.size(15),
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : AppColors.iconPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(width: responsive.spacing(10)),
            GestureDetector(
              onTap: _isForwarding
                  ? null
                  : () {
                      final id = _selectedRecipientId ?? '';
                      final name = _selectedRecipientName ?? '';
                      if (id.isEmpty || name.isEmpty) return;
                      _onContactSelected(contactId: id, contactName: name);
                    },
              child: Container(
                width: responsive.size(46),
                height: responsive.size(46),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: _isForwarding
                    ? SizedBox(
                        width: responsive.size(18),
                        height: responsive.size(18),
                        child: CircularProgressIndicator(
                          strokeWidth: responsive.size(2),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : Icon(
                        Icons.send_rounded,
                        color: Colors.white,
                        size: responsive.size(20),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<ChatContactModel> _filterRecentChats(List<ChatContactModel> chats) {
    if (_searchQuery.isEmpty) return chats.take(5).toList();
    return chats
        .where((c) => c.user.fullName.toLowerCase().contains(_searchQuery))
        .take(5)
        .toList();
  }

  List<ContactLocal> _filterAppUsers(List<ContactLocal> contacts) {
    if (_searchQuery.isEmpty) return contacts;
    return contacts
        .where(
          (c) =>
              c.preferredDisplayName.toLowerCase().contains(_searchQuery) ||
              c.mobileNo.contains(_searchQuery),
        )
        .toList();
  }

  void _selectRecipient({
    required String id,
    required String name,
    String? chatPictureUrl,
  }) {
    setState(() {
      if (_selectedRecipientId == id) {
        _selectedRecipientId = null;
        _selectedRecipientName = null;
        _selectedRecipientChatPictureUrl = null;
      } else {
        _selectedRecipientId = id;
        _selectedRecipientName = name;
        _selectedRecipientChatPictureUrl = chatPictureUrl;
      }
    });
  }

  void _onContactSelected({
    required String contactId,
    required String contactName,
  }) {
    _forwardMessageTo(contactId: contactId, contactName: contactName);
  }

  String _normalizeForwardFileUrl(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return trimmed;

    final streamPrefix = '/api/images/stream/';
    final chatsFilePrefix = '/chats/file/';
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      final uri = Uri.tryParse(trimmed);
      final path = uri?.path;
      if (path != null) {
        final streamIndex = path.indexOf(streamPrefix);
        if (streamIndex >= 0) {
          return path.substring(streamIndex + streamPrefix.length);
        }
        final chatsIndex = path.indexOf(chatsFilePrefix);
        if (chatsIndex >= 0) {
          return path.substring(chatsIndex + chatsFilePrefix.length);
        }
      }
    }
    if (trimmed.startsWith(streamPrefix)) {
      return trimmed.substring(streamPrefix.length);
    }

    if (trimmed.startsWith(chatsFilePrefix)) {
      return trimmed.substring(chatsFilePrefix.length);
    }

    final absoluteStreamPrefix = '${ApiUrls.mediaBaseUrl}$streamPrefix';
    if (trimmed.startsWith(absoluteStreamPrefix)) {
      return trimmed.substring(absoluteStreamPrefix.length);
    }

    final absoluteChatsFilePrefix = '${ApiUrls.apiBaseUrl}$chatsFilePrefix';
    if (trimmed.startsWith(absoluteChatsFilePrefix)) {
      return trimmed.substring(absoluteChatsFilePrefix.length);
    }

    return trimmed;
  }

  Future<void> _forwardMessageTo({
    required String contactId,
    required String contactName,
  }) async {
    if (_isForwarding) return;
    setState(() => _isForwarding = true);

    try {
      int successCount = 0;
      for (final msg in widget.messages) {
        if (msg.messageType == MessageType.deleted) continue;

        final hasText = msg.message.trim().isNotEmpty;
        bool sent = false;

        if (msg.isMediaMessage) {
          final raw = msg.imageUrl;
          if (raw == null || raw.trim().isEmpty) continue;

          final fileUrl = _normalizeForwardFileUrl(raw);
          final looksLocalPath =
              (fileUrl.startsWith('file://')) ||
              (fileUrl.startsWith('/') &&
                  !fileUrl.startsWith('/api/') &&
                  !fileUrl.startsWith('/uploads/')) ||
              fileUrl.contains('media_cache');

          if (fileUrl.isEmpty || fileUrl.startsWith('http') || looksLocalPath)
            continue;

          final isPdf =
              msg.mimeType == 'application/pdf' ||
              (msg.fileName?.toLowerCase().endsWith('.pdf') ?? false) ||
              (msg.pageCount != null);

          final String forwardType;
          switch (msg.messageType) {
            case MessageType.image:
              forwardType = 'image';
              break;
            case MessageType.video:
              forwardType = 'video';
              break;
            case MessageType.audio:
              forwardType = 'audio';
              break;
            case MessageType.document:
              forwardType = isPdf ? 'pdf' : 'document';
              break;
            default:
              forwardType = 'text';
          }

          final thumb = msg.thumbnailUrl;
          final normalizedThumb =
              (msg.messageType == MessageType.video &&
                      thumb != null &&
                      thumb.trim().isNotEmpty)
                  ? _normalizeForwardFileUrl(thumb)
                  : null;

          final result = await ChatEngineService.instance.sendMessageSilently(
            messageText: msg.message,
            receiverId: contactId,
            messageType: forwardType,
            fileUrl: fileUrl,
            mimeType: msg.mimeType,
            fileName: msg.fileName,
            fileSize: msg.fileSize,
            pageCount: msg.pageCount,
            audioDuration: msg.audioDuration,
            thumbnailUrl: normalizedThumb,
            imageWidth: msg.imageWidth,
            imageHeight: msg.imageHeight,
          );
          sent = result != null;
        } else if (msg.messageType == MessageType.location) {
          if (!hasText) continue;
          final result = await ChatEngineService.instance.sendMessageSilently(
            messageText: msg.message,
            receiverId: contactId,
            messageType: 'location',
          );
          sent = result != null;
        } else if (msg.messageType == MessageType.contact) {
          if (!hasText) continue;
          final result = await ChatEngineService.instance.sendMessageSilently(
            messageText: msg.message,
            receiverId: contactId,
            messageType: 'contact',
          );
          sent = result != null;
        } else if (msg.messageType == MessageType.poll) {
          if (!hasText) continue;
          final result = await ChatEngineService.instance.sendMessageSilently(
            messageText: msg.message,
            receiverId: contactId,
            messageType: 'poll',
          );
          sent = result != null;
        } else {
          if (!hasText) continue;
          final result = await ChatEngineService.instance.sendMessageSilently(
            messageText: msg.message,
            receiverId: contactId,
          );
          sent = result != null;
        }

        if (sent) successCount++;
      }

      if (!mounted) return;

      if (successCount > 0) {
        final label = successCount == 1 ? 'Message' : 'Messages';
        await AppSnackbar.show(context, '$successCount $label sent to $contactName');
        if (mounted) Navigator.of(context).pop();
      } else {
        await AppSnackbar.show(context, 'Failed to forward messages');
      }
    } catch (e) {
      debugPrint('Forward error: $e');
      if (mounted) await AppSnackbar.show(context, 'Failed to forward messages');
    } finally {
      if (mounted) setState(() => _isForwarding = false);
    }
  }
}
