local Lighting = game:GetService("Lighting")
local C = Color3.fromRGB
Lighting.Brightness = 0.9
Lighting.ClockTime = 16.8
Lighting.Ambient = C(96, 80, 86)
Lighting.OutdoorAmbient = C(120, 104, 108)
Lighting.ExposureCompensation = -0.25
Lighting.EnvironmentDiffuseScale = 0.35
Lighting.EnvironmentSpecularScale = 0.4
local cc = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
if cc then cc.Saturation = 0.2 cc.Contrast = 0.12 cc.Brightness = 0 end
local b = Lighting:FindFirstChildOfClass("BloomEffect")
if b then b.Intensity = 0.25 b.Threshold = 2 b.Size = 18 end
local k = workspace.Kitchen
for _, l in k:GetDescendants() do
	if l:IsA("PointLight") and l.Parent.Parent and l.Parent.Parent.Name == "Lamps" then
		l.Brightness = 0.9
		l.Range = 20
	end
end
local fill = k:FindFirstChild("FillLight")
if fill then fill.SpotLight.Brightness = 0.55 end
-- roof so the sun doesn't flood the counter
local roof = k.Room:FindFirstChild("Roof")
if not roof then
	roof = Instance.new("Part")
	roof.Name = "Roof"
	roof.Anchored = true
	roof.Size = Vector3.new(70, 1, 44)
	roof.CFrame = CFrame.new(0, 22.5, 12)
	roof.Color = C(255, 236, 226)
	roof.CastShadow = true
	roof.Parent = k.Room
end
return "ok"

