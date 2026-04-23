import 'package:flutter/material.dart';
import 'package:chataway_plus/core/responsive_layout/responsive_layout_builder.dart';
import 'package:chataway_plus/core/themes/app_text_styles.dart';
import 'package:chataway_plus/core/themes/colors/app_colors.dart';

class PollHubPage extends StatefulWidget {
  const PollHubPage({super.key});

  @override
  State<PollHubPage> createState() => _PollHubPageState();
}

class _PollHubPageState extends State<PollHubPage> {
  final TextEditingController _questionController = TextEditingController();
  final List<TextEditingController> _optionControllers = [
    TextEditingController(),
    TextEditingController(),
  ];

  bool _allowMultiple = false;

  @override
  void dispose() {
    _questionController.dispose();
    for (final controller in _optionControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _addOption() {
    if (_optionControllers.length >= 5) return;
    setState(() => _optionControllers.add(TextEditingController()));
  }

  void _removeOption(int index) {
    if (_optionControllers.length <= 2) return;
    setState(() {
      _optionControllers[index].dispose();
      _optionControllers.removeAt(index);
    });
  }

  void _submitPoll() {
    FocusScope.of(context).unfocus();
    final question = _questionController.text.trim();
    final options = _optionControllers
        .map((controller) => controller.text.trim())
        .where((value) => value.isNotEmpty)
        .toList();

    final safeQuestion = question.isEmpty ? 'Untitled poll' : question;
    final safeOptions = options.isNotEmpty ? options : ['Option 1', 'Option 2'];

    Navigator.of(context).pop(<String, dynamic>{
      'question': safeQuestion,
      'options': safeOptions.map((text) => {'text': text}).toList(),
      'allowMultiple': _allowMultiple,
      'anonymous': false,
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inputFillColor = isDark ? Colors.grey.shade900 : Colors.white;
    final inputTextColor = isDark ? Colors.white : AppColors.greyTextPrimary;
    final hintColor = isDark ? Colors.white54 : AppColors.greyTextSecondary;
    final headerTextColor = isDark ? Colors.white : AppColors.greyTextPrimary;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0.0,
        toolbarHeight: 68,
        centerTitle: false,
        titleSpacing: 0,
        leadingWidth: 50,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.primary, size: 24),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Poll Hub',
          style: AppTextSizes.large(context).copyWith(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : AppColors.iconPrimary,
          ),
        ),
      ),
      body: SafeArea(
        child: ResponsiveLayoutBuilder(
          builder: (context, constraints, breakpoint) {
            final responsive = ResponsiveSize(
              context: context,
              constraints: constraints,
              breakpoint: breakpoint,
            );

            return SingleChildScrollView(
              padding: EdgeInsets.all(responsive.spacing(16)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Question',
                    style: AppTextSizes.large(
                      context,
                    ).copyWith(color: headerTextColor),
                  ),
                  SizedBox(height: responsive.spacing(10)),
                  TextField(
                    controller: _questionController,
                    maxLines: 3,
                    style: TextStyle(color: inputTextColor),
                    decoration: InputDecoration(
                      hintText: 'Fire your question into the chat',
                      hintStyle: TextStyle(color: hintColor),
                      filled: true,
                      fillColor: inputFillColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          responsive.size(14),
                        ),
                        borderSide: BorderSide(
                          color: isDark
                              ? Colors.grey.shade700
                              : AppColors.greyLight.withAlpha(80),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          responsive.size(14),
                        ),
                        borderSide: const BorderSide(
                          color: AppColors.primary,
                          width: 1.2,
                        ),
                      ),
                      contentPadding: EdgeInsets.all(responsive.spacing(14)),
                    ),
                  ),
                  SizedBox(height: responsive.spacing(24)),
                  Text(
                    'Options',
                    style: AppTextSizes.large(
                      context,
                    ).copyWith(color: headerTextColor),
                  ),
                  SizedBox(height: responsive.spacing(10)),
                  ..._optionControllers.asMap().entries.map((entry) {
                    final index = entry.key;
                    final controller = entry.value;
                    return Padding(
                      padding: EdgeInsets.only(bottom: responsive.spacing(12)),
                      child: _OptionField(
                        index: index,
                        controller: controller,
                        canRemove: _optionControllers.length > 2,
                        onRemove: () => _removeOption(index),
                        responsive: responsive,
                        isDark: isDark,
                      ),
                    );
                  }),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: _optionControllers.length >= 5
                          ? null
                          : _addOption,
                      icon: const Icon(Icons.add_circle_outline),
                      label: Text(
                        _optionControllers.length >= 5
                            ? 'Maximum 5 options allowed'
                            : 'Add another option',
                      ),
                    ),
                  ),
                  SizedBox(height: responsive.spacing(20)),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _submitPoll,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: EdgeInsets.symmetric(
                          vertical: responsive.spacing(14),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            responsive.size(14),
                          ),
                        ),
                      ),
                      child: Text(
                        'Submit Poll',
                        style: AppTextSizes.large(
                          context,
                        ).copyWith(color: Colors.white),
                      ),
                    ),
                  ),
                  SizedBox(height: responsive.spacing(16)),
                  _ToggleOptionCard(
                    title: 'Allow multiple answers',
                    subtitle: 'Let people choose more than one option.',
                    value: _allowMultiple,
                    icon: Icons.layers_rounded,
                    onChanged: (value) =>
                        setState(() => _allowMultiple = value),
                    responsive: responsive,
                  ),
                  SizedBox(height: responsive.spacing(12)),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _OptionField extends StatelessWidget {
  const _OptionField({
    required this.index,
    required this.controller,
    required this.canRemove,
    required this.onRemove,
    required this.responsive,
    required this.isDark,
  });

  final int index;
  final TextEditingController controller;
  final bool canRemove;
  final VoidCallback onRemove;
  final ResponsiveSize responsive;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            style: TextStyle(
              color: isDark ? Colors.white : AppColors.greyTextPrimary,
            ),
            decoration: InputDecoration(
              prefixIcon: Icon(
                Icons.check_circle_outline,
                color: AppColors.primary.withAlpha((0.8 * 255).round()),
              ),
              hintText: 'Option ${index + 1}',
              hintStyle: TextStyle(
                color: isDark ? Colors.white54 : AppColors.greyTextSecondary,
              ),
              filled: true,
              fillColor: isDark ? Colors.grey.shade900 : Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(responsive.size(12)),
                borderSide: BorderSide(
                  color: isDark
                      ? Colors.grey.shade700
                      : AppColors.greyLight.withAlpha(80),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(responsive.size(12)),
                borderSide: const BorderSide(
                  color: AppColors.primary,
                  width: 1.2,
                ),
              ),
              contentPadding: EdgeInsets.symmetric(
                horizontal: responsive.spacing(12),
                vertical: responsive.spacing(12),
              ),
            ),
          ),
        ),
        if (canRemove) ...[
          SizedBox(width: responsive.spacing(8)),
          IconButton(
            onPressed: onRemove,
            icon: Icon(Icons.remove_circle_outline, color: Colors.red.shade400),
            constraints: const BoxConstraints(),
            padding: EdgeInsets.zero,
          ),
        ],
      ],
    );
  }
}

class _ToggleOptionCard extends StatelessWidget {
  const _ToggleOptionCard({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.icon,
    required this.onChanged,
    required this.responsive,
  });

  final String title;
  final String subtitle;
  final bool value;
  final IconData icon;
  final ValueChanged<bool> onChanged;
  final ResponsiveSize responsive;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.all(responsive.spacing(16)),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade800 : Colors.white,
        borderRadius: BorderRadius.circular(responsive.size(12)),
        border: Border.all(
          color: isDark ? Colors.grey.shade700 : AppColors.greyLight,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: responsive.size(40),
            height: responsive.size(40),
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha((0.1 * 255).round()),
              borderRadius: BorderRadius.circular(responsive.size(8)),
            ),
            child: Icon(
              icon,
              color: AppColors.primary,
              size: responsive.size(20),
            ),
          ),
          SizedBox(width: responsive.spacing(12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextSizes.regular(context).copyWith(
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                SizedBox(height: responsive.spacing(2)),
                Text(
                  subtitle,
                  style: AppTextSizes.small(context).copyWith(
                    color: isDark ? Colors.white70 : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.primary,
            activeTrackColor: AppColors.primary.withAlpha((0.5 * 255).round()),
            inactiveThumbColor: isDark ? Colors.white70 : Colors.grey.shade600,
            inactiveTrackColor: isDark ? Colors.white24 : Colors.grey.shade300,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }
}
