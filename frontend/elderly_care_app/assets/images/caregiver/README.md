# Caregiver imagery

Place approved artwork here.

| File | Used by | Spec |
|------|---------|------|
| `intro_hero.png` | Onboarding page 2 (care introduction) hero | Transparent-background PNG, roughly 5:4 landscape (e.g. 1500x1200), elderly woman on the left and a smiling caregiver in blue scrubs on the right, holding hands, subjects centred and filling the lower ~85% of the frame. The top ~10% and the left/right edges sit over a pale circle with leaf and heart decoration, so keep them free of background. The bottom edge fades into the page automatically. Must be licensed for the app. |
| `welcome_hero.png` | Caregiver welcome screen hero | Transparent-background PNG, **4:5 portrait** (e.g. 1200x1500), caregiver in blue scrubs + elderly woman, subjects anchored bottom-right. Keep the left ~30% mostly clear: the benefit labels sit over that edge. The bottom ~8% is hidden behind the green wave. Must be licensed for the app. |

The screen reserves this box at about 44% of the screen height (250–420dp tall), bleeding
slightly off the right edge. Until `welcome_hero.png` exists the screen shows a drawn
placeholder illustration in exactly that box
(see `lib/features/caregiver_onboarding/presentation/welcome_hero.dart`).
