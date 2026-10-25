-- Cook the Trend: the real recipe card. Ingredients + quantities, numbered real-life steps, the expected
-- result of each step, and (recap mode) what you did well / what to try next time. "Make This" starts cooking.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("CTT")
local Recipes = require(Shared.Recipes)
local Coach = require(Shared.Coach)
local Dish = require(Shared.Dish)
local UI = require(script.Parent.UI)

local K = UI.Colors

local Sheet = {}
Sheet.__index = Sheet

local StepIcons = { pick = "🧺", chop = "🔪", heat = "🔥", pour = "🥣", place = "✨", stack = "🍔" }

function Sheet.new(root: Frame, deps)
	local self = setmetatable({}, Sheet)
	self.deps = deps
	local overlay = UI.new("TextButton", {
		Name = "RecipeSheet",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.4,
		Size = UDim2.new(0.72, 0, 1, 0),
		Position = UDim2.new(0.28, 0, 0, 0),
		Visible = false,
		ZIndex = 50,
		Parent = root,
	})
	self.overlay = overlay
	local card = UI.new("Frame", {
		BackgroundColor3 = K.cream,
		Size = UDim2.new(0, 900, 0, 640),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		ZIndex = 51,
		Parent = overlay,
	}, { UI.corner(28), UI.stroke(K.ink, 4) })
	self.card = card
	self.scale = UI.new("UIScale", { Parent = card })

	-- header band
	local head = UI.new("Frame", {
		BackgroundColor3 = K.pink,
		Size = UDim2.new(1, 0, 0, 96),
		ZIndex = 52,
		Parent = card,
	}, { UI.corner(28), UI.pad(12, 24) })
	self.head = head
	self.headGrad = UI.new("UIGradient", { Rotation = 0, Parent = head })
	self.kicker = UI.label({
		Text = "📖 REAL RECIPE",
		Font = UI.Font,
		TextSize = 18,
		TextColor3 = Color3.fromRGB(255, 240, 245),
		Size = UDim2.new(1, 0, 0, 20),
		ZIndex = 53,
		Parent = head,
	})
	self.titleL = UI.label({
		Text = "",
		Font = UI.Font,
		TextSize = 36,
		TextColor3 = K.paper,
		Size = UDim2.new(1, -60, 0, 40),
		Position = UDim2.new(0, 0, 0, 20),
		TextWrapped = false,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 53,
		Parent = head,
	})
	UI.textStroke(Color3.fromRGB(120, 30, 70), 2).Parent = self.titleL
	self.metaL = UI.label({
		Text = "",
		TextSize = 18,
		TextColor3 = K.paper,
		Size = UDim2.new(1, -60, 0, 22),
		Position = UDim2.new(0, 0, 0, 60),
		ZIndex = 53,
		Parent = head,
	})
	UI.button({ Text = "❌", Size = UDim2.new(0, 48, 0, 48), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 8, 0, 6), Color = Color3.fromRGB(255, 255, 255), TextColor = K.ink, TextSize = 22, Corner = 24, ZIndex = 54, Parent = head }, function()
		self:hide()
	end, deps.Sfx)

	-- left: summary + ingredients
	local left = UI.new("Frame", {
		BackgroundColor3 = Color3.fromRGB(255, 240, 228),
		Size = UDim2.new(0, 300, 1, -196),
		Position = UDim2.new(0, 20, 0, 110),
		ZIndex = 52,
		Parent = card,
	}, { UI.corner(20), UI.pad(14, 16) })
	self.summaryL = UI.label({
		Text = "",
		TextSize = 17,
		Size = UDim2.new(1, 0, 0, 88),
		TextYAlignment = Enum.TextYAlignment.Top,
		ZIndex = 53,
		Parent = left,
	})
	UI.label({
		Text = "INGREDIENTS",
		Font = UI.Font,
		TextSize = 20,
		TextColor3 = K.pink,
		Size = UDim2.new(1, 0, 0, 24),
		Position = UDim2.new(0, 0, 0, 92),
		ZIndex = 53,
		Parent = left,
	})
	self.ingList = UI.new("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 1, -122),
		Position = UDim2.new(0, 0, 0, 122),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ScrollBarThickness = 4,
		ZIndex = 53,
		Parent = left,
	}, { UI.list(nil, 6) })

	-- right: steps
	UI.label({
		Text = "STEP BY STEP",
		Font = UI.Font,
		TextSize = 20,
		TextColor3 = K.pink,
		Size = UDim2.new(0, 300, 0, 24),
		Position = UDim2.new(0, 340, 0, 110),
		ZIndex = 53,
		Parent = card,
	})
	self.stepList = UI.new("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, -360, 1, -230),
		Position = UDim2.new(0, 340, 0, 140),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ScrollBarThickness = 5,
		ScrollBarImageColor3 = K.pink,
		ZIndex = 53,
		Parent = card,
	}, { UI.list(nil, 10), UI.pad(2, 10, 10, 2) })

	-- bottom actions
	local actions = UI.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -40, 0, 64),
		Position = UDim2.new(0, 20, 1, -78),
		ZIndex = 52,
		Parent = card,
	}, { UI.list(Enum.FillDirection.Horizontal, 14, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Center) })
	-- future hook: real-life photo upload + AI feedback (not live yet)
	self.photoBtn = UI.button({ Text = "📸 Cooked it IRL? (soon)", Size = UDim2.new(0, 280, 0, 56), Color = Color3.fromRGB(150, 140, 160), TextSize = 21, ZIndex = 53, LayoutOrder = 1, Parent = actions }, function()
		deps.toast("Photo check-ins + AI plating tips are coming soon!", K.sky)
	end, deps.Sfx)
	self.makeBtn = UI.button({ Text = "MAKE THIS  ▶", Size = UDim2.new(0, 260, 0, 60), Color = K.mint, TextSize = 28, ZIndex = 53, LayoutOrder = 2, Parent = actions }, function()
		local id = self.recipeId
		self:hide()
		if id then
			deps.onMake(id)
		end
	end, deps.Sfx)
	return self
end

local function chipRow(parent, text, color, order)
	local l = UI.label({
		Text = text,
		TextSize = 16,
		TextColor3 = K.ink,
		BackgroundColor3 = color,
		BackgroundTransparency = 0,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, 0, 0, 20),
		RichText = true,
		LayoutOrder = order,
		ZIndex = 55,
		Parent = parent,
	})
	UI.corner(10).Parent = l
	UI.pad(5, 10).Parent = l
	return l
end

-- mode: "preview" (before cooking) | "recap" (after results; res = final result with steps)
function Sheet:show(recipeId: string, mode: string?, res)
	local def = Recipes.Defs[recipeId]
	if not def then
		return
	end
	self.recipeId = recipeId
	self.overlay.Visible = true
	local area = self.overlay.AbsoluteSize / (self.deps.getScale and self.deps.getScale() or 1)
	local s = math.min(1, (area.X - 30) / 900, (area.Y - 24) / 640)
	self.scale.Scale = s * 0.85
	UI.tween(self.scale, 0.25, { Scale = s }, Enum.EasingStyle.Back)
	self.head.BackgroundColor3 = def.accent
	self.headGrad.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(230, 220, 230))
	self.kicker.Text = mode == "recap" and "📖 YOUR RECIPE CARD · TAKE IT TO YOUR KITCHEN" or "📖 REAL RECIPE · " .. def.creator
	self.titleL.Text = def.name
	self.metaL.Text = string.format("🍽 %s   ⏲ %s   %s", def.servings or "1 serving", def.realTime or (def.duration .. " s"), string.rep("★", def.difficulty) .. string.rep("☆", 3 - def.difficulty))
	self.summaryL.Text = def.summary or def.caption
	for _, c in self.ingList:GetChildren() do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	for i, ing in def.ingredients or {} do
		local row = UI.new("Frame", {
			BackgroundColor3 = K.paper,
			Size = UDim2.new(1, -6, 0, 40),
			LayoutOrder = i,
			ZIndex = 54,
			Parent = self.ingList,
		}, { UI.corner(12) })
		UI.label({ Text = ing.icon, TextSize = 22, Font = UI.Font, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.new(0, 36, 1, 0), ZIndex = 55, Parent = row })
		UI.label({ Text = ing.name, TextSize = 16, Size = UDim2.new(1, -40, 0, 20), Position = UDim2.new(0, 38, 0, 2), TextWrapped = false, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 55, Parent = row })
		UI.label({ Text = ing.qty, TextSize = 14, TextColor3 = Color3.fromRGB(150, 90, 110), Size = UDim2.new(1, -40, 0, 18), Position = UDim2.new(0, 38, 0, 20), TextWrapped = false, ZIndex = 55, Parent = row })
	end
	for _, c in self.stepList:GetChildren() do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	for i, step in def.steps do
		local learn = step.learn or {}
		local box = UI.new("Frame", {
			BackgroundColor3 = K.paper,
			Size = UDim2.new(1, 0, 0, 40),
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = i,
			ZIndex = 54,
			Parent = self.stepList,
		}, { UI.corner(16), UI.stroke(Color3.fromRGB(240, 220, 210), 2), UI.pad(10, 12, 12, 56), UI.list(nil, 5) })
		local num = UI.label({
			Text = tostring(i),
			Font = UI.Font,
			TextSize = 22,
			TextColor3 = K.paper,
			BackgroundColor3 = def.accent,
			BackgroundTransparency = 0,
			TextXAlignment = Enum.TextXAlignment.Center,
			Size = UDim2.new(0, 36, 0, 36),
			Position = UDim2.new(0, -46, 0, 0),
			ZIndex = 55,
			Parent = box,
		})
		UI.cornerScale(0.5).Parent = num
		-- the number circle must not be laid out by the list
		local holder = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 26), LayoutOrder = 0, ZIndex = 54, Parent = box })
		num.Parent = holder
		UI.label({
			Text = (StepIcons[step.type] or "") .. "  " .. step.title,
			Font = UI.Font,
			TextSize = 21,
			Size = UDim2.new(1, 0, 0, 26),
			ZIndex = 55,
			Parent = holder,
		})
		UI.label({
			Text = learn.tip or step.instruction,
			TextSize = 16,
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, 0, 0, 18),
			LayoutOrder = 1,
			ZIndex = 55,
			Parent = box,
		})
		-- visual "expected result" thumbnail (static 3D render of the food after this step)
		local okVp, vpErr = pcall(function()
			local vp = UI.new("ViewportFrame", {
				BackgroundColor3 = Color3.fromRGB(255, 244, 236),
				Size = UDim2.new(0, 230, 0, 124),
				Ambient = Color3.fromRGB(200, 185, 175),
				LightColor = Color3.fromRGB(255, 240, 220),
				LightDirection = Vector3.new(-0.5, -1, -0.6),
				LayoutOrder = 2,
				ZIndex = 55,
				Parent = box,
			}, { UI.corner(12) })
			local cam = Instance.new("Camera")
			cam.FieldOfView = 30
			cam.Parent = vp
			vp.CurrentCamera = cam
			local model = Dish.stepPreview(recipeId, i)
			model.Parent = vp
			local cf, size = model:GetBoundingBox()
			local dist = math.max(size.X, size.Z * 0.8, size.Y * 1.3) * 1.25 + 0.6
			local target = cf.Position
			cam.CFrame = CFrame.lookAt(target + Vector3.new(0, dist * 0.62, dist * 0.8), target)
		end)
		if not okVp then
			warn("[CTT] step preview failed", vpErr)
		end
		if learn.expected then
			chipRow(box, "<b>Looks like:</b> " .. learn.expected, Color3.fromRGB(226, 246, 236), 3)
		end
		if learn.why and mode ~= "recap" then
			chipRow(box, "<b>Why:</b> " .. learn.why, Color3.fromRGB(255, 244, 214), 4)
		end
		if mode == "recap" and res and res.steps and res.steps[i] then
			local r = res.steps[i]
			local good, improve = Coach.feedback(step, r.quality or 0, r.label, r.details)
			local pct = math.floor((r.quality or 0) * 100 + 0.5)
			chipRow(box, string.format("<b>You:</b> %s (%d%%)", r.label or "", pct), Color3.fromRGB(235, 236, 255), 5)
			if good then
				chipRow(box, "✓ " .. good, Color3.fromRGB(214, 244, 226), 6)
			end
			if improve then
				chipRow(box, "💡 <b>Next time:</b> " .. improve, Color3.fromRGB(255, 230, 220), 7)
			end
		end
	end
	self.stepList.CanvasPosition = Vector2.zero
	self.makeBtn.Text = mode == "recap" and "COOK IT AGAIN  ▶" or "MAKE THIS  ▶"
end

function Sheet:hide()
	self.overlay.Visible = false
end

function Sheet:isOpen()
	return self.overlay.Visible
end

return Sheet
