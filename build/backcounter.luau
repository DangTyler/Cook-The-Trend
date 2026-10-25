local bc = workspace.Kitchen.BackCounter
for _, p in bc:GetChildren() do
  if p:IsA("BasePart") and p.Size.Y > 5 then p.Color = Color3.fromRGB(255, 232, 222) end
end
if not bc:FindFirstChild("Door") then
  for i = 0, 15 do
    local x = -30 + i * 4
    local d = Instance.new("Part") d.Name = "Door" d.Anchored = true d.CanCollide = false d.CanQuery = false
    d.Size = Vector3.new(3.6, 4.6, 0.1) d.CFrame = CFrame.new(x, 2.75, -5.06) d.Color = Color3.fromRGB(255, 242, 234) d.Parent = bc
    local h = Instance.new("Part") h.Name = "Handle" h.Anchored = true h.CanCollide = false h.CanQuery = false
    h.Size = Vector3.new(0.15, 0.9, 0.15) h.CFrame = CFrame.new(x + 1.4, 3.6, -4.95) h.Color = Color3.fromRGB(235, 190, 90) h.Material = Enum.Material.Metal h.Parent = bc
  end
end
return "ok"
