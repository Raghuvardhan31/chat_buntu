import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:chataway_plus/core/themes/app_text_styles.dart';
import 'package:chataway_plus/core/themes/colors/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chataway_plus/features/chat/data/services/chat_engine/index.dart';
import 'package:chataway_plus/core/isolates/contact_sync_isolate.dart';
import '../../../chat/presentation/providers/chat_list_providers/chat_list_provider.dart';
import '../../data/models/contact_local.dart';
import '../providers/contacts_management.dart';
import 'package:chataway_plus/core/routes/route_names.dart';
import 'package:chataway_plus/core/routes/navigation_service.dart';
import 'package:chataway_plus/features/chat/utils/chat_helper.dart';
import 'package:chataway_plus/core/storage/token_storage.dart';
import 'package:chataway_plus/features/shared/widgets/avatars/cached_circle_avatar.dart';
import 'package:chataway_plus/core/sync/authenticated_image_cache_manager.dart';
import 'package:chataway_plus/core/constants/api_url/api_urls.dart';
import 'package:chataway_plus/core/connectivity/connectivity_service.dart';
import 'package:chataway_plus/core/dialog_box/app_dialog_box.dart';
import 'package:chataway_plus/core/responsive_layout/responsive_layout_builder.dart';
import 'package:chataway_plus/core/snackbar/app_snackbar.dart';
import 'package:chataway_plus/features/chat/presentation/pages/media_viewer/app_user_chat_picture_view.dart';

/// Contacts Hub Page - Pure UI Version
///
/// This is a UI-only version ready for new API integration
/// Add your new API calls and business logic in the marked sections
class ContactsHubPage extends ConsumerStatefulWidget {
  const ContactsHubPage({super.key});
  @override
  ConsumerState<ContactsHubPage> createState() => _ContactsHubPageState();
}

class _ContactsHubPageState extends ConsumerState<ContactsHubPage>
    with SingleTickerProviderStateMixin {
  // ============================================
  // RESPONSIVE DESIGN VARIABLES
  // ============================================
  // ============================================
  // UI STATE VARIABLES
  // ============================================
  late TabController _tabController;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  // TODO: Replace with your data model
  List<ContactLocal> _filteredAppUsers = [];
  List<ContactLocal> _filteredNonAppUsers = [];
  bool _isLoading = true;
  bool _isManualRefresh = false;
  String _errorMessage = '';
  DateTime? _lastAvatarPrefetch;
  bool _avatarPrefetchInProgress = false;
  StreamSubscription? _profileUpdateSub; // WhatsApp-style profile updates
  String? _currentUserId;
  String? _currentUserPhoneNormalized;
  // ============================================
  // LIFECYCLE METHODS
  // ============================================
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!mounted) return;
      setState(() {});
    });
    // TODO: Add your initial data loading logic here
    _loadCurrentUserIdentifiers();
    _loadContacts();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _prefetchAvatarsIfOnline();
    });

    // WHATSAPP-STYLE: Listen for profile updates from contacts
    _profileUpdateSub = ChatEngineService.instance.profileUpdateStream.listen((
      update,
    ) async {
      if (kDebugMode) {
        debugPrint('👤 [ContactsHub] Profile update from: ${update.userId}');
      }
      // Refresh from DB and reload UI
      if (mounted) {
        // Wait for notifier to reload from database
        await ref
            .read(contactsManagementNotifierProvider.notifier)
            .loadFromCache();
        // Then refresh UI silently (no loading indicator flash)
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
    _searchFocusNode.dispose();
    _profileUpdateSub?.cancel();
    super.dispose();
  }

  // ============================================
  // DATA METHODS (TODO: Implement with your API)
  // ============================================

  List<ContactLocal> _sortContacts(List<ContactLocal> input) {
    final list = List<ContactLocal>.from(input);
    int cmp(ContactLocal a, ContactLocal b) {
      final an = a.preferredDisplayName.trim().toLowerCase();
      final bn = b.preferredDisplayName.trim().toLowerCase();
      final n = an.compareTo(bn);
      if (n != 0) return n;
      return a.mobileNo.compareTo(b.mobileNo);
    }

    list.sort(cmp);
    return list;
  }

  String _normalizePhone(String input) {
    final digits = input.replaceAll(RegExp(r'[^0-9]'), '');
    return digits.length > 10 ? digits.substring(digits.length - 10) : digits;
  }

  Future<void> _loadCurrentUserIdentifiers() async {
    try {
      final phone = await TokenSecureStorage.instance.getPhoneNumber();
      final userId = await TokenSecureStorage.instance.getCurrentUserIdUUID();

      final normalizedPhone = _normalizePhone(phone ?? '');
      final trimmedUserId = (userId ?? '').trim();

      if (!mounted) return;
      setState(() {
        _currentUserId = trimmedUserId.isEmpty ? null : trimmedUserId;
        _currentUserPhoneNormalized = normalizedPhone.isEmpty
            ? null
            : normalizedPhone;
      });
    } catch (_) {}
  }

  bool _isSelfContact(ContactLocal contact, {String? currentUserIdOverride}) {
    final currentId = (currentUserIdOverride ?? _currentUserId ?? '').trim();
    if (currentId.isNotEmpty) {
      final appUserId = (contact.appUserId ?? '').trim();
      final detailsUserId = (contact.userDetails?.userId ?? '').trim();
      if (appUserId.isNotEmpty && appUserId == currentId) return true;
      if (detailsUserId.isNotEmpty && detailsUserId == currentId) return true;
    }

    final currentPhone = (_currentUserPhoneNormalized ?? '').trim();
    if (currentPhone.isNotEmpty) {
      final contactPhone = _normalizePhone(contact.mobileNo);
      if (contactPhone.isNotEmpty && contactPhone == currentPhone) return true;
    }

    return false;
  }

  void _showSelfNotAllowedMessage() {
    if (!mounted) return;
    AppSnackbar.showInfo(context, 'Currently not allowing texts to yourself..');
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
        debugPrint('⚠️ Error filtering current user: $e');
      }
      return contacts; // Return unfiltered on error
    }
  }

  /// TODO: Implement initial contact loading
  void _loadContacts({bool silent = false}) async {
    if (!mounted) return;
    if (!silent) {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });
    }

    // TODO: Add your API call here to load contacts
    // Pull from local database via providers
    await ref.read(contactsManagementNotifierProvider.notifier).loadFromCache();
    final List<ContactLocal> appUsers = ref.read(appUserContactsProvider);
    final List<ContactLocal> nonAppUsers = ref.read(nonAppUserContactsProvider);

    // Exclude current user's own contact from both lists
    final filteredApp = await _excludeCurrentUser(appUsers);
    final filteredNon = await _excludeCurrentUser(nonAppUsers);

    if (!mounted) return;
    setState(() {
      _filteredAppUsers = _sortContacts(filteredApp);
      _filteredNonAppUsers = _sortContacts(filteredNon);
      _isLoading = false;
    });
    // Background prefetch (non-blocking)
    Future.microtask(() {
      if (!mounted) return;
      _prefetchAvatarsIfOnline();
    });
  }

  /// Refresh contacts - syncs with server (same flow as login)
  Future<void> _refreshContacts({bool manual = true}) async {
    if (!mounted) return;

    // Check if offline before attempting refresh
    if (!ConnectivityCache.instance.isOnline) {
      AppSnackbar.showOfflineWarning(
        context,
        "You're offline. Connect to internet",
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _isManualRefresh = manual;
      _errorMessage = '';
    });

    try {
      if (kDebugMode) {
        debugPrint('🔄 [ContactsHub] Starting contact refresh...');
      }

      // Step 1: Sync contacts using isolate (calls check-contacts API)
      final handler = ContactSyncIsolateHandler();
      final syncResponse = await handler.syncContacts();

      if (!mounted) return;

      if (syncResponse.success) {
        final total = syncResponse.totalContacts ?? syncResponse.contactCount;
        final registered = syncResponse.appUsers ?? 0;
        final nonRegistered = syncResponse.regularContacts ?? 0;

        if (kDebugMode) {
          debugPrint('📦 [ContactsHub] Sync complete: Total=$total');
          debugPrint('🟩 [ContactsHub] Registered App Users=$registered');
          debugPrint('🟥 [ContactsHub] Non-App Users=$nonRegistered');
        }

        // Step 2: Refresh providers from database
        await ref
            .read(contactsManagementNotifierProvider.notifier)
            .refreshContacts();

        if (kDebugMode) {
          debugPrint('💾 [ContactsHub] Providers refreshed from database');
        }
      } else {
        if (kDebugMode) {
          debugPrint(
            '❌ [ContactsHub] Sync failed: ${syncResponse.error ?? 'Unknown error'}',
          );
        }
        if (!mounted) return;
        setState(() {
          _errorMessage = syncResponse.error ?? 'Failed to refresh contacts';
        });
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [ContactsHub] Refresh exception: $e');
      }
      if (!mounted) return;

      // Check if this is an offline/network error
      final errorStr = e.toString().toLowerCase();
      final isOfflineError =
          errorStr.contains('socketexception') ||
          errorStr.contains('clientexception') ||
          errorStr.contains('host lookup') ||
          errorStr.contains('network') ||
          errorStr.contains('connection') ||
          !ConnectivityCache.instance.isOnline;

      if (isOfflineError) {
        AppSnackbar.showOfflineWarning(
          context,
          "You're offline. Connect to internet",
        );
      } else {
        setState(() {
          _errorMessage = 'Error refreshing contacts: $e';
        });
      }
    }

    // Step 3: Update UI with filtered lists
    if (!mounted) return;
    final List<ContactLocal> appUsers = ref.read(appUserContactsProvider);
    final List<ContactLocal> nonAppUsers = ref.read(nonAppUserContactsProvider);

    final filteredApp = await _excludeCurrentUser(appUsers);
    final filteredNon = await _excludeCurrentUser(nonAppUsers);

    if (!mounted) return;
    setState(() {
      _filteredAppUsers = _sortContacts(filteredApp);
      _filteredNonAppUsers = _sortContacts(filteredNon);
      _isLoading = false;
      _isManualRefresh = false;
    });

    // Background prefetch after refresh
    if (!mounted) return;
    _prefetchAvatarsIfOnline();
  }

  // ============================================
  // SEARCH & FILTER LOGIC
  // ============================================
  Future<void> _filterContacts(String query) async {
    if (!mounted) return;
    if (query.isEmpty) {
      final List<ContactLocal> appUsers = ref.read(appUserContactsProvider);
      final List<ContactLocal> nonAppUsers = ref.read(
        nonAppUserContactsProvider,
      );

      // Exclude current user's own contact from both lists
      final filteredApp = await _excludeCurrentUser(appUsers);
      final filteredNon = await _excludeCurrentUser(nonAppUsers);

      if (!mounted) return;
      setState(() {
        _filteredAppUsers = _sortContacts(filteredApp);
        _filteredNonAppUsers = _sortContacts(filteredNon);
      });
      return;
    }

    // TODO: Implement your search logic based on your data model
    final lowerQuery = query.toLowerCase();
    final List<ContactLocal> appUsers = ref.read(appUserContactsProvider);
    final List<ContactLocal> nonAppUsers = ref.read(nonAppUserContactsProvider);

    // Apply search filter
    final searchedApp = appUsers
        .where(
          (c) =>
              c.preferredDisplayName.toLowerCase().contains(lowerQuery) ||
              c.mobileNo.contains(query),
        )
        .toList();
    final searchedNon = nonAppUsers
        .where(
          (c) =>
              c.preferredDisplayName.toLowerCase().contains(lowerQuery) ||
              c.mobileNo.contains(query),
        )
        .toList();

    // Exclude current user's own contact from search results
    final filteredApp = await _excludeCurrentUser(searchedApp);
    final filteredNon = await _excludeCurrentUser(searchedNon);

    if (!mounted) return;
    setState(() {
      _filteredAppUsers = _sortContacts(filteredApp);
      _filteredNonAppUsers = _sortContacts(filteredNon);
    });
  }

  ResponsiveSize _responsiveFor(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return ResponsiveSize(
      context: context,
      constraints: BoxConstraints(maxWidth: width),
      breakpoint: DeviceBreakpoint.fromWidth(width),
    );
  }

  // ============================================
  // NAVIGATION ACTIONS
  // ============================================

  /// Invite contact to download ChatAway+ app
  void _inviteContact(dynamic contact) {
    final responsive = _responsiveFor(context);
    AppDialogBox.show<void>(
      context,
      title: 'Invite Contact',
      titleAlignment: TextAlign.left,
      message:
          'Please inform them to download ChatAway+ app to start chatting.',
      buttons: const [],
      dialogWidth: responsive.size(295),
      customActions: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              padding: EdgeInsets.symmetric(
                horizontal: responsive.spacing(16),
                vertical: responsive.spacing(8),
              ),
            ),
            child: Text(
              'OK',
              style: AppTextSizes.regular(
                context,
              ).copyWith(fontWeight: FontWeight.w600, color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }

  /// Navigate to individual chat with selected contact
  /// Navigate to individual chat with selected contact
  void _messageContact(ContactLocal contact) async {
    final currentUserId = await ChatHelper.getCurrentUserId();

    if (currentUserId == null) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Please login first')));
      }
      return;
    }

    if (_isSelfContact(contact, currentUserIdOverride: currentUserId)) {
      _showSelfNotAllowedMessage();
      return;
    }

    if (!mounted) return;

    // Await navigation so we can refresh after the chat screen is popped.
    await Navigator.pushNamed(
      context,
      RouteNames.oneToOneChat,
      arguments: {
        'contactName': contact.preferredDisplayName,
        'receiverId': contact.userDetails?.userId ?? contact.mobileNo,
        'currentUserId': currentUserId,
      },
    );

    // WHATSAPP-STYLE: Force refresh chat list so new conversation appears immediately
    // Use forceRefreshContacts() to bypass debounce - critical for new chats
    try {
      await ref.read(chatListNotifierProvider.notifier).forceRefreshContacts();
      if (kDebugMode) {
        debugPrint(
          '✅ Chat list refreshed after returning from individual chat',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error refreshing chat list after message: $e');
      }
    }
  }

  /// TODO: Implement profile navigation
  void _navigateToProfile() {
    Navigator.of(context).pushNamed(RouteNames.currentUserProfile);
  }

  /// Navigate to blocked contacts page
  void _navigateToBlockContacts() {
    NavigationService.goToBlockContacts();
  }

  /// Navigate back to chat list
  void _navigateBack() {
    NavigationService.goToChatList();
  }
  // ============================================
  // UI BUILD METHODS
  // ============================================

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final viewInsets = mediaQuery.viewInsets.bottom;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;

        if (_isSearching) {
          if (_searchController.text.isNotEmpty) {
            setState(() {
              _searchController.clear();
            });
            _filterContacts('');
          } else {
            setState(() {
              _isSearching = false;
            });
            _searchFocusNode.unfocus();
            FocusScope.of(context).unfocus();
          }
          return;
        }

        if (_searchFocusNode.hasFocus) {
          _searchFocusNode.unfocus();
          FocusScope.of(context).unfocus();
          return;
        }

        if (_searchController.text.isNotEmpty) {
          setState(() {
            _searchController.clear();
          });
          _filterContacts('');
          return;
        }

        _navigateBack();
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        resizeToAvoidBottomInset: false,
        appBar: _buildAppBar(),
        body: SafeArea(
          top: false,
          bottom: true,
          child: AnimatedPadding(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            padding: EdgeInsets.only(bottom: viewInsets > 0 ? viewInsets : 0),
            child: _isLoading ? _buildLoadingState() : _buildContent(),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final responsive = _responsiveFor(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AppBar(
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
        onPressed: _navigateBack,
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

            // Only focus when user explicitly opens search
            if (_isSearching) {
              Future.delayed(const Duration(milliseconds: 120), () {
                if (mounted) {
                  FocusScope.of(context).requestFocus(_searchFocusNode);
                }
              });
            } else {
              _searchFocusNode.unfocus();
            }
          },
        ),
        PopupMenuButton<String>(
          icon: Icon(
            Icons.more_vert,
            color: isDark ? Colors.white : AppColors.iconPrimary,
            size: responsive.size(24),
          ),
          offset: Offset(0, responsive.spacing(100)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(responsive.size(8)),
          ),
          elevation: 8.0,
          color: Theme.of(context).colorScheme.surface,
          onSelected: (String value) {
            switch (value) {
              case 'refresh':
                _refreshContacts();
                break;
              case 'profile':
                _navigateToProfile();
                break;
              case 'block_contacts':
                _navigateToBlockContacts();
                break;
            }
          },
          itemBuilder: (BuildContext context) => [
            PopupMenuItem<String>(
              value: 'refresh',
              height: responsive.size(48),
              padding: EdgeInsets.symmetric(
                horizontal: responsive.spacing(24),
                vertical: responsive.spacing(12),
              ),
              child: Text(
                'Refresh',
                style: AppTextSizes.natural(context).copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.normal,
                ),
              ),
            ),
            PopupMenuItem<String>(
              value: 'profile',
              height: responsive.size(48),
              padding: EdgeInsets.symmetric(
                horizontal: responsive.spacing(24),
                vertical: responsive.spacing(12),
              ),
              child: Text(
                'Profile',
                style: AppTextSizes.natural(context).copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.normal,
                ),
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
                style: AppTextSizes.natural(context).copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.normal,
                ),
              ),
            ),
          ],
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
                  Icons.people,
                  size: responsive.size(20),
                  color: _tabController.index == 0
                      ? (isDark ? Colors.white : AppColors.colorBlack)
                      : (isDark ? Colors.white54 : AppColors.colorGrey),
                ),
                SizedBox(width: responsive.spacing(8)),
                Text(
                  'Users',
                  style: AppTextSizes.regular(context).copyWith(
                    fontWeight: FontWeight.w600,
                    color: _tabController.index == 0
                        ? (isDark ? Colors.white : AppColors.colorBlack)
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
                  Icons.person_add,
                  size: responsive.size(20),
                  color: _tabController.index == 1
                      ? (isDark ? Colors.white : AppColors.colorBlack)
                      : (isDark ? Colors.white54 : AppColors.colorGrey),
                ),
                SizedBox(width: responsive.spacing(8)),
                Text(
                  'Invite',
                  style: AppTextSizes.regular(context).copyWith(
                    fontWeight: FontWeight.w600,
                    color: _tabController.index == 1
                        ? (isDark ? Colors.white : AppColors.colorBlack)
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

  Widget _buildTitle() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Text(
      'Find people',
      style: AppTextSizes.large(context).copyWith(
        fontWeight: FontWeight.bold,
        color: isDark ? Colors.white : AppColors.colorGrey,
      ),
    );
  }

  Widget _buildSearchField() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextField(
      controller: _searchController,
      autofocus: false, // avoid keyboard popping unexpectedly
      focusNode: _searchFocusNode,
      onChanged: _filterContacts,
      cursorColor: isDark ? Colors.white : AppColors.colorBlack,
      style: AppTextSizes.regular(
        context,
      ).copyWith(color: isDark ? Colors.white : AppColors.iconPrimary),
      decoration: InputDecoration(
        hintText: "Search contacts",
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

  Widget _buildContent() {
    if (_errorMessage.isNotEmpty) {
      return _buildErrorState();
    }

    ref.watch(appUserContactsProvider);
    ref.watch(nonAppUserContactsProvider);

    final List<ContactLocal> usersList = _filteredAppUsers;
    final List<ContactLocal> inviteList = _filteredNonAppUsers;

    return TabBarView(
      controller: _tabController,
      children: [
        _buildContactList(usersList, isAppUser: true),
        _buildContactList(inviteList, isAppUser: false),
      ],
    );
  }

  Widget _buildContactList(
    List<ContactLocal> contacts, {
    required bool isAppUser,
  }) {
    final responsive = _responsiveFor(context);
    if (contacts.isEmpty) {
      return _buildEmptyState(isAppUser: isAppUser);
    }

    return ListView.builder(
      padding: EdgeInsets.only(
        top: responsive.spacing(4),
        bottom: responsive.spacing(110),
      ),
      itemCount: contacts.length,
      itemBuilder: (context, index) {
        return _buildContactTile(contacts[index], isAppUser: isAppUser);
      },
    );
  }

  Widget _buildContactTile(ContactLocal contact, {required bool isAppUser}) {
    final responsive = _responsiveFor(context);
    final isSelf = _isSelfContact(contact);
    return InkWell(
      onTap: () {
        if (isSelf) {
          _showSelfNotAllowedMessage();
          return;
        }
        if (isAppUser) {
          _messageContact(contact);
        } else {
          _inviteContact(contact);
        }
      },
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: responsive.spacing(16),
          vertical: responsive.spacing(11),
        ),
        child: Row(
          children: [
            _buildContactAvatar(contact, isAppUser: isAppUser),
            SizedBox(width: responsive.spacing(12)),
            Expanded(
              child: _buildContactContent(
                contact,
                isAppUser: isAppUser,
                isSelf: isSelf,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactContent(
    ContactLocal contact, {
    required bool isAppUser,
    required bool isSelf,
  }) {
    final responsive = _responsiveFor(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final displayName = isSelf
        ? '${contact.preferredDisplayName} (You)'
        : contact.preferredDisplayName;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          displayName, // TODO: Replace with contact preferred display name
          style: AppTextSizes.regular(
            context,
          ).copyWith(color: isDark ? Colors.white : AppColors.colorBlack),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        SizedBox(height: responsive.spacing(4)),
        Text(
          contact.mobileNo, // TODO: Replace with contact.phone
          style: AppTextSizes.natural(
            context,
          ).copyWith(color: isDark ? Colors.white70 : AppColors.colorGrey),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildContactAvatar(ContactLocal contact, {required bool isAppUser}) {
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
    if (!mounted) return;
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
      final List<ContactLocal> list = _filteredAppUsers.isNotEmpty
          ? _filteredAppUsers
          : ref.read(appUserContactsProvider);
      if (list.isEmpty) return;
      final maxCount = 30;
      int count = 0;
      for (final c in list) {
        if (count >= maxCount) break;
        final url = c.userDetails?.chatPictureUrl;
        final version = c.userDetails?.chatPictureVersion;
        if (url == null || url.isEmpty) continue;

        final base = url.startsWith('http')
            ? url
            : '${ApiUrls.mediaBaseUrl}$url';
        String fullUrl;
        if (version == null || version.trim().isEmpty) {
          fullUrl = base;
        } else {
          try {
            final uri = Uri.parse(base);
            final params = Map<String, String>.from(uri.queryParameters);
            params['v'] = version;
            fullUrl = uri.replace(queryParameters: params).toString();
          } catch (_) {
            final sep = base.contains('?') ? '&' : '?';
            fullUrl = '$base${sep}v=$version';
          }
        }
        try {
          // Use AuthenticatedImageCacheManager for profile pictures
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
            'Loading contacts...',
            style: AppTextSizes.regular(
              context,
            ).copyWith(color: isDark ? Colors.white : AppColors.colorBlack),
          ),
          if (_isManualRefresh) ...[
            SizedBox(height: responsive.spacing(12)),
            Text(
              'Please don\'t press until it finishes (few seconds)',
              style: AppTextSizes.small(
                context,
              ).copyWith(color: isDark ? Colors.white54 : AppColors.colorGrey),
              textAlign: TextAlign.center,
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
            'Error loading contacts',
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

  Widget _buildEmptyState({required bool isAppUser}) {
    final responsive = _responsiveFor(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isAppUser ? Icons.people_outline : Icons.person_add_alt_outlined,
            size: responsive.size(64),
            color: isDark ? Colors.white54 : AppColors.iconSecondary,
          ),
          SizedBox(height: responsive.spacing(16)),
          Text(
            isAppUser ? 'No app users found' : 'No contacts to invite',
            style: AppTextSizes.large(
              context,
            ).copyWith(color: isDark ? Colors.white : AppColors.colorBlack),
          ),
          SizedBox(height: responsive.spacing(8)),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: responsive.spacing(32)),
            child: Text(
              isAppUser
                  ? 'Contacts using ChatAway+ will appear here'
                  : 'Invite your contacts to join ChatAway+',
              textAlign: TextAlign.center,
              style: AppTextSizes.regular(
                context,
              ).copyWith(color: isDark ? Colors.white54 : AppColors.colorGrey),
            ),
          ),
        ],
      ),
    );
  }
}
