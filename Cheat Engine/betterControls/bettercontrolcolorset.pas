unit bettercontrolColorSet;

{
  ============================================================================
  CHEAT ENGINE COLOR SYSTEM ORGANIZATION
  ============================================================================

  This unit provides dark-mode-aware color constants and ColorSet for theming.

  COLOR DEFINITION HIERARCHY:

  1. STANDARD COLORS (Light Mode)
     Source: FPC Graphics unit (graphics.pp)
     Examples: clRed, clGreen, clBlue, clYellow, etc.
     Used in: Pascal code (light mode)
     Mirrored in: bin/defines.lua (for Lua scripts)

  2. DARK MODE VARIANTS
     Source: THIS FILE (bettercontrolcolorset.pas)
     Examples: clRedDark, clGreenDark, clBlueDark, etc.
     Used in: Pascal code (dark mode)
     Mirrored in: bin/defines.lua (for Lua scripts)

  3. COLORSET (Theme-Aware Wrapper)
     Source: bettercontrols.pas initialization
     Properties: ColorSet.Red, ColorSet.Green, etc.
     Behavior: Automatically points to standard OR dark variants based on theme
     Usage: Recommended for all UI code that should adapt to dark mode

  USAGE GUIDELINES:

  - For colors that should adapt to dark mode:
    Use ColorSet.Red, ColorSet.Green, etc.
    Example: label.font.color := ColorSet.Red;

  - For semantic meaning (status indicators):
    Use ColorSet.StatusOK, StatusError, StatusWarning
    Example: statusLabel.font.color := ColorSet.StatusError;

  - For explicit light mode colors:
    Use clRed, clGreen, etc. (from Graphics unit)

  - For explicit dark mode colors:
    Use clRedDark, clGreenDark, etc. (from this unit)

  MAINTAINING COLOR CONSISTENCY:

  - When adding new dark mode colors: Define them in this file AND mirror in defines.lua
  - When modifying existing colors: Update values in both locations
  - Color values must match exactly between Pascal and Lua

  ============================================================================
}

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, graphics;

const
  // Dark mode color variants (muted versions for visibility on dark backgrounds)
  // IMPORTANT: These values MUST be mirrored in bin/defines.lua for Lua script usage
  // Standard colors (clRed, clGreen, etc.) are defined in FPC's Graphics unit (<lazarusInstallDir>\lcl\graphics.pp)
  clRedDark     = TColor($4444DD);   // Muted lighter red (vs clRed=$0000FF)
  clGreenDark   = TColor($00AA00);   // Muted darker green (vs clGreen=$008000)
  clLimeDark    = TColor($00DD00);   // Muted lime (vs clLime=$00FF00)
  clBlueDark    = TColor($DD4444);   // Muted lighter blue (vs clBlue=$FF0000)
  clYellowDark  = TColor($00DDDD);   // Muted yellow (vs clYellow=$00FFFF)
  clTealDark    = TColor($AAA000);   // Muted teal (vs clTeal=$808000)
  clOrangeDark  = TColor($0088DD);   // Muted orange (vs clOrange=$0080FF)
  clPurpleDark  = TColor($DD00DD);   // Muted purple (vs clPurple=$800080)
  clMaroonDark  = TColor($0000AA);   // Muted maroon (vs clMaroon=$000080)
  clNavyDark    = TColor($AA0000);   // Muted navy (vs clNavy=$800000)
  clOliveDark   = TColor($008888);   // Muted olive (vs clOlive=$008080)
  clFuchsiaDark = TColor($DD00AA);   // Muted fuchsia (vs clFuchsia=$FF00FF)
  clAquaDark    = TColor($DDDD00);   // Muted aqua (vs clAqua=$FFFF00)

  // Dark mode UI element colors
  // IMPORTANT: These values MUST be mirrored in bin/defines.lua
  clFormBackgroundDark        = TColor($242424);  // Dark gray form background
  clCheckboxFillDark          = TColor($E8E8E8);  // Light gray checkbox fill
  clInactiveCheckboxFillDark  = TColor($999999);  // Medium gray inactive checkbox
  clBtnBorderDark             = TColor($9B9B9B);  // Medium gray button border
  clInactiveFontMask          = TColor($AAAAAA);  // XOR mask for inactive font color
  
  // Light mode UI element colors (non-standard colors not in Graphics unit)
  clOrange       = $0080FF;  // Bright orange

type
  TBetterControlColorSet=record
    // Button colors
    ButtonFaceColorDefault: TColor;
    ButtonFaceColorHover: TColor;
    ButtonFaceColorDown: TColor;
    ButtonFaceColorDisabled: TColor;
    ButtonBorderColor: TColor;
    ButtonBorderColorHover: TColor;
    ButtonInactiveBorderColor: TColor;

    // Text and background colors
    FontColor: TColor;
    TextBackground: TColor;
    EditBackground: TColor;
    FormBackground: TColor;
    InactiveFontColor: TColor;
    HighlightColor: TColor;

    // Checkbox colors
    CheckboxFillColor: TColor;
    InactiveCheckboxFillColor: TColor;
    CheckboxCheckMarkColor: TColor;
    InactiveCheckboxCheckMarkColor: TColor;

    // Dark-mode-aware standard color variants
    // These automatically use appropriate shades based on light/dark mode
    Red: TColor;
    Green: TColor;
    Lime: TColor;
    Blue: TColor;
    Yellow: TColor;
    Teal: TColor;
    Orange: TColor;
    Purple: TColor;

    // Semantic color aliases (for code readability)
    // These map to appropriate colors and can be customized
    StatusOK: TColor;        // Success/good state
    StatusWarning: TColor;   // Warning/caution state
    StatusError: TColor;     // Error/failure state
    ValidationError: TColor; // Input validation errors
  end;

implementation

end.

