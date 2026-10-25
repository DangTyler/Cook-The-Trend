-- Cook the Trend: lightweight visual effects (particles, bursts, rings, confetti).
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Fx = {}

local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local SPARK = "rbxasset://textures/particles/sparkles_main.dds"

Fx.folder = nil

function Fx.setFolder(f: Instance)
	Fx.folder = f
end

local function anchorPart(pos: Vector3, parent)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Transparency = 1
	p.Size = Vector3.new(0.4, 0.4, 0.4)
	p.CFrame = CFrame.new(pos)
	p.Parent = parent or Fx.folder or workspace
	return p
end
Fx.anchorPart = anchorPart

-- kind: steam | smoke | bubbles | sparkle | splash | sizzle
function Fx.emitter(parent: BasePart, kind: string, color: Color3?)
	local e = Instance.new("ParticleEmitter")
	e.Name = "Fx_" .. kind
	e.LightEmission = 0
	e.Rate = 0
	if kind == "steam" then
		e.Texture = SMOKE
		e.Color = ColorSequence.new(Color3.new(1, 1, 1))
		e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, 0.55), NumberSequenceKeypoint.new(1, 1) })
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 2.6) })
		e.Lifetime = NumberRange.new(1.4, 2.2)
		e.Speed = NumberRange.new(1.5, 2.6)
		e.SpreadAngle = Vector2.new(14, 14)
		e.Acceleration = Vector3.new(0, 0.6, 0)
		e.RotSpeed = NumberRange.new(-40, 40)
		e.Rotation = NumberRange.new(0, 360)
		e.EmissionDirection = Enum.NormalId.Top
	elseif kind == "smoke" then
		e.Texture = SMOKE
		e.Color = ColorSequence.new(Color3.fromRGB(70, 64, 60), Color3.fromRGB(30, 28, 26))
		e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.15, 0.3), NumberSequenceKeypoint.new(1, 1) })
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 3.6) })
		e.Lifetime = NumberRange.new(1.6, 2.6)
		e.Speed = NumberRange.new(1.8, 3)
		e.SpreadAngle = Vector2.new(20, 20)
		e.RotSpeed = NumberRange.new(-50, 50)
		e.Rotation = NumberRange.new(0, 360)
		e.EmissionDirection = Enum.NormalId.Top
	elseif kind == "bubbles" then
		e.Texture = SPARK
		e.Color = ColorSequence.new(Color3.new(1, 1, 1))
		e.Transparency = NumberSequence.new(0.2, 1)
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(1, 0.35) })
		e.Lifetime = NumberRange.new(0.3, 0.6)
		e.Speed = NumberRange.new(0.6, 1.4)
		e.SpreadAngle = Vector2.new(80, 80)
		e.EmissionDirection = Enum.NormalId.Top
	elseif kind == "sizzle" then
		e.Texture = SPARK
		e.Color = ColorSequence.new(Color3.fromRGB(255, 220, 140))
		e.LightEmission = 0.6
		e.Transparency = NumberSequence.new(0, 1)
		e.Size = NumberSequence.new(0.18, 0.05)
		e.Lifetime = NumberRange.new(0.25, 0.5)
		e.Speed = NumberRange.new(3, 6)
		e.SpreadAngle = Vector2.new(70, 70)
		e.Acceleration = Vector3.new(0, -20, 0)
		e.EmissionDirection = Enum.NormalId.Top
	elseif kind == "sparkle" then
		e.Texture = SPARK
		e.Color = ColorSequence.new(color or Color3.fromRGB(255, 230, 120))
		e.LightEmission = 1
		e.Transparency = NumberSequence.new(0, 1)
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
		e.Lifetime = NumberRange.new(0.6, 1.1)
		e.Speed = NumberRange.new(2, 5)
		e.SpreadAngle = Vector2.new(180, 180)
		e.Drag = 3
	elseif kind == "splash" then
		e.Texture = SPARK
		e.Color = ColorSequence.new(color or Color3.fromRGB(230, 190, 130))
		e.Transparency = NumberSequence.new(0.1, 1)
		e.Size = NumberSequence.new(0.3, 0.1)
		e.Lifetime = NumberRange.new(0.3, 0.6)
		e.Speed = NumberRange.new(2, 4)
		e.SpreadAngle = Vector2.new(60, 60)
		e.Acceleration = Vector3.new(0, -25, 0)
		e.EmissionDirection = Enum.NormalId.Top
	end
	e.Parent = parent
	return e
end

-- small chunky bits flying out (chop crumbs, juice)
function Fx.burst(pos: Vector3, color: Color3, count: number?, power: number?)
	local parent = Fx.folder or workspace
	for i = 1, count or 6 do
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		local s = 0.08 + math.random() * 0.12
		p.Size = Vector3.new(s, s, s)
		p.Color = color
		p.Material = Enum.Material.SmoothPlastic
		p.CFrame = CFrame.new(pos)
		p.Parent = parent
		local dir = Vector3.new(math.random() - 0.5, 0.8 + math.random(), math.random() - 0.5).Unit * (power or 1.2)
		local mid = pos + dir * 0.8 + Vector3.new(0, 0.4, 0)
		local land = pos + Vector3.new(dir.X * 1.4, -0.1, dir.Z * 1.4)
		local t1 = TweenService:Create(p, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = CFrame.new(mid) * CFrame.Angles(math.random() * 3, math.random() * 3, 0) })
		t1:Play()
		t1.Completed:Once(function()
			local t2 = TweenService:Create(p, TweenInfo.new(0.24, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { CFrame = CFrame.new(land), Transparency = 0.2 })
			t2:Play()
		end)
		Debris:AddItem(p, 1.2)
	end
end

function Fx.sparkleAt(pos: Vector3, color: Color3?, amount: number?)
	local a = anchorPart(pos)
	local e = Fx.emitter(a, "sparkle", color)
	e:Emit(amount or 18)
	Debris:AddItem(a, 2)
end

function Fx.splashAt(pos: Vector3, color: Color3?, amount: number?)
	local a = anchorPart(pos)
	local e = Fx.emitter(a, "splash", color)
	e:Emit(amount or 12)
	Debris:AddItem(a, 1.5)
end

function Fx.puffAt(pos: Vector3, kind: string?, amount: number?)
	local a = anchorPart(pos)
	local e = Fx.emitter(a, kind or "steam")
	e:Emit(amount or 6)
	Debris:AddItem(a, 3)
end

-- confetti burst for celebrations
function Fx.confetti(pos: Vector3, count: number?)
	local parent = Fx.folder or workspace
	local colors = { Color3.fromRGB(255, 84, 136), Color3.fromRGB(255, 196, 0), Color3.fromRGB(64, 206, 150), Color3.fromRGB(84, 170, 255), Color3.fromRGB(255, 146, 52) }
	for i = 1, count or 40 do
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Size = Vector3.new(0.22, 0.03, 0.12)
		p.Color = colors[(i % #colors) + 1]
		p.Material = Enum.Material.SmoothPlastic
		p.CFrame = CFrame.new(pos)
		p.Parent = parent
		local ang = math.random() * math.pi * 2
		local r = 1.5 + math.random() * 3.5
		local up = pos + Vector3.new(math.cos(ang) * r * 0.5, 3 + math.random() * 2.5, math.sin(ang) * r * 0.5)
		local down = pos + Vector3.new(math.cos(ang) * r, -0.5, math.sin(ang) * r)
		local t1 = TweenService:Create(p, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = CFrame.new(up) * CFrame.Angles(math.random() * 6, math.random() * 6, 0) })
		t1:Play()
		t1.Completed:Once(function()
			local t2 = TweenService:Create(p, TweenInfo.new(1.4, Enum.EasingStyle.Sine, Enum.EasingDirection.In), { CFrame = CFrame.new(down) * CFrame.Angles(math.random() * 12, math.random() * 12, 0), Transparency = 0.6 })
			t2:Play()
		end)
		Debris:AddItem(p, 2.2)
	end
end

-- flat ring of small neon tiles (target markers)
function Fx.ring(parent: Instance, center: CFrame, radius: number, color: Color3, n: number?, thick: number?)
	local m = Instance.new("Model")
	m.Name = "Ring"
	n = n or 16
	for i = 1, n do
		local a = i / n * math.pi * 2
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Material = Enum.Material.Neon
		p.Color = color
		p.Size = Vector3.new(thick or 0.08, 0.04, 2 * math.pi * radius / n * 0.6)
		p.CFrame = center * CFrame.Angles(0, a, 0) * CFrame.new(radius, 0, 0)
		p.Parent = m
	end
	m.Parent = parent
	return m
end

return Fx
