import 'package:flutter/material.dart';

/// Responsive design utilities for different screen sizes
class ResponsiveBreakpoints {
  // Mobile breakpoints
  static const double mobilePortrait = 480;
  static const double mobileLandscape = 768;

  // Tablet breakpoints
  static const double tabletPortrait = 768;
  static const double tabletLandscape = 1024;

  // Desktop breakpoints
  static const double desktop = 1024;
  static const double desktopWide = 1440;
  static const double ultraWide = 1920;
}

/// Device type enumeration
enum DeviceType {
  mobile,
  tablet,
  desktop,
  ultraWide,
}

/// Screen orientation helper
enum ScreenOrientation {
  portrait,
  landscape,
}

/// Layout configuration for different screen sizes
class LayoutConfig {
  final bool useHorizontalLayout;
  final bool useCompactUI;
  final double maxContentWidth;
  final EdgeInsets padding;
  final double spacing;

  const LayoutConfig({
    required this.useHorizontalLayout,
    required this.useCompactUI,
    required this.maxContentWidth,
    required this.padding,
    required this.spacing,
  });
}

/// Responsive helper class
class ResponsiveHelper {
  static DeviceType getDeviceType(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    if (width < ResponsiveBreakpoints.tabletPortrait) {
      return DeviceType.mobile;
    } else if (width < ResponsiveBreakpoints.desktop) {
      return DeviceType.tablet;
    } else if (width < ResponsiveBreakpoints.ultraWide) {
      return DeviceType.desktop;
    } else {
      return DeviceType.ultraWide;
    }
  }

  static ScreenOrientation getOrientation(BuildContext context) {
    return MediaQuery.of(context).orientation == Orientation.portrait
        ? ScreenOrientation.portrait
        : ScreenOrientation.landscape;
  }

  static bool isMobile(BuildContext context) {
    return getDeviceType(context) == DeviceType.mobile;
  }

  static bool isTablet(BuildContext context) {
    return getDeviceType(context) == DeviceType.tablet;
  }

  static bool isDesktop(BuildContext context) {
    return getDeviceType(context) == DeviceType.desktop;
  }

  static bool isPortrait(BuildContext context) {
    return getOrientation(context) == ScreenOrientation.portrait;
  }

  static bool isLandscape(BuildContext context) {
    return getOrientation(context) == ScreenOrientation.landscape;
  }

  /// Get appropriate gem size for screen
  static double getGemSize(BuildContext context) {
    final deviceType = getDeviceType(context);
    final orientation = getOrientation(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    // Calculate available space for game board
    double availableWidth = screenWidth - 32; // padding
    double availableHeight = screenHeight - 200; // UI elements

    if (orientation == ScreenOrientation.landscape) {
      availableHeight = screenHeight - 120;
    }

    // Game board is 8x8, so divide by 8 plus spacing
    final maxGemSizeWidth =
        (availableWidth - (7 * 4)) / 8; // 4px spacing between gems
    final maxGemSizeHeight = (availableHeight - (7 * 4)) / 8;

    double gemSize =
        [maxGemSizeWidth, maxGemSizeHeight].reduce((a, b) => a < b ? a : b);

    // Apply device-specific constraints
    switch (deviceType) {
      case DeviceType.mobile:
        gemSize = gemSize.clamp(28.0, 48.0);
        break;
      case DeviceType.tablet:
        gemSize = gemSize.clamp(32.0, 56.0);
        break;
      case DeviceType.desktop:
        gemSize = gemSize.clamp(40.0, 64.0);
        break;
      case DeviceType.ultraWide:
        gemSize = gemSize.clamp(48.0, 72.0);
        break;
    }

    return gemSize;
  }

  /// Get appropriate spacing for screen
  static double getSpacing(BuildContext context) {
    final deviceType = getDeviceType(context);

    switch (deviceType) {
      case DeviceType.mobile:
        // Slightly tighter spacing on small phones
        return 3.0;
      case DeviceType.tablet:
        return 6.0;
      case DeviceType.desktop:
        return 8.0;
      case DeviceType.ultraWide:
        return 10.0;
    }
  }

  /// Get appropriate padding for screen
  static EdgeInsets getPadding(BuildContext context) {
    final deviceType = getDeviceType(context);

    switch (deviceType) {
      case DeviceType.mobile:
        // Tighter padding on small phones
        return const EdgeInsets.all(6.0);
      case DeviceType.tablet:
        return const EdgeInsets.all(16.0);
      case DeviceType.desktop:
        return const EdgeInsets.all(24.0);
      case DeviceType.ultraWide:
        return const EdgeInsets.all(32.0);
    }
  }

  /// Get appropriate font size for device
  static double getFontSize(BuildContext context, double baseSize) {
    final deviceType = getDeviceType(context);

    switch (deviceType) {
      case DeviceType.mobile:
        return baseSize * 0.9;
      case DeviceType.tablet:
        return baseSize;
      case DeviceType.desktop:
        return baseSize * 1.1;
      case DeviceType.ultraWide:
        return baseSize * 1.2;
    }
  }

  /// Get appropriate button height for touch targets
  static double getButtonHeight(BuildContext context) {
    final deviceType = getDeviceType(context);

    switch (deviceType) {
      case DeviceType.mobile:
        return 48.0; // Minimum touch target size
      case DeviceType.tablet:
        return 52.0;
      case DeviceType.desktop:
        return 44.0; // Can be smaller for mouse input
      case DeviceType.ultraWide:
        return 48.0;
    }
  }

  /// Get UI layout configuration
  static bool shouldUseCompactLayout(BuildContext context) {
    return isMobile(context) && isPortrait(context);
  }

  /// Get maximum content width for readability
  static double getMaxContentWidth(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final deviceType = getDeviceType(context);

    switch (deviceType) {
      case DeviceType.mobile:
        return screenWidth;
      case DeviceType.tablet:
        return screenWidth * 0.9;
      case DeviceType.desktop:
        return (screenWidth * 0.8).clamp(400.0, 1000.0);
      case DeviceType.ultraWide:
        return (screenWidth * 0.6).clamp(800.0, 1200.0);
    }
  }

  /// Get layout configuration for current screen
  static LayoutConfig getLayoutConfig(BuildContext context) {
    final isCompact = isMobile(context) && isPortrait(context);

    return LayoutConfig(
      useHorizontalLayout:
          !isCompact && (isLandscape(context) || isDesktop(context)),
      useCompactUI: isCompact,
      maxContentWidth: getMaxContentWidth(context),
      padding: getPadding(context),
      spacing: getSpacing(context),
    );
  }

  /// Get safe area padding
  static EdgeInsets getSafeAreaPadding(BuildContext context) {
    final safePadding = MediaQuery.of(context).padding;
    final basePadding = getPadding(context);

    return EdgeInsets.only(
      top: safePadding.top + basePadding.top,
      bottom: safePadding.bottom + basePadding.bottom,
      left: safePadding.left + basePadding.left,
      right: safePadding.right + basePadding.right,
    );
  }

  /// Get game board size that fits the screen perfectly
  static Size getGameBoardSize(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final safePadding = getSafeAreaPadding(context);

    // Available space after UI elements
    double availableWidth = screenSize.width - safePadding.horizontal;
    double availableHeight = screenSize.height - safePadding.vertical;

    // Reserve space for UI elements
    if (isPortrait(context)) {
      // Reserve some space for score/timer/attacks.
      // Allow larger board on phones to meet usability goals.
      final isTiny = screenSize.height < 700 || screenSize.width < 360;
      availableHeight -= isTiny ? 260 : 220;
    } else {
      availableWidth -= 400; // Space for side panels
      availableHeight -= 150; // Space for top/bottom UI
    }

    // Calculate board size (square)
    final boardSize =
        [availableWidth, availableHeight].reduce((a, b) => a < b ? a : b);

    return Size(boardSize, boardSize);
  }

  /// Compute a recommended max board extent in portrait to avoid overflows
  static double getPortraitMaxBoardExtent(BuildContext context) {
    final safe = getSafeAreaPadding(context);
    final size = MediaQuery.of(context).size;
    final availHeight = size.height - safe.vertical;
    // Leave minimal headroom for timer/score/attacks; allow bigger board
    final isTiny = size.height < 700 || size.width < 360;
    final reserved = isTiny ? 180.0 : 150.0;
    // Cap between 280 and 680 to reach ~70–80% on common phone sizes
    return (availHeight - reserved).clamp(280.0, 680.0);
  }

  /// Get responsive icon size
  static double getIconSize(BuildContext context, {double baseSize = 24.0}) {
    final deviceType = getDeviceType(context);

    switch (deviceType) {
      case DeviceType.mobile:
        return baseSize;
      case DeviceType.tablet:
        return baseSize * 1.2;
      case DeviceType.desktop:
        return baseSize * 1.1;
      case DeviceType.ultraWide:
        return baseSize * 1.3;
    }
  }

  /// Get appropriate app bar height
  static double getAppBarHeight(BuildContext context) {
    if (isMobile(context)) {
      return kToolbarHeight;
    } else {
      return kToolbarHeight * 1.2;
    }
  }

  /// Check if screen should use horizontal layout for multiplayer
  static bool shouldUseHorizontalMultiplayerLayout(BuildContext context) {
    return isLandscape(context) || isTablet(context) || isDesktop(context);
  }

  /// Get card elevation based on device type
  static double getCardElevation(BuildContext context) {
    final deviceType = getDeviceType(context);

    switch (deviceType) {
      case DeviceType.mobile:
        return 4.0;
      case DeviceType.tablet:
        return 6.0;
      case DeviceType.desktop:
        return 2.0; // Less elevation for desktop
      case DeviceType.ultraWide:
        return 3.0;
    }
  }
}
