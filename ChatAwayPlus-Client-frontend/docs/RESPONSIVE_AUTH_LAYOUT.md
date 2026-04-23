# Responsive Auth Layout Playbook

A reference for keeping the ChatAway+ auth screens pixel-consistent across every
Android device, matching WhatsApp/Instagram behavior without fighting the
keyboard.

## Core Principles

1. **Single Scrollable Column**
   - Wrap each auth page body with `LayoutBuilder`, `SingleChildScrollView`, and
     `ConstrainedBox(minHeight: constraints.maxHeight)`.
   - This allows tall phones to stretch the content and short phones to scroll
     without clipping.

2. **Keyboard-Safe CTA**
   - Keep the bottom button inside the scrollable column.
   - Apply `padding: EdgeInsets.only(bottom: MediaQuery.viewInsets.bottom)` so
     the keyboard never overlaps the CTA.
   - Wrap the button with `SafeArea(top: false)` for additional inset safety.

3. **Deterministic Spacing**
   - Replace `screenHeight * (x / 812)` math with semantic spacers:
     ```dart
     const verticalSpacingXL = 32.0;
     const verticalSpacingL = 24.0;
     const verticalSpacingM = 16.0;
     const verticalSpacingS = 8.0;
     ```
   - Use these constants everywhere to keep gaps uniform.

4. **Consistent Widths**
   - Constrain forms to a max width (e.g., 360 px) so tablets/large phones don’t
     stretch inputs.
   - Example helper:
     ```dart
     double resolveContentWidth(BoxConstraints constraints) {
       final maxWidth = constraints.maxWidth;
       return maxWidth > 400 ? 400 : maxWidth;
     }
     ```

5. **Reusable Variable Names**
   - `contentMaxWidth` – clamped width for form controls.
   - `horizontalPadding` – derived from layout constraints (e.g., 16/20/24).
   - `keyboardInset` – `MediaQuery.of(context).viewInsets.bottom`.
   - `buttonBottomPadding` – safe-area aware padding before CTA.
   - `verticalSpacing*` – constants from step 3.

## Implementation Template

```dart
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final keyboardInset = media.viewInsets.bottom;

    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          behavior: HitTestBehavior.opaque,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: EdgeInsets.only(bottom: keyboardInset),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: child,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
```

Each auth page supplies its own `Column` to `AuthScaffold`, using the shared
spacing constants and width helpers. That keeps our existing visual design but
ensures it stays aligned on every device.
