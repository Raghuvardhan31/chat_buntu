import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:chataway_plus/core/themes/app_text_styles.dart';
import 'package:chataway_plus/features/chat/data/services/chat_engine/index.dart';
import 'package:chataway_plus/core/themes/colors/app_colors.dart';
import 'package:chataway_plus/core/routes/navigation_service.dart';
import 'package:chataway_plus/features/contacts/data/models/contact_local.dart';
import 'package:chataway_plus/features/shared/widgets/avatars/cached_circle_avatar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chataway_plus/features/blocked_contacts/presentation/providers/blocked_contacts/blocked_contacts_providers.dart';
import 'package:chataway_plus/core/snackbar/app_snackbar.dart';
import 'package:chataway_plus/core/dialog_box/app_dialog_box.dart';
import 'package:chataway_plus/core/connectivity/connectivity_service.dart';
import 'package:chataway_plus/core/responsive_layout/responsive_layout_builder.dart';
import '../../data/models/blocked_contacts_models.dart';
import 'package:chataway_plus/features/chat/presentation/pages/media_viewer/app_user_chat_picture_view.dart';

class BlockedContactsPage extends ConsumerStatefulWidget {
  const BlockedContactsPage({super.key});

  @override
  ConsumerState<BlockedContactsPage> createState() =>
      _BlockedContactsPageState();
}

class _BlockedContactsPageState extends ConsumerState<BlockedContactsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = false;
  bool _wasOnline = false;

  List<BlockedContactUiModel> _blockedContacts = [];
  List<BlockedContactUiModel> _filteredBlockedContacts = [];

  List<ContactLocal> _allContacts = [];
  List<ContactLocal> _filteredAllContacts = [];
  StreamSubscription? _profileUpdateSub; // WhatsApp-style profile updates

  @override
  void initState() {
    super.initState();
    _wasOnline = ConnectivityCache.instance.isOnline;
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() => setState(() {}));
    _filteredBlockedContacts = List.from(_blockedContacts);
    _filteredAllContacts = List.from(_allContacts);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadBlockedContacts();
    });

    // WHATSAPP-STYLE: Listen for profile updates from contacts
    _profileUpdateSub = ChatEngineService.instance.profileUpdateStream.listen((
      update,
    ) async {
      debugPrint('👤 [BlockedContacts] Profile update from: ${update.userId}');
      // Refresh from DB and reload UI
      if (mounted) {
        // Reinitialize to reload from database
        await ref.read(blockedContactsNotifierProvider.notifier).initialize();
        // Then refresh UI
        if (mounted) {
          _loadBlockedContacts();
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

  Future<void> _loadBlockedContacts() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      await ref.read(blockedContactsNotifierProvider.notifier).initialize();
      if (!mounted) return;

      final s = ref.read(blockedContactsNotifierProvider);
      _blockedContacts = List<BlockedContactUiModel>.from(s.blockedContacts);
      _allContacts = List<ContactLocal>.from(s.availableContacts);
      final names = _blockedContacts
          .map((c) => c.name)
          .where((n) => n.isNotEmpty)
          .join(', ');
      debugPrint(
        'loading block contacts count ${_blockedContacts.length} with names: [$names]',
      );
      setState(() {
        _filteredBlockedContacts = List.from(_blockedContacts);
        _filteredAllContacts = List.from(_allContacts);
        _isLoading = false;
      });

      if (ConnectivityCache.instance.isOnline) {
        unawaited(_refreshFromServerAndSyncUI());
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _refreshFromServerAndSyncUI() async {
    try {
      await ref
          .read(blockedContactsNotifierProvider.notifier)
          .refreshFromServer();
      if (!mounted) return;
      _syncFromProvider();
    } catch (_) {}
  }

  void _filterContacts(String query) {
    if (query.isEmpty) {
      setState(() {
        _filteredBlockedContacts = List.from(_blockedContacts);
        _filteredAllContacts = List.from(_allContacts);
      });
      return;
    }

    final lowerQuery = query.toLowerCase();
    setState(() {
      _filteredBlockedContacts = _blockedContacts
          .where(
            (c) =>
                c.name.toLowerCase().contains(lowerQuery) ||
                c.mobile.contains(query),
          )
          .toList();
      _filteredAllContacts = _allContacts
          .where(
            (c) =>
                c.name.toLowerCase().contains(lowerQuery) ||
                c.mobileNo.contains(query),
          )
          .toList();
    });
  }

  Future<void> _unblockContact(BlockedContactUiModel contact) async {
    final name = contact.name.isNotEmpty ? contact.name : 'this contact';
    final confirmed = await _showConfirm(
      title: 'Unblock Contact',
      message: 'Do you want to unblock $name?',
      confirmText: 'Unblock',
      confirmColor: AppColors.primary,
      titleAlignment: TextAlign.left,
      messageAlignment: TextAlign.left,
    );
    if (confirmed != true) return;
    final userId = contact.userId;
    if (userId.isEmpty) return;

    if (mounted) {
      AppSnackbar.showCustom(
        context,
        'Unblocking...',
        bottomPosition: 120,
        duration: const Duration(seconds: 1),
      );
    }

    var ok = false;
    late final String serverMessage;
    try {
      final result = await ref
          .read(blockedContactsNotifierProvider.notifier)
          .unblockUser(userId);
      ok = result.isSuccess;
      serverMessage = result.message;
    } on SocketException {
      if (mounted) {
        AppSnackbar.showOfflineWarning(
          context,
          "You're offline. Check your connection",
        );
      }
      return;
    } catch (e) {
      if (mounted) {
        AppSnackbar.showError(
          context,
          'Failed to unblock user. Please try again.',
          bottomPosition: 120,
        );
      }
      return;
    }
    if (ok) {
      // State already updated by notifier - just sync local lists (fast, no API call)
      _syncFromProvider();
      if (mounted) {
        AppSnackbar.showSuccess(
          context,
          serverMessage.isNotEmpty ? serverMessage : 'Unblocked $name',
          bottomPosition: 120,
          duration: const Duration(seconds: 2),
        );
      }
    } else {
      if (mounted) {
        AppSnackbar.showError(
          context,
          serverMessage.isNotEmpty
              ? serverMessage
              : 'Failed to unblock user. Please try again.',
          bottomPosition: 120,
        );
      }
    }
  }

  /// Fast sync from provider state (no API call, no loading spinner)
  void _syncFromProvider() {
    if (!mounted) return;
    final s = ref.read(blockedContactsNotifierProvider);
    setState(() {
      _blockedContacts = List<BlockedContactUiModel>.from(s.blockedContacts);
      _allContacts = List<ContactLocal>.from(s.availableContacts);
      _filteredBlockedContacts = List.from(_blockedContacts);
      _filteredAllContacts = List.from(_allContacts);
    });
  }

  Future<void> _blockContact(ContactLocal contact) async {
    final confirmed = await _showConfirm(
      title: 'Block Contact',
      message:
          'Do you want to block ${contact.preferredDisplayName}? They will not be able to contact you.',
      confirmText: 'Block',
      confirmColor: AppColors.error,
      titleAlignment: TextAlign.left,
      messageAlignment: TextAlign.left,
    );
    if (confirmed != true) return;

    final appUserId = contact.appUserId;
    if (appUserId == null || appUserId.isEmpty) {
      if (mounted) {
        AppSnackbar.showError(
          context,
          'Cannot block: User not registered',
          bottomPosition: 120,
        );
      }
      return;
    }

    if (mounted) {
      AppSnackbar.showCustom(
        context,
        'Blocking...',
        bottomPosition: 120,
        duration: const Duration(seconds: 1),
      );
    }

    var ok = false;
    late final String serverMessage;
    try {
      final result = await ref
          .read(blockedContactsNotifierProvider.notifier)
          .blockUser(appUserId);
      ok = result.isSuccess;
      serverMessage = result.message;
    } on SocketException {
      if (mounted) {
        AppSnackbar.showOfflineWarning(
          context,
          "You're offline. Check your connection",
        );
      }
      return;
    } catch (e) {
      if (mounted) {
        AppSnackbar.showError(
          context,
          'Failed to block user. Please try again.',
          bottomPosition: 120,
        );
      }
      return;
    }
    if (ok) {
      // State already updated by notifier - just sync local lists (fast, no API call)
      _syncFromProvider();
      if (mounted) {
        AppSnackbar.showSuccess(
          context,
          serverMessage.isNotEmpty
              ? serverMessage
              : 'Blocked ${contact.preferredDisplayName}',
          bottomPosition: 120,
          duration: const Duration(seconds: 2),
        );
      }
    } else {
      if (mounted) {
        AppSnackbar.showError(
          context,
          serverMessage.isNotEmpty
              ? serverMessage
              : 'Failed to block user. Please try again.',
          bottomPosition: 120,
        );
      }
    }
  }

  Future<bool?> _showConfirm({
    required String title,
    required String message,
    required String confirmText,
    required Color confirmColor,
    TextAlign titleAlignment = TextAlign.center,
    TextAlign messageAlignment = TextAlign.center,
  }) {
    final responsive = _responsiveFor(context);

    return AppDialogBox.show<bool>(
      context,
      title: title,
      message: message,
      buttons: const [],
      barrierDismissible: false,
      dialogWidth: responsive.size(295),
      titleColor: confirmColor,
      titleAlignment: titleAlignment,
      messageAlignment: messageAlignment,
      contentAlignment: CrossAxisAlignment.start,
      customActions: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.colorGrey,
              padding: EdgeInsets.symmetric(
                horizontal: responsive.spacing(16),
                vertical: responsive.spacing(10),
              ),
            ),
            child: Text(
              'Cancel',
              style: AppTextSizes.regular(context).copyWith(
                fontWeight: FontWeight.w500,
                color: AppColors.colorGrey,
              ),
            ),
          ),
          SizedBox(width: responsive.spacing(8)),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: confirmColor,
              foregroundColor: Colors.white,
              elevation: 1,
              padding: EdgeInsets.symmetric(
                horizontal: responsive.spacing(24),
                vertical: responsive.spacing(10),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(responsive.size(6)),
              ),
              // Override global infinite minimumSize from theme so this
              // dialog button does not force an infinite width.
              minimumSize: Size(responsive.spacing(40), responsive.size(40)),
            ),
            child: Text(
              confirmText,
              style: AppTextSizes.regular(
                context,
              ).copyWith(fontWeight: FontWeight.w500, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<bool>>(internetStatusStreamProvider, (prev, next) {
      final nowOnline = next.maybeWhen(data: (v) => v, orElse: () => null);
      if (nowOnline == null) return;

      if (!_wasOnline && nowOnline) {
        unawaited(_refreshFromServerAndSyncUI());
      }
      _wasOnline = nowOnline;
    });

    final theme = Theme.of(context);

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

        NavigationService.goToSettingsMain();
      },
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: _buildAppBar(context),
        body: _isLoading ? _buildLoadingState(context) : _buildContent(context),
      ),
    );
  }

  ResponsiveSize _responsiveFor(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return ResponsiveSize(
      context: context,
      constraints: BoxConstraints(maxWidth: width),
      breakpoint: DeviceBreakpoint.fromWidth(width),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    final responsive = _responsiveFor(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AppBar(
      backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
      elevation: 0,
      scrolledUnderElevation: 0,
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
        onPressed: () {
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

          NavigationService.goToSettingsMain();
        },
      ),
      title: _isSearching ? _buildSearchField(isDark) : _buildTitle(theme),
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
      ],
      bottom: TabBar(
        controller: _tabController,
        tabs: [
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.block,
                  size: responsive.size(20),
                  color: _tabController.index == 0
                      ? theme.colorScheme.onSurface
                      : (isDark ? Colors.white54 : AppColors.colorGrey),
                ),
                SizedBox(width: responsive.spacing(8)),
                Text(
                  'Blocked Contacts',
                  style: AppTextSizes.small(context).copyWith(
                    fontWeight: FontWeight.w600,
                    color: _tabController.index == 0
                        ? theme.colorScheme.onSurface
                        : (isDark ? Colors.white54 : AppColors.colorGrey),
                  ),
                ),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.people,
                  size: responsive.size(20),
                  color: _tabController.index == 1
                      ? theme.colorScheme.onSurface
                      : (isDark ? Colors.white54 : AppColors.colorGrey),
                ),
                SizedBox(width: responsive.spacing(8)),
                Text(
                  'Contacts',
                  style: AppTextSizes.small(context).copyWith(
                    fontWeight: FontWeight.w600,
                    color: _tabController.index == 1
                        ? theme.colorScheme.onSurface
                        : (isDark ? Colors.white54 : AppColors.colorGrey),
                  ),
                ),
              ],
            ),
          ),
        ],
        labelColor: isDark ? Colors.white : AppColors.iconPrimary,
        unselectedLabelColor: isDark ? Colors.white54 : AppColors.colorGrey,
        indicatorColor: AppColors.primary,
      ),
    );
  }

  Widget _buildTitle(ThemeData theme) {
    return Text(
      'Blocked Contacts',
      style: AppTextSizes.large(context).copyWith(
        fontWeight: FontWeight.bold,
        color: theme.colorScheme.onSurface,
      ),
    );
  }

  Widget _buildSearchField(bool isDark) {
    return TextField(
      controller: _searchController,
      autofocus: true,
      onChanged: _filterContacts,
      cursorColor: isDark ? Colors.white : AppColors.colorBlack,
      style: AppTextSizes.regular(
        context,
      ).copyWith(color: isDark ? Colors.white : AppColors.iconPrimary),
      decoration: InputDecoration(
        hintText: 'Search blocked contacts',
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

  Widget _buildLoadingState(BuildContext context) {
    final responsive = _responsiveFor(context);

    return Center(
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
        strokeWidth: responsive.size(3),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    return TabBarView(
      controller: _tabController,
      children: [
        _buildBlockedContactsList(context),
        _buildAllContactsList(context),
      ],
    );
  }

  Widget _buildBlockedContactsList(BuildContext context) {
    final responsive = _responsiveFor(context);

    if (_filteredBlockedContacts.isEmpty) {
      return _buildEmptyState(
        icon: Icons.block,
        message: 'No blocked contacts',
        subtitle: 'Blocked contacts will appear here',
        responsive: responsive,
      );
    }

    return ListView.builder(
      padding: EdgeInsets.only(bottom: responsive.spacing(110)),
      itemCount: _filteredBlockedContacts.length,
      itemBuilder: (context, index) {
        final contact = _filteredBlockedContacts[index];
        return _buildBlockedContactCard(contact, responsive);
      },
    );
  }

  Widget _buildAllContactsList(BuildContext context) {
    final responsive = _responsiveFor(context);

    if (_filteredAllContacts.isEmpty) {
      return _buildEmptyState(
        icon: Icons.people_outline,
        message: 'No contacts',
        subtitle: 'Your contacts will appear here',
        responsive: responsive,
      );
    }

    return ListView.builder(
      padding: EdgeInsets.only(bottom: responsive.spacing(110)),
      itemCount: _filteredAllContacts.length,
      itemBuilder: (context, index) {
        final contact = _filteredAllContacts[index];
        return _buildAllContactCard(contact, responsive);
      },
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String message,
    required String subtitle,
    required ResponsiveSize responsive,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: responsive.size(80),
            color: isDark ? Colors.white38 : AppColors.colorGrey,
          ),
          SizedBox(height: responsive.spacing(20)),
          Text(
            message,
            style: AppTextSizes.large(context).copyWith(
              color: isDark ? Colors.white54 : AppColors.colorGrey,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: responsive.spacing(8)),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: responsive.spacing(40)),
            child: Text(
              subtitle,
              textAlign: TextAlign.center,
              style: AppTextSizes.regular(
                context,
              ).copyWith(color: isDark ? Colors.white38 : AppColors.colorGrey),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBlockedContactCard(
    BlockedContactUiModel contact,
    ResponsiveSize responsive,
  ) {
    final chatPictureUrl = contact.chatPictureUrl;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ListTile(
      contentPadding: EdgeInsets.symmetric(
        horizontal: responsive.spacing(16),
        vertical: responsive.spacing(4),
      ),
      leading: GestureDetector(
        onTap: () {
          Navigator.of(context, rootNavigator: true).push(
            MaterialPageRoute(
              builder: (_) => AppUserChatPictureView(
                displayName: contact.name.isNotEmpty ? contact.name : 'Unknown',
                chatPictureUrl: chatPictureUrl,
                showLikeButton: false,
              ),
            ),
          );
        },
        child: CachedCircleAvatar(
          chatPictureUrl: chatPictureUrl,
          radius: responsive.size(24),
          backgroundColor: AppColors.lighterGrey,
          iconColor: AppColors.iconPrimary,
          contactName: contact.name,
        ),
      ),
      title: Text(
        contact.name.isNotEmpty ? contact.name : 'Unknown',
        style: AppTextSizes.regular(context).copyWith(
          color: theme.colorScheme.onSurface,
          fontWeight: FontWeight.w600,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: contact.mobile.isNotEmpty
          ? Text(
              contact.mobile,
              style: AppTextSizes.small(
                context,
              ).copyWith(color: isDark ? Colors.white54 : AppColors.colorGrey),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )
          : null,
      trailing: OutlinedButton(
        onPressed: () => _unblockContact(contact),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: AppColors.error),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(responsive.size(8)),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: responsive.spacing(12),
            vertical: responsive.spacing(6),
          ),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Text(
          'Unblock',
          style: AppTextSizes.small(
            context,
          ).copyWith(color: AppColors.error, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildAllContactCard(ContactLocal contact, ResponsiveSize responsive) {
    final displayName = contact.preferredDisplayName;
    final chatPictureUrl = contact.userDetails?.chatPictureUrl;
    final chatPictureVersion = contact.userDetails?.chatPictureVersion;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ListTile(
      contentPadding: EdgeInsets.symmetric(
        horizontal: responsive.spacing(16),
        vertical: responsive.spacing(4),
      ),
      leading: GestureDetector(
        onTap: () {
          Navigator.of(context, rootNavigator: true).push(
            MaterialPageRoute(
              builder: (_) => AppUserChatPictureView(
                displayName: displayName,
                chatPictureUrl: chatPictureUrl,
                chatPictureVersion: chatPictureVersion,
                showLikeButton: false,
              ),
            ),
          );
        },
        child: CachedCircleAvatar(
          chatPictureUrl: chatPictureUrl,
          chatPictureVersion: chatPictureVersion,
          radius: responsive.size(24),
          backgroundColor: AppColors.lighterGrey,
          iconColor: AppColors.iconPrimary,
          contactName: displayName,
        ),
      ),
      title: Text(
        displayName,
        style: AppTextSizes.regular(context).copyWith(
          color: theme.colorScheme.onSurface,
          fontWeight: FontWeight.w600,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        contact.mobileNo,
        style: AppTextSizes.small(
          context,
        ).copyWith(color: isDark ? Colors.white54 : AppColors.colorGrey),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: OutlinedButton(
        onPressed: () => _blockContact(contact),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: AppColors.error),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(responsive.size(8)),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: responsive.spacing(12),
            vertical: responsive.spacing(6),
          ),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Text(
          'Block',
          style: AppTextSizes.small(
            context,
          ).copyWith(color: AppColors.error, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
