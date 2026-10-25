-- The player's avatar stands behind the counter as the chef (faces the camera).
local spawn = workspace:FindFirstChildOfClass("SpawnLocation")
if not spawn then
  spawn = Instance.new("SpawnLocation")
  spawn.Parent = workspace
end
spawn.Anchored = true
spawn.Size = Vector3.new(2, 0.4, 1.4)
local pos = Vector3.new(0, 0.2, -4.3)
spawn.CFrame = CFrame.lookAt(pos, pos + Vector3.new(0, 0, 1))
spawn.Transparency = 1
spawn.CanCollide = true
spawn.Neutral = true
spawn.Duration = 0
return "spawn at " .. tostring(spawn.Position) .. " look " .. tostring(spawn.CFrame.LookVector)
