-- Cook the Trend: real mesh slicing with EditableMesh + EditableImage.
-- Each choppable ingredient is a lathe (surface of revolution) along X with a procedural texture atlas:
--   left half of the atlas = skin (u around, v along), right half = cross-section disc.
-- Cutting rebuilds the ingredient as separate pieces whose ends are true planar caps at the player's
-- cut positions (wonky cuts = tilted planes). Falls back to nil if the APIs are unavailable.
local AssetService = game:GetService("AssetService")

local FruitMesh = {}

local TEX_W, TEX_H = 256, 128
local RINGS_PER_UNIT = 9
local SIDES = 28

local C = Color3.fromRGB
local function clamp01(x)
	return math.clamp(x, 0, 1)
end
local function mix(a: Color3, b: Color3, t: number)
	return a:Lerp(b, clamp01(t))
end
local function hash(x: number, y: number): number
	local n = math.sin(x * 127.1 + y * 311.7) * 43758.5453
	return n - math.floor(n)
end

------------------------------------------------------------------ profiles (radius as fraction of R, t in 0..1)
local Profiles = {}
Profiles.strawberry = {
	radius = function(t)
		-- pointed tip at t=0, shoulders near the stem end
		local body = math.sin(math.min(1, t / 0.82) * math.pi / 2) ^ 0.75
		if t > 0.82 then
			body *= 1 - ((t - 0.82) / 0.18) ^ 2 * 0.32
		end
		return body
	end,
	capEnd = true, -- stem end is flat
}
Profiles.kiwi = {
	radius = function(t)
		return math.sqrt(math.max(0, 1 - (2 * t - 1) ^ 2)) ^ 0.85
	end,
}
Profiles.tomato = {
	radius = function(t)
		return math.sqrt(math.max(0, 1 - (2 * t - 1) ^ 2)) ^ 0.75
	end,
}
Profiles.scallion = {
	radius = function(t)
		return 1 - 0.12 * math.max(0, (t - 0.85) / 0.15)
	end,
	capStart = true,
	capEnd = true,
}
Profiles.chashu = {
	radius = function(t)
		return 1 - 0.18 * math.abs(2 * t - 1) ^ 10
	end,
	capStart = true,
	capEnd = true,
}

------------------------------------------------------------------ textures
local painters = {}
-- skin(u, v) -> Color3 ; cap(r, a) -> Color3   (r 0..1 from centre, a angle)
painters.strawberry = {
	skin = function(u, v)
		local base = mix(C(200, 22, 48), C(236, 46, 66), 0.5 + 0.5 * math.sin(v * 9 + u * 3))
		-- seed grid, offset every other row
		local su, sv = u * 18, v * 14
		local row = math.floor(sv)
		local fu = (su + (row % 2) * 0.5) % 1
		local fv = sv % 1
		local d = math.sqrt((fu - 0.5) ^ 2 + ((fv - 0.5) * 1.3) ^ 2)
		if d < 0.12 then
			return mix(C(250, 220, 90), C(210, 160, 40), d / 0.12)
		elseif d < 0.2 then
			return base:Lerp(C(150, 10, 30), 0.35)
		end
		return base:Lerp(C(255, 255, 255), hash(u * 50, v * 50) * 0.05)
	end,
	cap = function(r, a)
		if r > 0.9 then
			return C(214, 28, 52)
		end
		local streak = 0.5 + 0.5 * math.sin(a * 14)
		local flesh = mix(C(255, 92, 110), C(255, 150, 160), r < 0.55 and 1 - r / 0.55 or 0)
		flesh = flesh:Lerp(C(255, 225, 228), (r < 0.28 and (1 - r / 0.28) or 0) * 0.9)
		return flesh:Lerp(C(255, 200, 205), streak * 0.18 * (1 - r))
	end,
}
painters.kiwi = {
	skin = function(u, v)
		local n = hash(math.floor(u * 90), math.floor(v * 60))
		return mix(C(120, 84, 44), C(160, 120, 70), n)
	end,
	cap = function(r, a)
		if r > 0.94 then
			return C(120, 86, 46)
		end
		if r < 0.2 then
			return mix(C(250, 246, 214), C(214, 228, 150), r / 0.2)
		end
		-- seed ring
		local seedA = (a / (math.pi * 2) * 34) % 1
		if r > 0.3 and r < 0.42 and math.abs(seedA - 0.5) < 0.22 and math.abs((r - 0.36) / 0.06) < 0.8 then
			return C(24, 20, 16)
		end
		local streak = 0.5 + 0.5 * math.sin(a * 34)
		return mix(C(110, 186, 40), C(160, 220, 80), (r - 0.2) * 0.6 + streak * 0.15 * (r < 0.6 and 1 or 0))
	end,
}
painters.tomato = {
	skin = function(u, v)
		local shine = math.max(0, math.sin(u * math.pi * 2) * math.sin(v * math.pi)) ^ 6
		return mix(C(206, 32, 26), C(232, 52, 40), 0.5 + 0.5 * math.sin(v * 4)):Lerp(C(255, 200, 190), shine * 0.6)
	end,
	cap = function(r, a)
		if r > 0.88 then
			return C(214, 36, 30)
		end
		local lobe = math.cos(a * 3)
		if r > 0.25 and r < 0.75 and lobe > 0.15 then
			-- gel chamber with seeds
			local s = hash(math.floor(r * 22), math.floor(a * 9))
			if s > 0.82 then
				return C(250, 214, 120)
			end
			return C(255, 140, 96)
		end
		return mix(C(236, 70, 54), C(250, 120, 96), 1 - r)
	end,
}
painters.scallion = {
	skin = function(u, v)
		if v < 0.22 then
			return mix(C(246, 248, 232), C(210, 236, 180), v / 0.22)
		end
		local stripe = 0.5 + 0.5 * math.sin(u * math.pi * 2 * 9)
		return mix(C(70, 160, 56), C(110, 196, 80), stripe * 0.6)
	end,
	cap = function(r, a)
		local ring = 0.5 + 0.5 * math.sin(r * 26)
		return mix(C(200, 236, 170), C(236, 250, 220), ring)
	end,
}
painters.chashu = {
	skin = function(u, v)
		local n = hash(math.floor(u * 70), math.floor(v * 40))
		local twine = (v * 3.2) % 1 < 0.04
		if twine then
			return C(240, 232, 214)
		end
		return mix(C(110, 52, 28), C(164, 86, 46), n * 0.7 + 0.3 * math.sin(u * 20))
	end,
	cap = function(r, a)
		if r > 0.86 then
			return C(130, 62, 32)
		end
		-- spiral of fat through pink meat
		local spiral = math.sin(a * 1 + r * 22)
		if spiral > 0.75 then
			return C(252, 236, 222)
		end
		return mix(C(232, 150, 128), C(250, 190, 170), (1 - r) * 0.6)
	end,
}

local imageCache = {}
local imageBlocked = false -- EditableImage needs "Allow Mesh / Image APIs" in Experience Settings > Security
local function getImage(id: string)
	if imageBlocked then
		return nil
	end
	if imageCache[id] then
		return imageCache[id]
	end
	local p = painters[id]
	if not p then
		return nil
	end
	local okImg, img = pcall(function()
		return AssetService:CreateEditableImage({ Size = Vector2.new(TEX_W, TEX_H) })
	end)
	if not okImg or not img then
		imageBlocked = true
		warn("[CTT] EditableImage blocked; slicing uses vertex colours instead:", img)
		return nil
	end
	local buf = buffer.create(TEX_W * TEX_H * 4)
	local half = TEX_W / 2
	for y = 0, TEX_H - 1 do
		for x = 0, TEX_W - 1 do
			local col
			if x < half then
				col = p.skin(x / half, y / TEX_H)
			else
				local cx, cy = (x - half + 0.5) / half * 2 - 1, (y + 0.5) / TEX_H * 2 - 1
				local r = math.sqrt(cx * cx + cy * cy)
				col = p.cap(math.min(r, 1), math.atan2(cy, cx) + math.pi)
			end
			local o = (y * TEX_W + x) * 4
			buffer.writeu8(buf, o, math.floor(col.R * 255))
			buffer.writeu8(buf, o + 1, math.floor(col.G * 255))
			buffer.writeu8(buf, o + 2, math.floor(col.B * 255))
			buffer.writeu8(buf, o + 3, 255)
		end
		if y % 8 == 7 then
			task.wait() -- spread texture generation over many frames (no input hitches)
		end
	end
	img:WritePixelsBuffer(Vector2.zero, Vector2.new(TEX_W, TEX_H), buf)
	imageCache[id] = img
	return img
end

-- cap UV: map disc coords (-1..1) into the right half of the atlas
local function capUV(cy: number, cz: number)
	return Vector2.new(0.5 + (cy * 0.5 + 0.5) * 0.5, cz * 0.5 + 0.5)
end

------------------------------------------------------------------ geometry
-- Build one piece between plane A (x = xa + ta*y) and plane B (x = xb + tb*y) in normalised units
-- (-1..1 along the length). spec: { len, dia }. Returns EditableMesh, bounds min/max (studs).
-- emIn: append into an existing mesh (many pieces -> one live mesh; the client budget is tiny).
-- makeXf(min, max) -> function(Vector3) -> Vector3 : per-piece placement baked into the vertices.
local function buildPiece(id: string, spec, xa, ta, xb, tb, capA: boolean, capB: boolean, useColors: boolean, emIn, makeXf)
	local prof = Profiles[id]
	local paint = painters[id]
	local em = emIn or AssetService:CreateEditableMesh()
	if not em then
		error("EditableMesh budget unavailable right now")
	end
	local colorCache = {}
	local function colorId(col: Color3)
		local key = math.floor(col.R * 31) * 1024 + math.floor(col.G * 31) * 32 + math.floor(col.B * 31)
		local c = colorCache[key]
		if not c then
			c = em:AddColor(col, 1)
			colorCache[key] = c
		end
		return c
	end
	local half = spec.len / 2
	local R = spec.dia / 2
	local function rAt(xn)
		return R * prof.radius(clamp01((xn + 1) / 2))
	end
	local lenN = xb - xa
	local rings = math.max(2, math.floor(lenN * RINGS_PER_UNIT * spec.len / 2 + 0.5))
	local minV, maxV = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
	local function track(p)
		minV = minV:Min(p)
		maxV = maxV:Max(p)
	end
	local grid = {}
	for j = 0, rings do
		local s = j / rings
		grid[j] = {}
		for k = 0, SIDES do
			local th = k / SIDES * math.pi * 2
			local cy, cz = math.cos(th), math.sin(th)
			-- x on each tilted plane at this angle (using the radius at the plane)
			local xA = xa + ta * cy * rAt(xa) / half
			local xB = xb + tb * cy * rAt(xb) / half
			local xn = xA + (xB - xA) * s
			local r = rAt(xn)
			local p = Vector3.new(xn * half, cy * r, cz * r)
			track(p)
			grid[j][k] = { p = p, uvv = Vector2.new((k / SIDES) * 0.5, clamp01((xn + 1) / 2)) }
		end
	end
	local xf = makeXf and makeXf(minV, maxV) or function(p)
		return p
	end
	for j = 0, rings do
		for k = 0, SIDES do
			local g = grid[j][k]
			g.v = em:AddVertex(xf(g.p))
			g.uv = em:AddUV(g.uvv)
			g.c = useColors and colorId(paint.skin(g.uvv.X * 2, g.uvv.Y)) or nil
		end
	end
	for j = 0, rings - 1 do
		for k = 0, SIDES - 1 do
			local a, b, c, d = grid[j][k], grid[j + 1][k], grid[j + 1][k + 1], grid[j][k + 1]
			local f1 = em:AddTriangle(a.v, d.v, b.v)
			em:SetFaceUVs(f1, { a.uv, d.uv, b.uv })
			local f2 = em:AddTriangle(b.v, d.v, c.v)
			em:SetFaceUVs(f2, { b.uv, d.uv, c.uv })
			if useColors then
				em:SetFaceColors(f1, { a.c, d.c, b.c })
				em:SetFaceColors(f2, { b.c, d.c, c.c })
			end
		end
	end
	local function cap(j: number, facingNeg: boolean)
		local ring = grid[j]
		local sumP = Vector3.zero
		local rMax = 0.001
		for k = 0, SIDES - 1 do
			sumP += ring[k].p
		end
		local center = sumP / SIDES
		for k = 0, SIDES - 1 do
			rMax = math.max(rMax, (ring[k].p - center).Magnitude)
		end
		if useColors then
			-- concentric rings so the radial cross-section pattern (core, seeds, flesh) shows in vertex colours
			local RINGS = 9
			local prevV, prevC
			local cvC = em:AddVertex(xf(center))
			local cC = colorId(paint.cap(0, 0))
			for rr = 1, RINGS do
				local fr = rr / RINGS
				local vs, cs = {}, {}
				for k = 0, SIDES - 1 do
					local th = k / SIDES * math.pi * 2
					local pos = center + (ring[k].p - center) * fr
					vs[k] = em:AddVertex(xf(pos))
					cs[k] = colorId(paint.cap(fr, th + math.pi))
				end
				for k = 0, SIDES - 1 do
					local k2 = (k + 1) % SIDES
					if rr == 1 then
						local f = facingNeg and em:AddTriangle(cvC, vs[k], vs[k2]) or em:AddTriangle(cvC, vs[k2], vs[k])
						em:SetFaceColors(f, facingNeg and { cC, cs[k], cs[k2] } or { cC, cs[k2], cs[k] })
					else
						local a1, b1, c1, d1 = prevV[k], vs[k], vs[k2], prevV[k2]
						local ca, cb, cc, cd = prevC[k], cs[k], cs[k2], prevC[k2]
						local f1, f2
						if facingNeg then
							f1 = em:AddTriangle(a1, b1, c1)
							em:SetFaceColors(f1, { ca, cb, cc })
							f2 = em:AddTriangle(a1, c1, d1)
							em:SetFaceColors(f2, { ca, cc, cd })
						else
							f1 = em:AddTriangle(a1, c1, b1)
							em:SetFaceColors(f1, { ca, cc, cb })
							f2 = em:AddTriangle(a1, d1, c1)
							em:SetFaceColors(f2, { ca, cd, cc })
						end
					end
				end
				prevV, prevC = vs, cs
			end
			return
		end
		local cv = em:AddVertex(xf(center))
		local cuv = em:AddUV(capUV(0, 0))
		local uvs = {}
		for k = 0, SIDES do
			local off = ring[k].p - center
			uvs[k] = em:AddUV(capUV(off.Y / rMax, off.Z / rMax))
		end
		-- cap gets its own vertices so it shades flat (sharp edge against the skin)
		local cvs = {}
		for k = 0, SIDES do
			cvs[k] = em:AddVertex(xf(ring[k].p))
		end
		-- both windings (separate vertices so each side gets its own normal): caps read from either side
		local cv2 = em:AddVertex(xf(center))
		local cvs2 = {}
		for k = 0, SIDES do
			cvs2[k] = em:AddVertex(xf(ring[k].p))
		end
		for k = 0, SIDES - 1 do
			local f1 = em:AddTriangle(cv, cvs[k], cvs[k + 1])
			em:SetFaceUVs(f1, { cuv, uvs[k], uvs[k + 1] })
			local f2 = em:AddTriangle(cv2, cvs2[k + 1], cvs2[k])
			em:SetFaceUVs(f2, { cuv, uvs[k + 1], uvs[k] })
		end
	end
	if capA then
		cap(0, true)
	end
	if capB then
		cap(rings, false)
	end
	return em, minV, maxV
end

------------------------------------------------------------------ public
FruitMesh.supported = nil

function FruitMesh.has(id: string): boolean
	return Profiles[id] ~= nil
end

-- Build the whole/cut ingredient as a Model (pivot = bottom centre, like Dish builders).
-- cuts: { {x=, clean=} } normalised -1..1. Returns Model or nil on failure.
function FruitMesh.chopBody(id: string, spec, cuts)
	if FruitMesh.supported == false or not Profiles[id] then
		return nil
	end
	local tStart = os.clock()
	local ok, result = pcall(function()
		local prof = Profiles[id]
		local img = getImage(id)
		local model = Instance.new("Model")
		model.Name = "Chop_" .. id
		local root = Instance.new("Part")
		root.Name = "Root"
		root.Anchored = true
		root.CanCollide = false
		root.CanQuery = false
		root.Transparency = 1
		root.Size = Vector3.new(0.2, 0.2, 0.2)
		root.CFrame = CFrame.new()
		root.Parent = model
		model.PrimaryPart = root
		local sorted = table.clone(cuts)
		table.sort(sorted, function(a, b)
			return a.x < b.x
		end)
		local planes = { { x = -1, t = 0, cap = prof.capStart == true } }
		for i, c in sorted do
			-- wonky cuts lean; deterministic per index so rebuilds don't jitter
			local tilt = c.clean and 0 or ((i % 2 == 0) and 0.32 or -0.28)
			table.insert(planes, { x = c.x, t = tilt, cap = true })
		end
		table.insert(planes, { x = 1, t = 0, cap = prof.capEnd == true })
		local gap = 0.07 * math.min(1, 5 / #planes) -- studs between pieces (tighter when slices are thin)
		local R = spec.dia / 2
		-- every piece goes into ONE EditableMesh (the live-mesh budget is only a handful per client)
		local em = AssetService:CreateEditableMesh()
		if not em then
			error("EditableMesh budget unavailable right now")
		end
		local allMin, allMax = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
		for i = 1, #planes - 1 do
			local A, B = planes[i], planes[i + 1]
			if B.x - A.x > 0.02 then
				local spread = (i - #planes / 2) * gap
				local interior = i > 1 and i < #planes - 1
				buildPiece(id, spec, A.x, A.t, B.x, B.t, A.cap, B.cap, img == nil, em, function(mn, mx)
					local c = (mn + mx) / 2
					local place
					if interior then
						-- a slice cut on both sides topples over like a real one, cut face up toward the camera
						local w = mx.X - mn.X
						local rr = math.max(mx.Y - mn.Y, mx.Z - mn.Z) / 2
						local ang = math.rad(78)
						local h = rr * math.sin(math.rad(90) - ang) + w / 2 * math.cos(math.rad(90) - ang)
						place = CFrame.new(c.X + spread * 2.2, h + 0.03, c.Z + 0.35) * CFrame.Angles(math.rad(-12), 0, ang)
					else
						place = CFrame.new(c.X + spread * 2.2, c.Y + R, c.Z)
					end
					return function(p)
						local w = place:PointToWorldSpace(p - c)
						allMin = allMin:Min(w)
						allMax = allMax:Max(w)
						return w
					end
				end)
			end
		end
		local mp = AssetService:CreateMeshPartAsync(Content.fromObject(em))
		mp.Name = "Piece"
		mp.Anchored = true
		mp.CanCollide = false
		mp.CanTouch = false
		mp.CanQuery = false
		mp.Material = Enum.Material.SmoothPlastic
		if img then
			mp.TextureContent = Content.fromObject(img)
		end
		-- EditableMesh parts draw vertices relative to the part origin (no recentring): keep it at the model origin
		mp.CFrame = CFrame.new()
		mp.Parent = model
		mp.Destroying:Connect(function()
			em:Destroy()
		end)
		return model
	end)
	if not ok then
		FruitMesh.failures = (FruitMesh.failures or 0) + 1
		warn("[CTT] EditableMesh slice build failed (" .. FruitMesh.failures .. "), using fallback this time:", result)
		if FruitMesh.failures >= 3 then
			FruitMesh.supported = false
			task.delay(20, function()
				FruitMesh.supported = nil
				FruitMesh.failures = 0
			end)
		end
		return nil
	end
	FruitMesh.supported = true
	FruitMesh.builds = (FruitMesh.builds or 0) + 1
	local lp = game:GetService("Players").LocalPlayer
	if lp then
		lp:SetAttribute("CTT_FMBuilds", FruitMesh.builds)
		lp:SetAttribute("CTT_FMLastMs", math.floor((os.clock() - tStart) * 1000))
	end
	return result
end

-- A single crosswise slice lying flat, cut face up (toppings). Pivot = bottom centre. Synchronous-ish (one mesh).
function FruitMesh.slice(id: string, dia: number, thick: number)
	if not FruitMesh.ready or not Profiles[id] then
		return nil
	end
	local ok, model = pcall(function()
		local img = getImage(id)
		-- build from a long virtual fruit so the slice is near-cylindrical
		local spec = { len = 1.6, dia = dia }
		local tN = thick / (spec.len / 2)
		local em, mn, mx = buildPiece(id, spec, -tN / 2, 0, tN / 2, 0, true, true, img == nil)
		local mp = AssetService:CreateMeshPartAsync(Content.fromObject(em))
		mp.Name = "Slice"
		mp.Anchored = true
		mp.CanCollide = false
		mp.CanTouch = false
		mp.CanQuery = false
		mp.Material = Enum.Material.SmoothPlastic
		if img then
			mp.TextureContent = Content.fromObject(img)
		end
		mp.Destroying:Connect(function()
			em:Destroy()
		end)
		local m = Instance.new("Model")
		m.Name = id .. "_slice"
		local root = Instance.new("Part")
		root.Name = "Root"
		root.Anchored = true
		root.CanCollide = false
		root.CanQuery = false
		root.Transparency = 1
		root.Size = Vector3.new(0.2, 0.2, 0.2)
		root.CFrame = CFrame.new()
		root.Parent = m
		m.PrimaryPart = root
		-- lay it down: cut faces (normals along X) point up
		mp.CFrame = CFrame.new(0, thick / 2, 0) * CFrame.Angles(0, 0, math.rad(90))
		mp.Parent = m
		return m
	end)
	if ok then
		return model
	end
	warn("[CTT] slice mesh failed:", model)
	return nil
end

-- Smooth tubes along polylines (noodles, honey drizzle). One MeshPart for all paths.
-- paths: { {Vector3...}, ... } in model space; returns MeshPart positioned in that space, or nil.
function FruitMesh.tubes(paths, radius: number, sides: number?)
	if not FruitMesh.ready then
		return nil
	end
	sides = sides or 7
	local ok, part = pcall(function()
		local em = AssetService:CreateEditableMesh()
		if not em then
			error("no budget")
		end
		local minV, maxV = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
		-- build around the paths' centre (vertex coordinates are mesh-local)
		local c0 = Vector3.zero
		local cnt = 0
		for _, pts in paths do
			for _, p in pts do
				c0 += p
				cnt += 1
			end
		end
		c0 /= math.max(cnt, 1)
		for _, pts in paths do
			local rings = {}
			for i, p in pts do
				local prev = pts[math.max(1, i - 1)]
				local nxt = pts[math.min(#pts, i + 1)]
				local t = (nxt - prev)
				if t.Magnitude < 1e-4 then
					t = Vector3.xAxis
				end
				t = t.Unit
				local up = math.abs(t.Y) < 0.95 and Vector3.yAxis or Vector3.xAxis
				local n1 = t:Cross(up).Unit
				local n2 = t:Cross(n1).Unit
				-- taper the ends a little so strands don't look chopped
				local r = radius * ((i == 1 or i == #pts) and 0.6 or 1)
				local ring = {}
				for k = 0, sides - 1 do
					local a = k / sides * math.pi * 2
					local radial = n1 * math.cos(a) + n2 * math.sin(a)
					local v = p + radial * r - c0
					minV = minV:Min(v)
					maxV = maxV:Max(v)
					ring[k] = { v = em:AddVertex(v), n = em:AddNormal(radial), uv = em:AddUV(Vector2.new(k / sides, i / #pts)) }
				end
				rings[i] = ring
			end
			for i = 1, #pts - 1 do
				local A, B = rings[i], rings[i + 1]
				for k = 0, sides - 1 do
					local k2 = (k + 1) % sides
					-- outward-facing winding (front faces are counter-clockwise seen from outside)
					local f1 = em:AddTriangle(A[k].v, B[k2].v, B[k].v)
					em:SetFaceNormals(f1, { A[k].n, B[k2].n, B[k].n })
					em:SetFaceUVs(f1, { A[k].uv, B[k2].uv, B[k].uv })
					local f2 = em:AddTriangle(A[k].v, A[k2].v, B[k2].v)
					em:SetFaceNormals(f2, { A[k].n, A[k2].n, B[k2].n })
					em:SetFaceUVs(f2, { A[k].uv, A[k2].uv, B[k2].uv })
				end
			end
		end
		local mp = AssetService:CreateMeshPartAsync(Content.fromObject(em))
		mp.Anchored = true
		mp.CanCollide = false
		mp.CanTouch = false
		mp.CanQuery = false
		mp.Material = Enum.Material.SmoothPlastic
		mp.CFrame = CFrame.new(c0 + (minV + maxV) / 2)
		mp.Destroying:Connect(function()
			em:Destroy()
		end)
		return mp
	end)
	if ok then
		return part
	end
	warn("[CTT] tube mesh failed:", part)
	return nil
end

-- The EditableMesh memory budget is not always available right after joining: probe until it is.
FruitMesh.ready = false
function FruitMesh.warmup()
	task.spawn(function()
		for attempt = 1, 60 do
			local ok, em = pcall(function()
				return AssetService:CreateEditableMesh()
			end)
			if ok and em then
				em:Destroy()
				FruitMesh.ready = true
				return
			end
			task.wait(2)
		end
		warn("[CTT] EditableMesh never became available; using primitive slicing")
	end)
end

-- warm the texture cache so the first cut doesn't hitch
function FruitMesh.preload(id: string)
	if Profiles[id] and FruitMesh.supported ~= false then
		task.spawn(function()
			pcall(getImage, id)
		end)
	end
end

return FruitMesh
