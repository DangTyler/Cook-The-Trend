--[[ Studio Device Simulator control (Edit datamodel, plugin context; HOLD THE STUDIO LEASE - the simulator is shared).
  & tools/bridge/run-luau.ps1 -Code ((Get-Content tests/ui/device-sim.luau -Raw) -replace '__DEVICE__','iPhone 14')
  & tools/bridge/run-luau.ps1 -Code ((Get-Content tests/ui/device-sim.luau -Raw) -replace '__DEVICE__','stop')
__DEVICE__ = a display name (exact or substring, e.g. "iPhone 14", "Galaxy A06", "iPad"), "list" or "stop".
Always run "stop" before releasing the lease (setters are refused while a Play server runs: set the device first).
]]
local WANT = "__DEVICE__"
local svc = game:GetService("StudioDeviceSimulatorService")
if WANT == "stop" then
	local ok, err = pcall(function()
		svc:StopSimulationAsync()
	end)
	task.wait(0.3)
	return "stop ok=" .. tostring(ok) .. " " .. tostring(err or "") .. " device=" .. tostring(svc:GetDeviceAsync())
		.. " viewport=" .. tostring(workspace.CurrentCamera.ViewportSize)
end
local ids = svc:GetDeviceListAsync()
local out, pick = {}, nil
for _, id in ipairs(ids) do
	local info = svc:GetDeviceInfoAsync(id)
	table.insert(out, string.format("%s | %s | %dx%d | %s", id, info.Name, info.Width, info.Height, tostring(info.DeviceForm)))
	if WANT ~= "list" and not pick and (info.Name == WANT or string.find(info.Name, WANT, 1, true)) then
		pick = id
	end
end
if WANT == "list" then
	return table.concat(out, "\n")
end
if not pick then
	return "NO_MATCH for " .. WANT .. "\n" .. table.concat(out, "\n")
end
pcall(function()
	svc:SetOrientationAsync(Enum.ScreenOrientation.LandscapeLeft)
end)
local ok, err = pcall(function()
	svc:SetDeviceAsync(pick)
end)
task.wait(0.4)
return "set " .. pick .. " ok=" .. tostring(ok) .. " " .. tostring(err or "") .. " viewport=" .. tostring(workspace.CurrentCamera.ViewportSize)
