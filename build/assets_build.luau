-- Wrap vetted generated meshes (workspace.GenStage) into ReplicatedStorage.CTTAssets overrides.
-- Each override: Model named after the Dish builder id, PrimaryPart "Root" at bottom-centre (origin).
local RS = game:GetService("ReplicatedStorage")
local stage = workspace:FindFirstChild("GenStage")
local assets = RS:FindFirstChild("CTTAssets") or Instance.new("Folder")
assets.Name = "CTTAssets"
assets.Parent = RS
local C = Color3.fromRGB

local function meshOf(name)
	local m = stage and stage:FindFirstChild(name)
	if not m then return nil end
	return m:FindFirstChildWhichIsA("MeshPart", true)
end

local function wrap(id, mesh, size, yaw, extras)
	local old = assets:FindFirstChild(id)
	if old then old:Destroy() end
	local model = Instance.new("Model")
	model.Name = id
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Anchored = true
	root.CanCollide = false
	root.CanQuery = false
	root.CanTouch = false
	root.Transparency = 1
	root.Size = Vector3.new(0.2, 0.2, 0.2)
	root.CFrame = CFrame.new()
	root.Parent = model
	model.PrimaryPart = root
	local mp = mesh:Clone()
	for _, d in mp:GetChildren() do
		if d:IsA("LuaSourceContainer") then d:Destroy() end
	end
	mp.Name = "Mesh"
	mp.Anchored = true
	mp.CanCollide = false
	mp.CanTouch = false
	mp.CanQuery = false
	mp.Size = size
	mp.CFrame = CFrame.new(0, size.Y / 2, 0) * CFrame.Angles(0, math.rad(yaw or 0), 0)
	mp.Parent = model
	if extras then extras(model) end
	model.Parent = assets
	return model
end

local function disc(parent, name, dia, h, y, color, mat, transp)
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = Enum.PartType.Cylinder
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Size = Vector3.new(h, dia, dia)
	p.CFrame = CFrame.new(0, y, 0) * CFrame.Angles(0, 0, math.rad(90))
	p.Color = color
	p.Material = mat or Enum.Material.SmoothPlastic
	p.Transparency = transp or 0
	p.Parent = parent
	return p
end

local done = {}
local bowl = meshOf("Gen_bowl")
if bowl then
	wrap("bowl", bowl, Vector3.new(4.4, 2.0, 4.4), 0)
	table.insert(done, "bowl")
end
local pot = meshOf("Gen_pot")
if pot then
	wrap("pot", pot, Vector3.new(3.6, 2.1, 2.9), 0, function(m)
		disc(m, "Water", 2.55, 0.1, 1.45, C(140, 196, 236), Enum.Material.Glass, 0.5)
		disc(m, "WaterBody", 2.5, 1.0, 0.9, C(120, 180, 225), Enum.Material.Glass, 0.72)
	end)
	table.insert(done, "pot")
end
local pan = meshOf("Gen_pan")
if pan then
	wrap("pan", pan, Vector3.new(3.1, 0.75, 3.5), 0)
	table.insert(done, "pan")
end
-- realistic fruit (generated meshes), oriented so cut faces point up
local function wrapRot(id, stageName, localSize, rot, worldH)
	local m = meshOf(stageName)
	if not m then return end
	local model = wrap(id, m, localSize, 0)
	local mp = model.Mesh
	mp.CFrame = CFrame.new(0, worldH / 2, 0) * rot
	table.insert(done, id)
end
wrapRot("strawberry_slice", "Gen_strawberry_slice", Vector3.new(1.0, 1.15, 0.18), CFrame.Angles(-math.pi / 2, 0, 0), 0.18)
wrapRot("kiwi_slice", "Gen_kiwi_slice", Vector3.new(0.18, 1.05, 1.05), CFrame.Angles(0, 0, -math.pi / 2), 0.18)
wrapRot("blueberry_cluster", "Gen_blueberry_cluster", Vector3.new(0.95, 0.48, 0.95), CFrame.new(), 0.48)
wrapRot("mint_leaf", "Gen_mint_leaf", Vector3.new(0.95, 0.3, 0.95), CFrame.new(), 0.3)
wrapRot("strawberry", "Gen_strawberry", Vector3.new(0.95, 1.2, 0.95), CFrame.new(), 1.2)
-- whole kiwi reads as a peach; a halved kiwi (cut face up-front) is instantly recognisable
wrapRot("kiwi", "Gen_kiwi_slice", Vector3.new(0.9, 1.05, 1.05), CFrame.Angles(0, math.rad(-35), 0), 1.05)
wrapRot("mint", "Gen_mint_leaf", Vector3.new(1.3, 0.45, 1.3), CFrame.new(), 0.45)
wrapRot("blueberry", "Gen_blueberry_cluster", Vector3.new(1.2, 0.6, 1.2), CFrame.new(), 0.6)
for _, id in { "knife", "board", "plate", "ladle" } do
	local m = meshOf("Gen_" .. id)
	if m then
		table.insert(done, id .. "(staged, not wrapped)")
	end
end
return table.concat(done, ", ")
