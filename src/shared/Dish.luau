-- Cook the Trend: procedural food, vessel and tool models (client-side visuals + feed previews).
-- Every builder returns a Model whose PrimaryPart "Root" sits at the bottom-centre (pivot = bottom centre).
-- If ReplicatedStorage.CTTAssets has a model with the same name, that vetted asset is used instead.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Dish = {}

local C = Color3.fromRGB
local rad = math.rad

Dish.Colors = {
	noodleRaw = C(246, 232, 170),
	noodleIdeal = C(244, 204, 96),
	noodleOver = C(185, 120, 45),
	noodleBurnt = C(60, 42, 28),
	pattyRaw = C(214, 102, 112),
	pattyIdeal = C(122, 68, 38),
	pattyOver = C(80, 45, 28),
	pattyBurnt = C(32, 26, 22),
	broth = C(218, 154, 86),
	yogurt = C(255, 176, 204),
	honey = C(255, 176, 40),
	bowl = C(232, 88, 62),
	bowlInner = C(44, 40, 58),
}

local function part(parent, size: Vector3, cf: CFrame, color: Color3, props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if props then
		for k, v in props do
			if k == "Shape" then
				p.Shape = v
			elseif k == "Attr" then
				for ak, av in v do
					p:SetAttribute(ak, av)
				end
			else
				(p :: any)[k] = v
			end
		end
	end
	p.Parent = parent
	return p
end
Dish.part = part

-- disc lying flat (cylinder axis vertical), cf = centre of disc
local function disc(parent, dia: number, h: number, cf: CFrame, color: Color3, props)
	local p = part(parent, Vector3.new(h, dia, dia), cf * CFrame.Angles(0, 0, rad(90)), color, props)
	p.Shape = Enum.PartType.Cylinder
	return p
end
Dish.disc = disc

local function ball(parent, size: Vector3, cf: CFrame, color: Color3, props)
	local p = part(parent, size, cf, color, props)
	if size.X == size.Y and size.Y == size.Z then
		p.Shape = Enum.PartType.Ball
	else
		local m = Instance.new("SpecialMesh")
		m.MeshType = Enum.MeshType.Sphere
		m.Parent = p
	end
	return p
end
Dish.ball = ball

-- horizontal cylinder along X
local function rod(parent, len: number, dia: number, cf: CFrame, color: Color3, props)
	local p = part(parent, Vector3.new(len, dia, dia), cf, color, props)
	p.Shape = Enum.PartType.Cylinder
	return p
end
Dish.rod = rod

local function newModel(name: string)
	local m = Instance.new("Model")
	m.Name = name
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Anchored = true
	root.CanCollide = false
	root.CanQuery = false
	root.CanTouch = false
	root.Transparency = 1
	root.Size = Vector3.new(0.2, 0.2, 0.2)
	root.CFrame = CFrame.new()
	root.Parent = m
	m.PrimaryPart = root
	return m
end
Dish.newModel = newModel

-- ring wall made of slabs (bowls, pots, pans, cups)
local function ringWall(parent, rBottom: number, rTop: number, h: number, y0: number, thick: number, n: number, color, props)
	local rMid = (rBottom + rTop) / 2
	local slant = math.atan2(rTop - rBottom, h)
	local slantLen = math.sqrt(h * h + (rTop - rBottom) ^ 2)
	local w = 2 * math.pi * rMid / n * 1.12
	for i = 1, n do
		local a = (i / n) * math.pi * 2
		local cf = CFrame.new(0, y0, 0)
			* CFrame.Angles(0, a, 0)
			* CFrame.new(rMid, h / 2, 0)
			* CFrame.Angles(0, 0, -slant)
		part(parent, Vector3.new(thick, slantLen, w), cf, color, props)
	end
end
Dish.ringWall = ringWall

------------------------------------------------------------------ vessels
-- Vessel geometry: bottom at y=0. surface(fill) -> y, radiusAt(y) -> r
Dish.Vessels = {
	bowl = {
		height = 1.7,
		rBottom = 1.15,
		rTop = 2.15,
		fillY = function(f)
			return 0.25 + f * 1.3
		end,
	},
	cup = {
		height = 2.5,
		rBottom = 1.3,
		rTop = 1.9,
		fillY = function(f)
			return 0.7 + f * 1.65
		end,
	},
	plate = {
		height = 0.2,
		rBottom = 1.8,
		rTop = 1.8,
		fillY = function()
			return 0.2
		end,
	},
}

function Dish.vesselRadiusAt(kind: string, y: number): number
	local v = Dish.Vessels[kind]
	local t = math.clamp(y / v.height, 0, 1)
	return v.rBottom + (v.rTop - v.rBottom) * t
end

function Dish.bowl()
	local m = newModel("Bowl")
	local col, inner = Dish.Colors.bowl, Dish.Colors.bowlInner
	disc(m, 1.6, 0.2, CFrame.new(0, 0.1, 0), C(200, 70, 50)) -- foot
	disc(m, 2.3, 0.18, CFrame.new(0, 0.25, 0), inner) -- inner floor
	ringWall(m, 1.15, 2.15, 1.7, 0.1, 0.16, 22, col)
	ringWall(m, 1.06, 2.05, 1.65, 0.15, 0.06, 22, inner)
	-- rim band + pattern dots
	for i = 1, 22 do
		local a = (i / 22) * math.pi * 2
		local cf = CFrame.new(0, 1.82, 0) * CFrame.Angles(0, a, 0) * CFrame.new(2.2, 0, 0)
		part(m, Vector3.new(0.2, 0.12, 0.66), cf, C(30, 28, 40))
		if i % 2 == 0 then
			local cf2 = CFrame.new(0, 1.05, 0) * CFrame.Angles(0, a, 0) * CFrame.new(1.72, 0, 0) * CFrame.Angles(0, 0, -0.53)
			part(m, Vector3.new(0.05, 0.26, 0.26), cf2, C(255, 214, 120))
		end
	end
	return m
end

function Dish.cup()
	local m = newModel("Cup")
	disc(m, 2.7, 0.16, CFrame.new(0, 0.08, 0), C(225, 240, 250), { Material = Enum.Material.Glass, Transparency = 0.3 })
	ringWall(m, 1.3, 1.9, 2.5, 0.0, 0.06, 22, C(235, 248, 255), { Material = Enum.Material.Glass, Transparency = 0.8 })
	for i = 1, 22 do
		local a = (i / 22) * math.pi * 2
		local cf = CFrame.new(0, 2.52, 0) * CFrame.Angles(0, a, 0) * CFrame.new(1.92, 0, 0)
		part(m, Vector3.new(0.12, 0.08, 0.6), cf, C(255, 255, 255), { Material = Enum.Material.Glass, Transparency = 0.25 })
	end
	-- parfait base layers (granola + berry compote) visible through the glass
	disc(m, 2.55, 0.28, CFrame.new(0, 0.3, 0), C(206, 150, 78), { Material = Enum.Material.Sand })
	disc(m, 2.7, 0.24, CFrame.new(0, 0.56, 0), C(214, 40, 90))
	for i = 1, 8 do
		local a = i / 8 * math.pi * 2
		ball(m, Vector3.new(0.34, 0.3, 0.34), CFrame.new(math.cos(a) * 1.2, 0.58, math.sin(a) * 1.2), i % 2 == 0 and C(232, 36, 66) or C(70, 80, 176))
	end
	return m
end

function Dish.plate()
	local m = newModel("Plate")
	disc(m, 4.2, 0.12, CFrame.new(0, 0.06, 0), C(225, 225, 230))
	disc(m, 3.7, 0.16, CFrame.new(0, 0.1, 0), C(255, 255, 255))
	disc(m, 2.5, 0.17, CFrame.new(0, 0.11, 0), C(246, 246, 250))
	return m
end

function Dish.pot()
	local m = newModel("Pot")
	local metal = C(150, 158, 170)
	disc(m, 3.0, 0.2, CFrame.new(0, 0.1, 0), C(110, 115, 125), { Material = Enum.Material.Metal })
	ringWall(m, 1.55, 1.6, 1.9, 0.0, 0.14, 22, metal, { Material = Enum.Material.Metal, Reflectance = 0.15 })
	for _, s in { -1, 1 } do
		part(m, Vector3.new(0.7, 0.18, 0.4), CFrame.new(s * 1.95, 1.6, 0), C(40, 40, 46))
	end
	local water = disc(m, 3.05, 0.1, CFrame.new(0, 1.35, 0), C(140, 196, 236), { Material = Enum.Material.Glass, Transparency = 0.55, Name = "Water" })
	disc(m, 2.95, 0.9, CFrame.new(0, 0.85, 0), C(120, 180, 225), { Material = Enum.Material.Glass, Transparency = 0.7, CanQuery = false })
	water.CanQuery = false
	return m
end

function Dish.pan()
	local m = newModel("Pan")
	disc(m, 3.2, 0.16, CFrame.new(0, 0.08, 0), C(38, 38, 44), { Material = Enum.Material.Metal })
	ringWall(m, 1.6, 1.75, 0.45, 0.0, 0.12, 22, C(48, 48, 56), { Material = Enum.Material.Metal })
	part(m, Vector3.new(2.6, 0.22, 0.4), CFrame.new(3.0, 0.35, 0) * CFrame.Angles(0, 0, rad(8)), C(60, 34, 24), { Material = Enum.Material.Wood })
	return m
end

function Dish.board()
	local m = newModel("Board")
	part(m, Vector3.new(5.6, 0.32, 2.9), CFrame.new(0, 0.16, 0), C(214, 160, 100), { Material = Enum.Material.Wood })
	part(m, Vector3.new(5.0, 0.02, 2.4), CFrame.new(0, 0.33, 0), C(226, 176, 118), { Material = Enum.Material.Wood })
	disc(m, 0.35, 0.34, CFrame.new(2.45, 0.17, -1.05), C(150, 105, 60))
	return m
end

function Dish.knife()
	local m = newModel("Knife")
	-- blade vertical in the YZ plane, edge at y=0, long axis along Z (towards camera)
	part(m, Vector3.new(0.06, 0.75, 1.9), CFrame.new(0, 0.4, -0.3), C(210, 220, 230), { Material = Enum.Material.Metal, Reflectance = 0.35 })
	part(m, Vector3.new(0.05, 0.12, 1.9), CFrame.new(0, 0.07, -0.3), C(240, 245, 250), { Material = Enum.Material.Metal, Reflectance = 0.5 })
	part(m, Vector3.new(0.2, 0.32, 1.25), CFrame.new(0, 0.6, 1.25), C(40, 32, 30), { Material = Enum.Material.Wood })
	for _, z in { 0.95, 1.5 } do
		disc(m, 0.08, 0.22, CFrame.new(0, 0.6, z) * CFrame.Angles(0, 0, rad(90)), C(220, 200, 150), { Material = Enum.Material.Metal })
	end
	return m
end

function Dish.pitcher(kind: string)
	local m = newModel("Pitcher")
	local body = kind == "honey" and C(255, 200, 80) or (kind == "yogurt" and C(240, 240, 250) or C(196, 120, 70))
	if kind == "honey" then
		-- honey dipper
		rod(m, 2.4, 0.12, CFrame.new(-0.9, 0.0, 0), C(200, 150, 90), { Material = Enum.Material.Wood })
		for i = 0, 3 do
			disc(m, 0.55 - math.abs(i - 1.5) * 0.08, 0.14, CFrame.new(0.45 + i * 0.16, 0, 0) * CFrame.Angles(0, 0, rad(90)), C(220, 165, 95), { Material = Enum.Material.Wood })
		end
		ball(m, Vector3.new(0.7, 0.5, 0.5), CFrame.new(0.7, -0.15, 0), Dish.Colors.honey, { Material = Enum.Material.Glass, Transparency = 0.15 })
		return m
	end
	-- ladle / jug: bowl at origin, handle to +X
	ball(m, Vector3.new(1.5, 1.0, 1.5), CFrame.new(0, 0, 0), C(160, 168, 180), { Material = Enum.Material.Metal })
	disc(m, 1.35, 0.1, CFrame.new(0, 0.32, 0), body)
	part(m, Vector3.new(3.0, 0.16, 0.24), CFrame.new(1.8, 0.85, 0) * CFrame.Angles(0, 0, rad(35)), C(160, 168, 180), { Material = Enum.Material.Metal })
	return m
end

function Dish.burner()
	local m = newModel("Burner")
	disc(m, 3.4, 0.12, CFrame.new(0, 0.06, 0), C(30, 30, 34), { Material = Enum.Material.Metal })
	local glow = {}
	for i, d in { 2.6, 1.7, 0.9 } do
		local ringParts = {}
		for k = 1, 16 do
			local a = (k / 16) * math.pi * 2
			local cf = CFrame.new(0, 0.14, 0) * CFrame.Angles(0, a, 0) * CFrame.new(d / 2, 0, 0)
			local p = part(m, Vector3.new(0.14, 0.06, d * 0.21), cf, C(70, 60, 60), { Name = "Coil", Material = Enum.Material.SmoothPlastic })
			table.insert(glow, p)
		end
	end
	return m, glow
end

------------------------------------------------------------------ ingredients
-- Chop bodies: horizontal along X, centred at y = dia/2
Dish.ChopSpecs = {
	scallion = { len = 2.5, dia = 0.46, outer = C(96, 186, 72), inner = C(206, 238, 176), tip = C(246, 246, 232), tipLen = 0.5 },
	chashu = { len = 2.3, dia = 1.05, outer = C(142, 72, 44), inner = C(244, 172, 152) },
	tomato = { len = 2.2, dia = 1.55, outer = C(226, 46, 42), inner = C(255, 120, 96), round = true },
	strawberry = { len = 2.3, dia = 1.25, outer = C(232, 36, 66), inner = C(255, 172, 182), round = true },
	kiwi = { len = 2.3, dia = 1.2, outer = C(140, 104, 58), inner = C(132, 204, 58), round = true },
}
-- hero-sized on the board so cuts read clearly from the camera
for _, s in Dish.ChopSpecs do
	s.len *= 1.4
	s.dia *= 1.3
	if s.tipLen then
		s.tipLen *= 1.4
	end
end

-- Build a chop body split into segments at sorted cut positions (normalised -1..1).
-- cuts: { {x=, clean=bool} } ; returns model
-- Realistic fruit variant: whole fruit mesh lying on its side; once cut it becomes a fan of real slices,
-- grouped into the segments the player actually cut (wonky segments tilt).
local function meshChopBody(id: string, cuts, spec)
	local assets = ReplicatedStorage:FindFirstChild("CTTAssets")
	local sliceT = assets and assets:FindFirstChild(id .. "_slice")
	local wholeT = assets and assets:FindFirstChild(id)
	if not (sliceT and wholeT) then
		return nil
	end
	local m = newModel("Chop_" .. id)
	local half = spec.len / 2
	local r = spec.dia / 2
	if #cuts == 0 then
		local w = wholeT:Clone()
		local _, ext = w:GetBoundingBox()
		-- lie it on its side along X, stretched to the board length
		local s = math.min(spec.len / math.max(ext.Y, 0.01), spec.dia / math.max(ext.X, 0.01))
		w:ScaleTo(s)
		w:PivotTo(CFrame.new(0, r, 0) * CFrame.Angles(0, 0, math.rad(90)) * CFrame.new(0, -ext.Y * s / 2, 0))
		for _, d in w:GetChildren() do
			d.Parent = m
		end
		w:Destroy()
		return m
	end
	table.sort(cuts, function(a, b)
		return a.x < b.x
	end)
	local xs = { -1 }
	for _, c in cuts do
		table.insert(xs, c.x)
	end
	table.insert(xs, 1)
	local gap = 0.14
	local thick = 0.13
	for i = 1, #xs - 1 do
		local a, b = xs[i] * half, xs[i + 1] * half
		local segLen = math.max(0.1, b - a)
		local n = math.max(1, math.floor(segLen / 0.3 + 0.5))
		local shift = (i - (#xs) / 2) * gap
		local c = cuts[i - 1]
		local wob = (c and not c.clean) and math.rad(((i * 37) % 31) - 15) or 0
		for k = 1, n do
			local x = a + (k - 0.5) * segLen / n + shift
			-- taper toward the ends so the fan keeps the fruit silhouette
			local u = math.abs(x / half)
			local sz = spec.dia * math.clamp(1.05 - u * u * 0.55, 0.4, 1.05)
			local sl = sliceT:Clone()
			local mesh = sl:FindFirstChild("Mesh")
			if mesh then
				-- slice meshes are authored face-up: lay them shingled along the board (overlapping, leaning
				-- ~30deg like real sliced fruit falling over), so the cut face reads from the camera
				local lean = math.rad(32) + wob * 0.6
				mesh.CFrame = CFrame.new(x, sz * 0.32 + 0.04, 0) * CFrame.Angles(0, math.rad(90), 0) * CFrame.Angles(lean, 0, 0) * (mesh.CFrame - mesh.CFrame.Position)
				-- scale the face to the fruit diameter, keep the thinnest axis as slice thickness
				local sv = mesh.Size
				local face = math.max(sv.X, sv.Y, sv.Z)
				local f = sz / face
				mesh.Size = Vector3.new(
					sv.X == math.min(sv.X, sv.Y, sv.Z) and thick or sv.X * f,
					sv.Y == math.min(sv.X, sv.Y, sv.Z) and thick or sv.Y * f,
					sv.Z == math.min(sv.X, sv.Y, sv.Z) and thick or sv.Z * f
				)
				mesh.Parent = m
			end
			sl:Destroy()
		end
	end
	return m
end

function Dish.chopBody(id: string, cuts)
	local spec = Dish.ChopSpecs[id]
	local fancy = meshChopBody(id, table.clone(cuts), spec)
	if fancy then
		return fancy
	end
	local m = newModel("Chop_" .. id)
	local half = spec.len / 2
	local xs = { -1 }
	table.sort(cuts, function(a, b)
		return a.x < b.x
	end)
	for _, c in cuts do
		table.insert(xs, c.x)
	end
	table.insert(xs, 1)
	local r = spec.dia / 2
	local gap = 0.05
	for i = 1, #xs - 1 do
		local a, b = xs[i] * half, xs[i + 1] * half
		local len = math.max(0.04, b - a - gap)
		local cx = (a + b) / 2 + (i - (#xs) / 2) * gap * 1.6
		local cut = cuts[i] -- cut at the left side of segment i+1
		local wobble = CFrame.new()
		local c = cuts[i - 1]
		if c and not c.clean then
			wobble = CFrame.Angles(0, rad(((i * 37) % 21) - 10), rad(((i * 53) % 15) - 7))
		end
		local cf = CFrame.new(cx, r, 0) * wobble
		local body = rod(m, len, spec.dia, cf, spec.outer, { Name = "Seg" })
		if spec.round and (i == 1 or i == #xs - 1) then
			-- rounded outer ends
			local ex = i == 1 and -len / 2 or len / 2
			ball(m, Vector3.new(spec.dia * 0.7, spec.dia, spec.dia), cf * CFrame.new(ex, 0, 0), spec.outer)
		end
		if spec.tip and i == 1 then
			local tl = math.min(spec.tipLen, len)
			rod(m, tl, spec.dia * 1.02, cf * CFrame.new(-len / 2 + tl / 2, 0, 0), spec.tip)
		end
		-- inner cross-section faces at cut sides
		if i > 1 then
			rod(m, 0.03, spec.dia * 0.86, cf * CFrame.new(-len / 2 - 0.005, 0, 0), spec.inner)
		end
		if i < #xs - 1 then
			rod(m, 0.03, spec.dia * 0.86, cf * CFrame.new(len / 2 + 0.005, 0, 0), spec.inner)
		end
		if id == "kiwi" and i > 1 then
			for k = 1, 6 do
				local a2 = k / 6 * math.pi * 2
				part(m, Vector3.new(0.04, 0.07, 0.07), cf * CFrame.new(-len / 2 - 0.02, math.cos(a2) * r * 0.45, math.sin(a2) * r * 0.45), C(30, 24, 20))
			end
		end
		_ = cut
	end
	return m
end

local builders = {}

builders.noodles = function()
	local m = newModel("noodles")
	for i = 0, 9 do
		local z = (i % 5 - 2) * 0.14
		local y = 0.1 + math.floor(i / 5) * 0.13
		rod(m, 2.2, 0.12, CFrame.new(0, y, z), Dish.Colors.noodleRaw, { Attr = { Cook = "noodle" } })
	end
	part(m, Vector3.new(0.35, 0.34, 0.8), CFrame.new(0, 0.17, 0), C(230, 60, 60)) -- paper band
	return m
end

builders.egg = function()
	local m = newModel("egg")
	ball(m, Vector3.new(0.8, 1.0, 0.8), CFrame.new(0, 0.5, 0), C(250, 246, 236))
	return m
end

builders.egg_half = function()
	local m = newModel("egg_half")
	ball(m, Vector3.new(0.95, 0.42, 1.25), CFrame.new(0, 0.12, 0), C(252, 250, 244))
	ball(m, Vector3.new(0.58, 0.26, 0.66), CFrame.new(0, 0.24, 0.04), C(255, 150, 30), { Material = Enum.Material.Glass, Transparency = 0.05 })
	return m
end

builders.scallion = function()
	local s = Dish.ChopSpecs.scallion
	local m = newModel("scallion")
	rod(m, s.len, s.dia, CFrame.new(0, s.dia / 2, 0), s.outer)
	rod(m, s.tipLen, s.dia * 1.02, CFrame.new(-s.len / 2 + s.tipLen / 2, s.dia / 2, 0), s.tip)
	return m
end

builders.scallion_pile = function()
	local m = newModel("scallion_pile")
	local rng = Random.new(7)
	for i = 1, 11 do
		local x, z = rng:NextNumber(-0.42, 0.42), rng:NextNumber(-0.32, 0.32)
		local col = i % 3 == 0 and C(206, 238, 176) or C(96, 186, 72)
		disc(m, 0.24, 0.08, CFrame.new(x, 0.05 + rng:NextNumber(0, 0.08), z) * CFrame.Angles(rng:NextNumber(-0.4, 0.4), 0, rng:NextNumber(-0.4, 0.4)), col)
	end
	return m
end

builders.chashu = function()
	local s = Dish.ChopSpecs.chashu
	local m = newModel("chashu")
	rod(m, s.len, s.dia, CFrame.new(0, s.dia / 2, 0), s.outer)
	for _, x in { -0.6, 0, 0.6 } do
		rod(m, 0.06, s.dia * 1.03, CFrame.new(x, s.dia / 2, 0), C(240, 236, 220)) -- twine
	end
	return m
end

builders.chashu_slice = function()
	local m = newModel("chashu_slice")
	disc(m, 1.1, 0.14, CFrame.new(0, 0.07, 0), C(150, 76, 44))
	disc(m, 0.9, 0.16, CFrame.new(0, 0.08, 0), C(244, 172, 152))
	disc(m, 0.5, 0.17, CFrame.new(0.08, 0.085, 0.05), C(252, 214, 196))
	return m
end

builders.nori = function()
	local m = newModel("nori")
	part(m, Vector3.new(0.95, 1.3, 0.05), CFrame.new(0, 0.55, 0) * CFrame.Angles(rad(-18), 0, 0), C(28, 52, 34))
	return m
end

builders.banana = function()
	local m = newModel("banana")
	for i = -1, 1 do
		rod(m, 0.8, 0.36, CFrame.new(i * 0.6, 0.22 + math.abs(i) * 0.14, 0) * CFrame.Angles(0, 0, rad(-i * 22)), C(250, 220, 70))
	end
	part(m, Vector3.new(0.14, 0.14, 0.14), CFrame.new(-0.95, 0.42, 0), C(90, 70, 40))
	return m
end

builders.cheese = function()
	local m = newModel("cheese")
	local w = Instance.new("WedgePart")
	w.Anchored, w.CanCollide, w.CanTouch = true, false, false
	w.Size = Vector3.new(1.0, 0.7, 1.3)
	w.CFrame = CFrame.new(0, 0.35, 0)
	w.Color = C(255, 205, 60)
	w.Material = Enum.Material.SmoothPlastic
	w.Parent = m
	for _, p in { Vector3.new(0.51, 0.4, 0.1), Vector3.new(-0.2, 0.2, -0.3) } do
		ball(m, Vector3.new(0.18, 0.18, 0.18), CFrame.new(p.X * 0.95, p.Y, p.Z), C(230, 170, 40))
	end
	return m
end

builders.bun = function()
	local m = newModel("bun")
	disc(m, 1.6, 0.4, CFrame.new(0, 0.2, 0), C(222, 160, 82))
	ball(m, Vector3.new(1.65, 0.9, 1.65), CFrame.new(0, 0.55, 0), C(214, 140, 60))
	for i = 1, 6 do
		local a = i / 6 * math.pi * 2
		ball(m, Vector3.new(0.12, 0.06, 0.07), CFrame.new(math.cos(a) * 0.4, 0.98, math.sin(a) * 0.4) * CFrame.Angles(0, a, 0), C(250, 240, 210))
	end
	return m
end

builders.bun_bottom = function()
	local m = newModel("bun_bottom")
	disc(m, 2.6, 0.55, CFrame.new(0, 0.275, 0), C(220, 150, 72))
	disc(m, 2.45, 0.05, CFrame.new(0, 0.56, 0), C(240, 200, 140))
	return m
end

builders.bun_top = function()
	local m = newModel("bun_top")
	disc(m, 2.65, 0.25, CFrame.new(0, 0.12, 0), C(240, 196, 130))
	ball(m, Vector3.new(2.7, 1.5, 2.7), CFrame.new(0, 0.25, 0), C(214, 138, 56))
	local rng = Random.new(3)
	for i = 1, 14 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(0.1, 0.95)
		local y = 0.25 + 0.75 * math.sqrt(math.max(0, 1 - (r / 1.35) ^ 2))
		ball(m, Vector3.new(0.16, 0.07, 0.09), CFrame.new(math.cos(a) * r, y, math.sin(a) * r) * CFrame.Angles(0, a, 0), C(252, 244, 214))
	end
	return m
end

builders.patty = function()
	local m = newModel("patty")
	disc(m, 2.3, 0.42, CFrame.new(0, 0.21, 0), Dish.Colors.pattyRaw, { Material = Enum.Material.Sand, Attr = { Cook = "patty" } })
	return m
end

builders.patty_cooked = function()
	local m = newModel("patty_cooked")
	disc(m, 2.45, 0.42, CFrame.new(0, 0.21, 0), Dish.Colors.pattyIdeal, { Material = Enum.Material.Sand, Attr = { Cook = "patty" } })
	-- craggy smashed edge
	for i = 0, 13 do
		local a = i / 14 * math.pi * 2
		ball(m, Vector3.new(0.42, 0.34 + (i % 3) * 0.05, 0.42), CFrame.new(math.cos(a) * 1.2, 0.2, math.sin(a) * 1.2), Dish.Colors.pattyIdeal, { Material = Enum.Material.Sand, Attr = { Cook = "patty" } })
	end
	for i = 1, 4 do
		part(m, Vector3.new(1.9, 0.02, 0.08), CFrame.new(0, 0.43, -0.6 + i * 0.28) * CFrame.Angles(0, rad(30), 0), C(70, 40, 24))
	end
	return m
end

builders.cheese_slice = function()
	local m = newModel("cheese_slice")
	part(m, Vector3.new(2.3, 0.08, 2.3), CFrame.new(0, 0.04, 0) * CFrame.Angles(0, rad(45), 0), C(255, 196, 40))
	for i = 0, 3 do
		local a = rad(45 + i * 90)
		part(m, Vector3.new(0.5, 0.07, 0.4), CFrame.new(math.cos(a) * 1.55, -0.12, math.sin(a) * 1.55) * CFrame.Angles(0, -a, rad(-35)), C(255, 190, 36))
		-- melty drips
		ball(m, Vector3.new(0.18, 0.4, 0.18), CFrame.new(math.cos(a) * 1.72, -0.32, math.sin(a) * 1.72), C(255, 186, 30))
	end
	return m
end

builders.lettuce_leaf = function()
	local m = newModel("lettuce_leaf")
	-- ruffled frill: overlapping flattened ellipsoids around the rim
	for i = 0, 11 do
		local a = i / 12 * math.pi * 2
		local up = (i % 2) * 0.08
		local cf = CFrame.new(math.cos(a) * 1.18, 0.07 + up, math.sin(a) * 1.18) * CFrame.Angles(0, -a, rad(-12 + (i % 3) * 10))
		ball(m, Vector3.new(0.75, 0.09, 0.95), cf, i % 2 == 0 and C(104, 196, 64) or C(150, 222, 92))
	end
	ball(m, Vector3.new(2.3, 0.1, 2.3), CFrame.new(0, 0.06, 0), C(170, 232, 118))
	return m
end

builders.lettuce = function()
	local m = newModel("lettuce")
	for i = 0, 4 do
		ball(m, Vector3.new(1.3 - i * 0.1, 0.9, 1.2 - i * 0.12), CFrame.new(0, 0.45 + i * 0.06, 0) * CFrame.Angles(0, i, 0), i % 2 == 0 and C(110, 200, 70) or C(150, 225, 100))
	end
	return m
end

builders.tomato = function()
	local m = newModel("tomato")
	ball(m, Vector3.new(1.2, 1.05, 1.2), CFrame.new(0, 0.52, 0), C(226, 46, 42))
	for i = 0, 4 do
		local a = i / 5 * math.pi * 2
		part(m, Vector3.new(0.35, 0.05, 0.1), CFrame.new(math.cos(a) * 0.15, 1.04, math.sin(a) * 0.15) * CFrame.Angles(0, -a, 0), C(70, 150, 50))
	end
	return m
end

builders.tomato_slice = function()
	local m = newModel("tomato_slice")
	disc(m, 2.0, 0.16, CFrame.new(0, 0.08, 0), C(226, 46, 42))
	disc(m, 1.7, 0.17, CFrame.new(0, 0.085, 0), C(255, 110, 90))
	for i = 0, 4 do
		local a = i / 5 * math.pi * 2
		ball(m, Vector3.new(0.32, 0.18, 0.22), CFrame.new(math.cos(a) * 0.45, 0.12, math.sin(a) * 0.45) * CFrame.Angles(0, -a, 0), C(255, 196, 120))
	end
	return m
end

builders.fish = function()
	local m = newModel("fish")
	ball(m, Vector3.new(1.7, 0.7, 0.6), CFrame.new(0, 0.35, 0), C(120, 150, 180))
	local w = Instance.new("WedgePart")
	w.Anchored, w.CanCollide = true, false
	w.Size = Vector3.new(0.1, 0.7, 0.6)
	w.CFrame = CFrame.new(1.0, 0.35, 0) * CFrame.Angles(0, rad(90), 0)
	w.Color = C(100, 130, 165)
	w.Parent = m
	ball(m, Vector3.new(0.14, 0.14, 0.14), CFrame.new(-0.55, 0.45, 0.25), C(20, 20, 20))
	return m
end

builders.donut = function()
	local m = newModel("donut")
	for i = 0, 11 do
		local a = i / 12 * math.pi * 2
		ball(m, Vector3.new(0.5, 0.42, 0.5), CFrame.new(math.cos(a) * 0.48, 0.21, math.sin(a) * 0.48), C(214, 150, 80))
		ball(m, Vector3.new(0.48, 0.2, 0.48), CFrame.new(math.cos(a) * 0.48, 0.38, math.sin(a) * 0.48), C(255, 130, 190))
	end
	return m
end

builders.strawberry = function()
	local m = newModel("strawberry")
	ball(m, Vector3.new(0.9, 1.05, 0.9), CFrame.new(0, 0.52, 0), C(232, 36, 66))
	for i = 0, 4 do
		local a = i / 5 * math.pi * 2
		part(m, Vector3.new(0.4, 0.05, 0.14), CFrame.new(math.cos(a) * 0.15, 1.02, math.sin(a) * 0.15) * CFrame.Angles(0, -a, rad(-15)), C(80, 170, 60))
	end
	return m
end

builders.strawberry_slice = function()
	local m = newModel("strawberry_slice")
	ball(m, Vector3.new(0.85, 0.16, 1.0), CFrame.new(0, 0.08, 0), C(232, 36, 66))
	ball(m, Vector3.new(0.62, 0.17, 0.76), CFrame.new(0, 0.09, 0), C(255, 160, 175))
	return m
end

builders.kiwi = function()
	local m = newModel("kiwi")
	ball(m, Vector3.new(1.1, 0.9, 0.9), CFrame.new(0, 0.45, 0), C(140, 104, 58), { Material = Enum.Material.Sand })
	return m
end

builders.kiwi_slice = function()
	local m = newModel("kiwi_slice")
	disc(m, 1.15, 0.14, CFrame.new(0, 0.07, 0), C(120, 88, 50))
	disc(m, 1.06, 0.15, CFrame.new(0, 0.075, 0), C(118, 194, 46), { Material = Enum.Material.Glass, Transparency = 0.05 })
	disc(m, 0.62, 0.152, CFrame.new(0, 0.076, 0), C(160, 216, 80))
	disc(m, 0.3, 0.16, CFrame.new(0, 0.08, 0), C(244, 246, 210))
	for i = 0, 13 do
		local a = i / 14 * math.pi * 2
		ball(m, Vector3.new(0.07, 0.03, 0.1), CFrame.new(math.cos(a) * 0.24, 0.16, math.sin(a) * 0.24) * CFrame.Angles(0, -a, 0), C(22, 18, 14))
	end
	return m
end

builders.blueberry = function()
	local m = newModel("blueberry")
	for i, p in { Vector3.new(0, 0, 0), Vector3.new(0.38, 0, 0.1), Vector3.new(0.15, 0, 0.36), Vector3.new(0.18, 0.3, 0.15) } do
		ball(m, Vector3.new(0.42, 0.42, 0.42), CFrame.new(p.X - 0.18, 0.21 + p.Y, p.Z - 0.15), C(60, 70, 160))
	end
	return m
end

builders.blueberry_cluster = function()
	local m = newModel("blueberry_cluster")
	for i = 0, 5 do
		local a = i / 6 * math.pi * 2
		ball(m, Vector3.new(0.32, 0.32, 0.32), CFrame.new(math.cos(a) * 0.26, 0.16, math.sin(a) * 0.26), C(58, 66, 156))
	end
	ball(m, Vector3.new(0.34, 0.34, 0.34), CFrame.new(0, 0.38, 0), C(70, 80, 176))
	return m
end

builders.mint = function()
	local m = newModel("mint")
	for i = 0, 2 do
		ball(m, Vector3.new(0.45, 0.06, 0.8), CFrame.new(0, 0.25 + i * 0.12, 0) * CFrame.Angles(rad(30), i * 2.1, 0), C(70, 190, 100))
	end
	rod(m, 0.6, 0.06, CFrame.new(0, 0.2, 0) * CFrame.Angles(0, 0, rad(90)), C(60, 140, 70))
	return m
end

builders.mint_leaf = function()
	local m = newModel("mint_leaf")
	ball(m, Vector3.new(0.4, 0.06, 0.7), CFrame.new(-0.12, 0.08, 0) * CFrame.Angles(0, rad(25), rad(10)), C(70, 196, 100))
	ball(m, Vector3.new(0.4, 0.06, 0.7), CFrame.new(0.12, 0.08, 0) * CFrame.Angles(0, rad(-25), rad(-10)), C(90, 210, 116))
	return m
end

builders.onion = function()
	local m = newModel("onion")
	ball(m, Vector3.new(1.0, 0.95, 1.0), CFrame.new(0, 0.47, 0), C(150, 60, 120))
	part(m, Vector3.new(0.1, 0.25, 0.1), CFrame.new(0, 1.0, 0), C(200, 180, 140))
	return m
end

builders.chili = function()
	local m = newModel("chili")
	for i = 0, 2 do
		rod(m, 0.55, 0.3 - i * 0.07, CFrame.new(i * 0.45 - 0.4, 0.17 + i * 0.05, 0) * CFrame.Angles(0, 0, rad(i * 18)), C(220, 30, 30))
	end
	part(m, Vector3.new(0.25, 0.1, 0.1), CFrame.new(-0.75, 0.17, 0), C(60, 140, 50))
	return m
end

builders.yogurt = function()
	local m = newModel("yogurt")
	ringWall(m, 0.5, 0.6, 0.9, 0, 0.08, 14, C(250, 250, 252))
	disc(m, 1.15, 0.08, CFrame.new(0, 0.9, 0), C(120, 190, 255))
	return m
end

-- Optional smooth-tube builder (client sets this to an EditableMesh implementation)
Dish.TubeBuilder = nil

-- cooked noodle nest (used in bowl)
builders.noodle_nest = function()
	local m = newModel("noodle_nest")
	if Dish.TubeBuilder and Dish.meshAllowed then
		local rng = Random.new(11)
		local paths = {}
		for s = 1, 16 do
			local z0 = rng:NextNumber(-1.1, 1.1)
			local ph = rng:NextNumber(0, 6)
			local len = 2.8 - math.abs(z0) * 0.95
			local pts = {}
			for k = 0, 22 do
				local x = -len / 2 + len * k / 22
				local z = z0 + math.sin(k * 0.75 + ph) * 0.13
				local y = 0.05 + math.sin(k * 0.45 + ph) * 0.05 + (s % 3) * 0.02
				table.insert(pts, Vector3.new(x, y, z))
			end
			table.insert(paths, pts)
		end
		local mp = Dish.TubeBuilder(paths, 0.065)
		if mp then
			mp.Color = Dish.Colors.noodleIdeal
			mp:SetAttribute("Cook", "noodle")
			mp.Name = "Noodles"
			mp.Parent = m
			return m
		end
	end
	local rng = Random.new(11)
	for s = 1, 13 do
		local z0 = rng:NextNumber(-1.05, 1.05)
		local ph = rng:NextNumber(0, 6)
		local len = 2.6 - math.abs(z0) * 0.9
		local prev
		for k = 0, 8 do
			local x = -len / 2 + len * k / 8
			local z = z0 + math.sin(k * 1.4 + ph) * 0.14
			local y = 0.04 + math.sin(k * 0.9 + ph) * 0.05
			local pt = Vector3.new(x, y, z)
			if prev then
				local mid = (pt + prev) / 2
				local d = (pt - prev).Magnitude
				local cf = CFrame.lookAt(mid, pt) * CFrame.Angles(0, rad(90), 0)
				rod(m, d + 0.06, 0.13, cf, Dish.Colors.noodleIdeal, { Attr = { Cook = "noodle" } })
			end
			prev = pt
		end
	end
	return m
end

-- realistic topping meshes read better a little larger than life on the dish
Dish.ItemScale = { strawberry_slice = 1.2, kiwi_slice = 1.15, blueberry_cluster = 1.25, mint_leaf = 1.2 }

-- Optional real-slice builder (client sets this to the EditableMesh FruitMesh.slice)
Dish.SliceBuilder = nil
-- EditableMesh memory is tight and every visible mesh must stay alive, so live meshes are only
-- used for the player's own food during a run (Kitchen toggles this); previews use static assets.
Dish.meshAllowed = false
local SliceSpecs = { kiwi_slice = { "kiwi", 1.15, 0.16 }, strawberry_slice = { "strawberry", 1.05, 0.14 } }

function Dish.make(id: string): Model
	local sl = SliceSpecs[id]
	if sl and Dish.SliceBuilder and Dish.meshAllowed then
		local m = Dish.SliceBuilder(sl[1], sl[2], sl[3])
		if m then
			return m
		end
	end
	local assets = ReplicatedStorage:FindFirstChild("CTTAssets")
	local override = assets and assets:FindFirstChild(id)
	if override and override:IsA("Model") then
		local c = override:Clone()
		local sc = Dish.ItemScale[id]
		if sc then
			c:ScaleTo(sc)
		end
		return c
	end
	local b = builders[id]
	if b then
		return b()
	end
	if Dish[id] and typeof(Dish[id]) == "function" then
		return Dish[id]()
	end
	local m = newModel(id)
	ball(m, Vector3.new(0.6, 0.6, 0.6), CFrame.new(0, 0.3, 0), C(255, 0, 255))
	return m
end

------------------------------------------------------------------ doneness tint
local function lerp3(a: Color3, b: Color3, t: number)
	return a:Lerp(b, math.clamp(t, 0, 1))
end

function Dish.donenessColor(kind: string, d: number): Color3
	local K = Dish.Colors
	local raw, ideal, over, burnt
	if kind == "patty" then
		raw, ideal, over, burnt = K.pattyRaw, K.pattyIdeal, K.pattyOver, K.pattyBurnt
	else
		raw, ideal, over, burnt = K.noodleRaw, K.noodleIdeal, K.noodleOver, K.noodleBurnt
	end
	if d < 0.65 then
		return lerp3(raw, ideal, d / 0.65)
	elseif d < 0.85 then
		return lerp3(ideal, over, (d - 0.65) / 0.2)
	end
	return lerp3(over, burnt, (d - 0.85) / 0.25)
end

function Dish.tint(model: Instance, d: number)
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			local k = p:GetAttribute("Cook")
			if k then
				p.Color = Dish.donenessColor(k, d)
			end
		end
	end
end

------------------------------------------------------------------ helpers
function Dish.setTransparency(model: Instance, t: number)
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") and p.Name ~= "Root" then
			local base = p:GetAttribute("BaseT")
			if base == nil then
				base = p.Transparency
				p:SetAttribute("BaseT", base)
			end
			p.Transparency = base + (1 - base) * t
		end
	end
end

function Dish.setQueryable(model: Instance, on: boolean)
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			p.CanQuery = on and p.Name ~= "Root"
		end
	end
end

-- position on a vessel's food surface from normalised coords
function Dish.surfacePoint(kind: string, fill: number, x: number, z: number): Vector3
	local v = Dish.Vessels[kind]
	local y = v.fillY(fill)
	local r = Dish.vesselRadiusAt(kind, y) * 0.86
	return Vector3.new(x * r, y, z * r)
end

------------------------------------------------------------------ per-step "looks like" previews
-- A model showing what the food should look like right after step i (for the recipe card).
function Dish.stepPreview(recipeId: string, i: number): Model
	local Recipes = require(script.Parent.Recipes)
	local def = Recipes.Defs[recipeId]
	local step = def.steps[i]
	local m = newModel("Preview_" .. recipeId .. "_" .. i)
	local kind = step.type
	local function put(child: Model, cf: CFrame)
		child:PivotTo(cf)
		for _, d in child:GetChildren() do
			d.Parent = m
		end
		child:Destroy()
	end
	if kind == "pick" then
		local n = #step.required
		for k, id in step.required do
			local it = Dish.make(id)
			local _, ext = it:GetBoundingBox()
			local big = math.max(ext.X, ext.Z, ext.Y * 0.8)
			if big > 1.3 then
				it:ScaleTo(1.3 / big)
			end
			put(it, CFrame.new((k - (n + 1) / 2) * 1.5, 0, 0))
		end
	elseif kind == "chop" then
		local cuts = {}
		for _, g in step.guides do
			table.insert(cuts, { x = g, clean = true })
		end
		local b = Dish.chopBody(step.item, cuts)
		local _, ext = b:GetBoundingBox()
		b:ScaleTo(math.min(1, 4 / math.max(ext.X, 0.1)))
		put(b, CFrame.new())
	elseif kind == "heat" then
		if step.vessel == "pan" then
			local p = Dish.make("patty_cooked")
			Dish.tint(p, (step.ideal[1] + step.ideal[2]) / 2)
			put(p, CFrame.new())
		else
			local n = Dish.make("noodle_nest")
			Dish.tint(n, (step.ideal[1] + step.ideal[2]) / 2)
			put(n, CFrame.new())
		end
	elseif kind == "pour" and def.dish ~= "dessert" or (kind == "pour" and not step.drizzle) then
		local vesselKind = def.dish == "ramen" and "bowl" or "cup"
		put(Dish.make(vesselKind), CFrame.new())
		local y = Dish.Vessels[vesselKind].fillY(step.target)
		local r = Dish.vesselRadiusAt(vesselKind, y)
		local col = step.item == "broth" and Dish.Colors.broth or Dish.Colors.yogurt
		local liquid = newModel("liquid")
		disc(liquid, r * 2 - 0.1, 0.12, CFrame.new(0, y, 0), col)
		if vesselKind == "cup" then
			local y0 = Dish.Vessels.cup.fillY(0)
			local h = (y - y0) / 3
			for k = 1, 3 do
				local yb = y0 + (k - 1) * h
				disc(liquid, (Dish.vesselRadiusAt("cup", yb) - 0.06) * 2, h + 0.01, CFrame.new(0, yb + h / 2, 0), col)
			end
		end
		put(liquid, CFrame.new())
		if def.dish == "ramen" then
			local nest = Dish.make("noodle_nest")
			put(nest, CFrame.new(0, y + 0.02, 0))
		end
	else
		local f = Dish.final(recipeId)
		put(f, CFrame.new())
	end
	return m
end

------------------------------------------------------------------ finished dishes
-- Returns model + ordered list of "layers" (Models) for reveal animations.
-- opts.results (optional) lets the real cooked result drive appearance (not used for targets).
function Dish.final(recipeId: string)
	local Recipes = require(script.Parent.Recipes)
	local def = Recipes.Defs[recipeId]
	local m = newModel("Final_" .. recipeId)
	local layers = {}
	local function add(child: Model, cf: CFrame)
		child:PivotTo(cf)
		child.Parent = m
		table.insert(layers, child)
		return child
	end
	if def.dish == "ramen" then
		local bowl = Dish.make("bowl")
		bowl.Parent = m
		local pourStep, placeStep
		for _, s in def.steps do
			if s.type == "pour" then
				pourStep = s
			elseif s.type == "place" then
				placeStep = s
			end
		end
		local fill = pourStep.target
		local y = Dish.Vessels.bowl.fillY(fill)
		local r = Dish.vesselRadiusAt("bowl", y)
		local broth = newModel("broth")
		disc(broth, r * 2 - 0.05, 0.12, CFrame.new(0, 0, 0), Dish.Colors.broth, { Material = Enum.Material.Glass, Transparency = 0.08 })
		for i = 1, 7 do
			local a = i * 0.9
			disc(broth, 0.16 + (i % 3) * 0.06, 0.13, CFrame.new(math.cos(a) * r * 0.6, 0.005, math.sin(a) * r * 0.55), C(255, 220, 120))
		end
		add(broth, CFrame.new(0, y - 0.06, 0))
		add(Dish.make("noodle_nest"), CFrame.new(0, y - 0.04, 0))
		for _, t in placeStep.toppings do
			local p = Dish.surfacePoint("bowl", fill, t.slot[1], t.slot[2])
			local rot = CFrame.Angles(0, math.atan2(-t.slot[1], -t.slot[2]), 0)
			add(Dish.make(t.item), CFrame.new(p) * rot)
		end
		-- chopsticks
		local sticks = newModel("chopsticks")
		for _, z in { -0.12, 0.12 } do
			rod(sticks, 4.2, 0.1, CFrame.new(0, 0, z) * CFrame.Angles(0, rad(z * 20), 0), C(60, 40, 30), { Material = Enum.Material.Wood })
		end
		add(sticks, CFrame.new(0.6, 1.95, 1.2) * CFrame.Angles(0, rad(-25), rad(6)))
	elseif def.dish == "burger" then
		local plate = Dish.make("plate")
		plate.Parent = m
		local y = 0.2
		local bb = add(Dish.make("bun_bottom"), CFrame.new(0, y, 0))
		y += 0.56
		local heights = { patty_cooked = 0.42, cheese_slice = 0.09, lettuce_leaf = 0.14, tomato_slice = 0.16, bun_top = 1.0 }
		for _, s in def.steps do
			if s.type == "stack" then
				for _, l in s.layers do
					add(Dish.make(l.item), CFrame.new(0, y, 0))
					y += heights[l.item] or 0.2
				end
			end
		end
		local skewer = newModel("skewer")
		rod(skewer, 2.6, 0.07, CFrame.new(0, 1.3, 0) * CFrame.Angles(0, 0, rad(90)), C(230, 200, 150), { Material = Enum.Material.Wood })
		part(skewer, Vector3.new(0.05, 0.45, 0.7), CFrame.new(0, 2.4, 0.35), C(235, 60, 60))
		add(skewer, CFrame.new(0, y - 1.6, 0))
		_ = bb
	elseif def.dish == "dessert" then
		local cup = Dish.make("cup")
		local pours = {}
		local placeStep
		for _, s in def.steps do
			if s.type == "pour" then
				table.insert(pours, s)
			elseif s.type == "place" then
				placeStep = s
			end
		end
		local fill = pours[1].target
		local y = Dish.Vessels.cup.fillY(fill)
		local r = Dish.vesselRadiusAt("cup", y)
		local yog = newModel("yogurt_fill")
		local y0 = Dish.Vessels.cup.fillY(0)
		local h = (y - y0) / 3
		for k = 1, 3 do
			local yb = y0 + (k - 1) * h
			local rk = Dish.vesselRadiusAt("cup", yb) - 0.06
			disc(yog, rk * 2, h + 0.01, CFrame.new(0, yb + h / 2, 0), Dish.Colors.yogurt)
		end
		disc(yog, r * 2 - 0.08, 0.12, CFrame.new(0, y, 0), Dish.Colors.yogurt)
		add(yog, CFrame.new(0, 0, 0))
		for _, t in placeStep.toppings do
			local p = Dish.surfacePoint("cup", fill, t.slot[1], t.slot[2])
			add(Dish.make(t.item), CFrame.new(p) * CFrame.Angles(0, t.slot[1] * 2, 0))
		end
		local honey = newModel("honey_drizzle")
		local smooth = false
		if Dish.TubeBuilder and Dish.meshAllowed then
			-- one continuous zigzag ribbon of honey
			local pts = {}
			local rr = r * 0.78
			for k = 0, 60 do
				local t = k / 60
				local z = -rr + 2 * rr * t
				local w = math.sqrt(math.max(0, rr * rr - z * z))
				local x = math.sin(t * math.pi * 7) * w * 0.9
				table.insert(pts, Vector3.new(x, 0.02 + math.sin(t * 40) * 0.01, z))
			end
			local mp = Dish.TubeBuilder({ pts }, 0.045)
			if mp then
				mp.Color = Dish.Colors.honey
				mp.Material = Enum.Material.Glass
				mp.Transparency = 0.05
				mp.Parent = honey
				smooth = true
			end
		end
		if not smooth then
			for i = 0, 4 do
				rod(honey, r * 1.5, 0.07, CFrame.new(0, 0, -0.6 + i * 0.3) * CFrame.Angles(0, rad(15 - i * 8), 0), Dish.Colors.honey, { Material = Enum.Material.Glass, Transparency = 0.1 })
			end
		end
		add(honey, CFrame.new(0, y + 0.22, 0))
		cup.Parent = m -- glass last so it renders over
	end
	return m, layers
end

return Dish
