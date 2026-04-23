import 'package:flutter/material.dart';
import 'package:chataway_plus/core/themes/app_text_styles.dart';
import 'package:chataway_plus/core/themes/colors/app_colors.dart';
import 'package:chataway_plus/core/responsive_layout/responsive_layout_builder.dart';
import 'defalut_status_page.dart';

class ShareYourVoiceWidget extends StatefulWidget {
  final ValueChanged<String> onShareYourVoiceSaved;
  final String initialStatus;
  final ResponsiveSize? responsive;
  const ShareYourVoiceWidget({
    super.key,
    required this.onShareYourVoiceSaved,
    this.initialStatus = '',
    this.responsive,
  });
  @override
  State<ShareYourVoiceWidget> createState() => ShareYourVoiceWidgetState();
}

class ShareYourVoiceWidgetState extends State<ShareYourVoiceWidget> {
  late String _status;

  @override
  void initState() {
    super.initState();
    _status = widget.initialStatus;
  }

  @override
  void didUpdateWidget(covariant ShareYourVoiceWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialStatus != oldWidget.initialStatus) {
      setState(() => _status = widget.initialStatus);
    }
  }

  @override
  Widget build(BuildContext context) {
    final responsive = widget.responsive;

    final isPlaceholder =
        _status.isEmpty || _status == 'Write custom or tap to choose preset';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: EdgeInsets.only(
            left: responsive != null ? responsive.spacing(36) : 36,
          ), // 36 px
          child: Text(
            'Share your voice',
            style: AppTextSizes.regular(
              context,
            ).copyWith(color: Theme.of(context).colorScheme.onSurface),
          ),
        ),
        SizedBox(
          height: responsive != null ? responsive.spacing(5) : 5,
        ), // 5 px
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => DefaultStatusPage(
                  initialStatus: _status,
                  onStatusSelected: (newStatus) {
                    setState(() => _status = newStatus);
                    widget.onShareYourVoiceSaved(newStatus);
                  },
                ),
              ),
            );
          },
          child: Padding(
            padding: EdgeInsets.symmetric(
              vertical: widget.responsive != null
                  ? widget.responsive!.spacing(8)
                  : 8,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  Icons.mic,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white
                      : AppColors.iconPrimary,
                  size: responsive != null ? responsive.size(24) : 24,
                ), // 24 px
                SizedBox(
                  width: responsive != null ? responsive.spacing(12) : 12,
                ), // 12 px
                Flexible(
                  child: Text(
                    isPlaceholder
                        ? 'Write custom or tap to choose preset'
                        : _status,
                    style: (isPlaceholder)
                        ? AppTextSizes.natural(context).copyWith(
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                ? Colors.white54
                                : AppColors.colorGrey,
                          )
                        : AppTextSizes.natural(context).copyWith(
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                    softWrap: true,
                    overflow: TextOverflow.visible,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
