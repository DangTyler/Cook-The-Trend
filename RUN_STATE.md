# RUN_STATE (update at milestones)

**Last update:** 2026-10-25 00:12 ET (deadline 2026-10-25 09:00 ET). Feature-complete; see HANDOFF.md / TEST_RESULTS.md

## Status
- Core loop + 3 recipes playable, server-authoritative, verified in Studio Play (autoplay harness + real clicks/keys).
- Partner direction applied (learning-first, "CookQuest" vision; title kept per user):
  - Fruit Cup is the flagship (free, first)
  - Demonstrate → Instruct → Do → Feedback on every step (ghost 3D demos, real-life tips, coach cards)
  - recipe card with quantities, steps and 3D "looks like" thumbnails; results recap
  - realistic AI meshes (bowl/pot/pan/fruit)
  - modern BuilderSans type
- Code review (subagent, build/code_review.md): high and medium client/server fixes applied:
  - double-tap guard and ctx cancel
  - flip tap gate
  - async saves outside the busy lock
  - placement scored on the camera ray
  - slide-off pour release
  - rollback on rejected steps
  - profile `rev`
  - finish locks restart/quit
  - DataStore `seq` guard
  - autosave pcall
  - ordered validation loops
  - loops play under mute
- EditableMesh slicing (`FruitMesh`) LIVE: the owner enabled "Allow Mesh / Image APIs" (~23:00). The client budget is ~3 live meshes, so pieces are merged into one mesh. Warm-up probe; static fallback when unavailable.
- Persistence now works in Studio (the owner enabled API access): verified across Play sessions.

## How to drive QA (Studio only)
Client Luau:
- `LocalPlayer:SetAttribute("CTT_Auto","good"|"bad"|"demo"|"")` ("demo" lets each lesson play 4.5 s)
- then `SetAttribute("CTT_Cmd", ...)` with one of: `start:<id>`, `retry`, `close`, `quit`, `unlock:<id>`, `recipe:<id>`, `recap`, `hidesheet`
- Read state from `LocalPlayer.CTT_Debug` attributes.

Push code: `tools/push.ps1 [-Only <path fragment>]`. Rebuild set/assets: `build/*.luau` via `tools/studio-mcp.ps1 -Tool execute_luau -LuauFile ...`.

## Known issues / next
- Two-client isolation not tested with real clients (no multi-client tooling from MCP). Isolation is by design: client-local scenes, per-player server tables.
- Kiwi slice texture reads yellow-green (AI texture).
- Results/recipe text is small on phones (cards scale to fit).

## Exact next action
None required: feature-complete and verified. Optional: owner publishes; two-client test via Test → Clients and Servers.
