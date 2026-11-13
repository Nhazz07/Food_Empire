
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ServerScriptService = game:GetService("ServerScriptService")

local SectorService = require(
    ServerScriptService:WaitForChild("Services")
        :WaitForChild("SectorService")
)

local SectorVisualService = {}

local zonesFolder = Workspace:WaitForChild("SectorZones")
local isRunning = false

local COLORS = {
    Neutral = Color3.fromRGB(150, 150, 150),
    Player = Color3.fromRGB(45, 190, 100),
    Rival = Color3.fromRGB(220, 65, 65),
}

local function getOwnerDisplay(owner)
    if owner == "Neutral" then
        return "NEUTRAL TERRITORY", COLORS.Neutral
    end

    if owner == "Rival" then
        return "RIVAL TERRITORY", COLORS.Rival
    end

    local userId = string.match(owner, "^Player_(%d+)$")

    if userId then
        local player = Players:GetPlayerByUserId(tonumber(userId))

        if player then
            return "CONTROLLED BY " .. string.upper(player.DisplayName), COLORS.Player
        end

        return "PLAYER-OWNED TERRITORY", COLORS.Player
    end

    return string.upper(owner) .. " TERRITORY", COLORS.Rival
end

local function createLabel(zone)
    local existing = zone:FindFirstChild("SectorBillboard")

    if existing then
        return existing
    end

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "SectorBillboard"
    billboard.Adornee = zone
    billboard.Size = UDim2.fromOffset(260, 70)
    billboard.StudsOffset = Vector3.new(0, zone.Size.Y / 2 + 4, 0)
    billboard.AlwaysOnTop = true
    billboard.MaxDistance = 250
    billboard.Parent = zone

    local title = Instance.new("TextLabel")
    title.Name = "SectorName"
    title.Size = UDim2.new(1, 0, 0.5, 0)
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.GothamBold
    title.TextScaled = true
    title.TextColor3 = Color3.new(1, 1, 1)
    title.TextStrokeTransparency = 0.3
    title.Parent = billboard

    local ownerLabel = Instance.new("TextLabel")
    ownerLabel.Name = "SectorOwner"
    ownerLabel.Position = UDim2.new(0, 0, 0.5, 0)
    ownerLabel.Size = UDim2.new(1, 0, 0.5, 0)
    ownerLabel.BackgroundColor3 = COLORS.Neutral
    ownerLabel.BackgroundTransparency = 0.15
    ownerLabel.Font = Enum.Font.GothamBold
    ownerLabel.TextScaled = true
    ownerLabel.TextColor3 = Color3.new(1, 1, 1)
    ownerLabel.Parent = billboard

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = ownerLabel

    return billboard
end

local function updateZone(zone)
    local sector = SectorService.GetSector(zone.Name)

    if not sector then
        warn("[SectorVisual] No sector configuration for zone:", zone.Name)
        return
    end

    local billboard = createLabel(zone)
    local title = billboard:FindFirstChild("SectorName")
    local ownerLabel = billboard:FindFirstChild("SectorOwner")

    local ownerText, ownerColor = getOwnerDisplay(sector.Owner)

    title.Text = string.upper(sector.DisplayName)
    ownerLabel.Text = ownerText
    ownerLabel.BackgroundColor3 = ownerColor
end

function SectorVisualService.Start()
    if isRunning then
        return
    end

    isRunning = true

    for _, zone in ipairs(zonesFolder:GetChildren()) do
        if zone:IsA("BasePart") then
            updateZone(zone)
        end
    end

    print("Food Empires: Sector visuals started!")

    task.spawn(function()
        while isRunning do
            task.wait(1)

            for _, zone in ipairs(zonesFolder:GetChildren()) do
                if zone:IsA("BasePart") then
                    updateZone(zone)
                end
            end
        end
    end)
end

function SectorVisualService.Stop()
    isRunning = false
end

return SectorVisualService
