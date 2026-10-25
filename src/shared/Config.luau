--!strict
-- Cook the Trend: shared tuning. Server and client both read this.
local Config = {}

Config.Version = "0.2.0"

-- HACKATHON / TESTING TOGGLE: true = every recipe is unlocked from the start (no grinding coins/followers).
-- Scores, coins, followers and best scores still work. Set to false to restore the unlock progression.
Config.UnlockAll = true

-- Score weights per category (renormalised when a recipe lacks a category)
Config.CategoryWeights = {
	ingredients = 15,
	prep = 20,
	cook = 35,
	plating = 30,
}
Config.CategoryNames = {
	ingredients = "Ingredients",
	prep = "Prep",
	cook = "Cooking",
	plating = "Plating",
}
Config.SkillPoints = 95 -- skill part of the 100-point score
Config.SpeedPoints = 5 -- small speed bonus

Config.Ranks = {
	{ rank = "S", min = 90, color = Color3.fromRGB(255, 196, 0), word = "Chef's kiss!" },
	{ rank = "A", min = 75, color = Color3.fromRGB(80, 210, 120), word = "Viral worthy!" },
	{ rank = "B", min = 60, color = Color3.fromRGB(70, 160, 255), word = "Solid post" },
	{ rank = "C", min = 40, color = Color3.fromRGB(255, 150, 60), word = "Needs a retake" },
	{ rank = "D", min = 0, color = Color3.fromRGB(235, 80, 80), word = "Kitchen disaster" },
}

function Config.rankFor(score: number)
	for _, r in Config.Ranks do
		if score >= r.min then
			return r
		end
	end
	return Config.Ranks[#Config.Ranks]
end

-- Network/anti-cheat tolerances
Config.TimeTolerance = 0.35 -- client event times may exceed server elapsed by this much
Config.MaxRunSeconds = 600
Config.MaxEventsPerStep = 60
Config.StepTransition = 0 -- server does not enforce a gap between steps

Config.PBFollowerBonus = 10
Config.FirstClearCoinBonus = 15

-- Ideal-zone defaults for heat steps
Config.BurntAt = 0.95
Config.AutoBurnAt = 1.25

-- Persistence
Config.DataStoreName = "CTT_Profile_v1"

return Config
