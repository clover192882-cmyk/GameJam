# Differences: ye_fish_duck vs Hollow Matsuri (game-jam)

Source package: `C:\Users\Admin\Documents\ye_fish_duck` ("Dead Man's Carnival", values from `scripts/game_config.gd`).
This log covers what was ported into `game-jam` for the Goldfish and Cork stalls, and what was changed on the way. Dart Balloon is untouched.

## 1. Game structure

| Area | ye_fish_duck | game-jam |
|---|---|---|
| Title | Dead Man's Carnival | Hollow Matsuri |
| Win condition | Buy the Gate Key for 5000 points at a Key Shop | Pay 200 points to unlock the gate, then step outside |
| Lose condition | 3 hearts; a round that ends with 0 points costs 1 heart; the Kidnapper ends you | 3 hearts; a round that ends with 0 points costs 1 heart; 0 hearts = Game Over (no Kidnapper, the guard sequence plays instead) |
| Starting points | none; the player earns up from 0 | 100 |
| Stall unlock cost | Booths 2 and 3: 300 and 700 | Goldfish 60, Cork 120 |
| Difficulty unlock cost | Medium 150, Hard 350 | Medium 40, Hard 90 |
| Repeat-win decay | none | each repeat win at the same stall and level pays 25% less, down to a 25% floor |
| Saving, menu, pause | separate menu and scene flow | Continue / New game, pause, save system, randomized layout |
| Global systems | autoloads GameState, HUD, AdrenalinePostProcess, InputSetup | not added; PointManager, StallManager, DifficultyManager, SaveManager and `scripts/minigame_fx.gd` instead |
| Player | basic first person | jointed rig with sprint, jump, V camera toggle, touch controls |

## 2. Goldfish scooping

| Item | ye_fish_duck | game-jam |
|---|---|---|
| Base points | goldfish 30, ribbon 60, black 100 | 2, 4, 6 |
| Difficulty multiplier | 1 / 1.5 / 2.5 | 1 / 2 / 4 (same ratio as Dart) |
| Net tear penalty | 20 points | 4 points |
| Small-fish point factor | lowered on Medium and Hard (0.67) | 1.0 on every level |
| Hard green zone | 0.18 wide (same as Easy), no big-fish zone | 0.10 for small fish, 0.12 for big fish |
| Wording | "nets", "hook" | "Scoops", "scoop" (a "net" is score everywhere) |
| Round time, scoops, fail cost | 45 s, 3 nets, 20% | unchanged |
| Presentation | basin set up for the package's own booth | basin on the ground in a custom open-front booth (low rail, tatami floor, invisible barrier), camera 2.05 m back at -42 degrees |
| HUD | package HUD autoload | `goldfish_ui.gd`: status pill and hint pill in the game's navy/amber style |

## 3. Duck gallery (Cork Gun Gallery)

| Item | ye_fish_duck | game-jam |
|---|---|---|
| Points (Easy / Medium / Hard) | standard 5/10/20, gold 10/20/50, skull -10/-20/-45 | standard 3/6/12, gold 6/12/30, skull -8/-16/-36 |
| Miss penalty | 5 / 10 / 30 | 2 / 4 / 8 |
| Reward scaling | difficulty multiplier skipped | repeat-win decay (`reward_scale`) applies to gains |
| Palette | bright blue backdrop, white waves, red and cream columns, bright bunting | dark navy backdrop, muted waves, deep red columns, darkened bunting, amber and red bulbs |
| Lighting | none of its own | warm lamp inside the set |
| Wording | "Ammo" | "Corks" |
| HUD | package HUD autoload | `cork_ui.gd`: same bottom status and hint pills as goldfish, so the stall sign stays visible |
| Unchanged | 30 s round, 6 shots, reload 1 s, spawn weights, speed multipliers 0.7 / 1.4 / 2.3 | same |

## 4. Wording unified across the game

- Score label is "Score" in all three minigames (Dart used "Net").
- Quitting is "E to give up" in all three (Dart used "forfeit").

## 5. Models and credits

- Fish models (`goldfish_poly.glb`, `fish_poly.glb`, `fish_quaternius.glb`) were copied from the package into `assets/models/`. The license is unknown and is noted in `assets/models/CREDITS.txt`.
- The duck models are built from primitives in code; there are no model files.
- The CC BY dart credit and the other credits are shown on an in-game Credits screen (menu button, and before the escape ending).

## 6. Also ported
- Hearts (HUD icons, saved), round summary lines, adrenaline vignette, FOV breathing and aim shake at 1 heart, credits screen.

## 7. Not ported (on purpose)
- Key Shop (game-jam already has the 200-point gate), Kidnapper (covered by the guard game-over), the package's menu, scenes and input setup (game-jam has its own).
- Dart Balloon from the package was ignored; the original game-jam version remains.
