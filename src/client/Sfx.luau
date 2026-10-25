-- Cook the Trend: sound cues (licensed Creator Store audio, see REFERENCES.md). Missing audio never blocks play.
local SoundService = game:GetService("SoundService")
local ContentProvider = game:GetService("ContentProvider")

local Sfx = {}

-- cue -> { ids (variants), volume, speed range, loop }
Sfx.Cues = {
	chop = { ids = { 71805435183945, 9120916820 }, volume = 0.7, pitch = { 0.92, 1.12 } },
	chopWood = { ids = { 9120809783 }, volume = 0.35, pitch = { 0.95, 1.1 } },
	sizzle = { ids = { 9114542867 }, volume = 0.45, loop = true },
	boil = { ids = { 1075001850 }, volume = 0.4, loop = true },
	pour = { ids = { 9117866003 }, volume = 0.6, loop = true },
	plop = { ids = { 18145114696, 90416226721742 }, volume = 0.6, pitch = { 0.9, 1.15 } },
	whoosh = { ids = { 127438224839678 }, volume = 0.35, pitch = { 0.95, 1.1 } },
	click = { ids = { 8755541422 }, volume = 0.45, pitch = { 0.95, 1.08 } },
	coins = { ids = { 1169806635 }, volume = 0.5 },
	cash = { ids = { 101396758527961 }, volume = 0.45 },
	jingle = { ids = { 1848281810 }, volume = 0.55 },
	cheer = { ids = { 113430121081082 }, volume = 0.4 },
	fail = { ids = { 75792831408247 }, volume = 0.45 },
	aww = { ids = { 9114010279 }, volume = 0.35 },
	buzz = { ids = { 94135799095134 }, volume = 0.3 },
	splat = { ids = { 87295773843957 }, volume = 0.45 },
	ding = { ids = { 9114059172 }, volume = 0.45 },
	sparkle = { ids = { 9126073001 }, volume = 0.35, pitch = { 0.95, 1.15 } },
	music = { ids = { 121736147160985 }, volume = 0.16, loop = true },
	steam = { ids = { 4772620521 }, volume = 0.3 },
	crunch = { ids = { 92009203113499 }, volume = 0.5, pitch = { 0.9, 1.1 } },
	thud = { ids = { 9113568548 }, volume = 0.4, pitch = { 0.9, 1.1 } },
}

local group = Instance.new("SoundGroup")
group.Name = "CTT_SFX"
group.Volume = 1
group.Parent = SoundService
local musicGroup = Instance.new("SoundGroup")
musicGroup.Name = "CTT_Music"
musicGroup.Volume = 1
musicGroup.Parent = SoundService

local folder = Instance.new("Folder")
folder.Name = "CTT_Sounds"
folder.Parent = SoundService

local templates = {} -- cue -> { Sound }
Sfx.Status = {} -- id -> "ok" | "failed"
local muted = false
local volume = 1
local lastPlay = {}

for cue, def in Sfx.Cues do
	templates[cue] = {}
	for _, id in def.ids do
		local s = Instance.new("Sound")
		s.Name = cue
		s.SoundId = "rbxassetid://" .. id
		s.Volume = def.volume
		s.Looped = def.loop == true
		s.SoundGroup = cue == "music" and musicGroup or group
		s.Parent = folder
		table.insert(templates[cue], s)
	end
end

task.spawn(function()
	local list = {}
	for _, arr in templates do
		for _, s in arr do
			table.insert(list, s)
		end
	end
	pcall(function()
		ContentProvider:PreloadAsync(list, function(assetId, status)
			Sfx.Status[assetId] = status == Enum.AssetFetchStatus.Success and "ok" or "failed"
		end)
	end)
end)

local function pick(cue)
	local arr = templates[cue]
	if not arr or #arr == 0 then
		return nil
	end
	-- prefer variants that loaded
	local ok = {}
	for _, s in arr do
		if Sfx.Status[s.SoundId] ~= "failed" then
			table.insert(ok, s)
		end
	end
	if #ok == 0 then
		return nil
	end
	return ok[math.random(1, #ok)]
end

function Sfx.play(cue: string, opts)
	if muted then
		return nil
	end
	-- anti-stacking: same cue no more than every 45 ms
	local now = os.clock()
	if lastPlay[cue] and now - lastPlay[cue] < 0.045 then
		return nil
	end
	lastPlay[cue] = now
	local t = pick(cue)
	if not t then
		return nil
	end
	local def = Sfx.Cues[cue]
	local s = t:Clone()
	s.Looped = false
	if def.pitch then
		s.PlaybackSpeed = def.pitch[1] + math.random() * (def.pitch[2] - def.pitch[1])
	end
	if opts and opts.volume then
		s.Volume = def.volume * opts.volume
	end
	if opts and opts.speed then
		s.PlaybackSpeed = opts.speed
	end
	s.Parent = folder
	s:Play()
	task.delay(math.max(2, (s.TimeLength > 0 and s.TimeLength or 4) + 0.5), function()
		s:Destroy()
	end)
	if opts and opts.maxLength then
		task.delay(opts.maxLength, function()
			if s.Parent then
				s:Stop()
				s:Destroy()
			end
		end)
	end
	return s
end

-- Looping sound handle: { setVolume(v), stop() }
local activeLoops = {}
function Sfx.loop(cue: string, vol: number?)
	local t = pick(cue)
	local def = Sfx.Cues[cue]
	local handle = { cue = cue }
	local s
	if t then
		s = t:Clone()
		s.Looped = true
		s.Volume = def.volume * (vol or 1)
		s.Parent = folder
		s:Play() -- mute is handled by the SoundGroup volume
	end
	function handle.setVolume(v: number)
		if s then
			s.Volume = def.volume * v
		end
	end
	function handle.setSpeed(v: number)
		if s then
			s.PlaybackSpeed = v
		end
	end
	function handle.stop()
		activeLoops[handle] = nil
		if s then
			s:Stop()
			s:Destroy()
			s = nil
		end
	end
	activeLoops[handle] = true
	return handle
end

function Sfx.stopAllLoops(exceptMusic: boolean?)
	for h in activeLoops do
		if not (exceptMusic and h.cue == "music") then
			h.stop()
		end
	end
end

function Sfx.setMuted(m: boolean)
	muted = m
	group.Volume = m and 0 or volume
	musicGroup.Volume = m and 0 or volume
end

function Sfx.isMuted()
	return muted
end

function Sfx.setVolume(v: number)
	volume = math.clamp(v, 0, 1)
	if not muted then
		group.Volume = volume
		musicGroup.Volume = volume
	end
end

function Sfx.getVolume()
	return volume
end

return Sfx
