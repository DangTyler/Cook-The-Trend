-- Cook the Trend: server-authoritative recipe sessions, scoring, rewards and persistence.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("CTT")
local Config = require(Shared.Config)
local Recipes = require(Shared.Recipes)
local StepMath = require(Shared.StepMath)

local remotes = ReplicatedStorage:FindFirstChild("CTTRemotes")
if remotes then
	remotes:Destroy()
end
remotes = Instance.new("Folder")
remotes.Name = "CTTRemotes"
local Request = Instance.new("RemoteFunction")
Request.Name = "Request"
Request.Parent = remotes
local Push = Instance.new("RemoteEvent")
Push.Name = "Push"
Push.Parent = remotes
remotes.Parent = ReplicatedStorage

---------------------------------------------------------------- persistence
local store
local storeOk = pcall(function()
	store = DataStoreService:GetDataStore(Config.DataStoreName)
end)

local profiles = {} -- [Player] = profile
local persist = {} -- [Player] = "on" | "off" | "loading"
local dirty = {}
local sessions = {} -- [Player] = session
local busy = {}
local lastSave = {}

local function newProfile()
	return {
		coins = 0,
		followers = 0,
		unlocked = {},
		best = {},
		runs = 0,
		v = 1,
	}
end

local function sanitize(p)
	local d = newProfile()
	if typeof(p) ~= "table" then
		return d
	end
	d.coins = math.max(0, math.floor(tonumber(p.coins) or 0))
	d.followers = math.max(0, math.floor(tonumber(p.followers) or 0))
	d.runs = math.max(0, math.floor(tonumber(p.runs) or 0))
	d.seq = math.max(0, math.floor(tonumber(p.seq) or 0))
	if typeof(p.unlocked) == "table" then
		for id, v in p.unlocked do
			if Recipes.Defs[id] and v == true then
				d.unlocked[id] = true
			end
		end
	end
	if typeof(p.best) == "table" then
		for id, b in p.best do
			if Recipes.Defs[id] and typeof(b) == "table" then
				d.best[id] = { score = tonumber(b.score) or 0, rank = tostring(b.rank or "D") }
			end
		end
	end
	return d
end

local function save(player, force)
	if persist[player] ~= "on" or not store then
		return false
	end
	if not force and lastSave[player] and os.clock() - lastSave[player] < 6 then
		dirty[player] = true
		return false
	end
	lastSave[player] = os.clock()
	dirty[player] = nil
	local data = profiles[player]
	if not data then
		return false
	end
	local ok, err = pcall(function()
		data.seq = (data.seq or 0) + 1
		store:UpdateAsync("u_" .. player.UserId, function(old)
			-- never overwrite a newer save written by another server
			if typeof(old) == "table" and (tonumber(old.seq) or 0) >= data.seq then
				warn("[CTT] skipped stale save for", player.Name)
				return nil
			end
			return data
		end)
	end)
	if not ok then
		warn("[CTT] save failed for", player.Name, err)
		dirty[player] = true
	end
	return ok
end

local function snapshot(player)
	local p = profiles[player]
	return {
		coins = p.coins,
		followers = p.followers,
		unlocked = p.unlocked,
		best = p.best,
		runs = p.runs,
		rev = p.rev or 0,
		persistence = persist[player],
		active = sessions[player] and {
			recipeId = sessions[player].recipeId,
			stepIndex = sessions[player].stepIndex,
			sessionId = sessions[player].id,
		} or nil,
	}
end

local function applyFollowerUnlocks(p)
	local newly = {}
	for _, id in Recipes.Order do
		local def = Recipes.Defs[id]
		if not p.unlocked[id] and (def.unlock.kind == "free" or Config.UnlockAll) then
			p.unlocked[id] = true
		elseif not p.unlocked[id] and def.unlock.kind == "followers" and p.followers >= def.unlock.amount then
			p.unlocked[id] = true
			table.insert(newly, id)
		end
	end
	return newly
end

local function loadProfile(player)
	persist[player] = "loading"
	local data, ok, err = nil, false, nil
	if storeOk and store then
		for attempt = 1, 3 do
			ok, err = pcall(function()
				data = store:GetAsync("u_" .. player.UserId)
			end)
			if ok or tostring(err):find("Studio access") then
				break
			end
			task.wait(attempt)
		end
	end
	if not player.Parent then
		return
	end
	profiles[player] = sanitize(data)
	if ok then
		persist[player] = "on"
	else
		persist[player] = "off"
		warn("[CTT] persistence unavailable, session-only progress:", err)
	end
	applyFollowerUnlocks(profiles[player])
	Push:FireClient(player, "profile", snapshot(player))
end

Players.PlayerAdded:Connect(function(player)
	profiles[player] = newProfile()
	applyFollowerUnlocks(profiles[player])
	task.spawn(loadProfile, player)
	player.CharacterAdded:Connect(function(char)
		local hum = char:WaitForChild("Humanoid", 5)
		if hum then
			hum.WalkSpeed = 0
			hum.JumpPower = 0
			hum.UseJumpPower = true
		end
		-- the avatar is the chef: stand behind the counter facing the camera, rooted in place
		local hrp = char:WaitForChild("HumanoidRootPart", 5)
		if hrp and hum then
			task.wait(0.2)
			-- standing on a little step so the chef shows above the counter
			local y = hum.HipHeight + hrp.Size.Y / 2 + 0.85
			if hum.RigType == Enum.HumanoidRigType.R6 then
				y = 3.8
			end
			local pos = Vector3.new(0, y, -4.3)
			hrp.CFrame = CFrame.lookAt(pos, pos + Vector3.new(0, 0, 1))
			hrp.Anchored = true
		end
	end)
end)
for _, p in Players:GetPlayers() do
	task.spawn(function()
		profiles[p] = newProfile()
		loadProfile(p)
	end)
end

Players.PlayerRemoving:Connect(function(player)
	save(player, true)
	profiles[player] = nil
	sessions[player] = nil
	persist[player] = nil
	busy[player] = nil
	dirty[player] = nil
	lastSave[player] = nil
end)

game:BindToClose(function()
	if RunService:IsStudio() then
		for _, p in Players:GetPlayers() do
			task.spawn(save, p, true)
		end
		task.wait(1)
		return
	end
	for _, p in Players:GetPlayers() do
		save(p, true)
	end
end)

task.spawn(function()
	while true do
		task.wait(10)
		local list = {}
		for p in dirty do
			table.insert(list, p)
		end
		for _, p in list do
			if p.Parent then
				pcall(save, p, true)
			end
		end
	end
end)

---------------------------------------------------------------- validation
local function isArray(t, maxLen)
	if typeof(t) ~= "table" then
		return false
	end
	local n = #t
	if n > maxLen then
		return false
	end
	for k in t do
		if typeof(k) ~= "number" or k < 1 or k > n or k % 1 ~= 0 then
			return false
		end
	end
	return true
end

local function validNumber(v)
	return typeof(v) == "number" and v == v and v > -1e4 and v < 1e4
end

-- Returns cleaned events or nil, reason
local function validateEvents(step, events, elapsed)
	local tol = Config.TimeTolerance
	local kind = step.type
	if not isArray(events, Config.MaxEventsPerStep) then
		return nil, "bad events"
	end
	if kind == "chop" then
		local out, prev = {}, -1
		local dur = StepMath.chopDuration(step)
		for _, t in events do
			if not validNumber(t) or t < prev or t < 0 or t > dur + 0.5 then
				return nil, "bad chop time"
			end
			prev = t
			table.insert(out, t)
		end
		if #out > 28 then
			return nil, "too many cuts"
		end
		if elapsed + tol < dur * 0.95 then
			return nil, "chop too fast"
		end
		if prev > elapsed + tol then
			return nil, "future cut"
		end
		return out
	elseif kind == "heat" then
		if #events ~= #step.phases then
			return nil, "phase count"
		end
		local out = {}
		for k = 1, #events do
			local t = events[k]
			if not validNumber(t) then
				return nil, "bad heat time"
			end
			out[k] = t
			local start = StepMath.heatPhaseStart(out, k)
			if t < start - 0.05 then
				return nil, "phase order"
			end
			local d = StepMath.heatDoneness(step, t - start)
			if d > Config.AutoBurnAt + 0.15 then
				return nil, "phase too long"
			end
		end
		if out[#out] > elapsed + tol then
			return nil, "future tap"
		end
		return out
	elseif kind == "pour" then
		local out, prev = {}, -1
		for _, p in events do
			if not isArray(p, 2) or #p ~= 2 or not validNumber(p[1]) or not validNumber(p[2]) then
				return nil, "bad pulse"
			end
			if p[1] < prev or p[2] < p[1] or p[1] < 0 then
				return nil, "pulse order"
			end
			prev = p[2]
			table.insert(out, { p[1], p[2] })
		end
		if #out == 0 or #out > 12 then
			return nil, "pulse count"
		end
		if prev > elapsed + tol then
			return nil, "future pour"
		end
		return out
	elseif kind == "place" then
		if #events ~= #step.toppings then
			return nil, "topping count"
		end
		local out = {}
		for i, p in events do
			if not isArray(p, 2) or #p ~= 2 or not validNumber(p[1]) or not validNumber(p[2]) then
				return nil, "bad point"
			end
			out[i] = { math.clamp(p[1], -3, 3), math.clamp(p[2], -3, 3) }
		end
		if elapsed + tol < 0.25 * #out then
			return nil, "placed too fast"
		end
		return out
	elseif kind == "stack" then
		if #events ~= #step.layers then
			return nil, "layer count"
		end
		local out = {}
		for k = 1, #events do
			local t = events[k]
			if not validNumber(t) then
				return nil, "bad drop"
			end
			out[k] = t
			local spawn = StepMath.stackSpawn(out, k)
			if t < spawn - 0.05 or t - spawn > StepMath.StackAutoDrop + 0.4 then
				return nil, "drop timing"
			end
		end
		if out[#out] > elapsed + tol then
			return nil, "future drop"
		end
		return out
	elseif kind == "pick" then
		local allowed = {}
		for _, id in step.required do
			allowed[id] = true
		end
		for _, id in step.decoys do
			allowed[id] = true
		end
		local out, seen = {}, {}
		for _, id in events do
			if typeof(id) ~= "string" or not allowed[id] then
				return nil, "unknown item"
			end
			if seen[id] then
				return nil, "duplicate pick"
			end
			seen[id] = true
			table.insert(out, id)
		end
		for _, id in step.required do
			if not seen[id] then
				return nil, "missing pick"
			end
		end
		if elapsed + tol < 0.2 * #out then
			return nil, "picked too fast"
		end
		return out
	end
	return nil, "unknown step"
end

---------------------------------------------------------------- results
local function explain(recipe, session, cats)
	local best, worst
	for cat, v in cats do
		if not best or v > cats[best] then
			best = cat
		end
		if not worst or v < cats[worst] then
			worst = cat
		end
	end
	local worstLabel
	local worstQ = math.huge
	for _, r in session.results do
		if r.quality < worstQ then
			worstQ = r.quality
			worstLabel = r.label
		end
	end
	if not best then
		return "Dish served."
	end
	local nice = {
		ingredients = "You picked all the right ingredients",
		prep = "Your knife work was sharp",
		cook = "Your cook was spot on",
		plating = "Your plating looked camera-ready",
	}
	local weak = {
		ingredients = "a weird ingredient snuck in",
		prep = "the cuts were chunky",
		cook = "the cook was off",
		plating = "the plating got messy",
	}
	if cats[worst] >= 0.85 then
		return "Flawless run: every step looked like the video."
	end
	return string.format(
		"%s, but %s (%s).",
		nice[best],
		weak[worst],
		string.lower(worstLabel or "")
	)
end

local function finish(player, session, recipe)
	local p = profiles[player]
	local total = os.clock() - session.startClock
	local score, cats, speedFrac = StepMath.finalScore(recipe, session.results, total)
	local rankInfo = Config.rankFor(score)
	local prevBest = p.best[recipe.id]
	local firstClear = prevBest == nil
	local isPB = prevBest == nil or score > prevBest.score

	local coins = math.floor(recipe.baseCoins * (0.3 + 0.7 * score / 100) + 0.5)
	if firstClear then
		coins += Config.FirstClearCoinBonus
	end
	local followers = math.floor(recipe.baseFollowers * (score / 100) ^ 1.4 + 0.5)
	if rankInfo.rank == "S" then
		followers = math.floor(followers * 1.25 + 0.5)
	end
	if isPB and not firstClear then
		followers += Config.PBFollowerBonus
	end

	p.coins += coins
	p.followers += followers
	p.runs += 1
	if isPB then
		p.best[recipe.id] = { score = score, rank = rankInfo.rank }
	end
	local newly = applyFollowerUnlocks(p)
	sessions[player] = nil
	p.rev = (p.rev or 0) + 1
	task.spawn(save, player, true)

	local catOut = {}
	for cat, v in cats do
		catOut[cat] = math.floor(v * 100 + 0.5)
	end
	local stepOut = {}
	for i, r in session.results do
		stepOut[i] = { label = r.label, quality = r.quality, category = r.category, details = r.details }
	end
	return {
		ok = true,
		finished = true,
		score = score,
		rank = rankInfo.rank,
		rankWord = rankInfo.word,
		categories = catOut,
		explanation = explain(recipe, session, cats),
		seconds = math.floor(total + 0.5),
		speedBonus = speedFrac > 0.2 and score >= 60,
		coins = coins,
		followers = followers,
		firstClear = firstClear,
		personalBest = isPB,
		previousBest = prevBest and prevBest.score or nil,
		newlyUnlocked = newly,
		steps = stepOut,
		profile = snapshot(player),
	}
end

---------------------------------------------------------------- request handler
local handlers = {}

function handlers.hello(player)
	return { ok = true, profile = snapshot(player) }
end

function handlers.unlock(player, data)
	local id = typeof(data) == "table" and data.recipeId
	local def = typeof(id) == "string" and Recipes.Defs[id]
	local p = profiles[player]
	if not def then
		return { ok = false, reason = "Unknown recipe" }
	end
	if p.unlocked[id] then
		return { ok = true, profile = snapshot(player) }
	end
	if def.unlock.kind ~= "coins" then
		return { ok = false, reason = string.format("Reach %d followers", def.unlock.amount) }
	end
	if p.coins < def.unlock.amount then
		return { ok = false, reason = string.format("Need %d more coins", def.unlock.amount - p.coins) }
	end
	p.coins -= def.unlock.amount
	p.unlocked[id] = true
	p.rev = (p.rev or 0) + 1
	task.spawn(save, player, true)
	return { ok = true, profile = snapshot(player), unlocked = id }
end

function handlers.start(player, data)
	local id = typeof(data) == "table" and data.recipeId
	local def = typeof(id) == "string" and Recipes.Defs[id]
	local p = profiles[player]
	if not def then
		return { ok = false, reason = "Unknown recipe" }
	end
	if not p.unlocked[id] then
		return { ok = false, reason = "Locked" }
	end
	local cur = sessions[player]
	if cur and not (data.force == true) then
		return { ok = false, reason = "Already cooking", active = cur.recipeId }
	end
	local session = {
		id = HttpService:GenerateGUID(false),
		recipeId = id,
		stepIndex = 1,
		stepStart = os.clock(),
		startClock = os.clock(),
		results = {},
	}
	sessions[player] = session
	return { ok = true, sessionId = session.id, stepIndex = 1, recipeId = id }
end

function handlers.step(player, data)
	local session = sessions[player]
	if not session then
		return { ok = false, reason = "No active dish" }
	end
	if typeof(data) ~= "table" or data.sessionId ~= session.id then
		return { ok = false, reason = "Stale session" }
	end
	if data.stepIndex ~= session.stepIndex then
		return { ok = false, reason = "Wrong step", expected = session.stepIndex }
	end
	local recipe = Recipes.Defs[session.recipeId]
	local step = recipe.steps[session.stepIndex]
	local now = os.clock()
	if now - session.startClock > Config.MaxRunSeconds then
		sessions[player] = nil
		return { ok = false, reason = "Run timed out", expired = true }
	end
	local elapsed = now - session.stepStart
	local events, why = validateEvents(step, data.events, elapsed)
	if not events then
		warn("[CTT] rejected step from", player.Name, why)
		return { ok = false, reason = why }
	end
	local q, details, label = StepMath.evaluate(step, events)
	table.insert(session.results, {
		category = step.category,
		quality = q,
		label = label,
		details = details,
	})
	session.stepIndex += 1
	session.stepStart = os.clock()
	if session.stepIndex > #recipe.steps then
		local res = finish(player, session, recipe)
		res.quality = q
		res.label = label
		res.details = details
		return res
	end
	return { ok = true, quality = q, label = label, details = details, stepIndex = session.stepIndex }
end

-- Studio-only QA helper: reset this player's profile to a fresh one (refused on live servers)
function handlers.debugWipe(player)
	if not RunService:IsStudio() then
		return { ok = false, reason = "Unknown action" }
	end
	local keepSeq = profiles[player] and profiles[player].seq or 0
	profiles[player] = newProfile()
	profiles[player].seq = keepSeq
	applyFollowerUnlocks(profiles[player])
	sessions[player] = nil
	task.spawn(save, player, true)
	return { ok = true, profile = snapshot(player) }
end

function handlers.abandon(player, data)
	local session = sessions[player]
	if session and typeof(data) == "table" and data.sessionId == session.id then
		sessions[player] = nil
	end
	return { ok = true, profile = snapshot(player) }
end

Request.OnServerInvoke = function(player, action, data)
	if typeof(action) ~= "string" or not handlers[action] then
		return { ok = false, reason = "Unknown action" }
	end
	if not profiles[player] then
		return { ok = false, reason = "Not ready" }
	end
	if persist[player] == "loading" and action ~= "hello" then
		return { ok = false, reason = "Loading profile", retry = true }
	end
	if busy[player] then
		return { ok = false, reason = "Busy", retry = true }
	end
	busy[player] = true
	local ok, res = pcall(handlers[action], player, data)
	busy[player] = nil
	if not ok then
		warn("[CTT] handler error", action, res)
		return { ok = false, reason = "Server error" }
	end
	return res
end

print("[CTT] server ready", Config.Version)
