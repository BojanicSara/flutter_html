import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_html/style.dart';

/// [computeDimensionUnit] takes a [Dimension] and some information about the
/// context where the Dimension is being used, and returns a "used" value to
/// use in a rendering.
double _computeDimensionValue(Dimension dimension, double emValue, double autoValue) {
  switch (dimension.unit) {
    case Unit.em: return emValue * dimension.value;
    case Unit.px: return dimension.value;
    case Unit.auto: return autoValue;
  }
}

double _calculateEmValue(Style style, BuildContext buildContext) {
  //TODO is there a better value for this?
  return (style.fontSize?.size ?? 16) *
  MediaQuery.textScaleFactorOf(buildContext) *
  MediaQuery.of(buildContext).devicePixelRatio;
}

/// This class handles the calculation of widths and margins during parsing:
/// See [calculate] within.
class WidthAndMargins {
  final double? width;

  final EdgeInsets margins;

  const WidthAndMargins({required this.width, required this.margins});

  /// [WidthsAndMargins.calculate] calculates any auto values ans resolves any
  /// overconstraint for various elements..
  /// See https://drafts.csswg.org/css2/#Computing_widths_and_margins
  static WidthAndMargins calculate(
      Style style,
      Size containingBlockSize,
      bool isReplaced,
      BuildContext buildContext,
      ) {

    final emValue = _calculateEmValue(style, buildContext);

    double? width = _computeDimensionValue(style.width ?? Width.auto(), emValue, 0);
    double marginLeft = _computeDimensionValue(style.margin?.left ?? Margin.zero(), emValue, 0);
    double marginRight = _computeDimensionValue(style.margin?.right ?? Margin.zero(), emValue, 0);

    bool autoWidth = style.width?.unit == Unit.auto || style.width == null;
    bool autoMarginLeft = style.margin?.left?.unit == Unit.auto;
    bool autoMarginRight = style.margin?.right?.unit == Unit.auto;

    switch(style.display ?? Display.BLOCK) {
      case Display.BLOCK:

        if(isReplaced && autoWidth) {
          //TODO calculate width as for inline replaced element
          // See https://drafts.csswg.org/css2/#block-replaced-width
          //For now, just let the element calculate its own width
          width = null;
        }

        double? overrideMarginLeft;
        double? overrideMarginRight;

        double? autoLeftMarginValue;
        double? autoRightMarginValue;

        final borderWidth = (style.border?.left.width ?? 0) + (style.border?.right.width ?? 0);
        final paddingWidth = (style.padding?.left ?? 0) + (style.padding?.right ?? 0);
        final nonAutoWidths = borderWidth + paddingWidth;
        final nonAutoMarginWidth = marginLeft + marginRight;

        //If width is not auto, check the total width of the containing block:
        if(!autoWidth) {
          if(nonAutoWidths + (width ?? 0) + nonAutoMarginWidth > containingBlockSize.width) {
            autoLeftMarginValue = 0;
            autoRightMarginValue = 0;
            autoMarginLeft = false;
            autoMarginRight = false;
          }
        }

        //If all values are explicit, the box is over-constrained, and we must
        //override one of the given margin values (left if the overconstrained
        //element has a rtl directionality, and right if the overconstrained
        //element has a ltr directionality). Margins must be non-negative in
        //Flutter, so we set them to 0 if they go below that.
        if(!autoWidth && !autoMarginLeft && !autoMarginRight && width != null) {
          final difference = containingBlockSize.width - (nonAutoWidths + width + nonAutoMarginWidth);
          switch(style.direction) {
            case TextDirection.rtl:
              overrideMarginLeft = max(marginLeft + difference, 0);
              break;
            case TextDirection.ltr:
              overrideMarginRight = max(marginRight + difference, 0);
              break;
            case null:
              final directionality = Directionality.maybeOf(buildContext);
              if(directionality != null) {
                switch(directionality) {
                  case TextDirection.rtl:
                    overrideMarginLeft = max(marginLeft + difference, 0);
                    break;
                  case TextDirection.ltr:
                    overrideMarginRight = max(marginRight + difference, 0);
                    break;
                }
              } else {
                overrideMarginRight = max(marginRight + difference, 0);
              }
          }
        }

        //If exactly one unit is auto, calculate it from the equality.
        if(autoWidth && !autoMarginLeft && !autoMarginRight && width != null) {
          width = containingBlockSize.width - (nonAutoWidths + nonAutoMarginWidth);
        } else if((!autoWidth || width==null) && autoMarginLeft && !autoMarginRight) {
          overrideMarginLeft = containingBlockSize.width - (nonAutoWidths + (width ?? 0) + marginRight);
        } else if((!autoWidth || width == null) && !autoMarginLeft && autoMarginRight) {
          overrideMarginRight = containingBlockSize.width - (nonAutoWidths + (width ?? 0) + marginLeft);
        }

        //If width is auto, set all other auto values to 0, and the width is
        //calculated from the equality
        if(autoWidth && width != null) {
          autoLeftMarginValue = 0;
          autoRightMarginValue = 0;
          autoMarginLeft = false;
          autoMarginRight = false;
          width = containingBlockSize.width - (nonAutoWidths + nonAutoMarginWidth);
        }

        //If margin-left and margin-right are both auto, their values are equal,
        // and the element is centered.
        if(autoMarginLeft && autoMarginRight) {
          final marginWidth = containingBlockSize.width - (nonAutoWidths + (width ?? 0));
          overrideMarginLeft = marginWidth / 2;
          overrideMarginRight = marginWidth / 2;
        }

        marginLeft = overrideMarginLeft ?? _computeDimensionValue(style.margin?.left ?? Margin.zero(), emValue, autoLeftMarginValue ?? 0);
        marginRight = overrideMarginRight ?? _computeDimensionValue(style.margin?.right ?? Margin.zero(), emValue, autoRightMarginValue ?? 0);
        break;
      case Display.INLINE:
        //All inline elements have a computed auto value for margin of 0.
        if(autoMarginLeft) {
          marginLeft = 0;
        }
        if(autoMarginRight) {
          marginRight = 0;
        }
        if(isReplaced) {
          //TODO calculate intrinsic width
          //For now, we can just let the element calculate its own width!
          width = null;
        }
        else {
          width = null;
        }
        break;
      case Display.INLINE_BLOCK:
        //All inline elements have a computed auto value for margin of 0.
        if(autoMarginLeft) {
          marginLeft = 0;
        }
        if(autoMarginRight) {
          marginRight = 0;
        }
        if(isReplaced) {
          //TODO calculate intrinsic width
          //For now, we can just let the element calculate its own width!
          width = null;
        } else {
          //TODO calculate shrink-to-fit width for auto widths.
          //For now, we can just let the element calculate its own width!
          width = null;
        }


        // (See https://drafts.csswg.org/css2/#inline-replaced-width)
        break;
      case Display.LIST_ITEM:
        // TODO: Any handling for this case?
        break;
      case Display.NONE:
        // Do nothing
        break;
    }

    return WidthAndMargins(
      width: width,
      margins: EdgeInsets.only(
        left: marginLeft,
        right: marginRight,
        top: _computeDimensionValue(style.margin?.top ?? Margin.zero(), emValue, 0),
        bottom: _computeDimensionValue(style.margin?.bottom ?? Margin.zero(), emValue, 0),
      ),
    );
  }

}
