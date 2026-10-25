-- Cook the Trend: extra set dressing around the action zones (idempotent).
local C = Color3.fromRGB
local rad = math.rad
local K = workspace.Kitchen
local old = K:FindFirstChild("Decor2")
if old then old:Destroy() end
local D = Instance.new("Model")
D.Name = "Decor2"
local top = 3.0

local function P(size, cf, color, mat, props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = mat or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if props then for k, v in props do p[k] = v end end
	p.Parent = D
	return p
end
local function cyl(dia, h, cf, color, mat, props)
	local p = P(Vector3.new(h, dia, dia), cf * CFrame.Angles(0, 0, rad(90)), color, mat, props)
	p.Shape = Enum.PartType.Cylinder
	return p
end
local function ball(size, cf, color, mat)
	local p = P(size, cf, color, mat)
	local m = Instance.new("SpecialMesh")
	m.MeshType = Enum.MeshType.Sphere
	m.Parent = p
	return p
end

-- herb pots (front corners)
for _, pos in { Vector3.new(-8.6, top, 2.0), Vector3.new(8.4, top, 2.1) } do
	cyl(1.3, 1.1, CFrame.new(pos + Vector3.new(0, 0.55, 0)), C(236, 120, 96))
	cyl(1.35, 0.2, CFrame.new(pos + Vector3.new(0, 1.05, 0)), C(214, 100, 80))
	cyl(1.15, 0.1, CFrame.new(pos + Vector3.new(0, 1.12, 0)), C(90, 60, 40), Enum.Material.Sand)
	for k = 0, 8 do
		local a = k / 9 * math.pi * 2
		ball(Vector3.new(0.35, 0.12, 0.7), CFrame.new(pos + Vector3.new(math.cos(a) * 0.3, 1.5 + (k % 3) * 0.18, math.sin(a) * 0.3)) * CFrame.Angles(rad(35), -a, 0), k % 2 == 0 and C(80, 180, 90) or C(110, 205, 110))
	end
end
-- folded tea towel by the board
P(Vector3.new(1.6, 0.12, 1.1), CFrame.new(-7.6, top + 0.06, 0.2) * CFrame.Angles(0, rad(12), 0), C(255, 255, 255), Enum.Material.Fabric)
for i = 0, 2 do
	P(Vector3.new(1.62, 0.13, 0.12), CFrame.new(-7.6, top + 0.065, -0.2 + i * 0.4) * CFrame.Angles(0, rad(12), 0), C(240, 90, 110), Enum.Material.Fabric)
end
-- garlic + peppercorns near the board
ball(Vector3.new(0.6, 0.5, 0.6), CFrame.new(-7.2, top + 0.25, -1.4), C(250, 244, 232))
ball(Vector3.new(0.45, 0.4, 0.45), CFrame.new(-6.8, top + 0.2, -1.1), C(246, 238, 226))
cyl(0.9, 0.35, CFrame.new(-7.9, top + 0.18, -1.0), C(255, 255, 255))
cyl(0.7, 0.36, CFrame.new(-7.9, top + 0.19, -1.0), C(60, 50, 44), Enum.Material.Sand)
-- olive oil bottle + salt cellar near the stove
cyl(0.6, 1.6, CFrame.new(7.7, top + 0.8, -1.4), C(150, 190, 60), Enum.Material.Glass, { Transparency = 0.25 })
cyl(0.25, 0.5, CFrame.new(7.7, top + 1.85, -1.4), C(60, 50, 40))
cyl(0.9, 0.45, CFrame.new(7.4, top + 0.22, 0.6), C(110, 170, 210))
cyl(0.75, 0.46, CFrame.new(7.4, top + 0.24, 0.6), C(250, 250, 250), Enum.Material.Sand)
-- fruit bowl on the back counter
cyl(2.6, 0.6, CFrame.new(-12, 6.2, -6.4), C(255, 214, 120))
for k = 0, 5 do
	local a = k / 6 * math.pi * 2
	local col = ({ C(232, 36, 66), C(255, 170, 40), C(130, 200, 60) })[(k % 3) + 1]
	ball(Vector3.new(0.7, 0.7, 0.7), CFrame.new(-12 + math.cos(a) * 0.6, 6.75, -6.4 + math.sin(a) * 0.5), col)
end
-- stand mixer silhouette on the back counter
P(Vector3.new(1.6, 0.4, 1.4), CFrame.new(12.5, 6.1, -6.5), C(255, 140, 170))
P(Vector3.new(0.5, 2.0, 0.6), CFrame.new(13.1, 7.1, -6.5), C(255, 140, 170))
P(Vector3.new(1.9, 0.7, 0.8), CFrame.new(12.4, 8.2, -6.5), C(255, 140, 170))
cyl(1.2, 1.0, CFrame.new(12.3, 6.8, -6.5), C(220, 225, 235), Enum.Material.Metal)
-- cake stand with pastel cake
cyl(1.8, 0.1, CFrame.new(6, 6.9, -6.4), C(255, 255, 255))
cyl(0.25, 1.0, CFrame.new(6, 6.4, -6.4), C(255, 255, 255))
cyl(1.5, 0.9, CFrame.new(6, 7.4, -6.4), C(255, 220, 235))
cyl(1.55, 0.15, CFrame.new(6, 7.9, -6.4), C(255, 255, 255))
ball(Vector3.new(0.35, 0.35, 0.35), CFrame.new(6, 8.1, -6.4), C(232, 36, 66))
-- hanging utensil rail on the back wall
P(Vector3.new(10, 0.15, 0.15), CFrame.new(-17, 8.2, -7.8), C(200, 200, 210), Enum.Material.Metal)
for i = 0, 4 do
	local x = -21 + i * 2
	P(Vector3.new(0.1, 1.6, 0.1), CFrame.new(x, 7.3, -7.7), C(200, 200, 210), Enum.Material.Metal)
	cyl(0.7, 0.12, CFrame.new(x, 6.4, -7.7) * CFrame.Angles(rad(90), 0, 0), ({ C(255, 150, 120), C(140, 210, 190), C(255, 200, 90) })[(i % 3) + 1])
end

D.Parent = K
return "decor: " .. #D:GetChildren()
