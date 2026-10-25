-- Cook the Trend: kitchen-side HUD (instruction pill, step progress, gauges, action button, toasts).
local UI = require(script.Parent.UI)

local Hud = {}
Hud.__index = Hud

local K = UI.Colors

function Hud.new(root: Frame, deps)
	local self = setmetatable({}, Hud)
	self.deps = deps
	local area = UI.new("Frame", {
		Name = "KitchenHud",
		BackgroundTransparency = 1,
		Size = UDim2.new(0.72, 0, 1, 0),
		Position = UDim2.new(0.28, 0, 0, 0),
		Parent = root,
	})
	self.area = area

	-- input catcher (under everything else in the kitchen area)
	self.input = UI.new("TextButton", {
		Name = "KitchenInput",
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 0,
		Parent = area,
	})

	-- top instruction block
	local top = UI.new("Frame", {
		Name = "Top",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -40, 0, 150),
		Position = UDim2.new(0, 20, 0, 14),
		Visible = false,
		Parent = area,
	})
	self.top = top
	self.dots = UI.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 22),
		Parent = top,
	}, { UI.list(Enum.FillDirection.Horizontal, 6, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center) })
	local pill = UI.new("Frame", {
		BackgroundColor3 = K.paper,
		Size = UDim2.new(0, 640, 0, 92),
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 30),
		Parent = top,
	}, { UI.corner(24), UI.stroke(K.ink, 3), UI.new("UISizeConstraint", { MaxSize = Vector2.new(760, 200) }) })
	self.pill = pill
	self.pillScale = UI.new("UIScale", { Parent = pill })
	self.toolIcon = UI.label({
		Text = "🔪",
		Font = UI.Font,
		TextSize = 44,
		Size = UDim2.new(0, 72, 1, 0),
		Position = UDim2.new(0, 8, 0, 0),
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = pill,
	})
	self.title = UI.label({
		Text = "",
		Font = UI.Font,
		TextSize = 36,
		TextColor3 = K.pink,
		Size = UDim2.new(1, -96, 0, 38),
		Position = UDim2.new(0, 84, 0, 8),
		Parent = pill,
	})
	self.instruction = UI.label({
		Text = "",
		TextSize = 26,
		TextColor3 = K.ink,
		Size = UDim2.new(1, -96, 0, 40),
		Position = UDim2.new(0, 84, 0, 46),
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = pill,
	})

	-- "you're filming this" pill: REC timer + live viewers
	local rec = UI.new("Frame", {
		Name = "Rec",
		BackgroundColor3 = Color3.fromRGB(20, 16, 26),
		BackgroundTransparency = 0.2,
		Size = UDim2.new(0, 176, 0, 66),
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 16, 1, -16),
		Visible = false,
		Parent = area,
	}, { UI.corner(16), UI.pad(6, 12) })
	self.rec = rec
	self.recDot = UI.new("Frame", {
		BackgroundColor3 = K.red,
		Size = UDim2.new(0, 14, 0, 14),
		Position = UDim2.new(0, 0, 0, 7),
		Parent = rec,
	}, { UI.cornerScale(0.5) })
	self.recTime = UI.label({
		Text = "REC 00:00",
		Font = UI.Font,
		TextSize = 22,
		TextColor3 = K.paper,
		Size = UDim2.new(1, -22, 0, 26),
		Position = UDim2.new(0, 22, 0, 0),
		Parent = rec,
	})
	self.viewers = UI.label({
		Text = "👀 120 watching",
		Font = UI.Font,
		TextSize = 18,
		TextColor3 = Color3.fromRGB(255, 210, 120),
		Size = UDim2.new(1, 0, 0, 24),
		Position = UDim2.new(0, 0, 0, 28),
		Parent = rec,
	})

	-- corner controls
	local ctrl = UI.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(0, 120, 0, 54),
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -16, 1, -16),
		Visible = false,
		Parent = area,
	}, { UI.list(Enum.FillDirection.Horizontal, 10, Enum.HorizontalAlignment.Right) })
	self.ctrl = ctrl
	self.restartBtn = UI.button({ Text = "🔄", Size = UDim2.new(0, 54, 0, 54), Color = K.sky, TextSize = 30, Parent = ctrl }, function()
		deps.onRestart()
	end, deps.Sfx)
	self.quitBtn = UI.button({ Text = "❌", Size = UDim2.new(0, 54, 0, 54), Color = Color3.fromRGB(120, 110, 130), TextSize = 28, Parent = ctrl }, function()
		deps.onQuit()
	end, deps.Sfx)
	self.ctrlHint = UI.label({
		Text = "",
		TextSize = 16,
		TextColor3 = K.paper,
		TextXAlignment = Enum.TextXAlignment.Right,
		Size = UDim2.new(0, 360, 0, 22),
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -16, 1, -76),
		Parent = area,
	})
	UI.textStroke(K.ink, 2).Parent = self.ctrlHint

	-- action button
	self.action = UI.button({
		Name = "Action",
		Text = "CHOP!",
		Size = UDim2.new(0, 300, 0, 84),
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -22),
		Color = K.pink,
		TextSize = 40,
		Corner = 26,
		Stroke = 4,
		Parent = area,
	})
	self.action.Visible = false
	self.actionScale = self.action:FindFirstChildOfClass("UIScale")

	-- heat gauge (horizontal)
	local gauge = UI.new("Frame", {
		Name = "Gauge",
		BackgroundColor3 = K.paper,
		Size = UDim2.new(0, 560, 0, 46),
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -128),
		Visible = false,
		Parent = area,
	}, { UI.corner(23), UI.stroke(K.ink, 3) })
	self.gauge = gauge
	local inner = UI.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -16, 1, -16),
		Position = UDim2.new(0, 8, 0, 8),
		ClipsDescendants = true,
		Parent = gauge,
	}, { UI.corner(15) })
	self.gaugeInner = inner
	self.gaugeZones = {}
	self.gaugeMarker = UI.new("Frame", {
		BackgroundColor3 = K.ink,
		Size = UDim2.new(0, 8, 1, 22),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0, 0, 0.5, 0),
		ZIndex = 3,
		Parent = gauge,
	}, { UI.corner(4), UI.stroke(K.paper, 2) })
	self.gaugeLabel = UI.label({
		Text = "",
		Font = UI.Font,
		TextSize = 26,
		TextColor3 = K.paper,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 30),
		Position = UDim2.new(0, 0, 0, -38),
		Parent = gauge,
	})
	UI.textStroke(K.ink, 3).Parent = self.gaugeLabel

	-- vertical fill gauge (pour)
	local fill = UI.new("Frame", {
		Name = "Fill",
		BackgroundColor3 = K.paper,
		Size = UDim2.new(0, 54, 0, 300),
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -30, 0.55, 0),
		Visible = false,
		Parent = area,
	}, { UI.corner(27), UI.stroke(K.ink, 3) })
	self.fillGauge = fill
	local fillInner = UI.new("Frame", {
		BackgroundColor3 = Color3.fromRGB(240, 232, 225),
		Size = UDim2.new(1, -16, 1, -16),
		Position = UDim2.new(0, 8, 0, 8),
		ClipsDescendants = true,
		Parent = fill,
	}, { UI.corner(19) })
	self.fillBar = UI.new("Frame", {
		BackgroundColor3 = K.orange,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, 0),
		Size = UDim2.new(1, 0, 0, 0),
		Parent = fillInner,
	})
	self.fillTarget = UI.new("Frame", {
		BackgroundColor3 = K.gold,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.new(1, 22, 0, 8),
		Position = UDim2.new(0.5, 0, 0.3, 0),
		ZIndex = 3,
		Parent = fill,
	}, { UI.corner(4), UI.stroke(K.ink, 2) })

	-- checklist (pick)
	self.checklist = UI.new("Frame", {
		Name = "Checklist",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -40, 0, 48),
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 166),
		Visible = false,
		Parent = area,
	}, { UI.list(Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Center) })

	-- popup layer
	self.popLayer = UI.new("Frame", {
		Name = "Pops",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 20,
		Parent = area,
	})

	-- idle prompt
	self.idle = UI.new("Frame", {
		Name = "Idle",
		BackgroundColor3 = K.paper,
		Size = UDim2.new(0, 560, 0, 120),
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -24),
		Parent = area,
	}, { UI.corner(26), UI.stroke(K.ink, 3), UI.pad(12, 20) })
	UI.label({
		Text = "👈  Pick a trend from your feed",
		Font = UI.Font,
		TextSize = 34,
		TextColor3 = K.pink,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 44),
		Parent = self.idle,
	})
	UI.label({
		Text = "Watch the technique, then make it yourself. Every step teaches a real kitchen skill.",
		TextSize = 21,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 52),
		Position = UDim2.new(0, 0, 0, 48),
		Parent = self.idle,
	})
	self.idleScale = UI.new("UIScale", { Parent = self.idle })

	-- toast
	self.toastLabel = UI.label({
		Text = "",
		Font = UI.Font,
		TextSize = 24,
		TextColor3 = K.paper,
		BackgroundColor3 = K.ink,
		BackgroundTransparency = 0.1,
		TextXAlignment = Enum.TextXAlignment.Center,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.new(0, 0, 0, 50),
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -130),
		Visible = false,
		ZIndex = 30,
		Parent = area,
	})
	UI.corner(25).Parent = self.toastLabel
	UI.pad(0, 24).Parent = self.toastLabel
	self.toastId = 0
	return self
end

-- phones: smaller pill/button footprint, REC moves to the bottom-left
function Hud:setCompact(on: boolean)
	if self.compact == on then
		return
	end
	self.compact = on
	self.pill.Size = on and UDim2.new(0, 560, 0, 70) or UDim2.new(0, 640, 0, 92)
	self.pill.Position = UDim2.new(0.5, 0, 0, on and 24 or 30)
	self.title.TextSize = on and 26 or 32
	self.title.Position = UDim2.new(0, 70, 0, on and 4 or 8)
	self.title.Size = UDim2.new(1, -80, 0, on and 30 or 38)
	self.instruction.TextSize = on and 18 or 22
	self.instruction.Position = UDim2.new(0, 70, 0, on and 34 or 46)
	self.toolIcon.TextSize = on and 34 or 44
	self.toolIcon.Size = UDim2.new(0, on and 60 or 72, 1, 0)
	self.action.Size = on and UDim2.new(0, 230, 0, 64) or UDim2.new(0, 300, 0, 84)
	self.action.TextSize = on and 32 or 40
	self.action.Position = UDim2.new(0.5, 0, 1, on and -12 or -22)
	self.rec.Position = on and UDim2.new(0, 12, 1, -12) or UDim2.new(0, 16, 1, -16)
	-- phones: checklist sits at the bottom so it never covers the ingredient tray
	self.checklist.AnchorPoint = on and Vector2.new(0.5, 1) or Vector2.new(0.5, 0)
	self.checklist.Position = on and UDim2.new(0.5, 0, 1, -14) or UDim2.new(0.5, 0, 0, 166)
	if self.tipChip then
		self.tipChip.Position = UDim2.new(0.5, 0, 0, on and 98 or 128)
	end
	self.gauge.Position = UDim2.new(0.5, 0, 1, on and -88 or -128)
	self.gauge.Size = on and UDim2.new(0, 480, 0, 40) or UDim2.new(0, 560, 0, 46)
	self.idle.Size = on and UDim2.new(0, 500, 0, 104) or UDim2.new(0, 560, 0, 120)
end

function Hud:setIdle(on: boolean)
	self.idle.Visible = on
	if on then
		self.idleScale.Scale = 0.6
		UI.tween(self.idleScale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
	end
end

function Hud:setRec(seconds: number, viewers: number?)
	self.rec.Visible = false -- simplified HUD: no REC pill
	do
		return
	end
	self.recTime.Text = string.format("REC %02d:%02d", math.floor(seconds / 60), math.floor(seconds % 60))
	self.recDot.BackgroundTransparency = (math.floor(seconds * 2) % 2 == 0) and 0 or 0.7
	if viewers then
		self.viewers.Text = "👀 " .. UI.formatCount(viewers) .. " watching"
	end
end

function Hud:setCooking(on: boolean)
	self.top.Visible = on
	self.ctrl.Visible = on
	self.rec.Visible = false
	if not on then
		self:hideLesson()
		if self.coach then
			self.coach.Visible = false
		end
		self.action.Visible = false
		self.gauge.Visible = false
		self.fillGauge.Visible = false
		self.checklist.Visible = false
		self.ctrlHint.Text = ""
	end
end

function Hud:setSteps(total: number, current: number, results)
	for _, c in self.dots:GetChildren() do
		if c:IsA("Frame") then
			c:Destroy()
		end
	end
	for i = 1, total do
		local done = i < current
		local cur = i == current
		local q = results and results[i]
		local col = K.paper
		if done then
			col = q and (q >= 0.8 and K.mint or (q >= 0.5 and K.gold or K.orange)) or K.mint
		elseif cur then
			col = K.pink
		end
		UI.new("Frame", {
			BackgroundColor3 = col,
			BackgroundTransparency = (done or cur) and 0 or 0.4,
			Size = UDim2.new(0, cur and 44 or 22, 0, 16),
			LayoutOrder = i,
			Parent = self.dots,
		}, { UI.corner(8), UI.stroke(K.ink, 2) })
	end
end

function Hud:setInstruction(icon: string, title: string, text: string)
	self.toolIcon.Text = icon
	self.title.Text = title
	self.instruction.Text = text
	self.pillScale.Scale = 0.85
	UI.tween(self.pillScale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
end

function Hud:setAction(text: string?, color: Color3?)
	if not text then
		self.action.Visible = false
		return
	end
	self.action.Visible = true
	self.action.Text = text
	self.action.BackgroundColor3 = color or K.pink
end

function Hud:punchAction()
	if self.actionScale then
		self.actionScale.Scale = 0.88
		UI.tween(self.actionScale, 0.2, { Scale = 1 }, Enum.EasingStyle.Back)
	end
end

-- zones: { {from, to, color, label} } over a 0..maxV range
function Hud:showGauge(zones, maxV: number)
	self.gauge.Visible = true
	for _, z in self.gaugeZones do
		z:Destroy()
	end
	self.gaugeZones = {}
	for _, z in zones do
		local f = UI.new("Frame", {
			BackgroundColor3 = z[3],
			BorderSizePixel = 0,
			Size = UDim2.new((z[2] - z[1]) / maxV, 0, 1, 0),
			Position = UDim2.new(z[1] / maxV, 0, 0, 0),
			Parent = self.gaugeInner,
		})
		if z[4] then
			local l = UI.label({
				Text = z[4],
				Font = UI.Font,
				TextSize = 16,
				TextColor3 = K.paper,
				TextXAlignment = Enum.TextXAlignment.Center,
				Size = UDim2.fromScale(1, 1),
				Parent = f,
			})
			UI.textStroke(K.ink, 1.5).Parent = l
		end
		table.insert(self.gaugeZones, f)
	end
	self.gaugeMax = maxV
end

function Hud:setGauge(v: number, label: string?)
	local x = math.clamp(v / (self.gaugeMax or 1), 0, 1)
	self.gaugeMarker.Position = UDim2.new(0, 8 + x * (self.gauge.AbsoluteSize.X / self:scale() - 16), 0.5, 0)
	if label then
		self.gaugeLabel.Text = label
	end
end

function Hud:scale(): number
	return self.deps.getScale and self.deps.getScale() or 1
end

function Hud:hideGauge()
	self.gauge.Visible = false
end

function Hud:showFill(target: number, color: Color3)
	self.fillGauge.Visible = true
	self.fillBar.BackgroundColor3 = color
	self.fillBar.Size = UDim2.new(1, 0, 0, 0)
	self.fillTarget.Position = UDim2.new(0.5, 0, 1 - (8 + target * (300 - 16)) / 300, 0)
end

function Hud:setFill(v: number)
	self.fillBar.Size = UDim2.new(1, 0, math.clamp(v, 0, 1.05), 0)
	self.fillBar.BackgroundColor3 = v > 1 and K.red or self.fillBar.BackgroundColor3
end

function Hud:hideFill()
	self.fillGauge.Visible = false
end

function Hud:setChecklist(items)
	for _, c in self.checklist:GetChildren() do
		if c:IsA("TextLabel") then
			c:Destroy()
		end
	end
	if not items then
		self.checklist.Visible = false
		return
	end
	self.checklist.Visible = true
	for i, it in items do
		local text = (it.done and "✓ " or "• ") .. it.text
		local w = game:GetService("TextService"):GetTextSize(text, 21, UI.Font, Vector2.new(1000, 40)).X + 34
		local l = UI.label({
			Text = text,
			Font = UI.Font,
			TextSize = 21,
			TextColor3 = K.ink,
			BackgroundColor3 = it.done and K.mint or K.paper,
			BackgroundTransparency = 0,
			TextWrapped = false,
			Size = UDim2.new(0, w, 0, 40),
			TextXAlignment = Enum.TextXAlignment.Center,
			LayoutOrder = i,
			Parent = self.checklist,
		})
		UI.corner(20).Parent = l
		UI.stroke(K.ink, 2).Parent = l
		UI.pad(0, 14).Parent = l
	end
end

function Hud:pop(text: string, color: Color3, screenPos: Vector2?, size: number?)
	local pos
	if screenPos then
		local abs = self.area.AbsolutePosition
		local s = self:scale()
		pos = UDim2.fromOffset((screenPos.X - abs.X) / s, (screenPos.Y - abs.Y) / s)
	else
		pos = UDim2.new(0.5, 0, 0.42, 0)
	end
	return UI.popText(self.popLayer, text, color, pos, size)
end

-- Lesson panel: "watch the technique" (big) -> compact tip chip while the player does it.
function Hud:_ensureLesson()
	if self.lesson then
		return
	end
	local K2 = K
	local f = UI.new("Frame", {
		Name = "Lesson",
		BackgroundColor3 = Color3.fromRGB(32, 26, 44),
		BackgroundTransparency = 0.08,
		Size = UDim2.new(0, 640, 0, 118),
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -20),
		Visible = false,
		ZIndex = 12,
		Parent = self.area,
	}, { UI.corner(20), UI.stroke(K2.gold, 2, 0.2), UI.pad(10, 16) })
	self.lesson = f
	self.lessonKicker = UI.label({ Text = "👀 WATCH, THEN YOUR TURN", Font = UI.Font, TextSize = 20, TextColor3 = K2.gold, Size = UDim2.new(1, -180, 0, 24), ZIndex = 13, Parent = f })
	self.lessonTip = UI.label({ Text = "", TextSize = 24, TextColor3 = K2.paper, Size = UDim2.new(1, -180, 0, 66), Position = UDim2.new(0, 0, 0, 28), TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 13, Parent = f })
	self.myTurn = UI.button({ Text = "MY TURN ▶", Size = UDim2.new(0, 166, 0, 64), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Color = K2.mint, TextSize = 24, ZIndex = 14, Parent = f }, function()
		if self.onMyTurn then
			self.onMyTurn()
		end
	end, self.deps.Sfx)
	self.lessonScale = UI.new("UIScale", { Parent = f })
	-- compact chip (during the interaction)
	self.tipChip = UI.label({
		Name = "TipChip",
		Text = "",
		TextSize = 16,
		TextColor3 = K2.paper,
		BackgroundColor3 = Color3.fromRGB(32, 26, 44),
		BackgroundTransparency = 0.2,
		Size = UDim2.new(0, 600, 0, 30),
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 128),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextWrapped = false,
		Visible = false,
		ZIndex = 12,
		Parent = self.area,
	})
	UI.corner(15).Parent = self.tipChip
	UI.pad(0, 12).Parent = self.tipChip
	-- coach feedback card
	local fb = UI.new("Frame", {
		Name = "Coach",
		BackgroundColor3 = K2.paper,
		Size = UDim2.new(0, 330, 0, 110),
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 14, 0.45, 0),
		Visible = false,
		ZIndex = 26,
		Parent = self.area,
	}, { UI.corner(18), UI.stroke(K2.ink, 3), UI.pad(8, 14) })
	self.coach = fb
	self.coachTitle = UI.label({ Text = "", Font = UI.Font, TextSize = 24, Size = UDim2.new(1, 0, 0, 28), ZIndex = 27, Parent = fb })
	self.coachText = UI.label({ Text = "", RichText = true, TextSize = 19, Size = UDim2.new(1, 0, 0, 62), Position = UDim2.new(0, 0, 0, 30), TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 27, Parent = fb })
	self.coachScale = UI.new("UIScale", { Parent = fb })
end

function Hud:showLesson(tip: string, expected: string?, why: string?)
	self:_ensureLesson()
	self.tipChip.Visible = false
	self.lesson.Visible = true
	self.lesson.Position = UDim2.new(0.5, 0, 1, self.compact and -6 or -20)
	self.action.Visible = false
	self.recHidden = self.compact -- phones: give the lesson the bottom of the screen
	if self.compact then
		self.rec.Visible = false
	end
	-- one short tip only (the full why/looks-like lives on the recipe card)
	local short = string.match(tip, "^(.-[%.!])%s") or tip
	self.lessonTip.Text = short
	self.lessonScale.Scale = 0.8
	UI.tween(self.lessonScale, 0.25, { Scale = self.compact and 0.82 or 1 }, Enum.EasingStyle.Back)
end

function Hud:compactLesson(tip: string?)
	self:_ensureLesson()
	self.lesson.Visible = false
	self.recHidden = false
	if self.top.Visible then
		self.rec.Visible = true
	end
	self.onMyTurn = nil
end

function Hud:hideLesson()
	if self.lesson then
		self.lesson.Visible = false
		self.tipChip.Visible = false
	end
	self.onMyTurn = nil
end

function Hud:showCoach(title: string, good: string?, improve: string?, color: Color3?)
	self:_ensureLesson()
	-- one line: the fix if there is one, otherwise the praise
	local lines = {}
	if improve then
		table.insert(lines, "💡 " .. improve)
	elseif good then
		table.insert(lines, "✓ " .. good)
	end
	self.coachTitle.Text = title
	self.coachTitle.TextColor3 = color or K.ink
	self.coachText.Text = table.concat(lines, "\n")
	self.coach.Visible = true
	self.coachScale.Scale = 0.7
	UI.tween(self.coachScale, 0.25, { Scale = self.compact and 0.8 or 1 }, Enum.EasingStyle.Back)
	self.coachId = (self.coachId or 0) + 1
	local id = self.coachId
	task.delay(2.6, function()
		if self.coachId == id then
			self.coach.Visible = false
		end
	end)
end

-- Cut track: a rhythm-style bar above the CHOP button. Ticks = cut lines, moving marker = knife.
local TRACK_W = 560
function Hud:showCutTrack(guides, window: number)
	self:hideCutTrack()
	local bar = UI.new("Frame", {
		Name = "CutTrack",
		BackgroundColor3 = Color3.fromRGB(32, 26, 44),
		BackgroundTransparency = 0.1,
		Size = UDim2.new(0, TRACK_W, 0, 40),
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, self.compact and -84 or -120),
		ZIndex = 15,
		Parent = self.area,
	}, { UI.corner(20), UI.stroke(K.paper, 2, 0.4) })
	self.cutTrack = bar
	local inner = TRACK_W - 40
	local function xpos(v)
		-- knife travels -1.15..1.15; map that span onto the bar
		return 20 + (v + 1.15) / 2.3 * inner
	end
	self.cutTrackX = xpos
	self.cutTicks = {}
	for gi, g in guides do
		local w = math.max(8, window * 2 / 2.3 * inner)
		local tick = UI.new("Frame", {
			BackgroundColor3 = K.paper,
			Size = UDim2.new(0, w, 0, 26),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0, xpos(g), 0.5, 0),
			ZIndex = 16,
			Parent = bar,
		}, { UI.corner(5) })
		self.cutTicks[gi] = tick
	end
	self.cutMarker = UI.new("Frame", {
		BackgroundColor3 = K.gold,
		Size = UDim2.new(0, 6, 0, 40),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0, xpos(-1.15), 0.5, 0),
		ZIndex = 18,
		Parent = bar,
	}, { UI.corner(3), UI.stroke(K.ink, 2) })
end

function Hud:setCutTrack(x: number, states)
	if not self.cutTrack then
		return
	end
	self.cutMarker.Position = UDim2.new(0, self.cutTrackX(x), 0.5, 0)
	local cols = { todo = Color3.fromRGB(230, 230, 240), next = K.gold, live = Color3.fromRGB(80, 255, 140), hit = K.mint, miss = K.red }
	for gi, tick in self.cutTicks do
		tick.BackgroundColor3 = cols[states[gi]] or K.paper
	end
end

function Hud:hideCutTrack()
	if self.cutTrack then
		self.cutTrack:Destroy()
		self.cutTrack = nil
	end
end

-- big punchy step-intro card ("SLICE!") that zooms in and fades
function Hud:banner(icon: string, text: string, color: Color3?)
	do
		return -- simplified HUD: the lesson panel already introduces each step
	end
	local f = UI.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(0, 600, 0, 120),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.45, 0),
		ZIndex = 25,
		Parent = self.popLayer,
	})
	local l = UI.label({
		Text = icon .. "  " .. text,
		Font = UI.Font,
		TextSize = 72,
		TextColor3 = color or K.paper,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.fromScale(1, 1),
		Rotation = -4,
		ZIndex = 25,
		Parent = f,
	})
	local st = UI.textStroke(K.ink, 5)
	st.Parent = l
	local sc = UI.new("UIScale", { Scale = 2.2, Parent = f })
	UI.tween(sc, 0.22, { Scale = 1 }, Enum.EasingStyle.Back)
	task.delay(0.6, function()
		UI.tween(sc, 0.25, { Scale = 0.6 })
		UI.tween(l, 0.25, { TextTransparency = 1 })
		UI.tween(st, 0.25, { Transparency = 1 })
	end)
	task.delay(0.9, function()
		f:Destroy()
	end)
end

-- "x3 COMBO" streak chip
function Hud:combo(n: number)
	if true then -- simplified HUD: combo is sound-only
		return
	end
	local l = UI.label({
		Text = "x" .. n .. " COMBO!",
		Font = UI.Font,
		TextSize = 40,
		TextColor3 = K.gold,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(0, 300, 0, 50),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.82, 0, 0.32, 0),
		Rotation = 8,
		ZIndex = 24,
		Parent = self.popLayer,
	})
	UI.textStroke(K.ink, 4).Parent = l
	local sc = UI.new("UIScale", { Scale = 0.4, Parent = l })
	UI.tween(sc, 0.2, { Scale = 1 + math.min(n, 6) * 0.06 }, Enum.EasingStyle.Back)
	task.delay(0.7, function()
		UI.tween(l, 0.3, { TextTransparency = 1, Position = UDim2.new(0.82, 0, 0.26, 0) })
	end)
	task.delay(1.1, function()
		l:Destroy()
	end)
end

function Hud:toast(text: string, color: Color3?, dur: number?)
	self.toastId += 1
	local id = self.toastId
	local l = self.toastLabel
	l.Text = text
	l.BackgroundColor3 = color or K.ink
	l.Visible = true
	l.TextTransparency = 0
	l.BackgroundTransparency = 0.05
	task.delay(dur or 2.2, function()
		if self.toastId == id then
			l.Visible = false
		end
	end)
end

return Hud
