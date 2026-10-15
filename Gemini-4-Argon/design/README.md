# MorphCook Design Reference — Warm Paper Cookbook (Tumblr-Era Minimalism)

MorphCook intentionally rejects noisy food-blog clutter and cold SaaS dashboards in favor of a **tactile, warm-paper heirloom cookbook** inspired by early-2010s Tumblr culinary zines, Kinfolk journals, and index-card recipe boxes.

## Color Tokens

| Token | Light Mode (`Warm Paper`) | Dark Mode (`Evening Candlelight`) | Usage |
|---|---|---|---|
| `paperBg` | `#FAF6F0` | `#1C1915` | Primary background surface |
| `cardCream` | `#F3ECE1` | `#26211C` | Recipe cards, modals, filter chips |
| `warmSand` | `#E6DCCD` | `#332C25` | Secondary containers, step badges |
| `inkPrimary` | `#2B2520` | `#EFE8DD` | Headlines, recipe steps, primary UI |
| `inkSecondary` | `#5C5248` | `#B8ACA0` | Editorial story copy, descriptions |
| `inkMuted` | `#8C7F70` | `#85796C` | Captions, disabled variant notes |
| `terracotta` | `#C85A32` | `#E06D44` | Primary action, selected variant badge |
| `sage` | `#6B7F5E` | `#829973` | Dietary safe badge, herbal accents |
| `ochre` | `#D49B35` | `#E2AC48` | Bookmarks, candlelight highlights |
| `coralAlert` | `#E0533C` | `#E0533C` | Visual timer flash alert (frame A) |
| `tealAlert` | `#2A8C82` | `#2A8C82` | Visual timer flash alert (frame B) |

## Typography

- **Editorial Serif (`Playfair Display`)**: Used for dish titles, screen headers, and step titles.
- **Technical Monospace (`JetBrains Mono`)**: Used for exact ingredient amounts, nutrition macros (`kcal`, `protein_g`, `carbs_g`, `fat_g`), timer readouts, and variant dimension codes.
- **Handwritten Margin Note (`Caveat`)**: Used for chef tips, margin annotations, and nostalgic polaroid captions.

## Signature Tactile Components

1. **`PaperGrainBackground`**: Subtle procedural paper texture painter over warm cream/espresso surfaces.
2. **`DashedRule`**: Hand-stitched horizontal divider lines separating recipe sections.
3. **`StripedPlaceholderArtwork`**: Offline-first diagonal woven linen & botanical monogram illustration for every dish—zero network image dependency.
4. **`PolaroidDishCard`**: Cream-bordered dish card with a subtle paper shadow, time-slot badge, and active variant tag.
5. **`DimensionVariantSwitcher`**: 3-axis pill matrix (`Diet` × `Effort` × `Calorie`) that morphs any dish in place while explaining why incompatible variants are disabled for the active household profile.
