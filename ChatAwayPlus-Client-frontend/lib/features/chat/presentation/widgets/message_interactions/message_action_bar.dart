import 'package:flutter/material.dart';
import 'package:chataway_plus/core/themes/colors/app_colors.dart';
import 'package:chataway_plus/core/responsive_layout/responsive_layout_builder.dart';

class MessageActionBar extends StatelessWidget {
  const MessageActionBar({
    super.key,
    required this.onClose,
    required this.onDelete,
    this.onForward,
    this.onEdit,
    this.onInfo,
    this.onCopy,
    this.onStar,
    this.onReact,
    this.showInfo = false,
    this.showCopy = true,
    this.showStar = true,
    this.showForward = true,
    this.showEdit = false,
    this.showReact = true,
    this.padding,
  });

  final VoidCallback onClose;
  final VoidCallback onDelete;
  final VoidCallback? onForward;
  final VoidCallback? onEdit;
  final VoidCallback? onInfo;
  final VoidCallback? onCopy;
  final VoidCallback? onStar;
  final VoidCallback? onReact;
  final bool showInfo;
  final bool showCopy;
  final bool showStar;
  final bool showForward;
  final bool showEdit;
  final bool showReact;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconColor = isDark ? Colors.white : AppColors.iconPrimary;
    final destructiveColor = AppColors.error;

    return ResponsiveLayoutBuilder(
      builder: (context, constraints, breakpoint) {
        final responsive = ResponsiveSize(
          context: context,
          constraints: constraints,
          breakpoint: breakpoint,
        );

        final effectivePadding =
            padding ??
            EdgeInsets.symmetric(
              horizontal: responsive.spacing(6),
              vertical: responsive.spacing(4),
            );

        final iconSize = responsive.size(24);
        final buttonSize = responsive.size(40);

        final actionButtons = <Widget>[
          if (showReact)
            IconButton(
              onPressed: onReact,
              icon: Icon(
                Icons.add_reaction_outlined,
                color: iconColor,
                size: iconSize,
              ),
              padding: EdgeInsets.zero,
              constraints: BoxConstraints(
                minWidth: buttonSize,
                minHeight: buttonSize,
              ),
            ),
          if (showStar)
            IconButton(
              onPressed: onStar,
              icon: Icon(
                Icons.star_border_rounded,
                color: iconColor,
                size: iconSize,
              ),
              padding: EdgeInsets.zero,
              constraints: BoxConstraints(
                minWidth: buttonSize,
                minHeight: buttonSize,
              ),
            ),
          if (showInfo)
            IconButton(
              onPressed: onInfo,
              icon: Icon(Icons.info_outline, color: iconColor, size: iconSize),
              padding: EdgeInsets.zero,
              constraints: BoxConstraints(
                minWidth: buttonSize,
                minHeight: buttonSize,
              ),
            ),
          if (showEdit)
            IconButton(
              onPressed: onEdit,
              icon: Icon(Icons.edit, color: iconColor, size: iconSize),
              padding: EdgeInsets.zero,
              constraints: BoxConstraints(
                minWidth: buttonSize,
                minHeight: buttonSize,
              ),
            ),
          IconButton(
            onPressed: onDelete,
            icon: Icon(Icons.delete, color: destructiveColor, size: iconSize),
            padding: EdgeInsets.zero,
            constraints: BoxConstraints(
              minWidth: buttonSize,
              minHeight: buttonSize,
            ),
          ),
          if (showForward)
            IconButton(
              onPressed: onForward,
              icon: Icon(
                Icons.turn_right_rounded,
                color: iconColor,
                size: iconSize,
              ),
              padding: EdgeInsets.zero,
              constraints: BoxConstraints(
                minWidth: buttonSize,
                minHeight: buttonSize,
              ),
            ),
        ];

        return Padding(
          padding: effectivePadding,
          child: Row(
            children: [
              IconButton(
                onPressed: onClose,
                icon: Icon(
                  Icons.close,
                  color: destructiveColor,
                  size: iconSize,
                ),
                padding: EdgeInsets.zero,
                constraints: BoxConstraints(
                  minWidth: buttonSize,
                  minHeight: buttonSize,
                ),
              ),
              SizedBox(width: responsive.spacing(4)),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    reverse: true,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: actionButtons,
                    ),
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
