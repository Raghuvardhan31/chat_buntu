import 'package:flutter/material.dart';
import 'package:chataway_plus/core/themes/app_text_styles.dart';
import 'package:chataway_plus/core/themes/colors/app_colors.dart';
import 'package:chataway_plus/core/responsive_layout/responsive_layout_builder.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/connectivity/connectivity_service.dart';
import 'package:chataway_plus/core/snackbar/app_snackbar.dart';
import 'package:chataway_plus/core/database/tables/cache/app_startup_snapshot_table.dart';
import 'package:chataway_plus/core/database/tables/user/current_user_table.dart';
import 'package:chataway_plus/core/storage/token_storage.dart';
import 'package:chataway_plus/core/routes/route_names.dart';

class DefaultStatusPage extends ConsumerStatefulWidget {
  final Function(String)? onStatusSelected;
  final bool autoFocus;
  final String initialStatus;
  const DefaultStatusPage({
    super.key,
    this.onStatusSelected,
    this.autoFocus = false,
    this.initialStatus = '',
  });
  @override
  ConsumerState<DefaultStatusPage> createState() => _DefaultStatusPageState();
}

class _DefaultStatusPageState extends ConsumerState<DefaultStatusPage> {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _textFocusNode = FocusNode();

  bool _isEditing = false;
  String _originalStatus = '';
  String _currentStatus = '';
  static const int maxStatusLength = 85;

  static const List<String> _predefined = [
    'Sharing moments on ChatAway+',
    'ChatAway+ is my voice',
    'Only available on ChatAway+',
    'Currently busy',
    'Phone on silent',
    'Delay leads to regret',
    'Any dream that has your tears - you must achieve it',
    'Sometimes your courage brings tears - but that doesn\'t mean you are weak',
    'Karma approaches us slowly like an elder, but strikes like a warrior',
    'Those who chase success see two suns in a day',
    'Consistency gives you wings to reach your destination',
    'Fear has no children - just defeat it',
    'Nature is the best reset button for our lives',
    "Don't forget to add people to your favorites",
    'Sometimes time stops at joy and pain, but remember it moves eventually',
    'You never graduate from world school',
  ];

  @override
  void initState() {
    super.initState();
    _originalStatus = widget.initialStatus;
    _currentStatus = widget.initialStatus;
    _textController.text = widget.initialStatus;
    if (widget.autoFocus) {
      _isEditing = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _textFocusNode.requestFocus();
        _textController.selection = TextSelection.fromPosition(
          TextPosition(offset: _textController.text.length),
        );
      });
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _textFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _safeNavigateBack();
      },
      child: ResponsiveLayoutBuilder(
        builder: (context, constraints, breakpoint) {
          final responsive = ResponsiveSize(
            context: context,
            constraints: constraints,
            breakpoint: breakpoint,
          );

          final theme = Theme.of(context);
          final isDark = theme.brightness == Brightness.dark;

          return Scaffold(
            backgroundColor: theme.scaffoldBackgroundColor,
            appBar: AppBar(
              backgroundColor: theme.scaffoldBackgroundColor,
              scrolledUnderElevation: 0,
              leadingWidth: responsive.size(30),
              title: _isEditing
                  ? null
                  : Padding(
                      padding: EdgeInsets.only(left: responsive.spacing(10)),
                      child: Text(
                        'Share your voice',
                        style: AppTextSizes.large(
                          context,
                        ).copyWith(color: theme.colorScheme.onSurface),
                      ),
                    ),
              centerTitle: false,
              leading: Padding(
                padding: EdgeInsets.only(left: responsive.spacing(16)),
                child: Center(
                  child: IconButton(
                    iconSize: responsive.size(24),
                    onPressed: _safeNavigateBack,
                    icon: Icon(Icons.arrow_back, color: AppColors.primary),
                    padding: EdgeInsets.zero,
                    alignment: Alignment.center,
                  ),
                ),
              ),
              actions: [
                if (_isEditing)
                  Center(
                    child: Padding(
                      padding: EdgeInsets.only(right: responsive.spacing(8)),
                      child: Text(
                        '${_emojiAwareLength(_textController.text)}/$maxStatusLength',
                        style: AppTextSizes.small(
                          context,
                        ).copyWith(color: AppColors.colorGrey),
                      ),
                    ),
                  ),
                IconButton(
                  iconSize: responsive.size(24),
                  icon: Icon(
                    Icons.copyright_outlined,
                    color: AppColors.primary,
                  ),
                  onPressed: _showQuotes,
                ),
                IconButton(
                  iconSize: responsive.size(24),
                  icon: Icon(
                    _isEditing ? Icons.close : Icons.edit,
                    color: _isEditing ? AppColors.error : AppColors.primary,
                  ),
                  onPressed: _isEditing ? _cancelEditing : _toggleEditing,
                ),
                if (_isEditing)
                  IconButton(
                    iconSize: responsive.size(24),
                    icon: Icon(
                      Icons.check,
                      color: isDark ? Colors.white : AppColors.iconPrimary,
                    ),
                    onPressed: () => _updateStatus(_textController.text),
                  ),
              ],
            ),
            body: Padding(
              padding: EdgeInsets.symmetric(horizontal: responsive.spacing(8)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: responsive.spacing(8),
                      vertical: responsive.spacing(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              'Current One...',
                              style: AppTextSizes.regular(context).copyWith(
                                color: isDark
                                    ? Colors.white54
                                    : AppColors.colorGrey,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox.shrink(),
                          ],
                        ),
                        SizedBox(height: responsive.spacing(8)),
                        _isEditing
                            ? TextField(
                                controller: _textController,
                                focusNode: _textFocusNode,
                                maxLines: 2,
                                keyboardType: TextInputType.multiline,
                                textCapitalization:
                                    TextCapitalization.sentences,
                                decoration: InputDecoration(
                                  hintText: 'Write your custom message here!',
                                  hintStyle: AppTextSizes.regular(context)
                                      .copyWith(
                                        color: isDark
                                            ? Colors.white54
                                            : AppColors.colorGrey,
                                        fontWeight: FontWeight.w300,
                                      ),
                                  filled: false,
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  counterText: '',
                                  contentPadding: const EdgeInsets.only(
                                    top: 0,
                                    bottom: 0,
                                  ),
                                  isDense: true,
                                ),
                                style: AppTextSizes.regular(context).copyWith(
                                  color: theme.colorScheme.onSurface,
                                  height: 1.2,
                                ),
                                inputFormatters: [
                                  LengthLimitingTextInputFormatter(
                                    maxStatusLength,
                                  ),
                                ],
                                onChanged: (_) => setState(() {}),
                              )
                            : GestureDetector(
                                onTap: _toggleEditing,
                                child: Text(
                                  (_currentStatus.isEmpty ||
                                          _currentStatus ==
                                              'Write custom or tap to choose preset')
                                      ? 'Write your custom message here!'
                                      : _currentStatus,
                                  style: AppTextSizes.natural(context).copyWith(
                                    color:
                                        (_currentStatus.isEmpty ||
                                            _currentStatus ==
                                                'Write custom or tap to choose preset')
                                        ? (isDark
                                              ? Colors.white54
                                              : AppColors.colorGrey)
                                        : theme.colorScheme.onSurface,
                                  ),
                                ),
                              ),
                      ],
                    ),
                  ),
                  SizedBox(height: responsive.spacing(4)),
                  Divider(
                    color: isDark ? Colors.white24 : Colors.grey.shade200,
                    thickness: 1.0,
                    height: responsive.spacing(1),
                  ),
                  SizedBox(height: responsive.spacing(4)),
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: responsive.spacing(8),
                    ),
                    child: Text(
                      'We recommend personalizing your status',
                      style: AppTextSizes.small(context).copyWith(
                        color: theme.colorScheme.onSurface,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                  SizedBox(height: responsive.spacing(6)),
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: responsive.spacing(8),
                    ),
                    child: Text(
                      'Available Options',
                      style: AppTextSizes.regular(context).copyWith(
                        color: isDark ? Colors.white54 : AppColors.colorGrey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  SizedBox(height: responsive.spacing(4)),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _combinedStatuses().length,
                      itemBuilder: (context, index) {
                        final statuses = _combinedStatuses();
                        final status = statuses[index];
                        final isSelected = status == _currentStatus;
                        final isCustom =
                            !_predefined.contains(status) &&
                            status == _currentStatus;
                        return GestureDetector(
                          onTap: () => _updateStatus(status),
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              vertical: responsive.spacing(12),
                              horizontal: responsive.spacing(8),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    status,
                                    style: AppTextSizes.natural(context)
                                        .copyWith(
                                          color: isSelected
                                              ? AppColors.primary
                                              : theme.colorScheme.onSurface,
                                        ),
                                    textAlign: TextAlign.left,
                                  ),
                                ),
                                if (isCustom || isSelected) ...[
                                  SizedBox(width: responsive.spacing(8)),
                                  Icon(
                                    Icons.mic,
                                    color: AppColors.primary,
                                    size: responsive.size(22),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  int _emojiAwareLength(String text) => text.characters.length;

  List<String> _combinedStatuses() {
    final list = List<String>.from(_predefined);
    if (_currentStatus.isNotEmpty &&
        _currentStatus != 'Write custom or tap to choose preset') {
      if (list.contains(_currentStatus)) list.remove(_currentStatus);
      final insertIndex = list.length >= 5 ? 5 : list.length;
      list.insert(insertIndex, _currentStatus);
    }
    return list;
  }

  void _toggleEditing() {
    setState(() {
      _isEditing = true;
      if (_currentStatus.isEmpty ||
          _currentStatus == 'Write custom or tap to choose preset' ||
          _currentStatus == 'Write your custom message here!') {
        _originalStatus = '';
        _textController.text = '';
      } else {
        _originalStatus = _currentStatus;
        _textController.text = _currentStatus;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _textFocusNode.requestFocus();
        _textController.selection = TextSelection.fromPosition(
          TextPosition(offset: _textController.text.length),
        );
      });
    });
  }

  void _cancelEditing() {
    setState(() {
      _isEditing = false;
      _textController.text = _originalStatus;
    });
  }

  Future<void> _updateStatus(String status) async {
    final online = ref
        .read(internetStatusStreamProvider)
        .maybeWhen(data: (v) => v, orElse: () => false);
    if (!online) {
      AppSnackbar.showOfflineWarning(
        context,
        "You're offline. Please connect to the internet",
      );
      return;
    }

    final newStatus = status.trim();
    final prevStatus = _currentStatus;
    setState(() {
      _currentStatus = newStatus;
      _isEditing = false;
    });

    try {
      final result = widget.onStatusSelected?.call(newStatus);
      if (result is Future) {
        await result;
      }
      if (!mounted) return;

      FocusScope.of(context).unfocus();
      await Future.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;
      // Upsert snapshot (compute profileComplete from local DB)
      try {
        final userId = await TokenSecureStorage.instance.getCurrentUserIdUUID();
        if (userId != null && userId.isNotEmpty) {
          final row = await CurrentUserProfileTable.instance.getByUserId(
            userId,
          );
          final firstName = row?[CurrentUserProfileTable.columnFirstName]
              ?.toString()
              .trim();
          final status = row?[CurrentUserProfileTable.columnStatusContent]
              ?.toString()
              .trim();
          final statusMeaningful =
              status != null &&
              status.isNotEmpty &&
              status != 'Write custom or tap to choose preset';
          final profileComplete =
              (firstName != null && firstName.isNotEmpty) && statusMeaningful;
          final route = profileComplete
              ? RouteNames.mainNavigation
              : RouteNames.currentUserProfile;
          await AppStartupSnapshotTable.instance.upsertSnapshot(
            userId: userId,
            profileComplete: profileComplete,
            lastKnownRoute: route,
          );
        }
      } catch (e) {
        // ignore snapshot errors silently
      }
      if (!mounted) return;
      AppSnackbar.showSuccess(
        context,
        'Status updated',
        bottomPosition: 120,
        duration: const Duration(seconds: 1),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _currentStatus = prevStatus;
        });
      }
      FocusScope.of(context).unfocus();
      await Future.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;
      AppSnackbar.showError(
        context,
        'Error updating status. Please try again',
        bottomPosition: 120,
        duration: const Duration(seconds: 2),
      );
    }
  }

  void _safeNavigateBack() {
    Navigator.of(context).pop();
  }

  void _showQuotes() {
    final dialogTheme = Theme.of(context);
    final dialogIsDark = dialogTheme.brightness == Brightness.dark;
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return Dialog(
          backgroundColor: dialogTheme.colorScheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.8,
              maxWidth: MediaQuery.of(ctx).size.width * 0.9,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Crafted by Raju Goud, Founder & CEO of ChatAway+',
                    style: AppTextSizes.regular(
                      context,
                    ).copyWith(color: AppColors.primary),
                    textAlign: TextAlign.center,
                  ),
                ),
                Divider(height: 1, color: dialogIsDark ? Colors.white24 : null),
                Flexible(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    children: [
                      _quote('Delay leads to regret'),
                      _quote(
                        'Any dream that has your tears - you must achieve it',
                      ),
                      _quote(
                        'Sometimes your courage brings tears - but that doesn\'t mean you are weak',
                      ),
                      _quote(
                        'Karma approaches us slowly like an elder, but strikes like a warrior',
                      ),
                      _quote('Those who chase success see two suns in a day'),
                      _quote(
                        'Consistency gives you wings to reach your destination',
                      ),
                      _quote('Fear has no children - just defeat it'),
                      _quote("Don't forget to add people to your favorites"),
                      _quote('Nature is the best reset button for our lives'),
                      _quote(
                        'Sometimes time stops at joy and pain, but remember it moves eventually',
                      ),
                      _quote('You never graduate from world school'),
                    ],
                  ),
                ),
                Divider(height: 1, color: dialogIsDark ? Colors.white24 : null),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: Text(
                      'Close',
                      style: AppTextSizes.regular(
                        context,
                      ).copyWith(color: AppColors.primary),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _quote(String q) {
    final quoteTheme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        q,
        style: AppTextSizes.regular(
          context,
        ).copyWith(color: quoteTheme.colorScheme.onSurface),
      ),
    );
  }
}
