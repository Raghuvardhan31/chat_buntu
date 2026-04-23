# ResponsiveLayoutBuilder Usage Guide

## Overview
Global responsive layout system for ChatAway+ that provides consistent breakpoints and sizing across all devices.

## Features
- ✅ Industry-standard breakpoints (Material Design, Bootstrap)
- ✅ Automatic device detection (mobile, tablet, desktop)
- ✅ Responsive sizing and spacing multipliers
- ✅ Content max-width constraints
- ✅ Grid column calculations
- ✅ Easy-to-use context extensions

---

## Breakpoints

| Breakpoint | Width Range | Device Type | Size Multiplier |
|------------|-------------|-------------|-----------------|
| **extraSmall** | < 360px | Small phones | 0.9x |
| **small** | 360px - 599px | Regular phones | 1.0x (base) |
| **medium** | 600px - 839px | Large phones / Small tablets | 1.2x |
| **large** | 840px - 1199px | Tablets | 1.4x |
| **extraLarge** | >= 1200px | Desktop / Large tablets | 1.6x |

---

## Basic Usage

### Method 1: Using ResponsiveLayoutBuilder (Recommended)

```dart
import 'package:chataway_plus/core/responsive_layout/responsive_layout_builder.dart';

class MyPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ResponsiveLayoutBuilder(
        builder: (context, constraints, breakpoint) {
          // Create responsive helper
          final responsive = ResponsiveSize(
            context: context,
            constraints: constraints,
            breakpoint: breakpoint,
          );

          return Padding(
            padding: EdgeInsets.symmetric(
              horizontal: responsive.horizontalPadding, // Auto padding
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: responsive.contentMaxWidth, // Auto max width
                ),
                child: Column(
                  children: [
                    SizedBox(height: responsive.spacing(32)), // Responsive spacing
                    Text(
                      'Welcome',
                      style: TextStyle(
                        fontSize: responsive.size(24), // Responsive size
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
```

### Method 2: Using Context Extensions (Quick Access)

```dart
import 'package:chataway_plus/core/responsive_layout/responsive_layout_builder.dart';

class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Quick access to breakpoint info
    if (context.isMobile) {
      return MobileLayout();
    } else if (context.isTablet) {
      return TabletLayout();
    } else {
      return DesktopLayout();
    }
  }
}
```

---

## Real Example: Phone Number Entry Page

### Before (Manual Approach)
```dart
class PhoneNumberEntryPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Manual breakpoint logic
        final horizontalPadding = constraints.maxWidth <= 360 ? 16.0 
            : constraints.maxWidth <= 420 ? 20.0 : 24.0;
        
        final contentMaxWidth = constraints.maxWidth > 420 ? 420.0 : constraints.maxWidth;

        return Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: contentMaxWidth),
              child: Column(
                children: [
                  Text('Enter your mobile number'),
                  // ... more widgets
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
```

### After (Using ResponsiveLayoutBuilder)
```dart
class PhoneNumberEntryPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ResponsiveLayoutBuilder(
      builder: (context, constraints, breakpoint) {
        final responsive = ResponsiveSize(
          context: context,
          constraints: constraints,
          breakpoint: breakpoint,
        );

        return Padding(
          padding: EdgeInsets.symmetric(
            horizontal: responsive.horizontalPadding, // Auto: 12-48px
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: responsive.contentMaxWidth, // Auto: 375-1000px
              ),
              child: Column(
                children: [
                  SizedBox(height: responsive.spacing(32)), // Auto scaled
                  Text(
                    'Enter your mobile number',
                    style: AppTextSizes.large(context),
                  ),
                  SizedBox(height: responsive.spacing(16)),
                  // ... more widgets
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
```

---

## Common Use Cases

### 1. Responsive Spacing
```dart
SizedBox(height: responsive.spacing(16)) // 16px on mobile, scales up on tablet/desktop
```

### 2. Responsive Sizing
```dart
Container(
  width: responsive.size(100), // 100px on mobile, scales up on larger screens
  height: responsive.size(100),
)
```

### 3. Conditional Layouts
```dart
ResponsiveLayoutBuilder(
  builder: (context, constraints, breakpoint) {
    if (breakpoint.isMobile) {
      return SingleColumnLayout();
    } else {
      return TwoColumnLayout();
    }
  },
)
```

### 4. Grid Layouts
```dart
final responsive = ResponsiveSize(...);

GridView.builder(
  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: responsive.gridColumns, // 1-4 columns based on screen
  ),
  itemBuilder: (context, index) => GridItem(),
)
```

### 5. Different Content for Different Devices
```dart
ResponsiveLayoutBuilder(
  builder: (context, constraints, breakpoint) {
    switch (breakpoint) {
      case DeviceBreakpoint.extraSmall:
      case DeviceBreakpoint.small:
        return CompactMobileView();
      case DeviceBreakpoint.medium:
        return TabletView();
      case DeviceBreakpoint.large:
      case DeviceBreakpoint.extraLarge:
        return DesktopView();
    }
  },
)
```

---

## Benefits

### ✅ Consistency
- Same breakpoints across entire app
- Predictable sizing behavior
- Unified responsive logic

### ✅ Maintainability
- Single source of truth for breakpoints
- Easy to update breakpoint values globally
- Less code duplication

### ✅ Readability
- Clear, semantic code
- Self-documenting breakpoint names
- Easy to understand responsive behavior

### ✅ Flexibility
- Works with existing MediaQuery and LayoutBuilder
- Compatible with AppTextSizes
- Can be combined with other responsive approaches

---

## Best Practices

1. **Use ResponsiveLayoutBuilder at page level**
   ```dart
   // ✅ Good - Wrap entire page
   Scaffold(
     body: ResponsiveLayoutBuilder(
       builder: (context, constraints, breakpoint) {
         return PageContent();
       },
     ),
   )
   ```

2. **Combine with AppTextSizes for text**
   ```dart
   // ✅ Good - Use AppTextSizes for text, ResponsiveSize for layout
   Text(
     'Hello',
     style: AppTextSizes.large(context), // Handles text scaling
   )
   SizedBox(height: responsive.spacing(16)) // Handles layout spacing
   ```

3. **Cache responsive helper**
   ```dart
   // ✅ Good - Create once, reuse
   final responsive = ResponsiveSize(
     context: context,
     constraints: constraints,
     breakpoint: breakpoint,
   );
   
   // Use multiple times
   responsive.spacing(16)
   responsive.size(100)
   responsive.horizontalPadding
   ```

4. **Use context extensions for quick checks**
   ```dart
   // ✅ Good - Quick device type checks
   if (context.isMobile) {
     return MobileWidget();
   }
   ```

---

## Migration Guide

To migrate existing pages to use ResponsiveLayoutBuilder:

1. **Replace manual LayoutBuilder**
   ```dart
   // Before
   LayoutBuilder(builder: (context, constraints) { ... })
   
   // After
   ResponsiveLayoutBuilder(builder: (context, constraints, breakpoint) { ... })
   ```

2. **Replace manual padding calculations**
   ```dart
   // Before
   final padding = constraints.maxWidth <= 360 ? 16.0 : 24.0;
   
   // After
   final padding = responsive.horizontalPadding;
   ```

3. **Replace manual max width logic**
   ```dart
   // Before
   final maxWidth = constraints.maxWidth > 420 ? 420.0 : constraints.maxWidth;
   
   // After
   final maxWidth = responsive.contentMaxWidth;
   ```

4. **Add responsive sizing**
   ```dart
   // Before
   SizedBox(height: 32)
   
   // After
   SizedBox(height: responsive.spacing(32))
   ```

---

## Testing Different Screen Sizes

```dart
// In your tests or during development
void testResponsiveLayout() {
  // Test mobile
  testWidgets('Mobile layout', (tester) async {
    tester.binding.window.physicalSizeTestValue = Size(375, 812);
    // ... test mobile layout
  });

  // Test tablet
  testWidgets('Tablet layout', (tester) async {
    tester.binding.window.physicalSizeTestValue = Size(768, 1024);
    // ... test tablet layout
  });

  // Test desktop
  testWidgets('Desktop layout', (tester) async {
    tester.binding.window.physicalSizeTestValue = Size(1920, 1080);
    // ... test desktop layout
  });
}
```

---

## Summary

**ResponsiveLayoutBuilder provides:**
- 🎯 Consistent breakpoints across app
- 📱 Automatic device detection
- 📏 Responsive sizing and spacing
- 🎨 Better code organization
- 🔧 Easy maintenance
- ✨ Production-ready responsive design

**Use it for:**
- Page layouts
- Spacing and padding
- Content max-width constraints
- Grid column calculations
- Device-specific UI variations
