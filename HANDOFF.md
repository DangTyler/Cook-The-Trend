# Cook the Trend: handoff

## Where the build is
- **Roblox place:** "Cook The Trend", placeId **86879072513404** (the open Studio place). All scripts, the kitchen set and the asset overrides live in it. The Studio session auto-saved (everything survived an accidental close). Nothing was published.
- **Local source + tools:** `C:\Users\GAMEPOWER\CookTheTrend`

  | Path | Contents |
  |---|---|
  | `src/shared/` | Config, Recipes (gameplay + real-recipe data), StepMath (shared scoring rules), Dish (food builders), Coach (feedback text) |
  | `src/server/CTTServer.server.luau` | sessions, validation, rewards, DataStore |
  | `src/client/` | CTTClient (entry), Feed, Hud, Kitchen (camera + 6 interactions + lessons), Results, RecipeSheet, FruitMesh (EditableMesh/EditableImage), Sfx, Fx, UI |
  | `build/*.luau` | rebuild the kitchen set, decor, lighting and the asset overrides |
  | `tools/push.ps1` | push all sources into Studio (via StudioMCP multi_edit) |

## How to play / review
1. In Studio press **Play** (solo). The feed is on the left and the kitchen on the right.
2. **Rainbow Fruit Cup** (first card, free): tap **MAKE THIS**.
   - Each step shows **Watch the technique** (real-life tip + ghost 3D demo). Tap **MY TURN**, then do it:
     - tap the ingredients
     - CHOP when the knife crosses the dotted lines
     - hold to pour to the gold line
     - tap the glowing spots to place toppings
   - A coach card after each step says what went well and what to fix.
   - The results compare **Yours vs The Video**, with score, rank, coins/followers and **📖 RECIPE + TIPS** (your real recipe card).
3. **Ramen** unlocks at 60 followers (one decent fruit cup run). **Burger** unlocks for 40 coins (UNLOCK on its card).
4. 📖 on any card opens the real recipe (ingredients + quantities, steps, "looks like" 3D thumbnails).
5. Controls:
   - mouse or touch; **Space** = the action button
   - ↻ (tap twice) restarts the dish; ✕ (tap twice) quits
   - switching recipe from the feed asks for a second tap

## Evidence
`captures/`:
- `final_01..18_*.jpg`: feed, lesson, EditableMesh slicing (03), toppings, results (good/bad), recipe card, recap, burger steps, chef avatar, EditableMesh noodles (18)
- `gameplay_fruitcup_final.gif`, `gameplay_ramen_lessons.gif`: frame-captured runs, about 2 fps

Test details are in TEST_RESULTS.md.

## Notes
- **Hackathon toggle:** `Config.UnlockAll = true` in `src/shared/Config.luau` (ReplicatedStorage.CTT.Config) unlocks every recipe from the start. Set it to `false` to bring back the coin/follower unlocks. Scores and rewards still work either way.
- HUD simplified (00:40): one-line lesson tip with MY TURN, a single-line feedback card on the left, no REC pill, step banner or combo text, and bigger text everywhere. The full tips stay on the recipe card.
- Slicing (01:05): realistic thickness per food (scallion 11 thin rings, strawberry/kiwi 6, chashu 6, tomato 5). Clear cut cues: a glowing slice plane at each cut, a gold ▼ on the next cut, the line turns green and the button reads NOW! when you are in the window, and a rhythm bar above CHOP shows the knife and every cut (green hit / red miss). The timing window scales with slice spacing.
- The QA profile was wiped at the end, so your next Play starts at 0 coins / 0 followers.
- Your avatar is the chef behind the counter and reacts when you serve.

## Owner actions remaining
1. **Publish** when happy (File → Publish to Roblox). Check Game Settings → Security keeps **Allow Mesh / Image APIs** on (needed for real slicing; the game falls back gracefully if it is off) and API access for DataStores.
2. Re-check audio and generated meshes on the live server (all assets are free Creator Store audio and your own AI-generated meshes).
3. Two-player isolation was not tested with real clients. Run Test → Clients and Servers (2 players) once if you want that verified.
4. Optional cleanup: `ServerStorage.GenStage` / `CTT_Staging` hold the raw generated and Toolbox assets (unused at runtime).

## Future hooks (ready, not live)
- `Recipes.Defs[id].media.reactionVideoId`
- `media.makeThisLink`
- the "📸 Cooked it IRL? (soon)" button on the recipe card
- AI plating feedback: return the same shape as `Coach.feedback(step, quality, label, details)`
