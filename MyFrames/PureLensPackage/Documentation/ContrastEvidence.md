# Default token contrast evidence

Calculated with WCAG relative luminance for the package's opaque default token pairs:

| Use | Foreground | Background | Ratio |
|---|---:|---:|---:|
| Primary action text | `#FFFFFF` | `#D63F38` | 4.54:1 |
| Light primary text | `#161824` | `#FBF7EF` | 16.51:1 |
| Light secondary text | `#62626B` | `#FBF7EF` | 5.65:1 |
| Light success copy | `#0B806C` | `#FBF7EF` | 4.55:1 |
| Camera-panel copy | `#FFFAF1` | `#15141A` | 17.61:1 |
| Camera-panel warning | `#FFC96B` | `#15141A` | 12.05:1 |
| Dark primary text | `#FFF9F1` | `#1D1C23` | 16.15:1 |
| Dark secondary text | `#C1BEC7` | `#1D1C23` | 9.22:1 |

The brighter source-mock coral `#FF665A` remains a non-text signal token (`brandSignal`). Text-bearing actions use the darker `brandStrong` token so white text reaches 4.5:1.

Camera imagery is variable and cannot be certified from token math. The pet identity therefore adds a dark backing capsule and shadow, but it still requires rendered checks against representative bright/dark live scenes. Custom host themes must be recalculated and visually inspected.
