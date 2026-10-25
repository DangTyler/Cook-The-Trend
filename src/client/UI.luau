-- Cook the Trend: small UI toolkit + theme.
local TweenService = game:GetService("TweenService")

local UI = {}

local C = Color3.fromRGB
UI.Colors = {
	ink = C(52, 34, 46),
	cream = C(255, 249, 240),
	paper = C(255, 255, 255),
	pink = C(255, 84, 136),
	orange = C(255, 146, 52),
	gold = C(255, 196, 0),
	mint = C(64, 206, 150),
	sky = C(84, 170, 255),
	red = C(238, 72, 72),
	feedBg = C(22, 18, 28),
	feedCard = C(36, 30, 44),
	muted = C(150, 140, 160),
	shadow = C(0, 0, 0),
}
UI.Font = Enum.Font.BuilderSansExtraBold
UI.Body = Enum.Font.BuilderSansBold
UI.Bold = Enum.Font.BuilderSansExtraBold

function UI.new(class: string, props, children)
	local o = Instance.new(class)
	if props then
		for k, v in props do
			if k ~= "Parent" then
				(o :: any)[k] = v
			end
		end
	end
	if children then
		for _, c in children do
			c.Parent = o
		end
	end
	if props and props.Parent then
		o.Parent = props.Parent
	end
	return o
end

function UI.corner(r: number?)
	return UI.new("UICorner", { CornerRadius = UDim.new(0, r or 14) })
end

function UI.cornerScale(s: number)
	return UI.new("UICorner", { CornerRadius = UDim.new(s, 0) })
end

function UI.stroke(color: Color3?, thick: number?, transp: number?)
	return UI.new("UIStroke", {
		Color = color or UI.Colors.ink,
		Thickness = thick or 2,
		Transparency = transp or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

function UI.textStroke(color: Color3?, thick: number?)
	return UI.new("UIStroke", {
		Color = color or UI.Colors.ink,
		Thickness = thick or 2,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
	})
end

function UI.pad(t: number, r: number?, b: number?, l: number?)
	return UI.new("UIPadding", {
		PaddingTop = UDim.new(0, t),
		PaddingRight = UDim.new(0, r or t),
		PaddingBottom = UDim.new(0, b or t),
		PaddingLeft = UDim.new(0, l or r or t),
	})
end

function UI.list(dir, gap: number?, hAlign, vAlign)
	return UI.new("UIListLayout", {
		FillDirection = dir or Enum.FillDirection.Vertical,
		Padding = UDim.new(0, gap or 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = hAlign or Enum.HorizontalAlignment.Left,
		VerticalAlignment = vAlign or Enum.VerticalAlignment.Top,
	})
end

function UI.gradient(c1: Color3, c2: Color3, rot: number?)
	return UI.new("UIGradient", {
		Color = ColorSequence.new(c1, c2),
		Rotation = rot or 90,
	})
end

function UI.label(props)
	local base = {
		BackgroundTransparency = 1,
		Font = UI.Body,
		TextColor3 = UI.Colors.ink,
		TextSize = 20,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, 0, 0, 24),
	}
	for k, v in props do
		base[k] = v
	end
	return UI.new("TextLabel", base)
end

function UI.tween(obj: Instance, t: number, props, style, dir)
	local tw = TweenService:Create(
		obj,
		TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out),
		props
	)
	tw:Play()
	return tw
end

-- Chunky game button with press feedback. onClick(button)
function UI.button(props, onClick, sfx)
	local color = props.Color or UI.Colors.pink
	local b = UI.new("TextButton", {
		Name = props.Name or "Button",
		Size = props.Size or UDim2.new(0, 200, 0, 56),
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		BackgroundColor3 = color,
		AutoButtonColor = false,
		Text = props.Text or "",
		Font = UI.Font,
		TextSize = props.TextSize or 26,
		TextColor3 = props.TextColor or UI.Colors.paper,
		TextWrapped = true,
		LayoutOrder = props.LayoutOrder or 0,
		ZIndex = props.ZIndex or 1,
		Parent = props.Parent,
	}, {
		UI.corner(props.Corner or 16),
		UI.new("UIStroke", { Color = UI.Colors.ink, Thickness = props.Stroke or 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
		UI.new("UIGradient", {
			Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(220, 220, 220)),
			Rotation = 90,
		}),
	})
	local ts = UI.new("UIStroke", {
		Color = UI.Colors.ink,
		Thickness = 2,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
		Parent = b,
	})
	_ = ts
	local scale = UI.new("UIScale", { Parent = b })
	b.MouseEnter:Connect(function()
		UI.tween(scale, 0.12, { Scale = 1.05 })
	end)
	b.MouseLeave:Connect(function()
		UI.tween(scale, 0.12, { Scale = 1 })
	end)
	b.MouseButton1Down:Connect(function()
		UI.tween(scale, 0.06, { Scale = 0.93 })
	end)
	b.MouseButton1Up:Connect(function()
		UI.tween(scale, 0.18, { Scale = 1 }, Enum.EasingStyle.Back)
	end)
	if onClick then
		b.Activated:Connect(function()
			if b:GetAttribute("Disabled") then
				return
			end
			if sfx then
				sfx.play("click")
			end
			onClick(b)
		end)
	end
	return b
end

function UI.setDisabled(b: GuiButton, disabled: boolean)
	b:SetAttribute("Disabled", disabled)
	b.BackgroundTransparency = disabled and 0.35 or 0
	b.TextTransparency = disabled and 0.35 or 0
end

-- floating feedback text, parent should be a full-screen frame
function UI.popText(parent: GuiObject, text: string, color: Color3, pos: UDim2, size: number?)
	local l = UI.label({
		Text = text,
		Font = UI.Font,
		TextSize = size or 46,
		TextColor3 = color,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(0, 520, 0, 64),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = pos,
		ZIndex = 20,
		Parent = parent,
		Rotation = math.random(-6, 6),
	})
	UI.textStroke(UI.Colors.ink, 3).Parent = l
	local sc = UI.new("UIScale", { Scale = 0.3, Parent = l })
	UI.tween(sc, 0.22, { Scale = 1 }, Enum.EasingStyle.Back)
	task.delay(0.45, function()
		UI.tween(l, 0.6, { Position = pos - UDim2.fromOffset(0, 70), TextTransparency = 1 })
		local st = l:FindFirstChildOfClass("UIStroke")
		if st then
			UI.tween(st, 0.6, { Transparency = 1 })
		end
	end)
	task.delay(1.2, function()
		l:Destroy()
	end)
	return l
end

function UI.formatCount(n: number): string
	if n >= 1e6 then
		return string.format("%.1fM", n / 1e6)
	elseif n >= 1e4 then
		return string.format("%.1fK", n / 1e3)
	end
	return tostring(math.floor(n))
end

return UI
