-- Cook the Trend: result reveal (your dish vs the video, score count-up, rank stamp, rewards, live chat).
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("CTT")
local Config = require(Shared.Config)
local Recipes = require(Shared.Recipes)
local Dish = require(Shared.Dish)
local Coach = require(Shared.Coach)
local UI = require(script.Parent.UI)

local K = UI.Colors

local Results = {}
Results.__index = Results

local ChatNames = { "ramenrat", "xX_chef_Xx", "spoonie", "bunbae", "lil_wok", "saucyboi", "mochi.moo", "grill_gal", "tofu_tim", "kiwikat", "noodlenerd", "crumbqueen" }
local ChatGood = { "W dish 🔥", "chef's kiss fr", "HOW is it that clean", "plating is unreal", "saving this", "10/10 would eat", "this is the one", "ok master chef", "my mouth is watering", "teach me 😭" }
local ChatMid = { "not bad!", "pretty good tbh", "the vibes are there", "solid attempt", "i'd still eat it", "decent decent", "W effort" }
local ChatBad = { "bro what 💀", "is it supposed to look like that", "the smoke alarm 😭", "L cook", "ratio + burnt", "chaotic energy", "i'm crying 💀", "certified kitchen disaster" }

function Results.new(root: Frame, deps)
	local self = setmetatable({}, Results)
	self.deps = deps
	local overlay = UI.new("Frame", {
		Name = "Results",
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.45,
		Size = UDim2.new(0.72, 0, 1, 0),
		Position = UDim2.new(0.28, 0, 0, 0),
		Visible = false,
		ZIndex = 40,
		Parent = root,
	})
	self.overlay = overlay
	local card = UI.new("Frame", {
		Name = "Card",
		BackgroundColor3 = K.cream,
		Size = UDim2.new(0, 860, 0, 620),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		ZIndex = 41,
		Parent = overlay,
	}, { UI.corner(30), UI.stroke(K.ink, 4) })
	self.card = card
	self.cardScale = UI.new("UIScale", { Parent = card })
	self.sizeCons = UI.new("UISizeConstraint", { Parent = card })

	self.title = UI.label({
		Text = "",
		Font = UI.Font,
		TextSize = 34,
		TextColor3 = K.ink,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 40),
		Position = UDim2.new(0, 0, 0, 14),
		ZIndex = 42,
		Parent = card,
	})
	-- comparison viewports
	local function vpBox(x, label, color)
		local box = UI.new("Frame", {
			BackgroundColor3 = color,
			Size = UDim2.new(0, 250, 0, 250),
			Position = UDim2.new(0, x, 0, 64),
			ZIndex = 42,
			Parent = card,
		}, { UI.corner(22), UI.stroke(K.ink, 3) })
		local vp = UI.new("ViewportFrame", {
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			Ambient = Color3.fromRGB(200, 185, 175),
			LightColor = Color3.fromRGB(255, 240, 220),
			LightDirection = Vector3.new(-0.5, -1, -0.6),
			ZIndex = 43,
			Parent = box,
		}, { UI.corner(22) })
		local l = UI.label({
			Text = label,
			Font = UI.Font,
			TextSize = 22,
			TextColor3 = K.paper,
			BackgroundColor3 = K.ink,
			BackgroundTransparency = 0,
			TextXAlignment = Enum.TextXAlignment.Center,
			Size = UDim2.new(0, 150, 0, 34),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 1, 0),
			ZIndex = 44,
			Parent = box,
		})
		UI.corner(17).Parent = l
		return vp
	end
	self.vpYours = vpBox(28, "YOURS", Color3.fromRGB(255, 226, 200))
	self.vpTarget = vpBox(298, "THE VIDEO", Color3.fromRGB(220, 230, 255))
	UI.label({
		Text = "vs",
		Font = UI.Font,
		TextSize = 30,
		TextColor3 = K.pink,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(0, 40, 0, 40),
		Position = UDim2.new(0, 278 - 20 + 10, 0, 170),
		ZIndex = 45,
		Parent = card,
	})

	-- score + rank (right column)
	local right = UI.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(0, 270, 0, 270),
		Position = UDim2.new(0, 572, 0, 60),
		ZIndex = 42,
		Parent = card,
	})
	self.rankStamp = UI.label({
		Text = "S",
		Font = UI.Font,
		TextSize = 150,
		TextColor3 = K.gold,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 150),
		ZIndex = 44,
		Parent = right,
	})
	UI.textStroke(K.ink, 5).Parent = self.rankStamp
	self.rankScale = UI.new("UIScale", { Parent = self.rankStamp })
	self.rankWord = UI.label({
		Text = "",
		Font = UI.Font,
		TextSize = 28,
		TextColor3 = K.ink,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 34),
		Position = UDim2.new(0, 0, 0, 150),
		ZIndex = 44,
		Parent = right,
	})
	self.scoreLabel = UI.label({
		Text = "0",
		Font = UI.Font,
		TextSize = 64,
		TextColor3 = K.pink,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 70),
		Position = UDim2.new(0, 0, 0, 186),
		ZIndex = 44,
		Parent = right,
	})
	UI.textStroke(K.ink, 3).Parent = self.scoreLabel
	self.pbLabel = UI.label({
		Text = "",
		Font = UI.Font,
		TextSize = 20,
		TextColor3 = K.ink,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 24),
		Position = UDim2.new(0, 0, 0, 254),
		ZIndex = 44,
		Parent = right,
	})

	-- category bars
	local bars = UI.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(0, 520, 0, 120),
		Position = UDim2.new(0, 28, 0, 336),
		ZIndex = 42,
		Parent = card,
	}, { UI.list(nil, 6) })
	self.bars = {}
	for i, cat in { "ingredients", "prep", "cook", "plating" } do
		local row = UI.new("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 24),
			LayoutOrder = i,
			ZIndex = 42,
			Parent = bars,
		})
		UI.label({
			Text = Config.CategoryNames[cat],
			Font = UI.Font,
			TextSize = 20,
			Size = UDim2.new(0, 130, 1, 0),
			ZIndex = 43,
			Parent = row,
		})
		local bg = UI.new("Frame", {
			BackgroundColor3 = Color3.fromRGB(235, 224, 214),
			Size = UDim2.new(1, -200, 0, 18),
			Position = UDim2.new(0, 130, 0.5, -9),
			ZIndex = 43,
			Parent = row,
		}, { UI.corner(9) })
		local fill = UI.new("Frame", {
			BackgroundColor3 = K.mint,
			Size = UDim2.new(0, 0, 1, 0),
			ZIndex = 44,
			Parent = bg,
		}, { UI.corner(9) })
		local pct = UI.label({
			Text = "",
			Font = UI.Font,
			TextSize = 20,
			TextXAlignment = Enum.TextXAlignment.Right,
			Size = UDim2.new(0, 60, 1, 0),
			Position = UDim2.new(1, -60, 0, 0),
			ZIndex = 43,
			Parent = row,
		})
		self.bars[cat] = { row = row, fill = fill, pct = pct }
	end
	self.explain = UI.label({
		Text = "",
		TextSize = 17,
		TextColor3 = K.ink,
		Size = UDim2.new(0, 530, 0, 72),
		Position = UDim2.new(0, 28, 0, 454),
		TextYAlignment = Enum.TextYAlignment.Top,
		ZIndex = 42,
		Parent = card,
	})
	-- rewards
	local rewards = UI.new("Frame", {
		BackgroundColor3 = Color3.fromRGB(255, 238, 205),
		Size = UDim2.new(0, 270, 0, 116),
		Position = UDim2.new(0, 572, 0, 340),
		ZIndex = 42,
		Parent = card,
	}, { UI.corner(18), UI.stroke(K.ink, 2), UI.pad(10, 14) })
	self.coinsLabel = UI.label({
		Text = "",
		Font = UI.Font,
		TextSize = 28,
		TextColor3 = Color3.fromRGB(200, 130, 0),
		Size = UDim2.new(1, 0, 0, 34),
		ZIndex = 43,
		Parent = rewards,
	})
	self.followersLabel = UI.label({
		Text = "",
		Font = UI.Font,
		TextSize = 28,
		TextColor3 = K.pink,
		Size = UDim2.new(1, 0, 0, 34),
		Position = UDim2.new(0, 0, 0, 36),
		ZIndex = 43,
		Parent = rewards,
	})
	self.bonusLabel = UI.label({
		Text = "",
		TextSize = 16,
		TextColor3 = K.ink,
		Size = UDim2.new(1, 0, 0, 22),
		Position = UDim2.new(0, 0, 0, 72),
		ZIndex = 43,
		Parent = rewards,
	})
	-- live chat
	local chat = UI.new("Frame", {
		BackgroundColor3 = Color3.fromRGB(30, 24, 40),
		BackgroundTransparency = 0.1,
		Size = UDim2.new(0, 270, 0, 0),
		Position = UDim2.new(0, 572, 0, 466),
		ClipsDescendants = true,
		ZIndex = 42,
		Visible = false,
		Parent = card,
	}, { UI.corner(14) })
	_ = chat
	-- buttons
	local btns = UI.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -56, 0, 64),
		Position = UDim2.new(0, 28, 1, -84),
		ZIndex = 42,
		Parent = card,
	}, { UI.list(Enum.FillDirection.Horizontal, 14, Enum.HorizontalAlignment.Center) })
	self.retryBtn = UI.button({ Text = "🔄 RETRY", Size = UDim2.new(0, 170, 0, 62), Color = K.sky, TextSize = 28, ZIndex = 43, LayoutOrder = 1, Parent = btns }, function()
		deps.onRetry()
	end, deps.Sfx)
	self.nextBtn = UI.button({ Text = "NEXT ▶", Size = UDim2.new(0, 170, 0, 62), Color = K.pink, TextSize = 28, ZIndex = 43, LayoutOrder = 2, Parent = btns }, function()
		deps.onNext()
	end, deps.Sfx)
	self.recipeBtn = UI.button({ Text = "📖 RECIPE + TIPS", Size = UDim2.new(0, 240, 0, 62), Color = K.mint, TextSize = 22, ZIndex = 43, LayoutOrder = 0, Parent = btns }, function()
		if deps.onRecipe then
			deps.onRecipe()
		end
	end, deps.Sfx)
	self.feedBtn = UI.button({ Text = "FEED", Size = UDim2.new(0, 120, 0, 62), Color = Color3.fromRGB(120, 110, 130), TextSize = 26, ZIndex = 43, LayoutOrder = 3, Parent = btns }, function()
		deps.onClose()
	end, deps.Sfx)

	-- side live chat column (outside the card, right edge of the kitchen area)
	self.chatCol = UI.new("Frame", {
		Name = "LiveChat",
		BackgroundTransparency = 1,
		Size = UDim2.new(0, 260, 0.7, 0),
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 16, 1, -20),
		ClipsDescendants = true,
		ZIndex = 41,
		Parent = overlay,
	}, { UI.list(nil, 6, nil, Enum.VerticalAlignment.Bottom) })
	self.liveTag = UI.label({
		Text = "● LIVE  0 watching",
		Font = UI.Font,
		TextSize = 20,
		TextColor3 = K.paper,
		BackgroundColor3 = K.red,
		BackgroundTransparency = 0,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(0, 200, 0, 30),
		Position = UDim2.new(0, 36, 0, 72),
		ZIndex = 46,
		Parent = card,
	})
	UI.corner(10).Parent = self.liveTag
	self.vpConns = {}
	return self
end

local function setupViewport(vp: ViewportFrame, model: Model, conns)
	for _, c in vp:GetChildren() do
		if not c:IsA("UICorner") then
			c:Destroy()
		end
	end
	local cam = Instance.new("Camera")
	cam.FieldOfView = 32
	cam.Parent = vp
	vp.CurrentCamera = cam
	local world = Instance.new("WorldModel")
	world.Parent = vp
	model.Parent = world
	local base = Dish.newModel("Base")
	Dish.disc(base, 7.5, 0.3, CFrame.new(0, -0.15, 0), Color3.fromRGB(255, 244, 232))
	base.Parent = world
	local _, size = model:GetBoundingBox()
	local fy = math.max(1.2, size.Y * 0.45)
	local t = 0
	local conn = RunService.RenderStepped:Connect(function(dt)
		t += dt
		local a = t * 0.5
		cam.CFrame = CFrame.lookAt(Vector3.new(math.sin(a) * 9.5, fy + 5.5, math.cos(a) * 9.5), Vector3.new(0, fy - 0.3, 0))
	end)
	table.insert(conns, conn)
end

function Results:_chat(rank: string, n: number)
	local pool = (rank == "S" or rank == "A") and ChatGood or (rank == "B" and ChatMid or ChatBad)
	for i = 1, n do
		task.delay(0.35 * i + math.random() * 0.3, function()
			if not self.overlay.Visible then
				return
			end
			local name = ChatNames[math.random(1, #ChatNames)]
			local msg = pool[math.random(1, #pool)]
			local l = UI.label({
				Text = string.format("<font color=\"#FFC23A\">%s</font>  %s", name, msg),
				RichText = true,
				TextSize = 18,
				TextColor3 = K.paper,
				BackgroundColor3 = Color3.fromRGB(20, 16, 28),
				BackgroundTransparency = 0.25,
				AutomaticSize = Enum.AutomaticSize.Y,
				Size = UDim2.new(1, 0, 0, 26),
				LayoutOrder = self.chatN or 0,
				ZIndex = 41,
				Parent = self.chatCol,
			})
			self.chatN = (self.chatN or 0) + 1
			UI.corner(10).Parent = l
			UI.pad(4, 10).Parent = l
			local kids = self.chatCol:GetChildren()
			local count = 0
			for _, c in kids do
				if c:IsA("TextLabel") then
					count += 1
				end
			end
			if count > 9 then
				for _, c in kids do
					if c:IsA("TextLabel") and c.LayoutOrder < (self.chatN - 9) then
						c:Destroy()
					end
				end
			end
		end)
	end
end

function Results:show(res, recipe, yourDish: Model?)
	local deps = self.deps
	for _, c in self.vpConns do
		c:Disconnect()
	end
	self.vpConns = {}
	for _, c in self.chatCol:GetChildren() do
		if c:IsA("TextLabel") then
			c:Destroy()
		end
	end
	self.overlay.Visible = true
	self.title.Text = recipe.name .. "  ·  " .. recipe.creator
	-- fit card into the kitchen area
	local area = self.overlay.AbsoluteSize / (deps.getScale and deps.getScale() or 1)
	local s = math.min(1, (area.X - 40) / 860, (area.Y - 30) / 620)
	self.cardScale.Scale = 0.5 * s
	UI.tween(self.cardScale, 0.35, { Scale = s }, Enum.EasingStyle.Back)
	-- chat column only when there is room beside the card
	self.chatCol.Visible = area.X - 860 * s > 560
	self.liveTag.Visible = true

	if yourDish then
		setupViewport(self.vpYours, yourDish, self.vpConns)
	end
	local target = Dish.final(recipe.id)
	setupViewport(self.vpTarget, target, self.vpConns)

	-- rank stamp + score count-up
	local rankInfo
	for _, r in Config.Ranks do
		if r.rank == res.rank then
			rankInfo = r
		end
	end
	self.rankStamp.Text = ""
	self.rankWord.Text = ""
	self.scoreLabel.Text = "0"
	self.pbLabel.Text = ""
	self.coinsLabel.Text = ""
	self.followersLabel.Text = ""
	self.bonusLabel.Text = ""
	-- lead with the most useful real-kitchen tip from this run
	local tipText = ""
	if res.steps then
		local worstI, worstQ = nil, 2
		for i, r in res.steps do
			if (r.quality or 1) < worstQ then
				worstI, worstQ = i, r.quality or 1
			end
		end
		local st = worstI and recipe.steps[worstI]
		if st and worstQ < 0.85 then
			local _, improve = Coach.feedback(st, worstQ, res.steps[worstI].label, res.steps[worstI].details)
			if improve then
				tipText = "\n💡 " .. improve
			end
		end
	end
	self.explain.Text = (res.explanation or "") .. tipText
	for cat, b in self.bars do
		local v = res.categories and res.categories[cat]
		b.row.Visible = v ~= nil
		b.fill.Size = UDim2.new(0, 0, 1, 0)
		b.pct.Text = ""
	end
	local watching = math.floor(200 + (res.score or 0) * 37 + math.random(0, 150))
	self.liveTag.Text = string.format("● LIVE  %s watching", UI.formatCount(watching))
	UI.setDisabled(self.retryBtn, true)
	UI.setDisabled(self.nextBtn, true)
	UI.setDisabled(self.feedBtn, true)

	task.spawn(function()
		task.wait(0.4)
		-- bars
		for cat, b in self.bars do
			local v = res.categories and res.categories[cat]
			if v then
				local col = v >= 85 and K.mint or (v >= 55 and K.gold or K.orange)
				b.fill.BackgroundColor3 = col
				UI.tween(b.fill, 0.6, { Size = UDim2.new(v / 100, 0, 1, 0) })
				b.pct.Text = v .. "%"
				deps.Sfx.play("click", { volume = 0.5 })
				task.wait(0.15)
			end
		end
		-- count-up
		local target = res.score or 0
		local e, dur = 0, 1.1
		while e < dur do
			e += task.wait()
			local v = math.floor(target * math.min(1, e / dur) ^ 0.6)
			self.scoreLabel.Text = tostring(v)
		end
		self.scoreLabel.Text = tostring(target) .. "<font size=\"30\">/100</font>"
		self.scoreLabel.RichText = true
		-- stamp
		self.rankStamp.Text = res.rank
		self.rankStamp.TextColor3 = rankInfo and rankInfo.color or K.gold
		self.rankWord.Text = res.rankWord or ""
		self.rankScale.Scale = 2.6
		UI.tween(self.rankScale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
		deps.Sfx.play("thud")
		if res.rank == "S" or res.rank == "A" then
			deps.Sfx.play("jingle")
			deps.Sfx.play("cheer", { volume = 0.8, maxLength = 3.5 })
		elseif res.rank == "B" then
			deps.Sfx.play("sparkle")
		else
			deps.Sfx.play("fail", { maxLength = 2.6 })
		end
		self:_chat(res.rank, 10)
		task.wait(0.5)
		if res.personalBest and not res.firstClear then
			self.pbLabel.Text = "🏆 NEW PERSONAL BEST!"
			self.pbLabel.TextColor3 = K.pink
		elseif res.firstClear then
			self.pbLabel.Text = "🏆 First clear!"
			self.pbLabel.TextColor3 = K.pink
		else
			local best = res.profile and res.profile.best[recipe.id]
			self.pbLabel.Text = best and ("Best: " .. best.rank .. " · " .. best.score) or ""
			self.pbLabel.TextColor3 = K.ink
		end
		-- rewards tick
		local c, f = res.coins or 0, res.followers or 0
		local e2 = 0
		deps.Sfx.play("coins")
		while e2 < 0.8 do
			e2 += task.wait()
			local a = math.min(1, e2 / 0.8)
			self.coinsLabel.Text = "💰 +" .. math.floor(c * a)
			self.followersLabel.Text = "👥 +" .. math.floor(f * a) .. " followers"
		end
		self.coinsLabel.Text = "💰 +" .. c
		self.followersLabel.Text = "👥 +" .. f .. " followers"
		deps.Sfx.play("cash", { volume = 0.7 })
		local bonus = {}
		if res.firstClear then
			table.insert(bonus, "+" .. Config.FirstClearCoinBonus .. " first-clear coins")
		end
		if res.personalBest and not res.firstClear then
			table.insert(bonus, "+" .. Config.PBFollowerBonus .. " PB followers")
		end
		if res.speedBonus then
			table.insert(bonus, "speed bonus!")
		end
		self.bonusLabel.Text = table.concat(bonus, " · ")
		if deps.onRewardsShown then
			deps.onRewardsShown(res)
		end
		UI.setDisabled(self.retryBtn, false)
		UI.setDisabled(self.nextBtn, false)
		UI.setDisabled(self.feedBtn, false)
	end)
end

function Results:hide()
	self.overlay.Visible = false
	for _, c in self.vpConns do
		c:Disconnect()
	end
	self.vpConns = {}
	for _, vp in { self.vpYours, self.vpTarget } do
		for _, c in vp:GetChildren() do
			if not c:IsA("UICorner") then
				c:Destroy()
			end
		end
	end
end

return Results
