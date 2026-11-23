--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CharacterScaleConfig = require(
	ReplicatedStorage:WaitForChild("shared"):WaitForChild("config"):WaitForChild("CharacterScaleConfig")
)

local CharacterScaleService = {}
local SCALE_VALUE_NAMES: { string } = {
	"BodyHeightScale",
	"BodyWidthScale",
	"BodyDepthScale",
	"HeadScale",
}

local playerAddedConnection: RBXScriptConnection? = nil
local characterConnections: { [Player]: RBXScriptConnection } = {}

local function getScaleValues(humanoid: Humanoid): { [string]: NumberValue }?
	local values: { [string]: NumberValue } = {}
	for _, name in ipairs(SCALE_VALUE_NAMES) do
		local value = humanoid:FindFirstChild(name) or humanoid:WaitForChild(name, 5)
		if not value or not value:IsA("NumberValue") then
			return nil
		end
		values[name] = value
	end
	return values
end

-- Server-authoritative and idempotent. HumanoidRootPart is deliberately never scaled.
function CharacterScaleService.ApplyProfile(character: Model, profileName: string, scale: number): boolean
	local humanoidInst = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 10)
	if not humanoidInst or not humanoidInst:IsA("Humanoid") then
		warn("Food Empire character scaling requires a Humanoid:", character:GetFullName())
		return false
	end

	local humanoid: Humanoid = humanoidInst
	if humanoid.RigType ~= Enum.HumanoidRigType.R15 then
		warn("Food Empire character scaling requires an R15 humanoid:", character:GetFullName())
		return false
	end

	if
		character:GetAttribute("CharacterScaleApplied") == true
		and character:GetAttribute("CharacterScaleProfile") == profileName
	then
		return true
	end

	local scaleValues = getScaleValues(humanoid)
	if not scaleValues then
		warn("R15 scale values unavailable for:", character:GetFullName())
		return false
	end

	for _, name in ipairs(SCALE_VALUE_NAMES) do
		scaleValues[name].Value = scale
	end

	local baseHipHeightAttr = humanoid:GetAttribute("FoodEmpireBaseHipHeight")
	local baseHipHeight: number
	if typeof(baseHipHeightAttr) == "number" then
		baseHipHeight = baseHipHeightAttr
	else
		baseHipHeight = humanoid.HipHeight
		humanoid:SetAttribute("FoodEmpireBaseHipHeight", baseHipHeight)
	end

	humanoid.HipHeight = baseHipHeight * scale

	character:SetAttribute("CharacterScaleProfile", profileName)
	character:SetAttribute("CharacterVisualScale", scale)
	character:SetAttribute("CharacterScaleApplied", true)
	return true
end

function CharacterScaleService.ApplyPlayerCharacter(character: Model): boolean
	return CharacterScaleService.ApplyProfile(character, "Player", CharacterScaleConfig.Player.Scale)
end

-- Future NPC spawners call this; it does not create NPCs or AI.
function CharacterScaleService.ApplyNPCProfile(character: Model, npcTier: string): boolean
	local profile = CharacterScaleConfig.NPC[npcTier]
	if not profile then
		warn("Unknown NPC scale tier:", tostring(npcTier))
		return false
	end
	return CharacterScaleService.ApplyProfile(character, "NPC_" .. npcTier, profile.Scale)
end

function CharacterScaleService.Start(): ()
	if playerAddedConnection then
		return
	end

	local function connectPlayer(player: Player)
		if characterConnections[player] then
			characterConnections[player]:Disconnect()
		end

		characterConnections[player] = player.CharacterAdded:Connect(function(character: Model)
			CharacterScaleService.ApplyPlayerCharacter(character)
		end)

		if player.Character then
			CharacterScaleService.ApplyPlayerCharacter(player.Character)
		end
	end

	playerAddedConnection = Players.PlayerAdded:Connect(connectPlayer)
	Players.PlayerRemoving:Connect(function(player: Player)
		if characterConnections[player] then
			characterConnections[player]:Disconnect()
			characterConnections[player] = nil
		end
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		connectPlayer(player)
	end
end

return CharacterScaleService
