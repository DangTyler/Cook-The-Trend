-- Cook the Trend: client entry. Wires feed, kitchen, HUD and results to the server session API.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("CTT")
local ClientMods = Shared:WaitForChild("Client")
local Recipes = require(Shared.Recipes)
local UI = require(ClientMods.UI)
local Sfx = require(ClientMods.Sfx)
local Feed = require(ClientMods.Feed)
local Hud = require(ClientMods.Hud)
local Kitchen = require(ClientMods.Kitchen)
local Results = require(ClientMods.Results)
local RecipeSheet = require(ClientMods.RecipeSheet)
local FruitMesh = require(ClientMods.FruitMesh)
FruitMesh.warmup()
-- smooth EditableMesh tubes for noodles / honey once the mesh budget is ready
require(Shared.Dish).TubeBuilder = function(paths, radius)
	return FruitMesh.tubes(paths, radius)
end
-- (topping slices stay static meshes: each live EditableMesh counts against a tiny per-client budget)

local remotes = ReplicatedStorage:WaitForChild("CTTRemotes")
local Request = remotes:WaitForChild("Request")
local Push = remotes:WaitForChild("Push")

for _, t in { Enum.CoreGuiType.Chat, Enum.CoreGuiType.PlayerList, Enum.CoreGuiType.Backpack, Enum.CoreGuiType.EmotesMenu } do
	pcall(function()
		StarterGui:SetCoreGuiEnabled(t, false)
	end)
end

-- no walking in this game: hide the touch thumbstick/jump so they never cover the feed
task.spawn(function()
	local ok, err = pcall(function()
		local mod = player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule", 5)
		if mod then
			require(mod):GetControls():Disable()
		end
	end)
	if not ok then
		warn("[CTT] could not disable controls", err)
	end
end)

local function request(action: string, data)
	local ok, res = pcall(function()
		return Request:InvokeServer(action, data)
	end)
	if not ok then
		warn("[CTT] request failed", action, res)
		return { ok = false, reason = "Network error", retry = true }
	end
	return res
end

---------------------------------------------------------------- gui root
local gui = Instance.new("ScreenGui")
gui.Name = "CookTheTrend"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")

local root = Instance.new("Frame")
root.Name = "Root"
root.BackgroundTransparency = 1
root.Parent = gui
local rootScale = Instance.new("UIScale")
rootScale.Parent = root
local currentScale = 1
local function getScale()
	return currentScale
end

local camera = workspace.CurrentCamera
local kitchen -- forward
local hud
local feed
local function relayout()
	local vp = camera.ViewportSize
	-- bigger overall UI (user: text was small); phones get a higher floor
	local s = math.clamp(vp.Y / 720, 0.75, 1.8)
	if vp.Y < 520 then
		s = math.max(s, 0.9)
	end
	-- narrow / phone landscape: keep enough feed width to read cards
	currentScale = s
	rootScale.Scale = s
	root.Size = UDim2.fromScale(1 / s, 1 / s)
	local feedFrac = vp.X / math.max(vp.Y, 1) > 1.9 and 0.27 or 0.28
	if vp.X < 900 then
		feedFrac = 0.31
	end
	if feed then
		feed.root.Size = UDim2.new(feedFrac, 0, 1, 0)
		feed:setCompact(vp.Y < 520)
	end
	if kitchen then
		kitchen:setFeedFrac(feedFrac, vp.Y < 520)
	end
	if hud then
		hud:setCompact(vp.Y < 520)
	end
	local hudArea = root:FindFirstChild("KitchenHud")
	if hudArea then
		hudArea.Size = UDim2.new(1 - feedFrac, 0, 1, 0)
		hudArea.Position = UDim2.new(feedFrac, 0, 0, 0)
	end
	local sheetFrame = root:FindFirstChild("RecipeSheet")
	if sheetFrame then
		sheetFrame.Size = UDim2.new(1 - feedFrac, 0, 1, 0)
		sheetFrame.Position = UDim2.new(feedFrac, 0, 0, 0)
	end
	local res = root:FindFirstChild("Results")
	if res then
		res.Size = UDim2.new(1 - feedFrac, 0, 1, 0)
		res.Position = UDim2.new(feedFrac, 0, 0, 0)
	end
end

---------------------------------------------------------------- state
local profile = nil
local active = nil -- { recipeId, sessionId, stepIndex, total, instruction, token }
local runToken = 0
local results
local recipeSheet

local function toast(text, color)
	if hud then
		hud:toast(text, color)
	end
end

local function setProfile(p)
	if not p then
		return
	end
	local old = profile
	-- ignore snapshots older than what we already show (results animation lag)
	if old and (p.rev or 0) < (old.rev or 0) then
		return
	end
	profile = p
	feed:setProfile(p)
	if old then
		if p.coins > old.coins then
			feed:bump("coins")
		end
		if p.followers > old.followers then
			feed:bump("followers")
		end
	end
end

local startRecipe -- forward

local function stopActive(abandon: boolean)
	runToken += 1
	local was = active
	active = nil
	kitchen:cancel()
	feed:setActive(nil)
	if was and abandon then
		request("abandon", { sessionId = was.sessionId })
	end
end

local function goIdle()
	results:hide()
	stopActive(false)
	hud:setIdle(true)
	kitchen:showcase(feed.selected or "dessert")
end

local starting = false
startRecipe = function(recipeId: string)
	if starting then
		return -- double-tap guard
	end
	local recipe = Recipes.Defs[recipeId]
	if not recipe then
		return
	end
	if profile and not profile.unlocked[recipeId] then
		toast("That trend is still locked!", UI.Colors.red)
		return
	end
	starting = true
	results:hide()
	if active then
		stopActive(true)
	else
		runToken += 1
		kitchen:cancel()
	end
	local res
	for attempt = 1, 5 do
		res = request("start", { recipeId = recipeId, force = true })
		if res and res.ok then
			break
		end
		if not (res and res.retry) then
			break
		end
		task.wait(0.4 * attempt)
	end
	starting = false
	if not (res and res.ok) then
		toast("Couldn't start: " .. tostring(res and res.reason), UI.Colors.red)
		hud:setIdle(true)
		kitchen:showcase(recipeId)
		return
	end
	runToken += 1
	local token = runToken
	active = { recipeId = recipeId, sessionId = res.sessionId, stepIndex = 1, total = #recipe.steps, instruction = recipe.steps[1].title }
	feed:setActive(active)
	feed:scrollTo(recipeId)
	hud:setIdle(false)
	Sfx.play("whoosh")
	task.spawn(function()
		local final = kitchen:run(recipe, res, {
			onFinished = function(res)
				-- scored: lock out restart/quit and show the new totals right away
				if token ~= runToken then
					return
				end
				active = nil
				feed:setActive(nil)
				hud.ctrl.Visible = false
				setProfile(res.profile)
			end,
			onStep = function(i, step)
				if token ~= runToken or not active then
					return
				end
				active.stepIndex = i
				active.instruction = step.title
				active.tip = step.learn and step.learn.tip or nil
				feed:setActive(active)
			end,
		})
		if token ~= runToken then
			return -- cancelled / replaced
		end
		if final and final.aborted then
			toast("Run reset: " .. tostring(final.reason), UI.Colors.orange)
			stopActive(true)
			hud:setIdle(true)
			return
		end
		if not final then
			return
		end
		if token ~= runToken then
			return
		end
		active = nil
		feed:setActive(nil)
		kitchen:finishRun()
		task.wait(0.4)
		if token ~= runToken then
			return
		end
		local snap = kitchen:snapshotDish()
		results:show(final, recipe, snap)
		results.lastRecipe = recipeId
		results.lastResult = final
	end)
end

---------------------------------------------------------------- build modules
feed = Feed.new(root, {
	Sfx = Sfx,
	getScale = getScale,
	onCook = function(id, force)
		startRecipe(id)
	end,
	onUnlock = function(id)
		local r = request("unlock", { recipeId = id })
		if r and r.ok then
			setProfile(r.profile)
			Sfx.play("cash")
			toast("🔓 " .. Recipes.Defs[id].name .. " unlocked!", UI.Colors.mint)
		else
			Sfx.play("buzz")
			toast(r and r.reason or "Can't unlock yet", UI.Colors.red)
		end
	end,
	onPreview = function(id)
		Sfx.play("click", { volume = 0.6 })
		if not active and not results.overlay.Visible then
			kitchen:showcase(id)
		end
	end,
	onRecipe = function(id)
		if recipeSheet then
			recipeSheet:show(id, "preview")
		end
	end,
	onToggleMute = function()
		Sfx.setMuted(not Sfx.isMuted())
		feed:setMuted(Sfx.isMuted())
	end,
	toast = function(t, c)
		toast(t, c)
	end,
})

local restartArm, quitArm = 0, 0
hud = Hud.new(root, {
	Sfx = Sfx,
	getScale = getScale,
	onRestart = function()
		if not active then
			return
		end
		if os.clock() < restartArm then
			restartArm = 0
			hud.ctrlHint.Text = ""
			startRecipe(active.recipeId)
		else
			restartArm = os.clock() + 3
			hud.ctrlHint.Text = "Tap 🔄 again to restart this dish"
			task.delay(3.1, function()
				if os.clock() >= restartArm then
					hud.ctrlHint.Text = ""
				end
			end)
		end
	end,
	onQuit = function()
		if not active then
			return
		end
		if os.clock() < quitArm then
			quitArm = 0
			hud.ctrlHint.Text = ""
			stopActive(true)
			hud:setIdle(true)
			kitchen:showcase(feed.selected or "dessert")
			toast("Dish abandoned. Pick another trend!", UI.Colors.ink)
		else
			quitArm = os.clock() + 3
			hud.ctrlHint.Text = "Tap ❌ again to quit this dish"
			task.delay(3.1, function()
				if os.clock() >= quitArm then
					hud.ctrlHint.Text = ""
				end
			end)
		end
	end,
})

kitchen = Kitchen.new({ Hud = hud, Sfx = Sfx, request = request })

results = Results.new(root, {
	Sfx = Sfx,
	getScale = getScale,
	onRetry = function()
		local id = results.lastRecipe
		if id then
			startRecipe(id)
		end
	end,
	onNext = function()
		local cur = results.lastRecipe
		local order = Recipes.Order
		local idx = table.find(order, cur) or 0
		-- next unlocked recipe after the current one, wrapping
		for k = 1, #order do
			local id = order[((idx + k - 1) % #order) + 1]
			if profile and profile.unlocked[id] and id ~= cur then
				startRecipe(id)
				return
			end
		end
		-- nothing else unlocked: back to the feed and point at the next lock
		goIdle()
		local nextId = order[(idx % #order) + 1]
		feed:scrollTo(nextId)
		local def = Recipes.Defs[nextId]
		if def.unlock.kind == "coins" then
			toast(string.format("Unlock %s for %d coins in the feed!", def.short, def.unlock.amount), UI.Colors.pink)
		else
			toast(string.format("%s unlocks at %d followers", def.short, def.unlock.amount), UI.Colors.pink)
		end
	end,
	onClose = function()
		goIdle()
	end,
	onRecipe = function()
		if results.lastRecipe and recipeSheet then
			recipeSheet:show(results.lastRecipe, "recap", results.lastResult)
		end
	end,
	onRewardsShown = function(res)
		setProfile(res.profile)
		-- the chef (your avatar) reacts to the reveal
		task.spawn(function()
			local char = player.Character
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			if hum then
				local emote = (res.rank == "S" or res.rank == "A") and "cheer" or (res.rank == "B" and "wave" or "laugh")
				pcall(function()
					hum:PlayEmote(emote)
				end)
			end
		end)
		if res.rank == "S" and results.lastRecipe then
			task.delay(1.2, function()
				toast("💖 " .. Recipes.Defs[results.lastRecipe].creator .. " followed you back!", UI.Colors.pink)
				Sfx.play("sparkle")
			end)
		end
		if res.newlyUnlocked and #res.newlyUnlocked > 0 then
			for _, id in res.newlyUnlocked do
				toast("🔓 New trend unlocked: " .. Recipes.Defs[id].name, UI.Colors.mint)
			end
		end
	end,
})

recipeSheet = RecipeSheet.new(root, {
	Sfx = Sfx,
	getScale = getScale,
	toast = function(t, c)
		toast(t, c)
	end,
	onMake = function(id)
		if active and active.recipeId == id then
			return
		end
		if active then
			toast("Finish or quit your current dish first (❌ bottom-right)", UI.Colors.orange)
			return
		end
		startRecipe(id)
	end,
})

camera:GetPropertyChangedSignal("ViewportSize"):Connect(relayout)
relayout()
hud:setIdle(true)
kitchen:showcase("dessert")

Push.OnClientEvent:Connect(function(kind, data)
	if kind == "profile" then
		setProfile(data)
	end
end)

task.spawn(function()
	for attempt = 1, 20 do
		local r = request("hello")
		if r and r.ok then
			setProfile(r.profile)
			if r.profile.persistence ~= "loading" then
				break
			end
		end
		task.wait(0.5)
	end
end)

-- background music (soft)
task.delay(1.5, function()
	Sfx.loop("music", 1)
end)

-- keep the camera ours after respawns
player.CharacterAdded:Connect(function()
	task.wait()
	camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Scriptable
end)

-- Studio-only QA hooks: autoplay + commands via player attributes (ignored in live servers)
if game:GetService("RunService"):IsStudio() then
	player:GetAttributeChangedSignal("CTT_Auto"):Connect(function()
		local v = player:GetAttribute("CTT_Auto")
		kitchen.autoplay = (v == "good" or v == "bad" or v == "demo") and v or nil
	end)
	player:GetAttributeChangedSignal("CTT_Cmd"):Connect(function()
		local cmd = player:GetAttribute("CTT_Cmd")
		if not cmd or cmd == "" then
			return
		end
		player:SetAttribute("CTT_Cmd", "")
		local verb, arg = string.match(cmd, "^(%w+):?(.*)$")
		if verb == "start" then
			startRecipe(arg)
		elseif verb == "retry" then
			results.retryBtn:SetAttribute("Disabled", false)
			if results.lastRecipe then
				startRecipe(results.lastRecipe)
			end
		elseif verb == "close" then
			goIdle()
		elseif verb == "recipe" then
			recipeSheet:show(arg, "preview")
		elseif verb == "recap" then
			if results.lastRecipe then
				recipeSheet:show(results.lastRecipe, "recap", results.lastResult)
			end
		elseif verb == "hidesheet" then
			recipeSheet:hide()
		elseif verb == "wipe" then
			local r = request("debugWipe")
			if r and r.ok then
				profile = nil
				setProfile(r.profile)
			end
			player:SetAttribute("CTT_LastUnlock", r and (r.ok and "wiped" or r.reason) or "nil")
		elseif verb == "quit" then
			stopActive(true)
			hud:setIdle(true)
		elseif verb == "unlock" then
			local r = request("unlock", { recipeId = arg })
			if r and r.ok then
				setProfile(r.profile)
			end
			player:SetAttribute("CTT_LastUnlock", r and (r.ok and "ok" or r.reason) or "nil")
		end
	end)
end

-- debug/QA hooks (read-only state for automated playtests)
local dbg = Instance.new("Folder")
dbg.Name = "CTT_Debug"
dbg.Parent = player
local function publishDebug()
	dbg:SetAttribute("active", active and active.recipeId or "")
	dbg:SetAttribute("step", active and active.stepIndex or 0)
	dbg:SetAttribute("resultsOpen", results.overlay.Visible)
	dbg:SetAttribute("coins", profile and profile.coins or -1)
	dbg:SetAttribute("followers", profile and profile.followers or -1)
	dbg:SetAttribute("focus", kitchen.focusName)
	dbg:SetAttribute("sceneParts", #kitchen.folder:GetDescendants())
	dbg:SetAttribute("lastScore", results.lastResult and results.lastResult.score or -1)
	dbg:SetAttribute("meshReady", FruitMesh.ready)
	if results.lastResult and results.lastResult.steps then
		local q = {}
		for i, st in results.lastResult.steps do
			q[i] = string.format("%d:%d", i, math.floor((st.quality or 0) * 100))
		end
		dbg:SetAttribute("stepQ", table.concat(q, " "))
	end
end
task.spawn(function()
	while true do
		publishDebug()
		task.wait(0.2)
	end
end)
print("[CTT] client ready")
