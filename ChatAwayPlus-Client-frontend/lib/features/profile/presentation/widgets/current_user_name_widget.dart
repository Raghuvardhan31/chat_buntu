import 'package:chataway_plus/core/snackbar/app_snackbar.dart';
import 'package:flutter/material.dart';
import 'package:chataway_plus/core/themes/app_text_styles.dart';
import 'package:chataway_plus/core/responsive_layout/responsive_layout_builder.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/profile/profile_page_providers.dart';
import '../../../../core/themes/colors/app_colors.dart';
import '../../../../core/connectivity/connectivity_service.dart';
import 'package:chataway_plus/core/database/tables/cache/app_startup_snapshot_table.dart';
import 'package:chataway_plus/core/storage/token_storage.dart';
import 'package:chataway_plus/core/routes/route_names.dart';
import 'package:chataway_plus/core/database/tables/user/current_user_table.dart';

class CurrentUserNameWidget extends ConsumerStatefulWidget {
  final String initialName;
  final void Function(String)? onNameSaved;
  final ResponsiveSize? responsive;
  const CurrentUserNameWidget({
    super.key,
    this.initialName = '',
    this.onNameSaved,
    this.responsive,
  });
  @override
  ConsumerState<CurrentUserNameWidget> createState() =>
      _CurrentUserNameWidgetState();
}

class _CurrentUserNameWidgetState extends ConsumerState<CurrentUserNameWidget> {
  late TextEditingController _nameController;
  bool _isModalOpened = false;
  static const int maxNameLength = 30;
  bool online = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    // Note: Profile is already loaded by parent CurrentUserProfilePage
    // No need to call loadProfileLocalOnlyActionProvider here - it causes redundant DB reads
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final responsive = widget.responsive;
    final name = ref.watch(profileDisplayNameProvider);
    final display = (name.isEmpty) ? 'Enter your display name' : name;
    final isPlaceholder = name.isEmpty;
    online = ref
        .watch(internetStatusStreamProvider)
        .maybeWhen(data: (v) => v, orElse: () => false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(
            left: responsive != null ? responsive.spacing(37) : 37,
          ), // 37 px
          child: Text(
            'Name',
            style: AppTextSizes.regular(
              context,
            ).copyWith(color: Theme.of(context).colorScheme.onSurface),
          ),
        ),
        SizedBox(
          height: responsive != null ? responsive.spacing(5) : 5,
        ), // 5 px
        SizedBox(
          width: double.infinity,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _showNameEditor,
            child: Padding(
              padding: EdgeInsets.symmetric(
                vertical: responsive != null ? responsive.spacing(8) : 8,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(
                    Icons.person,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white
                        : AppColors.iconPrimary,
                    size: responsive != null ? responsive.size(24) : 24,
                    // 24 px
                  ),
                  SizedBox(
                    width: responsive != null ? responsive.spacing(13) : 13,
                  ), // 13 px
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        display,
                        style: isPlaceholder
                            ? AppTextSizes.natural(context).copyWith(
                                color:
                                    Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? Colors.white54
                                    : AppColors.colorGrey,
                              )
                            : AppTextSizes.natural(context).copyWith(
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ),
                  const SizedBox.shrink(),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showNameEditor() {
    if (_isModalOpened) return;
    _isModalOpened = true;
    _nameController.text = ref.read(profileDisplayNameProvider);

    final sheetTheme = Theme.of(context);
    final sheetIsDark = sheetTheme.brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final responsive = widget.responsive;
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            // AnimatedPadding prevents keyboard "jump" when switching to emoji keyboard
            return AnimatedPadding(
              duration: const Duration(milliseconds: 100),
              curve: Curves.easeOut,
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(
                  horizontal: responsive?.spacing(20) ?? 20.0, // 20 px
                  vertical: responsive?.spacing(16) ?? 16.0, // 16 px
                ),
                decoration: BoxDecoration(
                  color: sheetTheme.colorScheme.surface,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(
                      responsive?.size(20) ?? 20.0,
                    ), // 20 px
                    topRight: Radius.circular(
                      responsive?.size(20) ?? 20.0,
                    ), // 20 px
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.person,
                          size: responsive?.size(18) ?? 18.0,
                          // 18 px
                          color: sheetTheme.colorScheme.onSurface,
                        ),
                        SizedBox(
                          width: responsive?.spacing(8) ?? 8.0, // 8 px
                        ),
                        Expanded(
                          child: TextField(
                            controller: _nameController,
                            autofocus: true,
                            maxLines: 1,
                            inputFormatters: [
                              LengthLimitingTextInputFormatter(maxNameLength),
                            ],
                            cursorColor: sheetTheme.colorScheme.onSurface,
                            style: AppTextSizes.small(context).copyWith(
                              color: sheetTheme.colorScheme.onSurface,
                              fontWeight: FontWeight.w500,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Enter your display name',
                              hintStyle: AppTextSizes.natural(context).copyWith(
                                color: sheetIsDark
                                    ? Colors.white54
                                    : AppColors.colorGrey,
                              ),
                              filled: false,
                              border: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                            ),
                            onChanged: (_) => setModalState(() {}),
                          ),
                        ),
                      ],
                    ),
                    // Divider below text field
                    Divider(
                      height: 1,
                      thickness: 1,
                      color: sheetIsDark
                          ? Colors.white24
                          : Colors.grey.shade300,
                    ),
                    Padding(
                      padding: EdgeInsets.only(
                        top: responsive?.spacing(8) ?? 8.0,
                      ), // 8 px
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          '${_nameController.text.characters.length}/$maxNameLength',
                          style: AppTextSizes.small(context).copyWith(
                            color: sheetIsDark
                                ? Colors.white54
                                : AppColors.colorGrey,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      height: responsive?.spacing(20) ?? 20.0, // 20 px
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text(
                            'Cancel',
                            style: AppTextSizes.regular(context).copyWith(
                              color: AppColors.colorGrey,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: responsive?.spacing(50) ?? 50.0,
                        ), // 50 px
                        TextButton(
                          onPressed: _nameController.text.trim().isEmpty
                              ? null
                              : () async {
                                  if (!mounted) return;

                                  final rootContext = this.context;

                                  if (!online) {
                                    AppSnackbar.showOfflineWarning(
                                      rootContext,
                                      "You're offline. Please connect to the internet",
                                    );
                                    return;
                                  }

                                  final newName = _nameController.text.trim();

                                  // Close modal and dismiss keyboard first
                                  Navigator.of(context).pop();

                                  try {
                                    await ref.read(updateNameActionProvider)(
                                      newName,
                                    );
                                    if (!mounted) return;
                                    widget.onNameSaved?.call(newName);
                                    final userId = await TokenSecureStorage
                                        .instance
                                        .getCurrentUserIdUUID();
                                    if (userId != null && userId.isNotEmpty) {
                                      try {
                                        final row =
                                            await CurrentUserProfileTable
                                                .instance
                                                .getByUserId(userId);
                                        final firstName =
                                            row?[CurrentUserProfileTable
                                                    .columnFirstName]
                                                ?.toString()
                                                .trim();
                                        final status =
                                            row?[CurrentUserProfileTable
                                                    .columnStatusContent]
                                                ?.toString()
                                                .trim();
                                        final statusMeaningful =
                                            status != null &&
                                            status.isNotEmpty &&
                                            status !=
                                                'Write custom or tap to choose preset';
                                        final profileComplete =
                                            (firstName != null &&
                                                firstName.isNotEmpty) &&
                                            statusMeaningful;
                                        final route = profileComplete
                                            ? RouteNames.mainNavigation
                                            : RouteNames.currentUserProfile;
                                        await AppStartupSnapshotTable.instance
                                            .upsertSnapshot(
                                              userId: userId,
                                              profileComplete: profileComplete,
                                              lastKnownRoute: route,
                                            );
                                      } catch (_) {}
                                    }

                                    // Show success snackbar after keyboard is dismissed
                                    if (!mounted) return;
                                    AppSnackbar.showSuccess(
                                      rootContext,
                                      'Name updated successfully',
                                      bottomPosition: 120,
                                      duration: const Duration(seconds: 1),
                                    );
                                  } catch (e) {
                                    // Show error snackbar if update fails
                                    if (!mounted) return;
                                    AppSnackbar.showError(
                                      rootContext,
                                      'Failed to update name. Please try again',
                                      bottomPosition: 120,
                                      duration: const Duration(seconds: 2),
                                    );
                                  }
                                },
                          child: Padding(
                            padding: EdgeInsets.only(
                              right: responsive?.spacing(10) ?? 10.0,
                            ), // 10 px
                            child: Text(
                              'Save',
                              style: AppTextSizes.regular(context).copyWith(
                                color: _nameController.text.trim().isEmpty
                                    ? AppColors.colorGrey
                                    : AppColors.primary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
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
      },
    ).whenComplete(() {
      _isModalOpened = false;
      if (mounted) setState(() {});
    });
  }
}
