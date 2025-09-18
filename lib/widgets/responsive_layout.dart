import 'package:flutter/material.dart';
import '../utils/responsive.dart';

/// A responsive layout widget that adapts to different screen sizes
class ResponsiveLayout extends StatelessWidget {
  final Widget child;
  final Color? backgroundColor;
  final bool includeAppBar;
  final String? title;
  final List<Widget>? actions;

  const ResponsiveLayout({
    super.key,
    required this.child,
    this.backgroundColor,
    this.includeAppBar = false,
    this.title,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final config = ResponsiveHelper.getLayoutConfig(context);

    final content = Container(
      width: double.infinity,
      height: double.infinity,
      color: backgroundColor,
      child: SafeArea(
        child: Padding(
          padding: config.padding,
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: config.maxContentWidth),
              child: child,
            ),
          ),
        ),
      ),
    );

    if (!includeAppBar) return content;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: title != null ? Text(title!) : null,
        actions: actions,
        elevation: ResponsiveHelper.getCardElevation(context),
        toolbarHeight: ResponsiveHelper.getAppBarHeight(context),
      ),
      body: content,
    );
  }
}

/// Responsive game layout specifically for multiplayer games
class ResponsiveGameLayout extends StatelessWidget {
  final Widget playerBoard;
  final Widget opponentBoard;
  final Widget gameUI;
  final Widget? sidePanel;

  const ResponsiveGameLayout({
    super.key,
    required this.playerBoard,
    required this.opponentBoard,
    required this.gameUI,
    this.sidePanel,
  });

  @override
  Widget build(BuildContext context) {
    final config = ResponsiveHelper.getLayoutConfig(context);
    final useHorizontalLayout =
        ResponsiveHelper.shouldUseHorizontalMultiplayerLayout(context);

    if (useHorizontalLayout) {
      // Landscape or tablet/desktop layout
      return Row(
        children: [
          // Left side - Player board
          Expanded(
            flex: 2,
            child: Column(
              children: [
                Expanded(child: playerBoard),
                if (!ResponsiveHelper.isDesktop(context))
                  SizedBox(
                    height: 60,
                    child: gameUI,
                  ),
              ],
            ),
          ),

          // Middle - Game UI and side panel
          if (ResponsiveHelper.isDesktop(context) || sidePanel != null)
            Container(
              width: ResponsiveHelper.isDesktop(context) ? 300 : 200,
              padding: config.padding,
              child: Column(
                children: [
                  if (ResponsiveHelper.isDesktop(context))
                    Expanded(child: gameUI),
                  if (sidePanel != null) Expanded(child: sidePanel!),
                ],
              ),
            ),

          // Right side - Opponent board
          Expanded(
            flex: 2,
            child: Column(
              children: [
                Expanded(child: opponentBoard),
                if (!ResponsiveHelper.isDesktop(context) && sidePanel != null)
                  SizedBox(
                    height: 60,
                    child: sidePanel,
                  ),
              ],
            ),
          ),
        ],
      );
    } else {
      // Portrait mobile layout: make middle/bottom panels flexible to avoid overflow
      return Column(
        children: [
          // Top - Opponent board
          Expanded(
            flex: 2,
            child: opponentBoard,
          ),

          // Middle - Game UI (tight height to prioritize boards)
          Flexible(
            fit: FlexFit.loose,
            child: Padding(
              padding: config.padding,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 100),
                child: SingleChildScrollView(child: gameUI),
              ),
            ),
          ),

          // Bottom - Player board
          Expanded(
            flex: 3,
            child: playerBoard,
          ),

          // Side panel at bottom if provided (scrollable + constrained)
          if (sidePanel != null)
            Flexible(
              fit: FlexFit.loose,
              child: Padding(
                padding: EdgeInsets.only(top: config.spacing),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 120),
                  child: SingleChildScrollView(child: sidePanel!),
                ),
              ),
            ),
        ],
      );
    }
  }
}

/// Responsive grid layout for menu screens
class ResponsiveGrid extends StatelessWidget {
  final List<Widget> children;
  final double childAspectRatio;
  final int? minColumns;
  final int? maxColumns;

  const ResponsiveGrid({
    super.key,
    required this.children,
    this.childAspectRatio = 1.0,
    this.minColumns,
    this.maxColumns,
  });

  @override
  Widget build(BuildContext context) {
    final config = ResponsiveHelper.getLayoutConfig(context);

    // Calculate columns based on screen size
    int columns = 2;
    if (ResponsiveHelper.isMobile(context)) {
      columns = ResponsiveHelper.isPortrait(context) ? 1 : 2;
    } else if (ResponsiveHelper.isTablet(context)) {
      columns = ResponsiveHelper.isPortrait(context) ? 2 : 3;
    } else {
      columns = 4;
    }

    // Apply min/max constraints
    if (minColumns != null) {
      columns = columns.clamp(minColumns!, double.infinity).toInt();
    }
    if (maxColumns != null) columns = columns.clamp(0, maxColumns!);

    return GridView.builder(
      padding: config.padding,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        childAspectRatio: childAspectRatio,
        crossAxisSpacing: config.spacing,
        mainAxisSpacing: config.spacing,
      ),
      itemCount: children.length,
      itemBuilder: (context, index) => children[index],
    );
  }
}

/// Responsive card widget with proper elevation and spacing
class ResponsiveCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final VoidCallback? onTap;

  const ResponsiveCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final config = ResponsiveHelper.getLayoutConfig(context);
    final elevation = ResponsiveHelper.getCardElevation(context);

    return Card(
      elevation: elevation,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: padding ?? config.padding,
          child: child,
        ),
      ),
    );
  }
}
