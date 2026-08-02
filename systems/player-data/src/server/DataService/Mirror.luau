--!strict

local Schema = require(script.Parent.Schema)

type Reader = (data: Schema.PlayerData) -> any

local FIELDS: { [string]: Reader } = {
	Coins = function(data)
		return data.currency.coins
	end,

	Gems = function(data)
		return data.currency.gems
	end,

	Rolls = function(data)
		return data.stats.rolls
	end,

	BestRarity = function(data)
		return data.stats.bestRarity
	end,
}

local Mirror = {}

function Mirror.push(player: Player, data: Schema.PlayerData)
	for attribute, read in FIELDS do
		local value = read(data)

		if player:GetAttribute(attribute) ~= value then
			player:SetAttribute(attribute, value)
		end
	end
end

function Mirror.clear(player: Player)
	for attribute in FIELDS do
		player:SetAttribute(attribute, nil)
	end
end

return Mirror
