-- Cook the Trend: turns a scored step into real-cooking feedback ("what went well / try next time").
-- Pure data; used by the client for the per-step card and the results recap.
local Coach = {}

local ItemNames = {
	banana = "banana", cheese = "cheese", fish = "fish", donut = "donut", onion = "onion", chili = "chili",
}

-- returns good (string?), improve (string?)
function Coach.feedback(step, quality: number, label: string?, details)
	local kind = step.type
	label = label or ""
	if kind == "pick" then
		local wrong = details and details.wrong or 0
		if wrong == 0 then
			return "You gathered exactly what the recipe needs.", nil
		end
		return "You found every ingredient.", "Read the ingredient list first. Grabbing extras wastes time and food."
	elseif kind == "chop" then
		if quality >= 0.85 then
			return "Even, straight slices: they'll sit flat and look pro.", nil
		elseif quality >= 0.55 then
			return "Most slices were clean.", "Slow down and cut on the line. One straight downward stroke per slice."
		end
		return nil, "Pieces came out chunky. Use the claw grip, keep the knife upright and cut on each line."
	elseif kind == "heat" then
		if string.find(label, "Burnt") then
			return nil, "Burnt! Watch the color, not the clock, and pull it the moment it turns golden brown."
		elseif string.find(label, "burnt") then
			return "Close to perfect.", "A little overdone. Pull it a few seconds earlier, because food keeps cooking off the heat."
		elseif string.find(label, "raw") or string.find(label, "underdone") then
			return nil, "Pulled too early. Give it more time and look for the color change before taking it off."
		end
		return "Perfect timing: right color, right texture.", nil
	elseif kind == "pour" then
		if string.find(label, "Spilled") then
			return nil, "It overflowed. Pour slowly as you get close to the line and stop early; you can always add more."
		elseif quality >= 0.85 then
			return "Spot-on portion.", nil
		elseif string.find(label, "much") or string.find(label, "overload") then
			return "Nice and generous...", "...but a bit too much. Measure it and slow down near the end."
		end
		return nil, "A little light. Use the measurement (cups or grams) so every portion is the same."
	elseif kind == "place" then
		local off = details and details.off or 0
		if off > 0 then
			return nil, "A topping slid off. Keep toppings inside the rim and set them down gently."
		elseif quality >= 0.85 then
			return "Clean, intentional plating with each topping in its spot.", nil
		end
		return "Everything made it on.", "Group toppings into sections and leave a little space so each one shows."
	elseif kind == "stack" then
		if quality >= 0.85 then
			return "A straight, stable stack.", nil
		end
		return nil, "Layers were off-center. Line each one up over the middle before letting go."
	end
	return nil, nil
end

return Coach
