# TEST_RESULTS (final build, 2026-10-25 00:10 ET)

**Evidence types:**
- **PLAY-SOLO:** Studio Play (1 client + server in one Studio, desktop viewport ~1280x719 unless noted). Driven by the Studio-only autoplay harness (`CTT_Auto` good/bad/demo, which calls the same input handlers a player triggers) or by real mouse/keyboard events (StudioMCP `user_mouse_input` / `user_keyboard_input`).
- **REMOTE-CALL:** direct `Request:InvokeServer` probes from the client.
- **DEVICE-EMU:** Studio Device Simulator (iPhone 14, 844x390 landscape).

None of this is a real phone or a real multiplayer server.

## Final regression (fresh profile via Studio-only `debugWipe`)
| Check | Result |
|---|---|
| Locked ramen cannot start (server) | PASS: REJECT "Locked" |
| Burger unlock with 0 coins | PASS: REJECT "Need 40 more coins" |
| Fruit Cup good / bad | PASS: S99 (steps 100/97/98/99/100/99) / D28 (75/34/16/0/17/0) |
| Ramen unlocks at 60 followers, good / bad | PASS: S100 / D23 |
| Burger coin unlock (40) then good / bad | PASS: unlock ok (coins 224→184); S100 / D14 |
| Rewards exactly once, match formulas | PASS: e.g. dessert good 0→104 coins (89 + 15 first clear), ramen +75, burger +95 |
| No leaks across 6 consecutive runs | PASS: 0 particle emitters left; Sound count 26–29 (24 templates + music + transient one-shots); scene parts identical per recipe at each results screen |
| Character reset (Health=0) mid-burger | PASS: run continued to results (score 80, rewards granted once) |
| Switch recipe mid-run (dessert step 2 → ramen) | PASS: abandoned dessert paid nothing; ramen +60 only |
| Server validation | PASS: unknown action, unknown recipe, wrong step index, stale session, unknown/duplicate/missing picks, too-fast picks/chops, NaN, non-array events, replayed step ("Wrong step"), step after abandon all rejected; coins unchanged |

## Learning layer (partner brief)
| Check | Result |
|---|---|
| Every step opens with "Watch the technique" (real tip + looks-like + why), ghost 3D demo, MY TURN | PASS: pick, chop, heat, pour, place, stack demos all render (captures/final_02, gameplay GIFs) |
| Coach card after every scored step (✓ / 💡 next time) | PASS |
| Recipe card from feed 📖 and results "RECIPE + TIPS"; quantities, steps, 3D looks-like thumbnails, MAKE THIS | PASS (final_08, final_09) |
| Recap mode shows your result + what to improve per step | PASS (final_11) |
| Results lead with the most useful improvement tip | PASS (final_10) |

## Visual tech
| Check | Result |
|---|---|
| EditableMesh slicing: real cut faces at the player's cut positions, toppled slices, one live mesh per ingredient | PASS after owner enabled "Allow Mesh / Image APIs" (final_03_editablemesh_slicing, final_12) |
| EditableMesh budget handling | PASS: budget is tiny (~3 live meshes on this client). Warm-up probe, per-step renderer choice, merged pieces; no budget errors in the final runs. Previews and toppings use static meshes. |
| EditableImage textures (strawberry seeds, kiwi seed ring, tomato chambers, scallion rings, chashu spiral) | PASS (Studio) |
| Smooth EditableMesh noodle strands: stiff when raw, relaxing into waves while boiling (pot) and in the bowl | PASS (final_18). Fixed: tube winding/normals and the mesh-local origin (EditableMesh parts draw vertices relative to the part origin). |
| Chef: your avatar stands behind the counter and emotes at the serve | PASS (final_16, final_17) |
| Post-fix sanity regression (00:05) | PASS: dessert S99, ramen S99, burger S99, ramen bad D23; 0 emitters left; console clean |
| AI-generated meshes (bowl, pot, pan, strawberry, blueberries, mint, slices) load in Play | PASS |

## Layout / devices
| Check | Result |
|---|---|
| Desktop 885x635 and 1280x719 viewports | PASS (all captures) |
| Phone (DEVICE-EMU iPhone 14): feed, compact header, cooking HUD, lesson panel, checklist, results | PASS with caveat: results / recipe-card text scales to ~0.55 and is small (readable but tight). Touch thumbstick hidden (StarterPlayer movement Scriptable). |

## Earlier checks (still valid)
- All 24 SFX ids load (Sound.IsLoaded).
- Missing media: every SoundId set invalid mid-session → a run still completed.
- Persistence: with Studio API access enabled (owner turned it on ~23:00), coins/followers persisted across separate Play sessions (followers 632 → 767 → 988 across restarts). Real published-server persistence is not verified.

## Not verified
- **Two-client isolation with real clients:** no multi-client tooling via MCP this session. Isolation is by design: the food scene is client-local (`workspace.CTT_Scene`) and the server keys every table by Player.
- Real mobile hardware, performance numbers, the published experience.
