-- Cook the Trend: the 3D countertop. Camera, scene setup, and the six reusable step interactions.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("CTT")
local Config = require(Shared.Config)
local StepMath = require(Shared.StepMath)
local Dish = require(Shared.Dish)
local Coach = require(Shared.Coach)
local UI = require(script.Parent.UI)
local Fx = require(script.Parent.Fx)
local FruitMesh = require(script.Parent.FruitMesh)

local K = UI.Colors
local C = Color3.fromRGB

local Kitchen = {}
Kitchen.__index = Kitchen

Kitchen.ItemNames = {
	noodles = "Noodles",
	egg = "Egg",
	scallion = "Scallion",
	chashu = "Chashu",
	banana = "Banana",
	cheese = "Cheese",
	bun = "Buns",
	patty = "Patty",
	lettuce = "Lettuce",
	tomato = "Tomato",
	fish = "Fish",
	donut = "Donut",
	strawberry = "Strawberry",
	kiwi = "Kiwi",
	blueberry = "Blueberries",
	mint = "Mint",
	onion = "Onion",
	chili = "Chili",
	chashu_slice = "Chashu slice",
	egg_half = "Soft egg",
	scallion_pile = "Scallions",
	nori = "Nori",
	strawberry_slice = "Strawberry",
	kiwi_slice = "Kiwi",
	blueberry_cluster = "Blueberries",
	mint_leaf = "Mint",
	patty_cooked = "Patty",
	cheese_slice = "Cheese",
	lettuce_leaf = "Lettuce",
	tomato_slice = "Tomato",
	bun_top = "Top bun",
}

local DecoyLines = {
	banana = "Banana ramen?? Not today.",
	cheese = "Cheese in ramen... bold. Wrong, but bold.",
	fish = "That fish is staring at you.",
	donut = "Dessert comes later!",
	onion = "Onion in a fruit cup? Crying.",
	chili = "Spicy fruit cup? Nope!",
}

local StepIcons = { pick = "🧺", chop = "🔪", heat = "🔥", pour = "🥣", place = "✨", stack = "🍔" }
local StepVerbs = { pick = "GRAB!", chop = "SLICE!", heat = "COOK!", pour = "POUR!", place = "PLATE IT!", stack = "STACK!" }

local StackHeights = { patty_cooked = 0.42, cheese_slice = 0.09, lettuce_leaf = 0.14, tomato_slice = 0.16, bun_top = 1.0 }

------------------------------------------------------------------ construction
function Kitchen.new(deps)
	local self = setmetatable({}, Kitchen)
	self.deps = deps
	self.hud = deps.Hud
	self.sfx = deps.Sfx
	self.camera = workspace.CurrentCamera
	local kitchen = workspace:WaitForChild("Kitchen")
	local anchors = kitchen:WaitForChild("Anchors")
	self.anchors = {
		Board = anchors:WaitForChild("Board").Position,
		Stove = anchors:WaitForChild("Stove").Position,
		Plate = anchors:WaitForChild("Plate").Position,
		Tray = anchors:WaitForChild("Tray").Position,
	}
	self.counterY = self.anchors.Plate.Y
	self.burnerCoils = {}
	local burner = kitchen:FindFirstChild("Burner", true)
	if burner then
		for _, p in burner:GetDescendants() do
			if p:IsA("BasePart") and p.Name == "Coil" then
				table.insert(self.burnerCoils, p)
			end
		end
	end
	local folder = Instance.new("Folder")
	folder.Name = "CTT_Scene"
	folder.Parent = workspace
	self.folder = folder
	Fx.setFolder(folder)

	self.handlers = {}
	self.shake = 0
	self.focusName = "Overview"
	self.focusPos = Vector3.new(0, 3.5, -0.5)
	self.focusOffset = Vector3.new(0, 7.5, 12)
	self.focusTarget = self.focusPos
	self.offsetTarget = self.focusOffset
	self.camCF = nil
	self.feedFrac = 0.28
	self:setFocus("Overview", true)
	self:_wireInput()
	RunService:BindToRenderStep("CTT_Camera", Enum.RenderPriority.Camera.Value + 1, function(dt)
		self:_updateCamera(dt)
	end)
	return self
end

local FOCI = {
	Overview = { pos = Vector3.new(0, 4.6, -0.4), off = Vector3.new(0, 6.2, 11.2) },
	Tray = { off = Vector3.new(0, 12.6, 6.4), add = Vector3.new(0, 0.3, 0.9) },
	Board = { off = Vector3.new(0, 7.2, 5.0), add = Vector3.new(0, 0.3, 0.2) },
	Stove = { off = Vector3.new(0, 8.8, 6.2), add = Vector3.new(0, 0.8, 0) },
	Plate = { off = Vector3.new(0, 8.8, 6.8), add = Vector3.new(0, 1.0, 0) },
	PlateClose = { off = Vector3.new(0, 8.2, 5.6), add = Vector3.new(0, 1.0, 0) },
	Serve = { off = Vector3.new(0, 5.6, 12.5), add = Vector3.new(0, 2.6, -2.2) }, -- frames the dish and the chef
	Stack = { off = Vector3.new(0, 3.4, 9.2), add = Vector3.new(0, 1.2, 0) },
}

function Kitchen:setFocus(name: string, instant: boolean?, extra: Vector3?)
	local f = FOCI[name]
	local pos
	if f.pos then
		pos = f.pos
	else
		local key = name
		if name == "PlateClose" or name == "Serve" or name == "Stack" then
			key = "Plate"
		end
		pos = self.anchors[key] + (f.add or Vector3.zero)
	end
	if extra then
		pos += extra
	end
	self.focusName = name
	self.focusTarget = pos
	self.offsetTarget = f.off
	if instant then
		self.focusPos = pos
		self.focusOffset = f.off
	end
end

function Kitchen:setFeedFrac(f: number, compact: boolean?)
	self.feedFrac = f
	self.compact = compact == true
end

function Kitchen:addShake(a: number)
	self.shake = math.min(0.6, self.shake + a)
end

function Kitchen:_updateCamera(dt: number)
	self.camera = workspace.CurrentCamera
	local cam = self.camera
	if cam.CameraType ~= Enum.CameraType.Scriptable then
		cam.CameraType = Enum.CameraType.Scriptable
	end
	cam.FieldOfView = 42
	local a = 1 - math.exp(-5 * dt)
	self.focusPos = self.focusPos:Lerp(self.focusTarget, a)
	self.focusOffset = self.focusOffset:Lerp(self.offsetTarget, a)
	local vp = cam.ViewportSize
	local aspect = vp.X / math.max(1, vp.Y)
	local tanH = math.tan(math.rad(cam.FieldOfView / 2)) * aspect
	local dist = self.focusOffset.Magnitude
	-- phones: the HUD pill eats the top of the frame, so aim a little "behind" the action
	local fp = self.focusPos + (self.compact and Vector3.new(0, 0.3, -1.1) or Vector3.zero)
	local eye = fp + self.focusOffset
	local base = CFrame.lookAt(eye, fp)
	-- shift so the focus appears centred in the area right of the feed
	local shift = self.feedFrac * dist * tanH
	local cf = base - base.RightVector * shift
	if self.shake > 0.001 then
		local s = self.shake
		cf *= CFrame.Angles((math.random() - 0.5) * 0.02 * s, (math.random() - 0.5) * 0.02 * s, 0)
		self.shake = math.max(0, self.shake - dt * 2.5)
	end
	cam.CFrame = cf
end

------------------------------------------------------------------ input
function Kitchen:_wireInput()
	local hud = self.hud
	local function isPointer(io)
		return io.UserInputType == Enum.UserInputType.MouseButton1 or io.UserInputType == Enum.UserInputType.Touch
	end
	hud.input.InputBegan:Connect(function(io)
		if isPointer(io) and self.handlers.press then
			self.handlers.press(Vector2.new(io.Position.X, io.Position.Y))
		end
	end)
	hud.input.InputEnded:Connect(function(io)
		if isPointer(io) and self.handlers.release then
			self.handlers.release(Vector2.new(io.Position.X, io.Position.Y))
		end
	end)
	UserInputService.InputChanged:Connect(function(io)
		if (io.UserInputType == Enum.UserInputType.MouseMovement or io.UserInputType == Enum.UserInputType.Touch) and self.handlers.move then
			self.handlers.move(Vector2.new(io.Position.X, io.Position.Y))
		end
	end)
	hud.action.MouseButton1Down:Connect(function()
		hud:punchAction()
		if self.handlers.press then
			self.handlers.press(nil)
		end
	end)
	hud.action.MouseButton1Up:Connect(function()
		if self.handlers.release then
			self.handlers.release(nil)
		end
	end)
	UserInputService.InputBegan:Connect(function(io, gp)
		if gp then
			return
		end
		if io.KeyCode == Enum.KeyCode.Space and self.handlers.press then
			hud:punchAction()
			self.handlers.press(nil)
		end
	end)
	UserInputService.InputEnded:Connect(function(io)
		if io.KeyCode == Enum.KeyCode.Space and self.handlers.release then
			self.handlers.release(nil)
		elseif (io.UserInputType == Enum.UserInputType.Touch or io.UserInputType == Enum.UserInputType.MouseButton1) and self.handlers.releaseAny then
			-- finger slid off the button: still end holds (pour)
			self.handlers.releaseAny()
		end
	end)
end

function Kitchen:clearHandlers()
	self.handlers = {}
end

-- screen (input) position -> viewport position for HUD pops
function Kitchen:toViewport(pos: Vector2): Vector2
	local inset = GuiService:GetGuiInset()
	return pos + inset
end

function Kitchen:worldToViewport(p: Vector3): Vector2
	local v = self.camera:WorldToScreenPoint(p)
	return Vector2.new(v.X, v.Y)
end

local StreakBreakers = { GOOD = true, WONKY = true, NICE = true, MESSY = true, WOBBLY = true, ["IT'S SLIDING!"] = true, ["Oops! It fell off"] = true }
function Kitchen:popWorld(p: Vector3, text: string, color: Color3, size: number?)
	self.hud:pop(text, color, self:worldToViewport(p), size)
	-- PERFECT streaks across steps turn into a combo counter
	if string.find(text, "PERFECT") then
		self.streak = (self.streak or 0) + 1
		if self.streak >= 2 then
			self.hud:combo(self.streak)
			self.sfx.play("sparkle", { speed = 1 + math.min(self.streak, 8) * 0.06 })
		end
	elseif StreakBreakers[text] or color == K.red or color == K.orange then
		self.streak = 0
	end
end

function Kitchen:rayFrom(pos: Vector2)
	return self.camera:ScreenPointToRay(pos.X, pos.Y)
end

-- intersect pointer ray with horizontal plane y
function Kitchen:pointOnPlane(pos: Vector2, y: number): Vector3?
	local r = self:rayFrom(pos)
	if math.abs(r.Direction.Y) < 1e-4 then
		return nil
	end
	local t = (y - r.Origin.Y) / r.Direction.Y
	if t < 0 then
		return nil
	end
	return r.Origin + r.Direction * t
end

------------------------------------------------------------------ run context
local Ctx = {}
Ctx.__index = Ctx

function Ctx:track(x)
	table.insert(self.trash, x)
	return x
end

function Ctx:clearStep()
	for _, x in self.trash do
		if typeof(x) == "RBXScriptConnection" then
			x:Disconnect()
		elseif typeof(x) == "Instance" then
			x:Destroy()
		elseif typeof(x) == "table" and x.stop then
			x.stop()
		elseif typeof(x) == "function" then
			x()
		end
	end
	self.trash = {}
end

function Ctx:wait(t: number): boolean
	local e = 0
	while e < t do
		if self.cancelled then
			return false
		end
		e += task.wait()
	end
	return not self.cancelled
end

local function tween(obj, t, props, style, dir)
	local tw = TweenService:Create(obj, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end

-- tween a model pivot with a CFrameValue
local function tweenPivot(model: Model, t: number, target: CFrame, style, dir)
	local v = Instance.new("CFrameValue")
	v.Value = model:GetPivot()
	local conn = v.Changed:Connect(function(cf)
		if model.Parent then
			model:PivotTo(cf)
		end
	end)
	local tw = TweenService:Create(v, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), { Value = target })
	tw.Completed:Once(function()
		conn:Disconnect()
		v:Destroy()
	end)
	tw:Play()
	return tw
end
Kitchen.tweenPivot = tweenPivot

local function hop(model: Model, target: CFrame, t: number, height: number)
	-- parabolic arc from current pivot to target
	local start = model:GetPivot()
	local e = 0
	while e < t do
		e += task.wait()
		local a = math.min(1, e / t)
		local cf = start:Lerp(target, a)
		model:PivotTo(cf + Vector3.new(0, math.sin(a * math.pi) * height, 0))
	end
	model:PivotTo(target)
end

------------------------------------------------------------------ scene
function Kitchen:setupScene(recipe)
	self:showcase(nil)
	self:teardownScene()
	local scene = Instance.new("Model")
	scene.Name = "Run"
	scene.Parent = self.folder
	self.scene = scene
	local A = self.anchors
	local board = Dish.make("board")
	board:PivotTo(CFrame.new(A.Board))
	board.Parent = scene
	self.boardTop = A.Board.Y + 0.33

	local dish = Instance.new("Model")
	dish.Name = "PlayerDish"
	dish.Parent = scene
	self.dish = dish
	local vessel
	if recipe.dish == "ramen" then
		vessel = Dish.make("bowl")
		self.vesselKind = "bowl"
	elseif recipe.dish == "dessert" then
		vessel = Dish.make("cup")
		self.vesselKind = "cup"
	else
		vessel = Dish.make("plate")
		self.vesselKind = "plate"
	end
	vessel:PivotTo(CFrame.new(A.Plate))
	vessel.Parent = dish
	self.vessel = vessel
	dish.PrimaryPart = vessel.PrimaryPart
	if recipe.dish == "burger" then
		local bb = Dish.make("bun_bottom")
		bb:PivotTo(CFrame.new(A.Plate + Vector3.new(0, 0.2, 0)))
		bb.Parent = dish
		self.stackTop = A.Plate.Y + 0.2 + 0.56
	end
	-- cooking vessel on the stove
	local needsPot, needsPan = false, false
	for _, s in recipe.steps do
		if s.type == "heat" then
			if s.vessel == "pot" then
				needsPot = true
			else
				needsPan = true
			end
		end
	end
	if needsPot then
		local pot = Dish.make("pot")
		pot:PivotTo(CFrame.new(A.Stove + Vector3.new(0, 0.12, 0)))
		pot.Parent = scene
		self.cooker = pot
		-- generated pot mesh is closed near the rim: fill it to the brim so water + noodles read on top
		local water = pot:FindFirstChild("Water", true)
		if water and pot:FindFirstChild("Mesh") then
			local cf, size = pot:GetBoundingBox()
			local top = cf.Position.Y + size.Y / 2
			water.CFrame = CFrame.new(water.Position.X, top - 0.16, water.Position.Z) * CFrame.Angles(0, 0, math.rad(90))
			water.Size = Vector3.new(0.06, 2.75, 2.75)
			water.Transparency = 0.35
			local body = pot:FindFirstChild("WaterBody", true)
			if body then
				body.Transparency = 1
			end
		end
	elseif needsPan then
		local pan = Dish.make("pan")
		pan:PivotTo(CFrame.new(A.Stove + Vector3.new(0, 0.12, 0)) * CFrame.Angles(0, math.rad(40), 0))
		pan.Parent = scene
		self.cooker = pan
	end
	self.fill = 0
	self.state = {}
	self:setBurner(0)
	for _, st in recipe.steps do
		if st.type == "chop" then
			FruitMesh.preload(st.item)
		end
	end
end

-- idle "hero shot": the previewed trend's finished dish slowly turning on the serving mat
function Kitchen:showcase(recipeId: string?)
	if self.showcaseModel then
		self.showcaseModel:Destroy()
		self.showcaseModel = nil
	end
	if self.showcaseConn then
		self.showcaseConn:Disconnect()
		self.showcaseConn = nil
	end
	if not recipeId or self.scene then
		return
	end
	local m = Dish.final(recipeId)
	local base = CFrame.new(self.anchors.Plate)
	m:PivotTo(base + Vector3.new(0, 3, 0))
	m.Parent = self.folder
	self.showcaseModel = m
	local t = 0
	local steam
	if recipeId == "ramen" then
		local a = Fx.anchorPart(self.anchors.Plate + Vector3.new(0, 1.8, 0), m)
		steam = Fx.emitter(a, "steam")
		steam.Rate = 5
	end
	self.showcaseConn = RunService.RenderStepped:Connect(function(dt)
		t += dt
		local drop = math.max(0, 1 - t / 0.35)
		m:PivotTo(base * CFrame.new(0, drop * drop * 3, 0) * CFrame.Angles(0, t * 0.35, 0))
	end)
	self:setFocus("Overview")
end

function Kitchen:teardownScene()
	self:showcase(nil)
	if self.scene then
		self.scene:Destroy()
		self.scene = nil
	end
	for _, c in self.folder:GetChildren() do
		c:Destroy()
	end
	self.dish = nil
	self.vessel = nil
	self.cooker = nil
	self:setBurner(0)
end

function Kitchen:setBurner(heat: number)
	for _, p in self.burnerCoils do
		if heat > 0 then
			p.Material = Enum.Material.Neon
			p.Color = C(255, 90, 30):Lerp(C(255, 170, 60), math.clamp(heat - 0.5, 0, 1))
		else
			p.Material = Enum.Material.SmoothPlastic
			p.Color = C(70, 60, 60)
		end
	end
end

------------------------------------------------------------------ lesson (demonstrate -> instruct)
-- Shows the real-life technique, loops a ghost 3D demo until the player taps MY TURN (or Space / tap).
-- demo(isDone) plays one cycle and must clean up its ghosts; it should return early when isDone() is true.
function Kitchen:lesson(ctx, step, demo)
	local learn = step.learn
	if not learn then
		return not ctx.cancelled
	end
	local hud = self.hud
	local prevAction = hud.action.Visible and { hud.action.Text, hud.action.BackgroundColor3 } or nil
	hud:setAction(nil)
	hud:showLesson(learn.short or learn.tip, learn.expected, learn.why)
	local done = false
	local function isDone()
		return done or ctx.cancelled
	end
	hud.onMyTurn = function()
		done = true
	end
	self.handlers = {
		press = function()
			done = true
		end,
	}
	local t0 = os.clock()
	local limit = self.autoplay == "demo" and 4.5 or (self.autoplay and 0.5 or 14)
	task.spawn(function()
		while not isDone() do
			if demo then
				local ok, err = pcall(demo, isDone)
				if not ok then
					warn("[CTT] demo error", err)
					task.wait(0.5)
				end
			else
				task.wait(0.3)
			end
			local w = 0
			while w < 0.4 and not isDone() do
				w += task.wait()
			end
		end
	end)
	while not isDone() and os.clock() - t0 < limit do
		task.wait()
	end
	done = true
	self:clearHandlers()
	hud:compactLesson(learn.tip)
	if prevAction then
		hud:setAction(prevAction[1], prevAction[2])
	end
	self.sfx.play("click", { volume = 0.6 })
	return not ctx.cancelled
end

-- gold outline on the tool / ingredient the player is using right now
function Kitchen:spotlight(ctx, model: Instance)
	if not model then
		return
	end
	local hl = Instance.new("Highlight")
	hl.Name = "Spotlight"
	hl.FillTransparency = 1
	hl.OutlineColor = Color3.fromRGB(255, 214, 90)
	hl.OutlineTransparency = 0.15
	hl.DepthMode = Enum.HighlightDepthMode.Occluded
	hl.Adornee = model
	hl.Parent = self.folder
	ctx:track(hl)
	return hl
end

-- ghost copy of a model for demos (translucent, non-queryable)
function Kitchen:ghost(model: Model, transparency: number?)
	Dish.setTransparency(model, transparency or 0.55)
	Dish.setQueryable(model, false)
	local hl = Instance.new("Highlight")
	hl.FillTransparency = 1
	hl.OutlineColor = K.gold
	hl.OutlineTransparency = 0.2
	hl.DepthMode = Enum.HighlightDepthMode.Occluded
	hl.Parent = model
	model.Parent = self.scene
	return model
end

local function waitOr(t: number, isDone)
	local e = 0
	while e < t do
		if isDone() then
			return false
		end
		e += task.wait()
	end
	return true
end

------------------------------------------------------------------ step: pick
local function shuffle(t)
	for i = #t, 2, -1 do
		local j = math.random(1, i)
		t[i], t[j] = t[j], t[i]
	end
	return t
end

function Kitchen:runPick(ctx, step)
	self:setFocus("Tray")
	local ids = {}
	for _, id in step.required do
		table.insert(ids, id)
	end
	for _, id in step.decoys do
		table.insert(ids, id)
	end
	shuffle(ids)
	local need = {}
	for _, id in step.required do
		need[id] = true
	end
	local items = {}
	local n = #ids
	local spacing = 1.75
	local x0 = -(n - 1) * spacing / 2
	local center = self.anchors.Tray
	-- the serving dish waits off-stage so it doesn't hide the tray
	local dishHome = self.dish and self.dish:GetPivot()
	if self.dish then
		self.dish:PivotTo(dishHome - Vector3.new(0, 12, 0))
	end
	ctx:track(function()
		if self.dish and dishHome then
			self.dish:PivotTo(dishHome + Vector3.new(0, 3, 0))
			tweenPivot(self.dish, 0.4, dishHome, Enum.EasingStyle.Bounce)
		end
	end)
	for i, id in ids do
		local m = Dish.make(id)
		local _, ext = m:GetBoundingBox()
		local big = math.max(ext.X, ext.Z)
		if big > 1.5 then
			m:ScaleTo(1.5 / big)
		end
		local base = CFrame.new(center + Vector3.new(x0 + (i - 1) * spacing, 0.12, 0))
		local coaster = Dish.newModel("Coaster")
		Dish.disc(coaster, 1.5, 0.12, CFrame.new(0, 0.06, 0), C(255, 236, 214))
		Dish.disc(coaster, 1.6, 0.08, CFrame.new(0, 0.03, 0), C(226, 140, 110))
		coaster:PivotTo(base - Vector3.new(0, 0.12, 0))
		coaster.Parent = self.scene
		ctx:track(coaster)
		-- vetted mesh assets ship with CanQuery off: make the whole item tappable, plus a
		-- generous invisible hit box so small fruit is easy to hit on phones
		Dish.setQueryable(m, true)
		local hit = Instance.new("Part")
		hit.Name = "HitBox"
		hit.Anchored = true
		hit.CanCollide = false
		hit.CanTouch = false
		hit.CanQuery = true
		hit.Transparency = 1
		hit.Size = Vector3.new(1.6, 1.8, 1.6)
		hit.CFrame = m:GetPivot() * CFrame.new(0, 0.9, 0)
		hit.Parent = m
		m:PivotTo(base + Vector3.new(0, 4, 0))
		m.Parent = self.scene
		ctx:track(m)
		local tag = Instance.new("BillboardGui")
		tag.Size = UDim2.new(0, 150, 0, 34)
		tag.StudsOffsetWorldSpace = Vector3.new(0, 1.9, 0)
		tag.AlwaysOnTop = true
		tag.Adornee = m.PrimaryPart
		tag.Parent = m
		local l = UI.label({
			Text = Kitchen.ItemNames[id] or id,
			Font = UI.Font,
			TextSize = 22,
			TextColor3 = K.paper,
			TextXAlignment = Enum.TextXAlignment.Center,
			Size = UDim2.fromScale(1, 1),
			Parent = tag,
		})
		UI.textStroke(K.ink, 2.5).Parent = l
		items[i] = { id = id, model = m, base = base, picked = false, wrong = false, tag = l }
		task.delay((i - 1) * 0.06, function()
			if m.Parent then
				tweenPivot(m, 0.45, base, Enum.EasingStyle.Bounce)
			end
		end)
	end
	self.sfx.play("whoosh")
	local picks = {}
	local got = 0
	local function refreshList()
		local list = {}
		for _, id in step.required do
			local done = false
			for _, it in items do
				if it.id == id and it.picked then
					done = true
				end
			end
			table.insert(list, { text = Kitchen.ItemNames[id] or id, done = done })
		end
		self.hud:setChecklist(list)
	end
	refreshList()
	local hl = Instance.new("Highlight")
	hl.FillTransparency = 1
	hl.OutlineColor = K.gold
	hl.OutlineTransparency = 0
	hl.DepthMode = Enum.HighlightDepthMode.Occluded
	hl.Parent = self.folder
	ctx:track(hl)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	local function refreshParams()
		local list = {}
		for _, it in items do
			if not it.picked and not it.wrong then
				table.insert(list, it.model)
			end
		end
		params.FilterDescendantsInstances = list
	end
	refreshParams()
	local function itemAt(pos: Vector2)
		local r = self:rayFrom(pos)
		local hit = workspace:Raycast(r.Origin, r.Direction * 200, params)
		if not hit then
			return nil
		end
		for _, it in items do
			if hit.Instance:IsDescendantOf(it.model) then
				return it
			end
		end
		return nil
	end
	-- lesson: the recipe's ingredients light up one by one (learn to recognise them)
	if not self:lesson(ctx, step, function(isDone)
		for _, it in items do
			if need[it.id] and not isDone() then
				Fx.sparkleAt(it.base.Position + Vector3.new(0, 0.7, 0), K.gold, 8)
				self:popWorld(it.base.Position + Vector3.new(0, 1.6, 0), Kitchen.ItemNames[it.id] or it.id, K.gold, 26)
				waitOr(0.55, isDone)
			end
		end
		waitOr(0.6, isDone)
	end) then
		return nil
	end
	local t0 = os.clock()
	local done = false
	-- hover outline (mouse) + tap to pick
	self.handlers.move = function(pos)
		local it = itemAt(pos)
		hl.Adornee = it and it.model or nil
	end
	local choose
	self.handlers.press = function(pos)
		if done or not pos then
			return
		end
		local it = itemAt(pos)
		if not it then
			return
		end
		choose(it)
	end
	choose = function(it)
		if done or it.picked or it.wrong then
			return
		end
		if need[it.id] then
			it.picked = true
			got += 1
			table.insert(picks, it.id)
			refreshParams()
			hl.Adornee = nil
			self.sfx.play("plop")
			self:popWorld(it.base.Position + Vector3.new(0, 1.5, 0), "✓ " .. (Kitchen.ItemNames[it.id] or it.id), K.mint, 34)
			Fx.sparkleAt(it.base.Position + Vector3.new(0, 0.6, 0), K.gold, 10)
			it.tag.Visible = false
			task.spawn(function()
				hop(it.model, it.base + Vector3.new(0, 0.2, 3.0), 0.35, 1.6)
				if it.model.Parent then
					tweenPivot(it.model, 0.2, it.base + Vector3.new(0, -1.5, 3.0))
					Dish.setTransparency(it.model, 1)
				end
			end)
			refreshList()
			if got >= #step.required then
				done = true
			end
		else
			it.wrong = true
			table.insert(picks, it.id)
			refreshParams()
			hl.Adornee = nil
			self.sfx.play("buzz")
			self:addShake(0.25)
			self:popWorld(it.base.Position + Vector3.new(0, 1.8, 0), DecoyLines[it.id] or "Not in this recipe!", K.red, 26)
			local h2 = Instance.new("Highlight")
			h2.FillColor = K.red
			h2.FillTransparency = 0.5
			h2.OutlineColor = K.red
			h2.Parent = it.model
			task.spawn(function()
				for k = 1, 6 do
					if not it.model.Parent then
						break
					end
					it.model:PivotTo(it.base * CFrame.Angles(0, 0, math.rad((k % 2 == 0 and 1 or -1) * 14)))
					task.wait(0.05)
				end
				if it.model.Parent then
					it.model:PivotTo(it.base)
					Dish.setTransparency(it.model, 0.55)
					it.tag.Text = "❌ " .. it.tag.Text
					it.tag.TextColor3 = K.red
				end
				h2:Destroy()
			end)
		end
	end
	if self.autoplay then
		task.spawn(function()
			ctx:wait(0.8)
			if self.autoplay == "bad" then
				for _, it in items do
					if not need[it.id] then
						choose(it)
						break
					end
				end
				ctx:wait(0.5)
			end
			for _, it in items do
				if need[it.id] and not ctx.cancelled then
					choose(it)
					ctx:wait(0.35)
				end
			end
		end)
	end
	while not done do
		if not ctx:wait(0.05) then
			return nil
		end
	end
	self:clearHandlers()
	-- make sure server min-time check passes (0.2 s per pick)
	local minT = 0.2 * #picks + 0.1
	local spent = os.clock() - t0
	if spent < minT and not ctx:wait(minT - spent) then
		return nil
	end
	ctx:wait(0.45)
	self.hud:setChecklist(nil)
	return picks
end

------------------------------------------------------------------ step: chop
function Kitchen:runChop(ctx, step)
	self:setFocus("Board")
	local spec = Dish.ChopSpecs[step.item]
	local half = spec.len / 2
	local origin = CFrame.new(self.anchors.Board.X, self.boardTop, self.anchors.Board.Z)
	local cuts = {}
	local body
	-- EditableMesh pieces with real cut faces (async); primitive fallback if unavailable
	local buildSeq = 0
	local useMesh = FruitMesh.ready -- one renderer per step so pieces never mix styles
	local function rebuild()
		buildSeq += 1
		local my = buildSeq
		local nb = (useMesh and FruitMesh.chopBody(step.item, spec, table.clone(cuts))) or Dish.chopBody(step.item, table.clone(cuts))
		if my ~= buildSeq or ctx.cancelled then
			nb:Destroy() -- a newer cut already rebuilt
			return
		end
		nb:PivotTo(origin)
		nb.Parent = self.scene
		if body then
			body:Destroy()
		end
		body = nb
	end
	rebuild()
	-- drop-in
	body:PivotTo(origin + Vector3.new(0, 3, 0))
	tweenPivot(body, 0.35, origin, Enum.EasingStyle.Bounce)
	self.sfx.play("thud")
	ctx:track(function()
		if body then
			body:Destroy()
		end
	end)
	-- cut lines: a thin glowing "slice plane" through the food at every cut, so it is obvious WHERE to cut.
	-- states: todo (white) / next (gold + arrow) / hit (green) / miss (red)
	local W = StepMath.chopWindow(step)
	local guides, gstate = {}, {}
	local GUIDE_C = { todo = Color3.fromRGB(255, 255, 255), next = K.gold, hit = K.mint, miss = K.red, live = Color3.fromRGB(80, 255, 140) }
	for gi, g in step.guides do
		local gm = Instance.new("Model")
		gm.Name = "Guide"
		Dish.part(gm, Vector3.new(0.035, spec.dia + 0.35, spec.dia + 0.5), origin * CFrame.new(g * half, (spec.dia + 0.35) / 2, 0), GUIDE_C.todo, { Name = "Plane", Material = Enum.Material.Neon, CanQuery = false, Transparency = 0.55 })
		Dish.part(gm, Vector3.new(0.06, 0.03, spec.dia + 0.9), origin * CFrame.new(g * half, 0.02, 0), GUIDE_C.todo, { Name = "Board", Material = Enum.Material.Neon, CanQuery = false, Transparency = 0.1 })
		gm.Parent = self.scene
		ctx:track(gm)
		guides[gi] = gm
		gstate[gi] = "todo"
	end
	local function paintGuide(gi, state)
		local col = GUIDE_C[state]
		for _, p in guides[gi]:GetChildren() do
			if p:IsA("BasePart") then
				p.Color = col
				if p.Name == "Plane" then
					-- cut lines fade out once handled so the slices stay visible
					p.Transparency = (state == "next" or state == "live") and 0.25 or (state == "todo" and 0.6 or 0.92)
				end
			end
		end
	end
	-- bouncing arrow over the next cut
	local arrowGui = Instance.new("BillboardGui")
	arrowGui.Size = UDim2.new(0, 60, 0, 60)
	arrowGui.AlwaysOnTop = true
	arrowGui.StudsOffsetWorldSpace = Vector3.new(0, 0, 0)
	local arrowPart = Dish.part(self.scene, Vector3.new(0.1, 0.1, 0.1), origin, K.gold, { Transparency = 1, CanQuery = false })
	ctx:track(arrowPart)
	arrowGui.Adornee = arrowPart
	arrowGui.Parent = arrowPart
	local arrowLbl = UI.label({ Text = "▼", Font = UI.Font, TextSize = 46, TextColor3 = K.gold, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), Parent = arrowGui })
	UI.textStroke(K.ink, 3).Parent = arrowLbl
	local knife = Dish.make("knife")
	knife.Parent = self.scene
	ctx:track(knife)
	local hoverY = spec.dia + 0.9
	local function knifeCF(xn: number, down: number)
		return origin * CFrame.new(xn * half, hoverY - down * (hoverY - 0.02), 0.1) * CFrame.Angles(0, math.rad(32), math.rad(-8 + down * 8))
	end
	knife:PivotTo(knifeCF(StepMath.ChopStart, 0))
	-- lesson: a ghost knife shows the straight-down cut on each line
	if not self:lesson(ctx, step, function(isDone)
		local g = self:ghost(Dish.make("knife"), 0.45)
		local arrow = Dish.part(self.scene, Vector3.new(0.12, 0.7, 0.12), CFrame.new(), K.gold, { Material = Enum.Material.Neon, CanQuery = false })
		for gi2, gx in step.guides do
			if isDone() or gi2 > 3 then
				break
			end
			local from = g:GetPivot()
			local to = knifeCF(gx, 0)
			local e = 0
			while e < 0.25 and not isDone() do
				e += task.wait()
				g:PivotTo(from:Lerp(to, math.min(1, e / 0.25)))
			end
			arrow.CFrame = origin * CFrame.new(gx * half, spec.dia + 1.9, 0.9)
			e = 0
			while e < 0.18 and not isDone() do
				e += task.wait()
				g:PivotTo(knifeCF(gx, math.sin(math.min(1, e / 0.18) * math.pi)))
			end
			self.sfx.play("chopWood", { volume = 0.4 })
			waitOr(0.12, isDone)
		end
		waitOr(0.3, isDone)
		g:Destroy()
		arrow:Destroy()
	end) then
		return nil
	end
	self:spotlight(ctx, knife)
	self.hud:setAction("CHOP!", K.pink)
	self.hud:showCutTrack(step.guides, W)
	ctx:track(function()
		self.hud:hideCutTrack()
	end)
	if not ctx:wait(0.8) then
		return nil
	end
	self.hud:pop("GO!", K.gold, nil, 54)
	local taps = {}
	local t0 = os.clock()
	local chopAnim = 0 -- seconds remaining of the chop-down animation
	local dur = StepMath.chopDuration(step)
	self.handlers.press = function()
		local t = os.clock() - t0
		if t > dur or #taps >= 26 then
			return
		end
		table.insert(taps, t)
		self.lastChopTaps = taps
		chopAnim = 0.14
		local x = StepMath.knifeX(step, t)
		if x < -1 or x > 1 then
			self.sfx.play("whoosh")
			self:popWorld(origin.Position + Vector3.new(x * half, 1.5, 0), "whiff", K.muted, 26)
			return
		end
		local grade, gq = StepMath.cutGrade(step, x)
		table.insert(cuts, { x = x, clean = gq > 0 })
		-- mark the nearest open guide as cut
		local bestI, bestD = nil, math.huge
		for gi, g in step.guides do
			if gstate[gi] ~= "hit" and gstate[gi] ~= "miss" and math.abs(g - x) < bestD then
				bestI, bestD = gi, math.abs(g - x)
			end
		end
		if bestI and bestD <= W then
			gstate[bestI] = "hit"
			paintGuide(bestI, "hit")
		end
		task.spawn(rebuild)
		self.sfx.play("chop")
		self.sfx.play("chopWood")
		self:addShake(0.12)
		local cutPos = origin.Position + Vector3.new(x * half, spec.dia * 0.6, 0)
		Fx.burst(cutPos, spec.inner, 5)
		if grade == "PERFECT" then
			self:popWorld(cutPos + Vector3.new(0, 1.4, 0), "PERFECT!", K.gold, 38)
			Fx.sparkleAt(cutPos, K.gold, 8)
		elseif grade == "GOOD" then
			self:popWorld(cutPos + Vector3.new(0, 1.4, 0), "GOOD", K.mint, 32)
		else
			self:popWorld(cutPos + Vector3.new(0, 1.4, 0), "WONKY", K.orange, 30)
		end

	end
	if self.autoplay then
		task.spawn(function()
			for gi, g in step.guides do
				if self.autoplay == "bad" and gi % 2 == 0 then
					continue
				end
				local x = g + (self.autoplay == "bad" and 0.11 or 0)
				local tt = (x - StepMath.ChopStart) / step.speed
				while os.clock() - t0 < tt do
					if ctx.cancelled then
						return
					end
					task.wait()
				end
				if self.handlers.press then
					self.handlers.press()
				end
			end
		end)
	end
	while true do
		local dt = task.wait()
		if ctx.cancelled then
			return nil
		end
		local t = os.clock() - t0
		if t > dur then
			break
		end
		local x = StepMath.knifeX(step, t)
		local down = 0
		if chopAnim > 0 then
			chopAnim = math.max(0, chopAnim - dt)
			local a = 1 - chopAnim / 0.14
			down = math.sin(a * math.pi)
		end
		knife:PivotTo(knifeCF(x, down))
		-- guide states: passed without a cut = miss; first open one = next; knife inside its window = live (tap NOW)
		local nextI, live = nil, false
		for gi, g in step.guides do
			local st = gstate[gi]
			if st ~= "hit" and st ~= "miss" then
				if x > g + W then
					gstate[gi] = "miss"
					paintGuide(gi, "miss")
				elseif not nextI then
					nextI = gi
					local want = math.abs(x - g) <= W and "live" or "next"
					live = want == "live"
					if st ~= want then
						gstate[gi] = want
						paintGuide(gi, want)
					end
				elseif st ~= "todo" then
					gstate[gi] = "todo"
					paintGuide(gi, "todo")
				end
			end
		end
		if nextI then
			arrowGui.Enabled = true
			arrowPart.CFrame = origin * CFrame.new(step.guides[nextI] * half, spec.dia + 0.9 + math.abs(math.sin(os.clock() * 6)) * 0.25, 0)
			arrowLbl.TextColor3 = live and GUIDE_C.live or K.gold
		else
			arrowGui.Enabled = false
		end
		self.hud:setAction(live and "NOW!" or "CHOP!", live and K.mint or K.pink)
		self.hud:setCutTrack(x, gstate, W)
	end
	self:clearHandlers()
	self.hud:setAction(nil)
	-- missed guides flash red
	local q, details = StepMath.evalChop(step, taps)
	for gi in step.guides do
		if details.hits[gi] == 0 then
			paintGuide(gi, "miss")
		end
	end
	arrowGui.Enabled = false
	self.hud:hideCutTrack()
	self.state[step.item .. "_chop"] = q
	tweenPivot(knife, 0.3, knifeCF(1.6, 0) + Vector3.new(0, 1.5, 0))
	ctx:wait(0.35)
	-- push the pieces aside
	if body then
		tweenPivot(body, 0.35, origin * CFrame.new(0, 0, -0.9) * CFrame.new(0, 0, 0))
		self.sfx.play("whoosh")
	end
	ctx:wait(0.35)
	return taps
end

------------------------------------------------------------------ step: heat
function Kitchen:runHeat(ctx, step)
	self:setFocus("Stove")
	local stove = self.anchors.Stove
	local isPan = step.vessel == "pan"
	local item
	local topDisc, botDisc
	local floorY = stove.Y + 0.12 + (isPan and 0.16 or 0.2)
	if isPan then
		item = Dish.newModel("PattyCook")
		botDisc = Dish.disc(item, 2.3, 0.21, CFrame.new(0, 0.105, 0), Dish.Colors.pattyRaw, { Material = Enum.Material.Sand })
		topDisc = Dish.disc(item, 2.3, 0.21, CFrame.new(0, 0.315, 0), Dish.Colors.pattyRaw, { Material = Enum.Material.Sand })
	else
		item = Dish.make("noodles")
	end
	local home = CFrame.new(stove.X, floorY + (isPan and 0 or 0.85), stove.Z)
	item:PivotTo(home + Vector3.new(0, 4, 0))
	item.Parent = self.scene
	ctx:track(item)
	hop(item, home, 0.4, 1)
	if isPan then
		self.sfx.play("splat")
		Fx.splashAt(home.Position, C(255, 220, 160), 10)
	else
		self.sfx.play("plop")
		Fx.splashAt(home.Position + Vector3.new(0, 0.8, 0), C(200, 230, 255), 14)
	end
	-- emitters
	local ep = Fx.anchorPart(stove + Vector3.new(0, isPan and 0.6 or 1.6, 0), self.scene)
	ctx:track(ep)
	local steam = Fx.emitter(ep, "steam")
	if not isPan then
		-- lighter, higher steam over the pot so the noodles stay visible
		steam.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.78), NumberSequenceKeypoint.new(1, 1) })
		steam.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 1.8) })
		ep.Position += Vector3.new(0, 0.9, 0)
	end
	local smoke = Fx.emitter(ep, "smoke")
	local extra = Fx.emitter(ep, isPan and "sizzle" or "bubbles")
	local loop = self.sfx.loop(isPan and "sizzle" or "boil", 0.4)
	ctx:track(loop)
	ctx:track(function()
		self:setBurner(0)
	end)
	self:setBurner(1)
	local lo, hi = step.ideal[1], step.ideal[2]
	self.hud:showGauge({
		{ 0, lo, C(120, 170, 230), "RAW" },
		{ lo, hi, K.mint, "PERFECT" },
		{ hi, Config.BurntAt, K.orange, "OVER" },
		{ Config.BurntAt, Config.AutoBurnAt, K.red, "BURNT" },
	}, Config.AutoBurnAt)
	ctx:track(function()
		self.hud:hideGauge()
	end)
	-- lesson: watch the colour change and where the sweet spot is on the gauge
	if not self:lesson(ctx, step, function(isDone)
		local target = (lo + hi) / 2
		local e = 0
		while e < 1.6 and not isDone() do
			e += task.wait()
			local d = target * math.min(1, e / 1.6)
			if isPan then
				botDisc.Color = Dish.donenessColor("patty", d)
			else
				Dish.tint(item, d)
			end
			self.hud:setGauge(d, d >= lo and "NOW! (demo)" or "Watch the color...")
		end
		if not isDone() then
			self:popWorld(stove + Vector3.new(0, 2.6, 0), "PULL HERE ✓", K.mint, 30)
			waitOr(0.9, isDone)
		end
		if isPan then
			botDisc.Color = Dish.Colors.pattyRaw
		else
			Dish.tint(item, 0)
		end
		self.hud:setGauge(0, "")
	end) then
		return nil
	end
	self:spotlight(ctx, item)
	local noodleMesh, noodleBusy, noodleW = nil, false, -1
	-- the generated pot mesh is closed fairly high inside, so float strands just under the rim
	local waterY = home.Y + 0.5
	if self.cooker then
		local cf, size = self.cooker:GetBoundingBox()
		waterY = cf.Position.Y + size.Y / 2 - 0.13
	end
	local taps = {}
	local t0 = os.clock()
	local phase = 1
	local pressed = false
	local flipping = false
	self.hud:setAction(step.phases[1], K.orange)
	self.handlers.press = function()
		-- ignore taps until the current phase has really started (after the flip pause)
		if not flipping and os.clock() - t0 >= StepMath.heatPhaseStart(taps, phase) then
			pressed = true
		end
	end
	local doneness = {}
	while phase <= #step.phases do
		local dt = task.wait()
		_ = dt
		if ctx.cancelled then
			return nil
		end
		local t = os.clock() - t0
		local start = StepMath.heatPhaseStart(taps, phase)
		local d = StepMath.heatDoneness(step, t - start)
		-- visuals
		if isPan then
			botDisc.Color = Dish.donenessColor("patty", d)
			if phase == 2 then
				topDisc.Color = Dish.donenessColor("patty", doneness[1])
			end
		else
			Dish.tint(item, d)
			-- noodles soften: sink and spread a little
			item:PivotTo(home * CFrame.new(0, -math.min(d, 0.8) * 0.4, 0) * CFrame.Angles(0, d * 0.6, 0))
			-- EditableMesh strands: stiff & straight when raw, relaxing into soft waves as they cook
			local w = math.clamp(d / 0.7, 0, 1)
			if FruitMesh.ready and not noodleBusy and math.abs(w - noodleW) > 0.08 then
				noodleBusy = true
				noodleW = w
				task.spawn(function()
					local paths = {}
					local base = item:GetPivot()
					for sIdx = 1, 10 do
						local z0 = (sIdx - 5.5) * (0.12 + w * 0.12)
						local pts = {}
						for k = 0, 16 do
							local x = -1.05 + 2.1 * k / 16
							local z = z0 + math.sin(k * 0.9 + sIdx) * 0.16 * w
							local wp = base:PointToWorldSpace(Vector3.new(x, 0, z))
							-- float on the water surface (the pot mesh hides anything deeper)
							local y = waterY + 0.02 + math.sin(k * 0.7 + sIdx * 1.3) * 0.05 * w - (sIdx % 2) * 0.03
							table.insert(pts, Vector3.new(wp.X, y, wp.Z))
						end
						table.insert(paths, pts)
					end
					local mp = FruitMesh.tubes(paths, 0.06)
					if mp and item.Parent and not ctx.cancelled then
						mp.Color = Dish.donenessColor("noodle", d)
						mp:SetAttribute("Cook", "noodle")
						mp.Name = "Strands"
						mp.Parent = item
						if noodleMesh then
							noodleMesh:Destroy()
						end
						noodleMesh = mp
						-- hide the primitive bundle once real strands exist
						for _, part in item:GetDescendants() do
							if part:IsA("BasePart") and part ~= mp and part.Name ~= "Root" then
								part.Transparency = 1
							end
						end
					elseif mp then
						mp:Destroy()
					end
					noodleBusy = false
				end)
			end
		end
		steam.Rate = isPan and (4 + math.min(d, 1) * 14) or (1.5 + math.min(d, 1) * 6) -- keep the pot readable
		smoke.Rate = d > 0.8 and (d - 0.8) * 60 or 0
		extra.Rate = isPan and (8 + d * 20) or (6 + d * 30)
		loop.setVolume(0.35 + math.min(d, 1.2) * 0.6)
		local label
		if d < lo - 0.15 then
			label = "Cooking..."
		elseif d < lo then
			label = "Almost..."
		elseif d <= hi then
			label = "NOW!"
		elseif d < Config.BurntAt then
			label = "Hurry!!"
		else
			label = "IT'S BURNING!"
		end
		self.hud:setGauge(d, label)
		if self.autoplay and not flipping then
			local target = self.autoplay ~= "bad" and (lo + hi) / 2 or (phase == 1 and 1.0 or 0.3)
			if d >= target then
				pressed = true
			end
		end
		if d >= Config.AutoBurnAt then
			pressed = true -- auto-pull: fully burnt
		end
		if pressed then
			pressed = false
			taps[phase] = t
			doneness[phase] = d
			local q, lbl = StepMath.gradeDoneness(step, d)
			local col = q >= 0.85 and K.mint or (q >= 0.5 and K.gold or K.red)
			self:popWorld(stove + Vector3.new(0, 2.5, 0), string.upper(lbl), col, 36)
			if q >= 0.85 then
				self.sfx.play("sparkle")
				Fx.sparkleAt(stove + Vector3.new(0, 1, 0), K.gold, 14)
			elseif d >= Config.BurntAt then
				self.sfx.play("fail", { maxLength = 2.2 })
				Fx.puffAt(stove + Vector3.new(0, 1, 0), "smoke", 14)
				self:addShake(0.3)
			end
			phase += 1
			if phase <= #step.phases then
				-- flip!
				flipping = true
				self.hud:setAction(step.phases[phase], K.orange)
				self.sfx.play("whoosh")
				task.spawn(function()
					local up = home + Vector3.new(0, 1.6, 0)
					local e = 0
					while e < 0.55 do
						e += task.wait()
						local a = math.min(1, e / 0.55)
						item:PivotTo(home:Lerp(up, math.sin(a * math.pi)) * CFrame.Angles(a * math.pi, 0, 0) * CFrame.new(0, a > 0.5 and -0.42 or 0, 0))
					end
					-- after flip: swap faces so the cooked side shows on top
					item:PivotTo(home)
					topDisc.Color = Dish.donenessColor("patty", doneness[1])
					botDisc.Color = Dish.Colors.pattyRaw
					self.sfx.play("splat")
					Fx.splashAt(home.Position, C(255, 220, 160), 12)
					flipping = false
				end)
			end
		end
	end
	self:clearHandlers()
	self.hud:setAction(nil)
	self:setBurner(0)
	loop.stop()
	steam.Rate = 0
	smoke.Rate = 0
	extra.Rate = 0
	local avg = 0
	for _, d in doneness do
		avg += d
	end
	avg /= #doneness
	self.state.doneness = avg
	self.state.donenessTop = doneness[1]
	self.state.donenessBottom = doneness[#doneness]
	-- move the cooked food to where it belongs
	if not isPan then
		-- noodles into the bowl
		local nest = Dish.make("noodle_nest")
		Dish.tint(nest, avg)
		local y = Dish.Vessels.bowl.fillY(0.3)
		local target = CFrame.new(self.anchors.Plate + Vector3.new(0, y, 0))
		hop(item, target + Vector3.new(0, 0.6, 0), 0.5, 2.5)
		item:Destroy()
		nest:PivotTo(target)
		nest.Parent = self.dish
		self.sfx.play("splat")
		Fx.splashAt(target.Position, Dish.Colors.broth, 8)
		self:setFocus("Plate")
	else
		hop(item, home + Vector3.new(-1.2, 0.8, 1.2), 0.35, 1.2)
	end
	ctx:wait(0.3)
	return taps
end

------------------------------------------------------------------ step: pour
function Kitchen:runPour(ctx, step)
	self:setFocus("Plate")
	local kind = self.vesselKind
	local base = self.anchors.Plate
	local color = step.item == "broth" and Dish.Colors.broth or (step.item == "yogurt" and Dish.Colors.yogurt or Dish.Colors.honey)
	local isDrizzle = step.drizzle == true
	local startFill = self.fill
	-- liquid surface
	local surf = Dish.newModel("Liquid_" .. step.item)
	local disc = Dish.disc(surf, 1, 0.14, CFrame.new(), color, { Material = isDrizzle and Enum.Material.Glass or Enum.Material.SmoothPlastic, Transparency = isDrizzle and 0.1 or 0 })
	surf.Parent = self.dish
	local yBase = Dish.Vessels[kind].fillY(startFill)
	-- liquid body = 3 stacked slices, each sized to the wall radius at its bottom (never pokes through tapered walls)
	local slices = {}
	if not isDrizzle then
		for k = 1, 3 do
			slices[k] = Dish.disc(surf, 1, 0.1, CFrame.new(), color)
		end
	end
	local function setSurface(f: number)
		if isDrizzle then
			-- honey: thin glossy layer on top + growing drizzle
			local y = yBase + 0.06 + math.min(f, 1.2) * 0.25
			local r = Dish.vesselRadiusAt(kind, yBase) * math.clamp(0.35 + f * 1.4, 0.35, 0.98)
			disc.Size = Vector3.new(0.06 + math.min(f, 1.2) * 0.2, r * 2, r * 2)
			disc.CFrame = CFrame.new(base + Vector3.new(0, y, 0)) * CFrame.Angles(0, 0, math.rad(90))
		else
			local y0 = Dish.Vessels[kind].fillY(0)
			local y = Dish.Vessels[kind].fillY(math.min(f, 1.02))
			local r = Dish.vesselRadiusAt(kind, y)
			disc.Size = Vector3.new(0.12, r * 2 - 0.08, r * 2 - 0.08)
			disc.CFrame = CFrame.new(base + Vector3.new(0, y, 0)) * CFrame.Angles(0, 0, math.rad(90))
			local h = math.max(0.02, (y - y0) / 3)
			for k = 1, 3 do
				local yb = y0 + (k - 1) * h
				local rk = Dish.vesselRadiusAt(kind, yb) - 0.06
				slices[k].Size = Vector3.new(h + 0.01, rk * 2, rk * 2)
				slices[k].CFrame = CFrame.new(base + Vector3.new(0, yb + h / 2, 0)) * CFrame.Angles(0, 0, math.rad(90))
			end
		end
	end
	setSurface(0)
	-- target ring
	if not isDrizzle then
		local ty = Dish.Vessels[kind].fillY(step.target)
		local ring = Fx.ring(self.scene, CFrame.new(base + Vector3.new(0, ty + 0.02, 0)), Dish.vesselRadiusAt(kind, ty) - 0.05, K.gold, 24, 0.1)
		ctx:track(ring)
	end
	-- pitcher
	local pitcher = Dish.pitcher(step.item)
	pitcher.Parent = self.scene
	ctx:track(pitcher)
	local rimY = Dish.Vessels[kind].height + 1.4
	local restCF = CFrame.new(base + Vector3.new(-2.3, rimY + 0.8, 0.2))
	local pourCF = CFrame.new(base + Vector3.new(-1.2, rimY + 0.5, 0.2)) * CFrame.Angles(0, 0, math.rad(isDrizzle and 0 or 60))
	pitcher:PivotTo(restCF + Vector3.new(0, 3, 0))
	tweenPivot(pitcher, 0.35, restCF, Enum.EasingStyle.Back)
	local stream = Dish.part(self.scene, Vector3.new(0.18, 1, 0.18), CFrame.new(), color, { Material = Enum.Material.Glass, Transparency = 1, CanQuery = false })
	ctx:track(stream)
	local sp = Fx.anchorPart(base + Vector3.new(0, yBase, 0), self.scene)
	ctx:track(sp)
	local splash = Fx.emitter(sp, "splash", color)
	local steamE = step.item == "broth" and Fx.emitter(sp, "steam") or nil
	local spill
	self.hud:showFill(step.target, color)
	ctx:track(function()
		self.hud:hideFill()
	end)
	-- lesson: a ghost pour fills exactly to the gold line
	if not self:lesson(ctx, step, function(isDone)
		local gd = Dish.disc(self.scene, 1, 0.1, CFrame.new(), color, { Material = Enum.Material.Glass, Transparency = 0.45, CanQuery = false })
		local e = 0
		tweenPivot(pitcher, 0.15, pourCF)
		while e < 1.4 and not isDone() do
			e += task.wait()
			local f = step.target * math.min(1, e / 1.4)
			local y = isDrizzle and (yBase + 0.08 + f * 0.25) or Dish.Vessels[kind].fillY(f)
			local r = Dish.vesselRadiusAt(kind, isDrizzle and yBase or y) * (isDrizzle and math.clamp(0.35 + f * 1.4, 0.35, 0.98) or 1) - 0.08
			gd.Size = Vector3.new(0.1, r * 2, r * 2)
			gd.CFrame = CFrame.new(base + Vector3.new(0, y, 0)) * CFrame.Angles(0, 0, math.rad(90))
			self.hud:setFill(f)
		end
		tweenPivot(pitcher, 0.2, restCF)
		if not isDone() then
			self:popWorld(base + Vector3.new(0, 3.2, 0), "STOP AT THE LINE ✓", K.mint, 28)
			waitOr(0.8, isDone)
		end
		gd:Destroy()
		self.hud:setFill(0)
	end) then
		return nil
	end
	self:spotlight(ctx, pitcher)
	self.hud:setAction("HOLD TO POUR", K.orange)
	local pulses = {}
	local pouring = false
	local pourStart = 0
	local pressAt = 0
	local toggled = false
	local t0 = os.clock()
	local loop
	local finished = false
	local function amountNow(t: number)
		local a = StepMath.pourAmount(step, pulses)
		if pouring then
			a += (t - pourStart) * step.rate
		end
		return a
	end
	local function startPour()
		if pouring or finished or #pulses >= 8 then
			return
		end
		pouring = true
		pourStart = os.clock() - t0
		tweenPivot(pitcher, 0.15, pourCF)
		loop = self.sfx.loop("pour", 0.8)
		self.hud:setAction("POURING...", K.gold)
	end
	local function stopPour()
		if not pouring then
			return
		end
		pouring = false
		local t = os.clock() - t0
		table.insert(pulses, { pourStart, t })
		tweenPivot(pitcher, 0.2, restCF)
		if loop then
			loop.stop()
			loop = nil
		end
		local a = StepMath.pourAmount(step, pulses)
		if a >= step.target - 0.12 or #pulses >= 8 or a > 1.0 then
			finished = true
		else
			self.hud:setAction("HOLD TO POUR", K.orange)
			self.hud:pop("A bit more...", K.paper, nil, 34)
		end
	end
	ctx:track(function()
		if loop then
			loop.stop()
		end
	end)
	self.handlers.press = function()
		if pouring and toggled then
			toggled = false
			stopPour()
			return
		end
		pressAt = os.clock()
		startPour()
	end
	self.handlers.releaseAny = function()
		if pouring and not toggled and os.clock() - pressAt >= 0.18 then
			stopPour()
		end
	end
	self.handlers.release = function()
		if not pouring then
			return
		end
		if os.clock() - pressAt < 0.18 then
			-- quick tap: keep pouring until the next tap (tap alternative to holding)
			toggled = true
			self.hud:setAction("TAP TO STOP", K.red)
			return
		end
		stopPour()
	end
	if self.autoplay then
		task.spawn(function()
			ctx:wait(0.6)
			local goal = self.autoplay ~= "bad" and step.target or math.min(1.1, step.target + 0.4)
			startPour()
			while pouring and amountNow(os.clock() - t0) < goal and not ctx.cancelled do
				task.wait()
			end
			stopPour()
		end)
	end
	while not finished do
		task.wait()
		if ctx.cancelled then
			return nil
		end
		local t = os.clock() - t0
		local a = amountNow(t)
		setSurface(a)
		self.fill = isDrizzle and startFill or math.min(a, 1)
		self.hud:setFill(a)
		local surfY = isDrizzle and yBase + 0.1 or Dish.Vessels[kind].fillY(math.min(a, 1.02))
		sp.Position = base + Vector3.new(0, surfY, 0)
		if pouring then
			local spout = pitcher:GetPivot() * CFrame.new(isDrizzle and 0.7 or -0.6, isDrizzle and -0.3 or 0.2, 0)
			local top = spout.Position
			local bottom = Vector3.new(base.X - 0.3, base.Y + surfY, base.Z + 0.2)
			local mid = (top + bottom) / 2
			local len = (top - bottom).Magnitude
			stream.Size = Vector3.new(isDrizzle and 0.09 or 0.2, len, isDrizzle and 0.09 or 0.2)
			stream.CFrame = CFrame.lookAt(mid, bottom) * CFrame.Angles(math.rad(90), 0, 0)
			stream.Transparency = 0.15
			splash.Rate = 25
			if steamE then
				steamE.Rate = 6
			end
			if a > 1.0 then
				if not spill then
					spill = Dish.disc(self.scene, 0.5, 0.05, CFrame.new(base + Vector3.new(1.8, 0.03, 1.2)), color)
					ctx:track(spill)
					self.sfx.play("splat")
					self:popWorld(base + Vector3.new(0, 3, 0), "OVERFLOW!", K.red, 40)
				end
				local s = 0.5 + (a - 1) * 8
				spill.Size = Vector3.new(0.05, math.min(s, 4), math.min(s, 4))
			end
			if a > 1.15 then
				stopPour()
				finished = true
			end
		else
			stream.Transparency = 1
			splash.Rate = 0
		end
	end
	self:clearHandlers()
	self.hud:setAction(nil)
	stream.Transparency = 1
	splash.Rate = 0
	local a = StepMath.pourAmount(step, pulses)
	setSurface(a)
	if not isDrizzle then
		self.fill = math.min(a, 1)
		-- noodles float up to peek out of the broth
		local nest = self.dish and self.dish:FindFirstChild("noodle_nest")
		if nest then
			local y = Dish.Vessels[kind].fillY(math.clamp(self.fill, 0.3, 1))
			tweenPivot(nest, 0.4, CFrame.new(base + Vector3.new(0, y + 0.04, 0)))
		end
	else
		self.state.honey = a
	end
	tweenPivot(pitcher, 0.3, restCF + Vector3.new(0, 4, 0))
	local _ = os.clock() - t0
	ctx:wait(0.5)
	return pulses
end

------------------------------------------------------------------ step: place
function Kitchen:runPlace(ctx, step)
	self:setFocus("PlateClose")
	local kind = self.vesselKind
	local base = self.anchors.Plate
	local fill = math.clamp(self.fill > 0 and self.fill or 0.6, 0.15, 1)
	local surfY = base.Y + Dish.Vessels[kind].fillY(fill)
	local radius = Dish.vesselRadiusAt(kind, surfY - base.Y) * 0.86
	local points = {}
	local idx = 1
	local held, ring
	local holding = false
	local lastPos: Vector2? = nil
	local placing = false
	local function upcoming()
		local list = {}
		for i, t in step.toppings do
			table.insert(list, { text = Kitchen.ItemNames[t.item] or t.item, done = i < idx })
		end
		self.hud:setChecklist(list)
	end
	local function spawnNext()
		local top = step.toppings[idx]
		if ring then
			ring:Destroy()
		end
		local slotWorld = base + Vector3.new(top.slot[1] * radius, surfY - base.Y + 0.03, top.slot[2] * radius)
		ring = Fx.ring(self.scene, CFrame.new(slotWorld + Vector3.new(0, 0.1, 0)), 0.45, K.gold, 14, 0.09)
		held = Dish.make(top.item)
		held:PivotTo(CFrame.new(base + Vector3.new(0, surfY - base.Y + 2.2, 0)))
		held.Parent = self.scene
		Dish.setQueryable(held, false)
		upcoming()
	end
	ctx:track(function()
		if ring then
			ring:Destroy()
		end
		if held then
			held:Destroy()
		end
	end)
	spawnNext()
	-- lesson: ghost toppings show the target arrangement (sections, clear centre)
	if not self:lesson(ctx, step, function(isDone)
		local ghosts = {}
		for _, top in step.toppings do
			if isDone() then
				break
			end
			local g = self:ghost(Dish.make(top.item), 0.45)
			local p = base + Vector3.new(top.slot[1] * radius, surfY - base.Y + 0.08, top.slot[2] * radius)
			g:PivotTo(CFrame.new(p) * CFrame.Angles(0, math.atan2(-top.slot[1], -top.slot[2]), 0))
			table.insert(ghosts, g)
			Fx.sparkleAt(p + Vector3.new(0, 0.3, 0), K.gold, 6)
			waitOr(0.35, isDone)
		end
		waitOr(1.0, isDone)
		for _, g in ghosts do
			g:Destroy()
		end
	end) then
		return nil
	end
	self.hud:setAction("PLACE", K.mint)
	local function aimAt(pos: Vector2?)
		if not held then
			return
		end
		local p = pos and self:pointOnPlane(pos, surfY)
		if p then
			-- hover on the same camera ray so what you see is exactly where it lands
			local dir = self:rayFrom(pos).Direction.Unit
			held:PivotTo(CFrame.new(p - dir * 1.3))
		end
	end
	local function place()
		if placing or not held then
			return
		end
		placing = true
		local pv = held:GetPivot().Position
		-- project the hover point back down its camera ray onto the food surface
		local camPos = self.camera.CFrame.Position
		local dd = pv - camPos
		if math.abs(dd.Y) > 1e-3 then
			local tt = (surfY - camPos.Y) / dd.Y
			if tt > 0 then
				pv = camPos + dd * tt
			end
		end
		local local3 = pv - base
		local nx, nz = local3.X / radius, local3.Z / radius
		local top = step.toppings[idx]
		local q, off = StepMath.gradePlacement(top.slot, nx, nz)
		points[idx] = { nx, nz }
		local item = held
		held = nil
		task.spawn(function()
			if off then
				-- falls off the dish onto the counter
				local dir = Vector3.new(nx, 0, nz).Unit
				local land = base + dir * (radius + 1.4) + Vector3.new(0, 0.05, 0)
				hop(item, CFrame.new(land) * CFrame.Angles(0, 0, math.rad(70)), 0.45, 0.6)
				self.sfx.play("splat")
				self:popWorld(land + Vector3.new(0, 1.5, 0), "Oops! It fell off", K.red, 32)
				item.Parent = self.scene
			else
				local target = CFrame.new(Vector3.new(pv.X, surfY + 0.07, pv.Z)) * CFrame.Angles(0, math.atan2(-nx, -nz), 0)
				tweenPivot(item, 0.16, target, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
				task.wait(0.16)
				item.Parent = self.dish
				self.sfx.play("plop")
				local word, col
				if q >= 0.85 then
					word, col = "PERFECT!", K.gold
					Fx.sparkleAt(target.Position + Vector3.new(0, 0.3, 0), K.gold, 12)
					self.sfx.play("sparkle", { volume = 0.6 })
				elseif q >= 0.55 then
					word, col = "NICE", K.mint
				else
					word, col = "MESSY", K.orange
				end
				self:popWorld(target.Position + Vector3.new(0, 1.2, 0), word, col, 32)
			end
		end)
		idx += 1
		if idx <= #step.toppings then
			task.delay(0.25, function()
				if not ctx.cancelled then
					spawnNext()
					aimAt(lastPos)
					placing = false
				end
			end)
		else
			if ring then
				ring:Destroy()
				ring = nil
			end
			placing = false
		end
	end
	self.handlers.move = function(pos)
		lastPos = pos
		if UserInputService.TouchEnabled and not holding then
			return
		end
		aimAt(pos)
	end
	self.handlers.press = function(pos)
		if pos then
			holding = true
			lastPos = pos
			aimAt(pos)
		else
			place() -- action button / space: drop where it hovers
		end
	end
	self.handlers.release = function(pos)
		if pos and holding then
			holding = false
			aimAt(pos)
			place()
		end
	end
	if self.autoplay then
		task.spawn(function()
			for i, top in step.toppings do
				while (placing or not held or idx ~= i) and not ctx.cancelled do
					task.wait()
				end
				if ctx.cancelled then
					return
				end
				ctx:wait(0.45)
				local sx, sz = top.slot[1], top.slot[2]
				if self.autoplay == "bad" then
					sx += 0.45
					if i == #step.toppings then
						sx, sz = 1.4, 0.2
					end
				end
				if held then
					local target = base + Vector3.new(sx * radius, surfY - base.Y, sz * radius)
					local dir = (target - self.camera.CFrame.Position).Unit
					held:PivotTo(CFrame.new(target - dir * 1.3))
					place()
				end
			end
		end)
	end
	-- ring pulse
	local t0 = os.clock()
	while idx <= #step.toppings or placing do
		task.wait()
		if ctx.cancelled then
			return nil
		end
		if ring then
			local s = 1 + math.sin((os.clock() - t0) * 6) * 0.12
			for _, p in ring:GetChildren() do
				p.Transparency = 0.5 - math.sin((os.clock() - t0) * 6) * 0.4
			end
			_ = s
		end
	end
	self:clearHandlers()
	self.hud:setAction(nil)
	self.hud:setChecklist(nil)
	local minT = 0.25 * #points + 0.1
	local spent = os.clock() - t0
	if spent < minT then
		ctx:wait(minT - spent)
	end
	ctx:wait(0.45)
	return points
end

------------------------------------------------------------------ step: stack
function Kitchen:runStack(ctx, step)
	local base = self.anchors.Plate
	local top = self.stackTop or (base.Y + 0.76)
	self:setFocus("Stack", false, Vector3.new(0, top - base.Y - 0.6, 0))
	local taps = {}
	local k = 1
	local t0 = os.clock()
	local current
	local currentSpawn
	local pressed = false
	local guide = Dish.part(self.scene, Vector3.new(0.05, 2.2, 0.05), CFrame.new(), K.paper, { Material = Enum.Material.Neon, Transparency = 0.5, CanQuery = false })
	ctx:track(guide)
	local centerRing = Fx.ring(self.scene, CFrame.new(base.X, top + 0.02, base.Z), 0.3, K.gold, 10, 0.08)
	ctx:track(centerRing)
	local SW = 1.45 -- world studs per unit offset
	-- lesson: a ghost layer swings and drops exactly as it passes the centre
	if not self:lesson(ctx, step, function(isDone)
		local layer = step.layers[1]
		local g = self:ghost(Dish.make(layer.item), 0.45)
		local e = 0
		local want = layer.period / 2
		while e < want and not isDone() do
			e += task.wait()
			local off = StepMath.stackOffset(layer, e)
			g:PivotTo(CFrame.new(base.X + off * SW, top + 2.6, base.Z))
		end
		if not isDone() then
			tweenPivot(g, 0.18, CFrame.new(base.X, top, base.Z), Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			waitOr(0.25, isDone)
			self:popWorld(Vector3.new(base.X, top + 1.4, base.Z), "DROP IN THE CENTER ✓", K.mint, 28)
			waitOr(0.8, isDone)
		end
		g:Destroy()
	end) then
		return nil
	end
	t0 = os.clock()
	self.hud:setAction("DROP!", K.pink)
	self.handlers.press = function()
		pressed = true
	end
	local lean = 0
	while k <= #step.layers do
		task.wait()
		if ctx.cancelled then
			return nil
		end
		local t = os.clock() - t0
		local spawn = StepMath.stackSpawn(taps, k)
		local layer = step.layers[k]
		if t < spawn then
			pressed = false
			continue
		end
		if not current or currentSpawn ~= spawn then
			current = Dish.make(layer.item)
			if layer.item == "patty_cooked" and self.state.doneness then
				Dish.tint(current, self.state.doneness)
			end
			current.Parent = self.scene
			currentSpawn = spawn
			self.sfx.play("whoosh", { volume = 0.6 })
		end
		local off = StepMath.stackOffset(layer, t - spawn)
		local hoverY = top + 2.6
		current:PivotTo(CFrame.new(base.X + off * SW, hoverY, base.Z) * CFrame.Angles(0, 0, math.rad(-off * 6)))
		guide.CFrame = CFrame.new(base.X + off * SW, (hoverY + top) / 2, base.Z)
		guide.Size = Vector3.new(0.05, hoverY - top, 0.05)
		if self.autoplay then
			local want = self.autoplay ~= "bad" and layer.period / 2 or layer.period / 4
			if t - spawn >= want then
				pressed = true
			end
		end
		local auto = t - spawn >= StepMath.StackAutoDrop
		if pressed or auto then
			pressed = false
			taps[k] = t
			local item = current
			current = nil
			local q = math.clamp(1 - math.max(0, math.abs(off) / layer.amp - 0.06) * 1.15, 0, 1)
			local landY = top
			local x = base.X + off * SW
			lean += off * 0.08
			local tilt = 0
			if math.abs(off) > 0.8 then
				tilt = (off > 0 and -1 or 1) * 22
			end
			local target = CFrame.new(x, landY, base.Z) * CFrame.Angles(0, 0, math.rad(tilt + -lean * 10))
			tweenPivot(item, 0.18, target, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			task.delay(0.18, function()
				if item.Parent then
					item.Parent = self.dish
				end
				self.sfx.play("thud")
				self.sfx.play("plop", { volume = 0.5 })
				self:addShake(0.15)
				local word, col
				if q >= 0.85 then
					word, col = "PERFECT!", K.gold
					Fx.sparkleAt(Vector3.new(x, landY + 0.3, base.Z), K.gold, 10)
				elseif q >= 0.55 then
					word, col = "NICE", K.mint
				else
					word, col = math.abs(off) > 0.8 and "IT'S SLIDING!" or "WOBBLY", K.orange
				end
				self:popWorld(Vector3.new(x, landY + 1.2, base.Z), word, col, 32)
			end)
			top += StackHeights[layer.item] or 0.2
			centerRing:PivotTo(CFrame.new(base.X, top + 0.02, base.Z))
			self:setFocus("Stack", false, Vector3.new(0, top - base.Y - 0.6, 0))
			k += 1
		end
	end
	self:clearHandlers()
	self.hud:setAction(nil)
	self.stackTop = top
	ctx:wait(0.5)
	-- skewer to finish (memorable touch)
	local skewer = Dish.newModel("skewer")
	Dish.rod(skewer, 2.8, 0.07, CFrame.new(0, 1.4, 0) * CFrame.Angles(0, 0, math.rad(90)), C(230, 200, 150), { Material = Enum.Material.Wood })
	Dish.part(skewer, Vector3.new(0.05, 0.45, 0.7), CFrame.new(0, 2.55, 0.35), C(235, 60, 60))
	skewer:PivotTo(CFrame.new(base.X, top + 3, base.Z))
	skewer.Parent = self.dish
	tweenPivot(skewer, 0.25, CFrame.new(base.X, top - 1.9, base.Z), Enum.EasingStyle.Back)
	self.sfx.play("crunch")
	ctx:wait(0.35)
	return taps
end

------------------------------------------------------------------ serve + results support
function Kitchen:serve(ctx, good: boolean)
	self:setFocus("Serve")
	self.sfx.play("ding")
	-- the chef (your avatar) reacts to the dish
	task.spawn(function()
		local char = Players.LocalPlayer.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hum then
			pcall(function()
				hum:PlayEmote(good and "cheer" or "laugh")
			end)
		end
	end)
	local dish = self.dish
	if dish then
		local pivot = dish:GetPivot()
		local e = 0
		while e < 1.0 do
			e += task.wait()
			local a = math.min(1, e / 1.0)
			local lift = math.sin(a * math.pi) * 0.6
			dish:PivotTo(pivot * CFrame.new(0, lift, 0) * CFrame.Angles(0, a * math.pi * 2, 0))
		end
		dish:PivotTo(pivot)
		if good then
			Fx.confetti(pivot.Position + Vector3.new(0, 2, 0), 50)
			Fx.sparkleAt(pivot.Position + Vector3.new(0, 1.5, 0), K.gold, 30)
		else
			Fx.puffAt(pivot.Position + Vector3.new(0, 1.2, 0), "steam", 8)
		end
	end
end

-- clone of the player's actual dish, re-centred at origin (for result viewports)
function Kitchen:snapshotDish(): Model?
	if not self.dish then
		return nil
	end
	local m = self.dish:Clone()
	local root = Dish.newModel("Snapshot")
	for _, c in m:GetChildren() do
		c.Parent = root
	end
	m:Destroy()
	-- move so the plate anchor is at origin
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") then
			d.CFrame = d.CFrame - self.anchors.Plate
		end
	end
	return root
end

------------------------------------------------------------------ main run loop
-- callbacks: onStep(i, step), onResult(i, res) ; returns final result or nil
function Kitchen:run(recipe, session, callbacks)
	local ctx = setmetatable({ cancelled = false, trash = {} }, Ctx)
	if self.ctx and self.ctx ~= ctx then
		self.ctx.cancelled = true
		self.ctx:clearStep()
	end
	self.ctx = ctx
	Dish.meshAllowed = true
	self:setupScene(recipe)
	self.hud:setCooking(true)
	self.hud:setIdle(false)
	local qualities = {}
	self.streak = 0
	local viewers = math.random(90, 160)
	local shown = viewers
	local recStart = os.clock()
	task.spawn(function()
		while not ctx.cancelled and self.ctx == ctx and not ctx.finished do
			shown += (viewers - shown) * 0.08 + (math.random() - 0.4) * 2
			self.hud:setRec(os.clock() - recStart, math.max(1, math.floor(shown)))
			task.wait(0.1)
		end
	end)
	local runners = {
		pick = self.runPick,
		chop = self.runChop,
		heat = self.runHeat,
		pour = self.runPour,
		place = self.runPlace,
		stack = self.runStack,
	}
	local final
	for i, step in recipe.steps do
		if ctx.cancelled then
			break
		end
		self.hud:setSteps(#recipe.steps, i, qualities)
		self.hud:setInstruction(StepIcons[step.type] or "🍳", step.title, step.instruction)
		self.hud:banner(StepIcons[step.type] or "🍳", StepVerbs[step.type] or "GO!", K.paper)
		self.sfx.play("whoosh", { volume = 0.8 })
		if callbacks.onStep then
			callbacks.onStep(i, step)
		end
		local attempts = 0
		local res
		repeat
			attempts += 1
			-- remember the dish so a rejected attempt can be rolled back (no doubled food)
			local before = {}
			if self.dish then
				for _, c in self.dish:GetChildren() do
					before[c] = true
				end
			end
			local fillBefore, topBefore = self.fill, self.stackTop
			local events = runners[step.type](self, ctx, step)
			ctx:clearStep()
			self:clearHandlers()
			if ctx.cancelled or events == nil then
				return nil
			end
			for retry = 1, 4 do
				res = self.deps.request("step", { sessionId = session.sessionId, stepIndex = i, events = events })
				if res and res.ok then
					break
				end
				if res and res.retry then
					task.wait(0.3 * retry)
				else
					break
				end
			end
			if ctx.cancelled then
				return nil
			end
			if not (res and res.ok) then
				local why = res and res.reason or "no response"
				if res and res.expected then
					why = "out of sync"
				end
				self.hud:toast("Server didn't accept that step (" .. why .. "). Try again!", K.red, 3)
				if self.dish then
					for _, c in self.dish:GetChildren() do
						if not before[c] then
							c:Destroy()
						end
					end
				end
				self.fill, self.stackTop = fillBefore, topBefore
				if res and (res.expired or res.reason == "No active dish" or res.reason == "Stale session" or res.expected) then
					return { aborted = true, reason = why }
				end
			end
		until (res and res.ok) or attempts >= 3
		if not (res and res.ok) then
			return { aborted = true, reason = "step rejected" }
		end
		qualities[i] = res.quality
		viewers = math.max(40, math.floor(viewers * (0.85 + res.quality * 0.6) + res.quality * 260 - 60))
		local col = res.quality >= 0.85 and K.mint or (res.quality >= 0.55 and K.gold or K.orange)
		-- coach card: what went well / what to try next time, in real-kitchen terms
		local good, improve = Coach.feedback(step, res.quality, res.label, res.details)
		self.hud:showCoach(string.format("%s  ·  %d%%", res.label, math.floor(res.quality * 100 + 0.5)), good, improve, col)
		if callbacks.onResult then
			callbacks.onResult(i, res)
		end
		if res.finished then
			final = res
			if callbacks.onFinished then
				callbacks.onFinished(res)
			end
		end
		ctx:wait(0.5)
	end
	self.hud:setSteps(#recipe.steps, #recipe.steps + 1, qualities)
	ctx.finished = true
	self.lastViewers = viewers
	if final then
		self.hud:setInstruction("🛎", "Order up!", "Let's see how it compares to the video...")
		if self.hud.coach then
			self.hud.coach.Visible = false
		end
		self.hud:hideLesson()
		self:serve(ctx, final.score >= 60)
	end
	return final
end

function Kitchen:cancel()
	Dish.meshAllowed = false
	if self.ctx then
		self.ctx.cancelled = true
		self.ctx:clearStep()
	end
	self:clearHandlers()
	self.sfx.stopAllLoops(true)
	self.hud:setCooking(false)
	self:teardownScene()
	self:setFocus("Overview")
end

function Kitchen:finishRun()
	Dish.meshAllowed = false
	self:clearHandlers()
	self.sfx.stopAllLoops(true)
	self.hud:setCooking(false)
end

return Kitchen
