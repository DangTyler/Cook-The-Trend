-- Cook the Trend: left-side vertical recipe feed (portrait cards with live 3D previews).
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("CTT")
local Recipes = require(Shared.Recipes)
local Dish = require(Shared.Dish)
local UI = require(script.Parent.UI)

local Feed = {}
Feed.__index = Feed

local K = UI.Colors

local function stars(n: number)
	return string.rep("★", n) .. string.rep("☆", 3 - n)
end

local function difficultyWord(n: number)
	return ({ "Easy", "Medium", "Hard" })[n] or "?"
end

-- animated preview inside a ViewportFrame
local function makePreview(vp: ViewportFrame, recipeId: string)
	local cam = Instance.new("Camera")
	cam.FieldOfView = 34
	cam.Parent = vp
	vp.CurrentCamera = cam
	local world = Instance.new("WorldModel")
	world.Parent = vp
	local model, layers = Dish.final(recipeId)
	model.Parent = world
	-- little counter disc under the dish
	local base = Dish.newModel("Base")
	Dish.disc(base, 7.5, 0.3, CFrame.new(0, -0.15, 0), Color3.fromRGB(255, 240, 225))
	Dish.disc(base, 7.9, 0.2, CFrame.new(0, -0.22, 0), Color3.fromRGB(230, 200, 180))
	base.Parent = world
	local homes = {}
	for i, l in layers do
		homes[i] = l:GetPivot()
	end
	-- steam puffs
	local puffs = {}
	if recipeId == "ramen" then
		for i = 1, 5 do
			local p = Dish.ball(world, Vector3.new(0.7, 0.7, 0.7), CFrame.new(0, 2, 0), Color3.new(1, 1, 1), { Transparency = 0.6 })
			puffs[i] = p
		end
	elseif recipeId == "dessert" then
		for i = 1, 6 do
			local p = Dish.part(world, Vector3.new(0.18, 0.18, 0.18), CFrame.new(0, 3, 0), Color3.fromRGB(255, 240, 150), { Material = Enum.Material.Neon })
			puffs[i] = p
		end
	end
	local _, size = model:GetBoundingBox()
	local h = size.Y
	local state = { t = math.random() * 3, cam = cam, layers = layers, homes = homes, puffs = puffs, h = h, recipeId = recipeId }
	return state
end

local CYCLE = 7

local function stepPreview(st, dt: number)
	st.t += dt
	local t = st.t % CYCLE
	-- camera orbit
	local ang = st.t * 0.45
	local dist = 10.5
	local focusY = math.max(1.4, st.h * 0.45)
	local pos = Vector3.new(math.sin(ang) * dist, focusY + 5.2, math.cos(ang) * dist)
	st.cam.CFrame = CFrame.lookAt(pos, Vector3.new(0, focusY - 0.2, 0))
	-- layered reveal: layers drop in one by one, hold, fly away
	local n = #st.layers
	for i, l in st.layers do
		local appear = 0.25 + (i - 1) * 0.28
		local home = st.homes[i]
		local y
		if t < appear then
			y = 7
		elseif t < appear + 0.35 then
			local a = (t - appear) / 0.35
			-- ease out bounce-ish
			y = (1 - a) ^ 2 * 7 - math.sin(a * math.pi) * 0.25
		elseif t > CYCLE - 0.5 then
			local a = (t - (CYCLE - 0.5)) / 0.5
			y = a * a * 9
		else
			y = 0
		end
		l:PivotTo(home + Vector3.new(0, y, 0))
	end
	_ = n
	for i, p in st.puffs do
		local ph = (st.t * 0.5 + i / #st.puffs) % 1
		if st.recipeId == "ramen" then
			p.CFrame = CFrame.new(math.sin(i * 2.1 + st.t) * 0.7, 2.0 + ph * 3.2, math.cos(i * 1.7) * 0.6)
			p.Size = Vector3.one * (0.5 + ph * 1.1)
			p.Transparency = 0.55 + ph * 0.45
		else
			local a = i / #st.puffs * math.pi * 2 + st.t * 0.6
			p.CFrame = CFrame.new(math.cos(a) * 2.2, 2.6 + math.sin(st.t * 3 + i) * 0.5, math.sin(a) * 2.2) * CFrame.Angles(st.t, st.t * 1.3, 0)
			p.Transparency = 0.2 + 0.8 * math.abs(math.sin(st.t * 2 + i))
		end
	end
end

function Feed.new(gui: ScreenGui, deps)
	local self = setmetatable({}, Feed)
	self.deps = deps
	self.cards = {}
	self.profile = nil
	self.active = nil
	self.selected = nil

	local root = UI.new("Frame", {
		Name = "Feed",
		Size = UDim2.new(0.28, 0, 1, 0),
		BackgroundColor3 = K.feedBg,
		BorderSizePixel = 0,
		Parent = gui,
	})
	self.root = root
	-- extend the panel colour up under the Roblox top bar
	UI.new("Frame", {
		Name = "TopFill",
		BackgroundColor3 = Color3.fromRGB(40, 28, 52),
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 80),
		Position = UDim2.new(0, 0, 0, -80),
		Parent = root,
	})
	UI.new("UIGradient", {
		Color = ColorSequence.new(Color3.fromRGB(40, 28, 52), Color3.fromRGB(16, 14, 22)),
		Rotation = 90,
		Parent = root,
	})
	-- inner scaled content
	local content = UI.new("Frame", {
		Name = "Content",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Parent = root,
	})
	self.content = content

	-- header
	local header = UI.new("Frame", {
		Name = "Header",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 116),
		Parent = content,
	}, { UI.pad(10, 14, 6, 14) })
	self.header = header
	local logo
	logo = UI.label({
		Text = "Cook the Trend",
		Font = UI.Font,
		TextSize = 34,
		TextColor3 = K.paper,
		Size = UDim2.new(1, -60, 0, 40),
		TextScaled = false,
		Parent = header,
	})
	self.logo = logo
	UI.new("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 120, 170)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 200, 90)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(120, 230, 200)),
		}),
		Parent = logo,
	})
	self.muteBtn = UI.button({
		Text = "🔊",
		Size = UDim2.new(0, 48, 0, 40),
		Position = UDim2.new(1, -48, 0, 0),
		Color = Color3.fromRGB(70, 60, 90),
		TextSize = 22,
		Corner = 12,
		Stroke = 2,
		Parent = header,
	}, function()
		deps.onToggleMute()
	end)

	local stats = UI.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 40),
		Position = UDim2.new(0, 0, 0, 48),
		Parent = header,
	}, { UI.list(Enum.FillDirection.Horizontal, 8, nil, Enum.VerticalAlignment.Center) })
	self.statsRow = stats
	local function chip(icon, color)
		local f = UI.new("Frame", {
			BackgroundColor3 = Color3.fromRGB(56, 46, 70),
			Size = UDim2.new(0.5, -4, 1, 0),
			Parent = stats,
		}, { UI.corner(20), UI.stroke(color, 2, 0.2) })
		local l = UI.label({
			Text = icon .. " 0",
			Font = UI.Font,
			TextSize = 24,
			TextColor3 = K.paper,
			TextXAlignment = Enum.TextXAlignment.Center,
			Size = UDim2.fromScale(1, 1),
			Parent = f,
		})
		return l, f
	end
	self.coinLabel, self.coinChip = chip("💰", K.gold)
	self.followLabel, self.followChip = chip("👥", K.pink)
	self.saveNote = UI.label({
		Text = "",
		TextSize = 14,
		TextColor3 = K.muted,
		Size = UDim2.new(1, 0, 0, 16),
		Position = UDim2.new(0, 0, 0, 92),
		Parent = header,
	})

	-- "now cooking" banner
	local banner = UI.new("Frame", {
		Name = "NowCooking",
		BackgroundColor3 = Color3.fromRGB(255, 92, 140),
		Size = UDim2.new(1, -24, 0, 0),
		Position = UDim2.new(0, 12, 0, 116),
		ClipsDescendants = true,
		Visible = false,
		Parent = content,
	}, { UI.corner(16), UI.stroke(K.paper, 2, 0.3), UI.pad(8, 12, 8, 12) })
	self.banner = banner
	self.bannerTitle = UI.label({
		Text = "NOW COOKING",
		Font = UI.Font,
		TextSize = 20,
		TextColor3 = K.paper,
		Size = UDim2.new(1, 0, 0, 24),
		Parent = banner,
	})
	self.bannerStep = UI.label({
		Text = "",
		TextSize = 17,
		TextColor3 = Color3.fromRGB(255, 240, 245),
		Size = UDim2.new(1, 0, 0, 40),
		Position = UDim2.new(0, 0, 0, 26),
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = banner,
	})
	local bar = UI.new("Frame", {
		BackgroundColor3 = Color3.fromRGB(180, 40, 90),
		Size = UDim2.new(1, 0, 0, 8),
		Position = UDim2.new(0, 0, 1, -8),
		Parent = banner,
	}, { UI.corner(4) })
	self.bannerFill = UI.new("Frame", {
		BackgroundColor3 = K.paper,
		Size = UDim2.new(0, 0, 1, 0),
		Parent = bar,
	}, { UI.corner(4) })

	-- scrolling feed
	local scroller = UI.new("ScrollingFrame", {
		Name = "Scroller",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 1, -122),
		Position = UDim2.new(0, 0, 0, 122),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = 5,
		ScrollBarImageColor3 = Color3.fromRGB(255, 140, 180),
		ElasticBehavior = Enum.ElasticBehavior.Always,
		Parent = content,
	}, { UI.list(nil, 18, Enum.HorizontalAlignment.Center), UI.pad(6, 14, 40, 14) })
	self.scroller = scroller

	for i, id in Recipes.Order do
		self:_makeCard(id, i)
	end
	-- portrait cards: height follows width (shorter on squat screens so a whole card fits)
	local function sizeCards()
		local w = scroller.AbsoluteSize.X - 28 * (self.deps.getScale and self.deps.getScale() or 1)
		local s = self.deps.getScale and self.deps.getScale() or 1
		local h = w / 0.6
		local maxH = scroller.AbsoluteSize.Y * 0.98
		if h > maxH then
			h = math.max(maxH, w / 0.85)
		end
		for _, c in self.cards do
			c.frame.Size = UDim2.new(1, 0, 0, h / s)
			-- short cards (phones): drop the caption so title, reward and button never collide
			local short = h / s < 470
			c.caption.Visible = not short
			c.info.Position = UDim2.new(0, 0, short and 0.52 or 0.6, 0)
		end
	end
	scroller:GetPropertyChangedSignal("AbsoluteSize"):Connect(sizeCards)
	task.defer(sizeCards)
	-- teaser card at end: more trends coming (not selectable)
	local tease = UI.new("Frame", {
		BackgroundColor3 = K.feedCard,
		Size = UDim2.new(1, 0, 0, 120),
		LayoutOrder = 99,
		Parent = scroller,
	}, { UI.corner(18), UI.stroke(Color3.fromRGB(90, 80, 110), 2, 0.3) })
	UI.label({
		Text = "📲  More trends drop soon\nYou're all caught up!",
		Font = UI.Font,
		TextSize = 20,
		TextColor3 = K.muted,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.fromScale(1, 1),
		Parent = tease,
	})

	-- preview animation, only visible cards
	self.conn = RunService.RenderStepped:Connect(function(dt)
		local top = scroller.AbsolutePosition.Y
		local bottom = top + scroller.AbsoluteSize.Y
		for _, c in self.cards do
			local y = c.frame.AbsolutePosition.Y
			local h = c.frame.AbsoluteSize.Y
			if y + h > top and y < bottom then
				stepPreview(c.preview, dt)
				-- first-time nudge: the free ramen card glows until the first cook
				if c.id == Recipes.Order[1] and self.profile and self.profile.runs == 0 and not self.active then
					c.selStroke.Transparency = 0.5 + 0.5 * math.sin(os.clock() * 5)
				end
				local t = (c.preview.t % CYCLE) / CYCLE
				c.scrub.Size = UDim2.new(t, 0, 1, 0)
			end
		end
	end)

	-- gentle snap to nearest card after scrolling settles
	local lastPos, still = scroller.CanvasPosition, 0
	local touching = false
	scroller.InputBegan:Connect(function(io)
		if io.UserInputType == Enum.UserInputType.Touch then
			touching = true
		end
	end)
	scroller.InputEnded:Connect(function(io)
		if io.UserInputType == Enum.UserInputType.Touch then
			touching = false
		end
	end)
	self.snapConn = RunService.Heartbeat:Connect(function(dt)
		local p = scroller.CanvasPosition
		if (p - lastPos).Magnitude > 0.5 then
			still = 0
			self.snapped = false
		else
			still += dt
		end
		lastPos = p
		if still > 0.35 and not self.snapped and not touching then
			self.snapped = true
			local best, bestD = nil, math.huge
			for _, c in self.cards do
				local d = math.abs(c.frame.AbsolutePosition.Y - (scroller.AbsolutePosition.Y + 6))
				if d < bestD then
					best, bestD = c, d
				end
			end
			if best and bestD > 4 and bestD < best.frame.AbsoluteSize.Y * 0.5 then
				local target = p.Y + (best.frame.AbsolutePosition.Y - scroller.AbsolutePosition.Y - 6)
				local maxY = math.max(0, scroller.AbsoluteCanvasSize.Y - scroller.AbsoluteWindowSize.Y)
				UI.tween(scroller, 0.25, { CanvasPosition = Vector2.new(0, math.clamp(target, 0, maxY)) })
			end
		end
	end)
	return self
end

function Feed:_makeCard(id: string, order: number)
	local def = Recipes.Defs[id]
	local deps = self.deps
	local frame = UI.new("Frame", {
		Name = "Card_" .. id,
		BackgroundColor3 = def.bg[1],
		Size = UDim2.new(1, 0, 0, 100),
		LayoutOrder = order,
		ClipsDescendants = true,
		Parent = self.scroller,
	}, {
		UI.corner(22),
		UI.new("UIGradient", { Color = ColorSequence.new(def.bg[1], def.bg[2]), Rotation = 70 }),
	})
	local selStroke = UI.stroke(K.gold, 4, 1)
	selStroke.Parent = frame

	local vp = UI.new("ViewportFrame", {
		Name = "Preview",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0.78, 0),
		Position = UDim2.new(0, 0, 0.02, 0),
		Ambient = Color3.fromRGB(200, 180, 170),
		LightColor = Color3.fromRGB(255, 240, 220),
		LightDirection = Vector3.new(-0.6, -1, -0.5),
		Parent = frame,
	})
	local preview = makePreview(vp, id)

	-- tap the card body to preview / select
	local hit = UI.new("TextButton", {
		Name = "Hit",
		BackgroundTransparency = 1,
		Text = "",
		Size = UDim2.fromScale(1, 1),
		ZIndex = 2,
		Parent = frame,
	})
	hit.Activated:Connect(function()
		self:select(id)
		if deps.onPreview then
			deps.onPreview(id)
		end
	end)

	-- top chips
	local top = UI.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -20, 0, 32),
		Position = UDim2.new(0, 10, 0, 10),
		ZIndex = 3,
		Parent = frame,
	}, { UI.list(Enum.FillDirection.Horizontal, 6) })
	local function topChip(text, color)
		local l = UI.label({
			Text = text,
			Font = UI.Font,
			TextSize = 17,
			TextColor3 = K.paper,
			BackgroundTransparency = 0.15,
			BackgroundColor3 = color,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.new(0, 0, 1, 0),
			TextWrapped = false,
			TextXAlignment = Enum.TextXAlignment.Center,
			ZIndex = 3,
			Parent = top,
		}, nil)
		UI.corner(14).Parent = l
		UI.pad(0, 10).Parent = l
		return l
	end
	topChip(stars(def.difficulty) .. " " .. difficultyWord(def.difficulty), Color3.fromRGB(40, 30, 50))
	topChip("🕐 ~" .. def.duration .. "s", Color3.fromRGB(40, 30, 50))

	-- completed badge
	local badge = UI.label({
		Text = "",
		Font = UI.Font,
		TextSize = 18,
		TextColor3 = K.ink,
		BackgroundColor3 = K.gold,
		BackgroundTransparency = 0,
		Size = UDim2.new(0, 120, 0, 32),
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 48),
		TextXAlignment = Enum.TextXAlignment.Center,
		Visible = false,
		ZIndex = 3,
		Parent = frame,
	})
	UI.corner(14).Parent = badge
	UI.stroke(K.ink, 2).Parent = badge

	-- right rail (social)
	local rail = UI.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(0, 56, 0, 190),
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -6, 0.27, 0),
		ZIndex = 3,
		Parent = frame,
	}, { UI.list(nil, 4, Enum.HorizontalAlignment.Center) })
	local avatar = UI.label({
		Text = string.upper(string.sub(def.creator, 2, 2)),
		Font = UI.Font,
		TextSize = 24,
		TextColor3 = K.paper,
		BackgroundColor3 = def.accent,
		BackgroundTransparency = 0,
		Size = UDim2.new(0, 46, 0, 46),
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 3,
		Parent = rail,
	})
	UI.cornerScale(0.5).Parent = avatar
	UI.stroke(K.paper, 2).Parent = avatar
	local function railItem(icon, count)
		local l = UI.label({
			Text = icon .. "\n" .. count,
			Font = UI.Font,
			TextSize = 18,
			TextColor3 = K.paper,
			Size = UDim2.new(1, 0, 0, 44),
			TextXAlignment = Enum.TextXAlignment.Center,
			ZIndex = 3,
			Parent = rail,
		})
		UI.textStroke(Color3.new(0, 0, 0), 1.5).Parent = l
		return l
	end
	local heart = railItem("❤", def.likes)
	-- tap the heart: like burst (local flavour only)
	local likeBtn = UI.new("TextButton", {
		BackgroundTransparency = 1,
		Text = "",
		Size = UDim2.fromScale(1, 1),
		ZIndex = 5,
		Parent = heart,
	})
	likeBtn.Activated:Connect(function()
		local liked = not heart:GetAttribute("Liked")
		heart:SetAttribute("Liked", liked)
		heart.TextColor3 = liked and Color3.fromRGB(255, 80, 130) or K.paper
		deps.Sfx.play("plop", { volume = 0.6 })
		if liked then
			for i = 1, 5 do
				local h = UI.label({
					Text = "❤",
					Font = UI.Font,
					TextSize = 26,
					TextColor3 = Color3.fromRGB(255, 80 + i * 20, 130),
					TextXAlignment = Enum.TextXAlignment.Center,
					Size = UDim2.new(0, 30, 0, 30),
					Position = UDim2.new(0.5, -15, 0, 0),
					ZIndex = 6,
					Parent = heart,
				})
				UI.tween(h, 0.7, { Position = UDim2.new(0.5, -15 + math.random(-40, 20), 0, -70 - math.random(0, 40)), TextTransparency = 1 })
				task.delay(0.8, function()
					h:Destroy()
				end)
			end
		end
	end)
	local recipeItem = railItem("📖", "Recipe")
	local recipeBtn = UI.new("TextButton", {
		BackgroundTransparency = 1,
		Text = "",
		Size = UDim2.fromScale(1, 1),
		ZIndex = 5,
		Parent = recipeItem,
	})
	recipeBtn.Activated:Connect(function()
		deps.Sfx.play("click")
		if deps.onRecipe then
			deps.onRecipe(id)
		end
	end)

	-- bottom info overlay
	local info = UI.new("Frame", {
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.25,
		Size = UDim2.new(1, 0, 0.4, 0),
		Position = UDim2.new(0, 0, 0.6, 0),
		ZIndex = 3,
		Parent = frame,
	}, {
		UI.new("UIGradient", {
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.3, 0.35),
				NumberSequenceKeypoint.new(1, 0.05),
			}),
			Rotation = 90,
		}),
		UI.pad(10, 12, 10, 12),
	})
	UI.label({
		Text = def.creator,
		Font = UI.Font,
		TextSize = 19,
		TextColor3 = K.paper,
		Size = UDim2.new(1, -50, 0, 22),
		Position = UDim2.new(0, 0, 0.0, 6),
		ZIndex = 4,
		Parent = info,
	})
	local captionLabel = UI.label({
		Text = def.caption,
		TextSize = 18,
		TextColor3 = Color3.fromRGB(240, 235, 245),
		Size = UDim2.new(1, -4, 0, 38),
		Position = UDim2.new(0, 0, 0, 30),
		TextYAlignment = Enum.TextYAlignment.Top,
		ZIndex = 4,
		Parent = info,
	})
	local nameRow = UI.label({
		Text = def.name,
		Font = UI.Font,
		TextSize = 25,
		TextColor3 = K.paper,
		Size = UDim2.new(1, 0, 0, 28),
		Position = UDim2.new(0, 0, 0, 70),
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextWrapped = false,
		ZIndex = 4,
		Parent = info,
	})
	UI.textStroke(Color3.new(0, 0, 0), 2).Parent = nameRow
	local reward = UI.label({
		Text = string.format("💰 up to %d   👥 up to +%d", math.floor(def.baseCoins * 1) + 15, math.floor(def.baseFollowers * 1.25)),
		Font = UI.Font,
		TextSize = 16,
		TextColor3 = Color3.fromRGB(255, 226, 120),
		Size = UDim2.new(1, 0, 0, 20),
		Position = UDim2.new(0, 0, 0, 100),
		ZIndex = 4,
		Parent = info,
	})
	_ = reward

	local cta = UI.button({
		Name = "Cook",
		Text = "MAKE THIS  ▶",
		Size = UDim2.new(1, -24, 0, 50),
		Position = UDim2.new(0, 12, 1, -62),
		Color = def.accent,
		TextSize = 25,
		ZIndex = 6,
		Parent = frame,
	}, function()
		self:_ctaPressed(id)
	end, deps.Sfx)

	-- video scrub bar
	local scrubBg = UI.new("Frame", {
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.7,
		Size = UDim2.new(1, -24, 0, 4),
		Position = UDim2.new(0, 12, 1, -8),
		ZIndex = 5,
		Parent = frame,
	}, { UI.corner(2) })
	local scrub = UI.new("Frame", {
		BackgroundColor3 = K.paper,
		Size = UDim2.new(0, 0, 1, 0),
		ZIndex = 5,
		Parent = scrubBg,
	}, { UI.corner(2) })

	-- lock overlay
	local lock = UI.new("Frame", {
		Name = "Lock",
		BackgroundColor3 = Color3.fromRGB(12, 10, 18),
		BackgroundTransparency = 0.3,
		Size = UDim2.new(1, 0, 0.62, 0),
		ZIndex = 5,
		Visible = false,
		Parent = frame,
	})
	local lockText = UI.label({
		Text = "🔒",
		Font = UI.Font,
		TextSize = 22,
		TextColor3 = K.paper,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, -20, 0, 80),
		Position = UDim2.new(0, 10, 0.5, -40),
		ZIndex = 6,
		Parent = lock,
	})
	local lockBar = UI.new("Frame", {
		BackgroundColor3 = Color3.fromRGB(70, 60, 90),
		Size = UDim2.new(0.7, 0, 0, 12),
		Position = UDim2.new(0.15, 0, 0.5, 46),
		ZIndex = 6,
		Visible = false,
		Parent = lock,
	}, { UI.corner(6) })
	local lockFill = UI.new("Frame", {
		BackgroundColor3 = K.pink,
		Size = UDim2.new(0, 0, 1, 0),
		ZIndex = 6,
		Parent = lockBar,
	}, { UI.corner(6) })

	self.cards[id] = {
		id = id,
		frame = frame,
		preview = preview,
		cta = cta,
		badge = badge,
		lock = lock,
		lockText = lockText,
		lockBar = lockBar,
		lockFill = lockFill,
		selStroke = selStroke,
		scrub = scrub,
		heart = heart,
		caption = captionLabel,
		info = info,
		confirmUntil = 0,
	}
end

function Feed:_ctaPressed(id: string)
	local p = self.profile
	if not p then
		return
	end
	local def = Recipes.Defs[id]
	local card = self.cards[id]
	if not p.unlocked[id] then
		if def.unlock.kind == "coins" then
			self.deps.onUnlock(id)
		else
			self.deps.toast(string.format("Reach %d followers to unlock this trend", def.unlock.amount), UI.Colors.pink)
		end
		return
	end
	if self.active and self.active.recipeId == id then
		self.deps.toast("You're already cooking this one!", UI.Colors.sky)
		return
	end
	if self.active then
		if os.clock() < card.confirmUntil then
			card.confirmUntil = 0
			self.deps.onCook(id, true)
		else
			card.confirmUntil = os.clock() + 3
			card.cta.Text = "TAP AGAIN TO SWITCH"
			task.delay(3.05, function()
				if os.clock() >= card.confirmUntil then
					self:refresh()
				end
			end)
			self.deps.toast("Switching abandons your current dish", UI.Colors.orange)
		end
		return
	end
	self.deps.onCook(id, false)
end

function Feed:select(id: string?)
	self.selected = id
	for cid, c in self.cards do
		local on = cid == id
		UI.tween(c.selStroke, 0.2, { Transparency = on and 0 or 1 })
	end
end

function Feed:setProfile(p)
	self.profile = p
	self:refresh()
end

function Feed:setActive(a)
	self.active = a
	local hH = self.headerH or 122
	local bH = self.compact and 78 or 104
	if a then
		local def = Recipes.Defs[a.recipeId]
		self.banner.Visible = true
		self.banner.Position = UDim2.new(0, 12, 0, hH - 6)
		UI.tween(self.banner, 0.25, { Size = UDim2.new(1, -24, 0, bH) })
		self.scroller.Position = UDim2.new(0, 0, 0, hH + bH)
		self.scroller.Size = UDim2.new(1, 0, 1, -(hH + bH))
		self.bannerTitle.Text = "🔥 NOW COOKING · " .. string.upper(def.short)
		self.bannerStep.Text = string.format("Step %d/%d · %s", a.stepIndex, a.total, a.instruction or "")
		UI.tween(self.bannerFill, 0.3, { Size = UDim2.new((a.stepIndex - 1) / a.total, 0, 1, 0) })
		self:select(a.recipeId)
	else
		self.banner.Visible = false
		self.banner.Size = UDim2.new(1, -24, 0, 0)
		self.scroller.Position = UDim2.new(0, 0, 0, hH)
		self.scroller.Size = UDim2.new(1, 0, 1, -hH)
	end
	self:refresh()
end

function Feed:refresh()
	local p = self.profile
	if not p then
		return
	end
	self.coinLabel.Text = "💰 " .. UI.formatCount(p.coins)
	self.followLabel.Text = "👥 " .. UI.formatCount(p.followers)
	if p.persistence == "off" then
		self.saveNote.Text = "⚠ Progress not saving this session"
	elseif p.persistence == "loading" then
		self.saveNote.Text = "Loading profile..."
	else
		self.saveNote.Text = ""
	end
	for id, c in self.cards do
		local def = Recipes.Defs[id]
		local unlocked = p.unlocked[id] == true
		local best = p.best[id]
		c.badge.Visible = best ~= nil
		if best then
			c.badge.Text = string.format("✓ %s · %d", best.rank, best.score)
		end
		c.lock.Visible = not unlocked
		if not unlocked then
			if def.unlock.kind == "coins" then
				c.lockText.Text = string.format("🔒\nUnlock for %d coins", def.unlock.amount)
				c.lockBar.Visible = true
				c.lockFill.Size = UDim2.new(math.clamp(p.coins / def.unlock.amount, 0, 1), 0, 1, 0)
				local can = p.coins >= def.unlock.amount
				c.cta.Text = can and string.format("UNLOCK  💰 %d", def.unlock.amount) or string.format("🔒 NEED 💰 %d", def.unlock.amount)
				c.cta.BackgroundColor3 = can and UI.Colors.mint or Color3.fromRGB(90, 80, 100)
			else
				c.lockText.Text = string.format("🔒\nReach %d followers", def.unlock.amount)
				c.lockBar.Visible = true
				c.lockFill.Size = UDim2.new(math.clamp(p.followers / def.unlock.amount, 0, 1), 0, 1, 0)
				c.cta.Text = string.format("🔒 %d/%d 👥", math.min(p.followers, def.unlock.amount), def.unlock.amount)
				c.cta.BackgroundColor3 = Color3.fromRGB(90, 80, 100)
			end
		elseif self.active and self.active.recipeId == id then
			c.cta.Text = "🔥 COOKING NOW"
			c.cta.BackgroundColor3 = Color3.fromRGB(120, 100, 130)
		elseif self.active then
			if os.clock() >= c.confirmUntil then
				c.cta.Text = "SWITCH TO THIS"
			end
			c.cta.BackgroundColor3 = UI.Colors.orange
		else
			c.cta.Text = best and "MAKE AGAIN  ▶" or "MAKE THIS  ▶"
			c.cta.BackgroundColor3 = def.accent
		end
	end
end

-- phones: tighter header so a card has room
function Feed:setCompact(on: boolean)
	if self.compact == on then
		return
	end
	self.compact = on
	self.headerH = on and 86 or 122
	self.header.Size = UDim2.new(1, 0, 0, on and 86 or 116)
	self.logo.TextSize = on and 26 or 34
	self.logo.Size = UDim2.new(1, -60, 0, on and 30 or 40)
	self.statsRow.Position = UDim2.new(0, 0, 0, on and 36 or 48)
	self.statsRow.Size = UDim2.new(1, 0, 0, on and 32 or 40)
	self.coinLabel.TextSize = on and 20 or 24
	self.followLabel.TextSize = on and 20 or 24
	self.saveNote.Position = UDim2.new(0, 0, 0, on and 70 or 92)
	self.bannerStep.TextSize = on and 15 or 17
	self:setActive(self.active)
end

function Feed:setMuted(m: boolean)
	self.muteBtn.Text = m and "🔇" or "🔊"
end

function Feed:scrollTo(id: string)
	local c = self.cards[id]
	if not c then
		return
	end
	local s = self.scroller
	local target = s.CanvasPosition.Y + (c.frame.AbsolutePosition.Y - s.AbsolutePosition.Y - 6)
	local maxY = math.max(0, s.AbsoluteCanvasSize.Y - s.AbsoluteWindowSize.Y)
	UI.tween(s, 0.4, { CanvasPosition = Vector2.new(0, math.clamp(target, 0, maxY)) })
end

function Feed:bump(which: string)
	local chip = which == "coins" and self.coinChip or self.followChip
	local sc = chip:FindFirstChildOfClass("UIScale") or UI.new("UIScale", { Parent = chip })
	sc.Scale = 1.25
	UI.tween(sc, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
end

return Feed
