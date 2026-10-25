-- Cook the Trend: deterministic rules for every step type.
-- The client uses these for live visuals; the server re-runs them on the submitted event times to score.
-- Event times are seconds since the step started (client clock), validated against server elapsed time.

local Config = require(script.Parent.Config)

local StepMath = {}

local function clamp(x: number, a: number, b: number): number
	return math.max(a, math.min(b, x))
end
StepMath.clamp = clamp

local function num(v: any, default: number): number
	if typeof(v) == "number" and v == v and v > -1e6 and v < 1e6 then
		return v
	end
	return default
end
StepMath.num = num

----------------------------------------------------------------- chop
-- Knife slides from -1.15 to +1.15 across the ingredient at step.speed units/sec.
StepMath.ChopStart = -1.15
StepMath.ChopSpan = 2.3
StepMath.ChopWindow = 0.15

-- Per-step hit window: dense guides (thin slices) get a proportionally tighter window
function StepMath.chopWindow(step): number
	local gmin = math.huge
	for i = 2, #step.guides do
		gmin = math.min(gmin, math.abs(step.guides[i] - step.guides[i - 1]))
	end
	if gmin == math.huge then
		return StepMath.ChopWindow
	end
	return math.min(StepMath.ChopWindow, gmin * 0.42)
end

function StepMath.chopDuration(step): number
	return StepMath.ChopSpan / step.speed
end

function StepMath.knifeX(step, t: number): number
	return StepMath.ChopStart + step.speed * t
end

-- taps: { number } (times). Returns quality, details { cuts = {x...}, hits = {guideIndex -> q}, extra = n }
function StepMath.evalChop(step, taps: { number })
	local cuts = {}
	for _, t in taps do
		local x = StepMath.knifeX(step, t)
		if x >= -1.0 and x <= 1.0 then
			table.insert(cuts, x)
		end
	end
	local W = StepMath.chopWindow(step)
	local hits = {}
	local used = {}
	for gi, g in step.guides do
		local best, bestI = nil, nil
		for ci, x in cuts do
			if not used[ci] then
				local d = math.abs(x - g)
				if d <= W and (best == nil or d < best) then
					best, bestI = d, ci
				end
			end
		end
		if bestI then
			used[bestI] = true
			hits[gi] = 1 - (best / W) * 0.4
		else
			hits[gi] = 0
		end
	end
	local extra = 0
	for ci in cuts do
		if not used[ci] then
			extra += 1
		end
	end
	local sum = 0
	for gi in step.guides do
		sum += hits[gi]
	end
	local q = sum / #step.guides - 0.04 * extra
	q = clamp(q, 0, 1)
	local label
	if q >= 0.85 then
		label = "Clean cuts"
	elseif q >= 0.55 then
		label = "Decent cuts"
	else
		label = "Chunky chaos"
	end
	return q, { cuts = cuts, hits = hits, extra = extra }, label
end

-- Feedback for a single cut at x (client-side juice only)
function StepMath.cutGrade(step, x: number): (string, number)
	local best = math.huge
	for _, g in step.guides do
		best = math.min(best, math.abs(x - g))
	end
	local W = StepMath.chopWindow(step)
	if best <= W * 0.4 then
		return "PERFECT", 1
	elseif best <= W then
		return "GOOD", 0.7
	end
	return "WONKY", 0
end

----------------------------------------------------------------- heat
StepMath.FlipPause = 0.7 -- seconds between phases while the item flips

-- phase start time for phase k given previous tap times
function StepMath.heatPhaseStart(taps: { number }, k: number): number
	if k == 1 then
		return 0
	end
	return taps[k - 1] + StepMath.FlipPause
end

function StepMath.heatDoneness(step, elapsedInPhase: number): number
	return math.max(0, elapsedInPhase) / step.fullTime
end

function StepMath.gradeDoneness(step, d: number): (number, string)
	local lo, hi = step.ideal[1], step.ideal[2]
	local c, half = (lo + hi) / 2, (hi - lo) / 2
	local off = math.abs(d - c)
	local q
	if d >= Config.BurntAt then
		q = 0
	elseif off <= half then
		q = 1 - 0.15 * (off / half)
	else
		q = clamp(0.85 - (off - half) / 0.22, 0, 0.85)
	end
	local label
	if d >= Config.BurntAt then
		label = "Burnt to a crisp"
	elseif d > hi then
		label = "A little burnt"
	elseif d < lo then
		label = d < lo - 0.2 and "Basically raw" or "A bit underdone"
	elseif off <= half * 0.4 then
		label = "Perfect cook"
	else
		label = "Great cook"
	end
	return q, label
end

function StepMath.evalHeat(step, taps: { number })
	local ds, qs, labels = {}, {}, {}
	local sum = 0
	for k = 1, #step.phases do
		local t = taps[k]
		local start = StepMath.heatPhaseStart(taps, k)
		local d = StepMath.heatDoneness(step, (t or start) - start)
		local q, label = StepMath.gradeDoneness(step, d)
		ds[k], qs[k], labels[k] = d, q, label
		sum += q
	end
	local q = sum / #step.phases
	-- report the worst label (most informative)
	local worstK = 1
	for k = 2, #step.phases do
		if qs[k] < qs[worstK] then
			worstK = k
		end
	end
	return q, { doneness = ds, qualities = qs, labels = labels }, labels[worstK]
end

----------------------------------------------------------------- pour
-- events: { {down, up}, ... } amount = sum(up - down) * rate
function StepMath.pourAmount(step, pulses): number
	local a = 0
	for _, p in pulses do
		a += math.max(0, p[2] - p[1]) * step.rate
	end
	return a
end

function StepMath.gradePour(step, a: number): (number, string)
	local diff = a - step.target
	local tol = step.drizzle and 0.18 or 0.28
	local q = clamp(1 - math.abs(diff) / tol, 0, 1)
	if a > 1.0 then
		q *= 0.5
	end
	local label
	if a > 1.0 then
		label = "Spilled everywhere!"
	elseif math.abs(diff) <= tol * 0.2 then
		label = step.drizzle and "Perfect drizzle" or "Perfect pour"
	elseif diff > 0 then
		label = step.drizzle and "Honey overload" or "A bit much"
	else
		label = "A little light"
	end
	return q, label
end

function StepMath.evalPour(step, pulses)
	local a = StepMath.pourAmount(step, pulses)
	local q, label = StepMath.gradePour(step, a)
	return q, { amount = a }, label
end

----------------------------------------------------------------- place
-- events: { {x, z}, ... } one per topping in order
function StepMath.gradePlacement(slot, x: number, z: number): (number, boolean)
	local r = math.sqrt(x * x + z * z)
	if r > 1.08 then
		return 0, true -- fell off the dish
	end
	local d = math.sqrt((x - slot[1]) ^ 2 + (z - slot[2]) ^ 2)
	return clamp(1 - math.max(0, d - 0.08) / 0.5, 0, 1), false
end

function StepMath.evalPlace(step, points)
	local sum, offCount = 0, 0
	local qs = {}
	for i, top in step.toppings do
		local p = points[i]
		local q, off = 0, true
		if p then
			q, off = StepMath.gradePlacement(top.slot, p[1], p[2])
		end
		qs[i] = q
		sum += q
		if off then
			offCount += 1
		end
	end
	local q = sum / #step.toppings
	local label
	if offCount > 0 then
		label = "Something fell off..."
	elseif q >= 0.85 then
		label = "Clean plating"
	elseif q >= 0.6 then
		label = "Nice plating"
	else
		label = "Messy plating"
	end
	return q, { qualities = qs, off = offCount }, label
end

----------------------------------------------------------------- stack
StepMath.StackFirstSpawn = 0.6
StepMath.StackGap = 0.75
StepMath.StackAutoDrop = 6

function StepMath.stackSpawn(taps: { number }, k: number): number
	if k == 1 then
		return StepMath.StackFirstSpawn
	end
	return taps[k - 1] + StepMath.StackGap
end

function StepMath.stackOffset(layer, tSinceSpawn: number): number
	return layer.amp * math.sin(2 * math.pi * math.max(0, tSinceSpawn) / layer.period)
end

function StepMath.evalStack(step, taps: { number })
	local offs, qs = {}, {}
	local sum = 0
	for k, layer in step.layers do
		local spawn = StepMath.stackSpawn(taps, k)
		local t = taps[k] or (spawn + StepMath.StackAutoDrop)
		local off = StepMath.stackOffset(layer, t - spawn)
		local q = clamp(1 - math.max(0, math.abs(off) / layer.amp - 0.06) * 1.15, 0, 1)
		offs[k], qs[k] = off, q
		sum += q
	end
	local q = sum / #step.layers
	local label
	if q >= 0.85 then
		label = "Tall & tidy"
	elseif q >= 0.6 then
		label = "Slight lean"
	else
		label = "Leaning tower of burger"
	end
	return q, { offsets = offs, qualities = qs }, label
end

----------------------------------------------------------------- pick
function StepMath.evalPick(step, picks: { string })
	local need = {}
	for _, id in step.required do
		need[id] = true
	end
	local got, wrong = {}, 0
	for _, id in picks do
		if need[id] then
			got[id] = true
		else
			wrong += 1
		end
	end
	local missing = 0
	for id in need do
		if not got[id] then
			missing += 1
		end
	end
	local q = clamp(1 - 0.25 * wrong - 0.5 * missing, 0, 1)
	local label = wrong == 0 and "Perfect picks" or (wrong == 1 and "One weird pick" or "Got distracted")
	return q, { wrong = wrong, missing = missing }, label
end

----------------------------------------------------------------- dispatch
function StepMath.evaluate(step, events)
	local kind = step.type
	if kind == "chop" then
		return StepMath.evalChop(step, events)
	elseif kind == "heat" then
		return StepMath.evalHeat(step, events)
	elseif kind == "pour" then
		return StepMath.evalPour(step, events)
	elseif kind == "place" then
		return StepMath.evalPlace(step, events)
	elseif kind == "stack" then
		return StepMath.evalStack(step, events)
	elseif kind == "pick" then
		return StepMath.evalPick(step, events)
	end
	return 0, {}, "?"
end

-- Minimum plausible step duration (server checks elapsed >= this - tolerance)
function StepMath.minDuration(step, events): number
	local kind = step.type
	if kind == "chop" then
		return StepMath.chopDuration(step) * 0.95
	end
	return 0
end

-- Final score from per-step qualities. results: { {category=, quality=} }
function StepMath.finalScore(recipe, results, totalSeconds: number)
	local catSum, catN = {}, {}
	for _, r in results do
		catSum[r.category] = (catSum[r.category] or 0) + r.quality
		catN[r.category] = (catN[r.category] or 0) + 1
	end
	local weightTotal, skill = 0, 0
	local cats = {}
	for cat, w in Config.CategoryWeights do
		if catN[cat] then
			local avg = catSum[cat] / catN[cat]
			cats[cat] = avg
			weightTotal += w
			skill += w * avg
		end
	end
	local skillFrac = weightTotal > 0 and skill / weightTotal or 0
	-- each step opens with a short technique demo, so par includes ~4.5 s per step
	local par = recipe.par + 4.5 * #recipe.steps
	local speedFrac = clamp((par * 1.4 - totalSeconds) / (par * 0.4), 0, 1)
	-- speed bonus scales with skill so a fast disaster earns nothing extra
	local score = Config.SkillPoints * skillFrac + Config.SpeedPoints * speedFrac * skillFrac
	return math.floor(score + 0.5), cats, speedFrac
end

return StepMath
