
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ServerScriptService = game:GetService("ServerScriptService")

local SectorService = require(
    ServerScriptService:WaitForChild("Services")
        :WaitForChild("SectorService")
)

local SectorCaptureService = {}

local CAPTURE_TIME = 5
local CHECK_INTERVAL = 0.2

local zonesFolder = Workspace:WaitForChild("SectorZones")

-- progress[sectorId][userId] = time the player entered
local progress = {}
local isRunning = false

local function isPlayerInsideZone(player, zone)
    local character = player.Character
    if not character then
        return false
    end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local root = character:FindFirstChild("HumanoidRootPart")

    if not humanoid or humanoid.Health <= 0 or not root then
        return false
    end

    -- Works even if the zone part is rotated.
    local localPosition = zone.CFrame:PointToObjectSpace(root.Position)
    local halfSize = zone.Size / 2

    return math.abs(localPosition.X) <= halfSize.X
        and math.abs(localPosition.Y) <= halfSize.Y
        and math.abs(localPosition.Z) <= halfSize.Z
end

local function tryCapture(player, sectorId)
    local sector = SectorService.GetSector(sectorId)

    if not sector or sector.Owner ~= "Neutral" then
        return false
    end

    -- Ownership is stored on the server.
    local ownerId = "Player_" .. player.UserId

    local success = SectorService.SetOwner(sectorId, ownerId)

    if success then
        print(
            "[Capture] " .. player.Name
                .. " captured " .. sector.DisplayName .. "!"
        )

        -- Clear progress for everyone once the sector is captured.
        progress[sectorId] = nil
    end

    return success
end

function SectorCaptureService.Start()
    if isRunning then
        return
    end

    isRunning = true
    print("Food Empires: Sector capture started!")

    task.spawn(function()
        while isRunning do
            task.wait(CHECK_INTERVAL)

            local now = os.clock()

            for _, zone in ipairs(zonesFolder:GetChildren()) do
                if zone:IsA("BasePart") then
                    local sectorId = zone.Name
                    local sector = SectorService.GetSector(sectorId)

                    if sector and sector.Owner == "Neutral" then
                        progress[sectorId] = progress[sectorId] or {}

                        for _, player in ipairs(Players:GetPlayers()) do
                            local userId = player.UserId

                            if isPlayerInsideZone(player, zone) then
                                progress[sectorId][userId] =
                                    progress[sectorId][userId] or now

                                local elapsed =
                                    now - progress[sectorId][userId]

                                if elapsed >= CAPTURE_TIME then
                                    tryCapture(player, sectorId)
                                    break
                                end
                            else
                                progress[sectorId][userId] = nil
                            end
                        end
                    else
                        progress[sectorId] = nil
                    end
                end
            end
        end
    end)
end

function SectorCaptureService.Stop()
    isRunning = false
end

return SectorCaptureService
