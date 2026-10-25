-- Cook the Trend: builds the static kitchen set (Workspace.Kitchen) + lighting. Edit-mode, idempotent.
local Lighting = game:GetService("Lighting")
local C = Color3.fromRGB
local rad = math.rad

local old = workspace:FindFirstChild("Kitchen")
if old then old:Destroy() end
local bp = workspace:FindFirstChild("Baseplate")
if bp then bp:Destroy() end

local K = Instance.new("Model")
K.Name = "Kitchen"

local function P(parent, size, cf, color, mat, props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = mat or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanTouch = false
	if props then for k, v in props do p[k] = v end end
	p.Parent = parent
	return p
end
local function cyl(parent, dia, h, cf, color, mat, props)
	local p = P(parent, Vector3.new(h, dia, dia), cf * CFrame.Angles(0, 0, rad(90)), color, mat, props)
	p.Shape = Enum.PartType.Cylinder
	return p
end
local function folder(name)
	local f = Instance.new("Model")
	f.Name = name
	f.Parent = K
	return f
end

-- room ---------------------------------------------------------------
local room = folder("Room")
P(room, Vector3.new(120, 1, 140), CFrame.new(0, -0.5, 30), C(196, 140, 98), Enum.Material.WoodPlanks)
-- back wall: pastel tiles
P(room, Vector3.new(70, 22, 1), CFrame.new(0, 11, -8.5), C(255, 214, 214), Enum.Material.CeramicTiles)
-- wainscot band
P(room, Vector3.new(70, 0.4, 0.4), CFrame.new(0, 6.2, -7.9), C(255, 255, 255))
-- side walls
P(room, Vector3.new(1, 22, 40), CFrame.new(-34, 11, 10), C(255, 226, 210), Enum.Material.SmoothPlastic)
P(room, Vector3.new(1, 22, 40), CFrame.new(34, 11, 10), C(255, 226, 210), Enum.Material.SmoothPlastic)

-- window with sunset
local win = folder("Window")
P(win, Vector3.new(12, 7, 0.2), CFrame.new(-1, 12.5, -7.9), C(255, 170, 120), Enum.Material.Neon)
local sky = P(win, Vector3.new(12, 3.5, 0.15), CFrame.new(-1, 14.25, -7.85), C(255, 140, 170), Enum.Material.Neon)
P(win, Vector3.new(12.8, 0.5, 0.6), CFrame.new(-1, 16.2, -7.7), C(255, 255, 255))
P(win, Vector3.new(12.8, 0.5, 0.9), CFrame.new(-1, 8.8, -7.55), C(255, 255, 255))
P(win, Vector3.new(0.4, 7, 0.5), CFrame.new(-1, 12.5, -7.7), C(255, 255, 255))
P(win, Vector3.new(0.5, 7.6, 0.6), CFrame.new(-7.3, 12.5, -7.7), C(255, 255, 255))
P(win, Vector3.new(0.5, 7.6, 0.6), CFrame.new(5.3, 12.5, -7.7), C(255, 255, 255))
-- city silhouette
for i = 0, 7 do
	local h = 1.2 + (i * 37 % 5) * 0.5
	P(win, Vector3.new(1.3, h, 0.1), CFrame.new(-6.5 + i * 1.55, 9.1 + h / 2, -7.75), C(200, 110, 150), Enum.Material.SmoothPlastic)
end
_ = sky
-- plants on sill
for _, x in { -5.8, 3.8 } do
	cyl(win, 0.9, 0.9, CFrame.new(x, 9.5, -7.4), C(240, 150, 110))
	for k = 0, 4 do
		local leaf = P(win, Vector3.new(0.25, 1.1, 0.5), CFrame.new(x + math.cos(k * 1.3) * 0.3, 10.4, -7.4 + math.sin(k * 1.3) * 0.3) * CFrame.Angles(0, k * 1.3, rad(25)), C(90, 180, 100))
		_ = leaf
	end
end

-- neon sign
local sign = folder("Sign")
local board = P(sign, Vector3.new(9, 2.2, 0.3), CFrame.new(10.5, 13, -7.85), C(40, 30, 50))
local sg = Instance.new("SurfaceGui")
sg.Face = Enum.NormalId.Front
sg.LightInfluence = 0
sg.PixelsPerStud = 60
sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
sg.Parent = board
local tl = Instance.new("TextLabel")
tl.BackgroundTransparency = 1
tl.Size = UDim2.fromScale(1, 1)
tl.Font = Enum.Font.FredokaOne
tl.Text = "cook the trend ♥"
tl.TextScaled = true
tl.TextColor3 = C(255, 120, 190)
tl.Parent = sg
local st = Instance.new("UIStroke")
st.Color = C(255, 220, 240)
st.Thickness = 3
st.Parent = tl
local sl = Instance.new("PointLight")
sl.Color = C(255, 110, 180)
sl.Range = 14
sl.Brightness = 1.2
sl.Parent = board

-- upper shelf with jars
local shelf = folder("Shelf")
P(shelf, Vector3.new(12, 0.35, 1.6), CFrame.new(-17, 10, -7.2), C(214, 160, 100), Enum.Material.Wood)
P(shelf, Vector3.new(12, 0.35, 1.6), CFrame.new(17, 10, -7.2), C(214, 160, 100), Enum.Material.Wood)
local jarCols = { C(255, 200, 80), C(255, 120, 120), C(140, 210, 160), C(160, 170, 255), C(255, 170, 210) }
for side = -1, 1, 2 do
	for i = 0, 5 do
		local x = side * 17 - 5 + i * 2
		local h = 1.2 + (i % 3) * 0.35
		cyl(shelf, 1.0, h, CFrame.new(x, 10.2 + h / 2, -7.2), C(230, 245, 255), Enum.Material.Glass, { Transparency = 0.35 })
		cyl(shelf, 0.85, h * 0.7, CFrame.new(x, 10.2 + h * 0.35, -7.2), jarCols[(i % 5) + 1])
		cyl(shelf, 1.05, 0.25, CFrame.new(x, 10.2 + h + 0.12, -7.2), C(200, 140, 90), Enum.Material.Wood)
	end
end

-- back counter (behind main counter, against wall)
local back = folder("BackCounter")
P(back, Vector3.new(66, 5.5, 3), CFrame.new(0, 2.75, -6.6), C(130, 200, 190))
P(back, Vector3.new(66, 0.4, 3.4), CFrame.new(0, 5.7, -6.6), C(245, 240, 235), Enum.Material.Marble)

-- main counter -------------------------------------------------------
local counter = folder("Counter")
local top = 3.0
P(counter, Vector3.new(24, 2.7, 6.2), CFrame.new(0, 1.35, -0.2), C(120, 196, 186))
P(counter, Vector3.new(24.6, 0.3, 6.8), CFrame.new(0, top - 0.15, -0.2), C(250, 246, 242), Enum.Material.Marble)
-- cabinet doors + handles on the camera-facing side (z = +2.9)
for i = 0, 7 do
	local x = -10.5 + i * 3
	P(counter, Vector3.new(2.7, 2.1, 0.12), CFrame.new(x, 1.35, 2.93), C(140, 214, 204))
	P(counter, Vector3.new(0.9, 0.14, 0.18), CFrame.new(x, 2.1, 3.05), C(235, 190, 90), Enum.Material.Metal)
end
P(counter, Vector3.new(24.2, 0.3, 0.2), CFrame.new(0, 0.15, 2.95), C(80, 140, 130))

-- cooktop + burner
local stoveX, stoveZ = 4.8, 0.2
local cook = folder("Cooktop")
P(cook, Vector3.new(4.6, 0.04, 4.0), CFrame.new(stoveX, top + 0.02, stoveZ), C(26, 24, 30), Enum.Material.Glass, { Reflectance = 0.2 })
local burner = Instance.new("Model")
burner.Name = "Burner"
burner.Parent = cook
for _, d in { 2.6, 1.7, 0.9 } do
	for k = 1, 16 do
		local a = (k / 16) * math.pi * 2
		local cf = CFrame.new(stoveX, top + 0.06, stoveZ) * CFrame.Angles(0, a, 0) * CFrame.new(d / 2, 0, 0)
		P(burner, Vector3.new(0.14, 0.05, d * 0.21), cf, C(70, 60, 60), nil, { Name = "Coil", CanCollide = false })
	end
end
-- knobs
for i = 0, 2 do
	cyl(cook, 0.45, 0.3, CFrame.new(stoveX - 1 + i, top - 0.6, 3.0) * CFrame.Angles(rad(90), 0, 0), C(50, 50, 56))
end

-- serving mat under the plate spot
local plateX, plateZ = 0, 0.9
local mat = folder("ServeMat")
cyl(mat, 5.4, 0.06, CFrame.new(plateX, top + 0.03, plateZ), C(255, 236, 214))
cyl(mat, 5.0, 0.07, CFrame.new(plateX, top + 0.035, plateZ), C(255, 248, 238))

-- ingredient tray (back of counter)
local tray = folder("Tray")
P(tray, Vector3.new(11.6, 0.12, 2.2), CFrame.new(0, top + 0.06, -2.3), C(214, 160, 100), Enum.Material.Wood)
P(tray, Vector3.new(11.6, 0.35, 0.15), CFrame.new(0, top + 0.18, -3.37), C(190, 135, 80), Enum.Material.Wood)

-- decor props
local decor = folder("Decor")
-- knife block
P(decor, Vector3.new(1.0, 1.6, 1.2), CFrame.new(-9.2, top + 0.8, -2.0) * CFrame.Angles(rad(-12), 0, 0), C(150, 100, 60), Enum.Material.Wood)
for i = 0, 2 do
	P(decor, Vector3.new(0.18, 0.6, 0.12), CFrame.new(-9.5 + i * 0.3, top + 1.85, -2.25) * CFrame.Angles(rad(-12), 0, 0), C(30, 30, 30))
end
-- salt & pepper
cyl(decor, 0.45, 0.9, CFrame.new(8.6, top + 0.45, -2.0), C(250, 250, 250))
cyl(decor, 0.45, 0.9, CFrame.new(9.2, top + 0.45, -2.0), C(60, 60, 64))
-- utensil crock
cyl(decor, 1.1, 1.2, CFrame.new(9.4, top + 0.6, -0.5), C(255, 160, 140))
for i = 0, 3 do
	P(decor, Vector3.new(0.12, 2.0, 0.12), CFrame.new(9.4 + (i - 1.5) * 0.18, top + 1.6, -0.5) * CFrame.Angles(0, 0, rad((i - 1.5) * 8)), C(200, 150, 100), Enum.Material.Wood)
end
-- phone on tripod + ring light (the "creator" setup)
local rig = folder("CreatorRig")
local rx, rz = -10.2, 1.4
for k = 0, 2 do
	local a = k / 3 * math.pi * 2
	P(rig, Vector3.new(0.08, 1.6, 0.08), CFrame.new(rx + math.cos(a) * 0.35, top + 0.7, rz + math.sin(a) * 0.35) * CFrame.Angles(math.sin(a) * 0.35, 0, -math.cos(a) * 0.35), C(40, 40, 46))
end
P(rig, Vector3.new(0.08, 1.4, 0.08), CFrame.new(rx, top + 2.1, rz), C(40, 40, 46))
local ringCenter = CFrame.new(rx, top + 3.2, rz) * CFrame.Angles(0, rad(-60), 0)
for k = 1, 18 do
	local a = k / 18 * math.pi * 2
	P(rig, Vector3.new(0.12, 0.2, 0.32), ringCenter * CFrame.Angles(0, 0, a) * CFrame.new(0, 0.85, 0), C(255, 250, 235), Enum.Material.Neon, { CanCollide = false })
end
P(rig, Vector3.new(0.5, 0.9, 0.06), ringCenter, C(30, 30, 36), nil, { CanCollide = false })
local rl = Instance.new("PointLight")
rl.Color = C(255, 245, 230)
rl.Brightness = 0.8
rl.Range = 12
rl.Parent = rig:GetChildren()[#rig:GetChildren()]

-- pendant lamps
local lamps = folder("Lamps")
for _, x in { -6, 0, 6 } do
	P(lamps, Vector3.new(0.08, 6, 0.08), CFrame.new(x, 19, -0.6), C(40, 40, 40))
	cyl(lamps, 2.2, 1.0, CFrame.new(x, 15.6, -0.6), C(255, 196, 120))
	local bulb = cyl(lamps, 0.9, 0.4, CFrame.new(x, 15.0, -0.6), C(255, 240, 200), Enum.Material.Neon, { CanCollide = false })
	local pl = Instance.new("PointLight")
	pl.Color = C(255, 214, 170)
	pl.Brightness = 1.6
	pl.Range = 22
	pl.Shadows = true
	pl.Parent = bulb
end
-- fill light from camera side
local fill = P(K, Vector3.new(1, 1, 1), CFrame.new(0, 12, 14), C(255, 255, 255), nil, { Transparency = 1, CanCollide = false, Name = "FillLight" })
local sp = Instance.new("SpotLight")
sp.Face = Enum.NormalId.Front
sp.Angle = 70
sp.Range = 34
sp.Brightness = 1.4
sp.Color = C(255, 236, 220)
sp.Parent = fill
fill.CFrame = CFrame.lookAt(Vector3.new(0, 12, 14), Vector3.new(0, 3, 0))

-- anchors -------------------------------------------------------------
local anchors = Instance.new("Folder")
anchors.Name = "Anchors"
anchors.Parent = K
local function anchor(name, pos)
	P(anchors, Vector3.new(0.3, 0.3, 0.3), CFrame.new(pos), C(255, 0, 0), nil, { Name = name, Transparency = 1, CanCollide = false, CanQuery = false })
end
anchor("Board", Vector3.new(-4.6, top, 0.5))
anchor("Stove", Vector3.new(stoveX, top, stoveZ))
anchor("Plate", Vector3.new(plateX, top + 0.07, plateZ))
anchor("Tray", Vector3.new(0, top + 0.12, -2.3))

K.Parent = workspace

-- spawn far behind the camera
local spawn = workspace:FindFirstChildOfClass("SpawnLocation")
if spawn then
	spawn.CFrame = CFrame.new(0, 0.5, 70)
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Transparency = 1
	spawn.CanCollide = true
	local d = spawn:FindFirstChildOfClass("Decal")
	if d then d:Destroy() end
end

-- lighting ------------------------------------------------------------
pcall(function() Lighting.Technology = Enum.Technology.Future end)
Lighting.ClockTime = 17.6
Lighting.Brightness = 1.6
Lighting.Ambient = C(120, 96, 100)
Lighting.OutdoorAmbient = C(170, 140, 140)
Lighting.EnvironmentDiffuseScale = 0.5
Lighting.EnvironmentSpecularScale = 0.5
Lighting.GlobalShadows = true
Lighting.ShadowSoftness = 0.4
for _, c in Lighting:GetChildren() do
	if c:IsA("PostEffect") or c:IsA("Atmosphere") or c:IsA("Sky") then c:Destroy() end
end
local cc = Instance.new("ColorCorrectionEffect")
cc.Saturation = 0.15
cc.Contrast = 0.08
cc.Brightness = 0.02
cc.TintColor = C(255, 246, 238)
cc.Parent = Lighting
local bloom = Instance.new("BloomEffect")
bloom.Intensity = 0.35
bloom.Size = 22
bloom.Threshold = 1.6
bloom.Parent = Lighting

local players = game:GetService("Players")
players.CharacterAutoLoads = true

return "kitchen built: " .. #K:GetDescendants() .. " instances"
