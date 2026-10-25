# Cook the Trend: scope & decisions

**Target:** Roblox place "Cook The Trend" (placeId 86879072513404, Studio id via `list_roblox_studios`). Never Rebounder / 14183433415.
**Deadline:** 2026-10-25 09:00 ET. Started 2026-10-24 21:14 ET.

## Pitch
"I saw this food trend. Can I actually make it?" A vertical short-video recipe feed on the left (28% width) and a hands-on 3D countertop on the right. Loop: browse → COOK THIS → hands-on steps → serve → "Yours vs The Video" reveal → coins/followers → unlock next trend.

## Decisions (settled, don't re-plan)
- **Single-player score attack**, one shared kitchen set; food/scene is client-local (`workspace.CTT_Scene`), so players never touch each other's ingredients. Characters spawn off-camera (z=70) with WalkSpeed 0; camera is Scriptable and independent of the character, so a reset/respawn doesn't disturb a dish.
- **Server-authoritative runs** (`ServerScriptService.CTTServer`): server owns the session (recipe, step index, step start clock, results). The client submits per-step *raw input events* (tap times, pour pulses, drop points). The server validates order, counts, timing bounds vs its own elapsed clock (+0.35 s tolerance), allowed ids and duplicates, then **re-scores with the shared `StepMath`**. The client never sends a score or a reward. Rewards are granted once, in `finish()`, and the session is then cleared.
  - Known limit: a modified client could fabricate perfect event times. That only reaches the same score a skilled player gets, it can't exceed timing bounds, and it can't mint currency.
- **Six reusable step types** (data-driven in `Recipes`): `pick` (tap the right ingredients; decoys are funny), `chop` (a knife sweeps; tap on the dotted lines), `heat` (doneness gauge, PULL/FLIP in the green zone, auto-burns), `pour` (hold or tap-toggle to fill to the gold line, overflow spills), `place` (drag/tap toppings onto glowing slots, misses fall off), `stack` (a swinging layer, tap to drop centered, the tower leans).
- **Recipes:** Midnight Tonkotsu ramen (free), Tower Smash Burger (unlock 40 coins), Rainbow Fruit Cup (unlocks at 100 followers).
- **Scoring:** Ingredients 15 / Prep 20 / Cooking 35 / Plating 30 (renormalized per recipe) → 95 pts skill + up to 5 speed bonus, scaled by skill. Ranks S≥90 A≥75 B≥60 C≥40 D.
- **Economy:** coins = base × (0.3 + 0.7 × score/100), +15 on first clear; followers = base × (score/100)^1.4, ×1.25 for S, +10 on a new PB.
- **Persistence:** DataStore `CTT_Profile_v1` with pcall, 3 retries and sanitizing. If unavailable the session continues, the feed shows "Progress not saving this session", and nothing is overwritten.
- **Art:** procedural, stylized Roblox geometry (`ReplicatedStorage.CTT.Dish`). Any model placed in `ReplicatedStorage.CTTAssets` with a builder id name overrides the procedural one (path for vetted Toolbox assets). The kitchen set is built by `build/kitchen_build.luau`.
- **Previews:** animated 3D ViewportFrames (layer drop-in loop, orbit camera, steam/sparkle) plus a fake video scrubber. No video assets, no TikTok embedding.
- **Scripts enter Studio only via StudioMCP `multi_edit`** (`tools/push.ps1` + `tools/manifest.txt`). MCP Luau is sandboxed.

## Partner direction (received 2026-10-24 22:35): learning-first ("CookQuest")
Improve, don't rebuild. Learning the real recipe is the main value; score and rewards drive engagement. The title stays "Cook the Trend" per the user.
- **Rainbow Fruit Cup is the flagship:** first card, free. Ramen unlocks at 60 followers, burger for 40 coins.
- **Every step = Demonstrate → Instruct → Do → Feedback:**
  - `Kitchen:lesson` shows "👀 Watch the technique" with the real-life tip, what it should look like and why. A ghost 3D demo loops until MY TURN (or tap/Space; auto after 14 s):
    - ghost knife chopping straight down on the lines
    - gauge sweep plus the colour change to the green zone
    - ghost liquid rising to the gold line
    - ghost toppings in their sections
    - ghost layer dropping dead center
    - the recipe's ingredients lighting up
  - The tip then stays as a chip during the interaction. After the server scores the step, a coach card says what went well and what to try next time (shared `Coach` module).
- **Recipe card** (`RecipeSheet`), opened from 📖 on each feed card or 📖 RECIPE + TIPS on results:
  - servings, real time, summary
  - ingredients with real quantities
  - numbered real-life steps, each with a static 3D "looks like" thumbnail (`Dish.stepPreview`), a "Looks like" result and a "Why"
  - MAKE THIS
  - in recap mode, per step: your result, ✓ what went well, 💡 next time
- **Results** lead with the most useful improvement tip. Score, rank, rewards, PB and unlocks are unchanged.
- **Food realism:**
  - AI-generated meshes wrapped in `ReplicatedStorage.CTTAssets`: bowl, pot, pan, strawberry, slices, kiwi, blueberries, mint
  - fruit chop bodies: whole fruit, then real shingled slices
  - `FruitMesh`: EditableMesh lathe meshes with true planar cut faces and EditableImage textures. Blocked until the owner enables **Game Settings → Security → Allow Mesh / Image APIs**; it falls back automatically.
- **Modern type:** BuilderSans replaces Fredoka.
- **Future hooks (data only, not live):**
  - `def.media.reactionVideoId` (character food-reaction video)
  - `def.media.makeThisLink` (deep link for a "Make This" button)
  - the disabled "📸 Cooked it IRL? (soon)" button on the recipe card (photo upload)
  - AI plating feedback (e.g. Gemma): plug in where `Coach.feedback` is called. It takes (step, quality, label, details) and returns good/improve strings, so an AI judge can return the same shape.
