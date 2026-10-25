-- Cook the Trend: data-driven recipe definitions shared by server and client.
-- Step types: pick, chop, heat, pour, place, stack (see StepMath for the rules of each).
-- Normalised dish coordinates: x/z in [-1, 1] across the dish radius.

local Recipes = {}

Recipes.Order = { "dessert", "ramen", "burger" }

-- evenly spaced cut lines (normalised -1..1 along the ingredient): realistic slice thickness per food
local function even(n: number, a: number, b: number)
	local t = {}
	for i = 0, n - 1 do
		table.insert(t, a + (b - a) * i / (n - 1))
	end
	return t
end

Recipes.Defs = {
	ramen = {
		id = "ramen",
		name = "Midnight Tonkotsu",
		short = "Ramen",
		creator = "@noodle.nana",
		caption = "3am ramen hits different. Bet you can't plate it this clean",
		tags = "#ramen #latenight #cooktok",
		likes = "1.2M",
		comments = "8.4K",
		difficulty = 1,
		duration = 75,
		par = 70,
		baseCoins = 60,
		baseFollowers = 70,
		unlock = { kind = "followers", amount = 60 },
		dish = "ramen",
		accent = Color3.fromRGB(255, 120, 70),
		bg = { Color3.fromRGB(255, 196, 140), Color3.fromRGB(214, 80, 60) },
		steps = {
			{
				type = "pick",
				category = "ingredients",
				title = "Grab the ingredients",
				instruction = "Tap the 4 things this ramen needs",
				required = { "noodles", "egg", "scallion", "chashu" },
				decoys = { "banana", "cheese" },
			},
			{
				type = "chop",
				category = "prep",
				item = "scallion",
				title = "Slice the scallions",
				instruction = "Thin rings: tap each time the knife hits a line",
				guides = even(11, -0.55, 0.85),
				speed = 0.32,
			},
			{
				type = "chop",
				category = "prep",
				item = "chashu",
				title = "Slice the chashu",
				instruction = "Tap each time the knife hits a line",
				guides = even(6, -0.65, 0.65),
				speed = 0.5,
			},
			{
				type = "heat",
				category = "cook",
				item = "noodles",
				vessel = "pot",
				title = "Boil the noodles",
				instruction = "Pull them out in the green zone",
				phases = { "PULL!" },
				fullTime = 6.5,
				ideal = { 0.56, 0.76 },
			},
			{
				type = "pour",
				category = "plating",
				item = "broth",
				title = "Pour the broth",
				instruction = "Hold to pour. Stop at the gold line",
				target = 0.78,
				rate = 0.36,
			},
			{
				type = "place",
				category = "plating",
				title = "Add the toppings",
				instruction = "Tap the glowing spot to place each topping",
				toppings = {
					{ item = "chashu_slice", slot = { 0.42, -0.18 } },
					{ item = "egg_half", slot = { -0.4, -0.22 } },
					{ item = "scallion_pile", slot = { 0.0, 0.42 } },
					{ item = "nori", slot = { -0.05, -0.6 } },
				},
			},
		},
	},

	burger = {
		id = "burger",
		name = "Tower Smash Burger",
		short = "Burger",
		creator = "@grillgremlin",
		caption = "POV: you stack it so tall it needs a skewer",
		tags = "#smashburger #stackchallenge",
		likes = "860K",
		comments = "5.1K",
		difficulty = 2,
		duration = 80,
		par = 72,
		baseCoins = 80,
		baseFollowers = 90,
		unlock = { kind = "coins", amount = 40 },
		dish = "burger",
		accent = Color3.fromRGB(255, 190, 40),
		bg = { Color3.fromRGB(255, 220, 120), Color3.fromRGB(230, 110, 40) },
		steps = {
			{
				type = "pick",
				category = "ingredients",
				title = "Grab the ingredients",
				instruction = "Tap the 5 things a smash burger needs",
				required = { "bun", "patty", "cheese", "lettuce", "tomato" },
				decoys = { "fish", "donut" },
			},
			{
				type = "chop",
				category = "prep",
				item = "tomato",
				title = "Slice the tomato",
				instruction = "Tap each time the knife hits a line",
				guides = even(5, -0.6, 0.6),
				speed = 0.5,
			},
			{
				type = "heat",
				category = "cook",
				item = "patty",
				vessel = "pan",
				title = "Smash & sear the patty",
				instruction = "FLIP in the green zone, then take it off",
				phases = { "FLIP!", "DONE!" },
				fullTime = 4.6,
				ideal = { 0.55, 0.74 },
			},
			{
				type = "stack",
				category = "plating",
				title = "Stack the tower",
				instruction = "Tap to drop each layer dead center",
				layers = {
					{ item = "patty_cooked", amp = 1.0, period = 1.7 },
					{ item = "cheese_slice", amp = 1.0, period = 1.5 },
					{ item = "lettuce_leaf", amp = 1.0, period = 1.35 },
					{ item = "tomato_slice", amp = 1.0, period = 1.2 },
					{ item = "bun_top", amp = 1.0, period = 1.05 },
				},
			},
		},
	},

	dessert = {
		id = "dessert",
		name = "Rainbow Fruit Cup",
		short = "Fruit Cup",
		creator = "@berry.bae",
		caption = "the prettiest 60-second dessert on your fyp",
		tags = "#fruitcup #aesthetic #dessert",
		likes = "2.3M",
		comments = "12K",
		difficulty = 2,
		duration = 85,
		par = 78,
		baseCoins = 90,
		baseFollowers = 110,
		unlock = { kind = "free" },
		dish = "dessert",
		accent = Color3.fromRGB(255, 105, 170),
		bg = { Color3.fromRGB(255, 200, 225), Color3.fromRGB(170, 110, 230) },
		steps = {
			{
				type = "pick",
				category = "ingredients",
				title = "Grab the fruit",
				instruction = "Tap the 4 things this fruit cup needs",
				required = { "strawberry", "kiwi", "blueberry", "mint" },
				decoys = { "onion", "chili" },
			},
			{
				type = "chop",
				category = "prep",
				item = "strawberry",
				title = "Slice the strawberries",
				instruction = "Tap each time the knife hits a line",
				guides = even(6, -0.6, 0.6),
				speed = 0.45,
			},
			{
				type = "chop",
				category = "prep",
				item = "kiwi",
				title = "Slice the kiwi",
				instruction = "Even rounds: tap on every line",
				guides = even(6, -0.6, 0.6),
				speed = 0.5,
			},
			{
				type = "pour",
				category = "plating",
				item = "yogurt",
				title = "Portion the yogurt",
				instruction = "Hold to fill. Stop at the gold line",
				target = 0.6,
				rate = 0.3,
			},
			{
				type = "place",
				category = "plating",
				title = "Top it like the video",
				instruction = "Tap the glowing spot to place each fruit",
				toppings = {
					{ item = "strawberry_slice", slot = { 0.66, 0.1 } },
					{ item = "kiwi_slice", slot = { -0.66, 0.1 } },
					{ item = "strawberry_slice", slot = { 0.36, -0.6 } },
					{ item = "kiwi_slice", slot = { -0.38, -0.6 } },
					{ item = "blueberry_cluster", slot = { 0.0, 0.0 } },
					{ item = "mint_leaf", slot = { 0.0, 0.66 } },
				},
			},
			{
				type = "pour",
				category = "plating",
				item = "honey",
				title = "Honey drizzle",
				instruction = "Just a little! Stop at the gold line",
				target = 0.25,
				rate = 0.42,
				drizzle = true,
			},
		},
	},
}

function Recipes.get(id: string)
	return Recipes.Defs[id]
end

------------------------------------------------------------------ learning layer
-- Real-life recipe data: quantities, and per step a technique demo text, a tip, why it matters
-- and what the result should look like. Keyed by step index so gameplay data stays untouched.
local Learn = {
	dessert = {
		servings = "1 cup",
		realTime = "10 min",
		summary = "A layered Greek-yogurt parfait: crunchy granola, berry compote, creamy yogurt and neatly cut fresh fruit.",
		ingredients = {
			{ icon = "🍓", name = "Strawberries", qty = "5 (about 80 g)" },
			{ icon = "🥝", name = "Kiwi", qty = "1" },
			{ icon = "🔵", name = "Blueberries", qty = "1/4 cup (40 g)" },
			{ icon = "🌿", name = "Fresh mint", qty = "2 leaves" },
			{ icon = "🥛", name = "Strawberry Greek yogurt", qty = "3/4 cup (180 g)" },
			{ icon = "🥣", name = "Granola", qty = "2 tbsp" },
			{ icon = "🍯", name = "Honey", qty = "1 tsp" },
		},
		steps = {
			{ short = "Grab only what the recipe needs. Rinse and dry the fruit.", tip = "Rinse the berries and kiwi in cold water, pat them dry, and set everything out before you start (mise en place).", why = "Wet fruit waters down the yogurt and slides around.", expected = "Clean, dry fruit lined up and ready." },
			{ short = "Slice straight down into even slices. Keep fingers curled.", tip = "Cut off the green top. Lay the berry flat and slice straight down into even 5 mm slices, fingertips curled into a claw.", why = "Even slices look neat and sit flat on the yogurt.", expected = "4 to 5 even slices per berry." },
			{ short = "Cut straight down into even rounds.", tip = "Trim both ends, peel the skin with a knife or spoon, then cut straight down into 6 mm rounds.", why = "Rounds show off the seed ring and are easy to eat with a spoon.", expected = "Bright green rounds of equal thickness." },
			{ short = "Fill to about two-thirds. Slow down near the line.", tip = "Spoon the yogurt over the granola and compote. Slow down near the top and smooth it flat.", why = "Too little looks sad; too much and the fruit sinks and overflows.", expected = "Glass about two-thirds full with a flat top." },
			{ short = "Group the fruit in sections. Blueberries in the middle.", tip = "Arrange in sections: strawberries on one side, kiwi on the other, blueberries in the middle, mint on top.", why = "Grouped colors read as intentional and look great on camera.", expected = "A colorful ring with a clear center." },
			{ short = "Just a thin drizzle of honey. Less is more.", tip = "Drizzle 1 tsp of honey from about 10 cm above in a thin zigzag.", why = "A light drizzle adds shine and sweetness without drowning the fruit.", expected = "Thin golden lines, not a puddle." },
		},
	},
	ramen = {
		servings = "1 bowl",
		realTime = "15 min (with ready broth)",
		summary = "A quick tonkotsu-style bowl: springy noodles in rich broth, topped with chashu, soft egg, scallions and nori.",
		ingredients = {
			{ icon = "🍜", name = "Fresh ramen noodles", qty = "1 portion (120 g)" },
			{ icon = "🥚", name = "Soft-boiled egg", qty = "1 (6.5 min boil)" },
			{ icon = "🌿", name = "Scallion", qty = "1 stalk" },
			{ icon = "🥩", name = "Chashu pork", qty = "3 slices" },
			{ icon = "🍲", name = "Tonkotsu broth", qty = "1.5 cups (350 ml), hot" },
			{ icon = "🟩", name = "Nori", qty = "1 sheet" },
		},
		steps = {
			{ short = "Grab only what the ramen needs.", tip = "Set out everything before the noodles go in: ramen cooks fast and waits for no one.", why = "Noodles go soggy while you hunt for toppings.", expected = "Toppings ready next to the stove." },
			{ short = "Slice thin, even rings.", tip = "Slice the scallion thinly on a slight angle, keeping the knife tip on the board.", why = "Thin rings release flavor and look delicate.", expected = "Small even rings, white and green parts." },
			{ short = "One smooth cut per slice.", tip = "Cut the chashu across the grain into 5 mm slices with one smooth stroke.", why = "Across the grain = tender bites.", expected = "Three even round slices." },
			{ short = "Pull the noodles when they turn golden. Don't overcook!", tip = "Boil the noodles in plenty of water for about 2-3 minutes (check the pack), then drain immediately.", why = "Even 30 seconds too long makes them mushy.", expected = "Golden, springy, not soft." },
			{ short = "Fill the bowl about three-quarters full.", tip = "Pour the hot broth in first or over the noodles until about 3/4 full.", why = "Leaves room for toppings without spilling.", expected = "Broth about 3/4 up the bowl." },
			{ short = "Place each topping in its own spot.", tip = "Place toppings in sections around the bowl, nori tucked at the back edge.", why = "Sections keep each topping visible and crisp.", expected = "Neat sections, nothing sinking." },
		},
	},
	burger = {
		servings = "1 burger",
		realTime = "15 min",
		summary = "A diner-style smash burger: a thin, crusty patty with melted cheese, crisp lettuce and tomato.",
		ingredients = {
			{ icon = "🍞", name = "Burger bun", qty = "1, toasted" },
			{ icon = "🥩", name = "Ground beef (80/20)", qty = "120 g ball" },
			{ icon = "🧀", name = "American cheese", qty = "1 slice" },
			{ icon = "🥬", name = "Lettuce", qty = "1 leaf" },
			{ icon = "🍅", name = "Tomato", qty = "1 slice (from 1 small tomato)" },
		},
		steps = {
			{ short = "Grab only what the burger needs.", tip = "Get the bun, cheese and veg ready first: a smash burger cooks in about 3 minutes.", why = "The patty overcooks while you prep.", expected = "Everything within reach of the pan." },
			{ short = "Slice even rounds across the middle.", tip = "Slice the tomato across its middle into 6 mm rounds with a serrated or very sharp knife.", why = "Thin rounds stay on the burger; thick ones slide out.", expected = "Even rounds that hold their shape." },
			{ short = "Flip when it's deep brown, not black.", tip = "Smash the ball flat in a very hot pan. Flip when the edges are deep brown (about 1.5-2 min), cook 1 more minute.", why = "The brown crust is where the flavor is.", expected = "Deep brown crust, juicy middle." },
			{ short = "Drop each layer right in the center.", tip = "Stack heavy to light: patty, cheese, lettuce, tomato, bun. Center each layer.", why = "A centered stack stays together when you bite.", expected = "A straight, tidy tower." },
		},
	},
}
for id, data in Learn do
	local def = Recipes.Defs[id]
	if def then
		def.servings = data.servings
		def.realTime = data.realTime
		def.summary = data.summary
		def.ingredients = data.ingredients
		for i, l in data.steps do
			if def.steps[i] then
				def.steps[i].learn = l
			end
		end
		-- future CookQuest hooks (not implemented yet): reaction video, photo upload, AI feedback
		def.media = { reactionVideoId = nil, makeThisLink = "recipe/" .. id }
	end
end

function Recipes.legacyGet(id: string)
	return Recipes.Defs[id]
end

return Recipes
