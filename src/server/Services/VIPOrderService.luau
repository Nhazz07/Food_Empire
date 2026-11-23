--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RecipeConfig = require(
	ReplicatedStorage:WaitForChild("shared"):WaitForChild("config"):WaitForChild("RecipeConfig")
)
local PlayerDataService = require("./PlayerDataService")

export type VIPOrderInfo = {
	RecipeId: string,
	DisplayName: string,
	BonusCoins: number,
	BonusRep: number,
	ExpiresAt: number,
}

local VIPOrderService = {}

local ORDER_DURATION = 75
local ORDER_POOL: { string } = {
	"GrilledFish",
	"ClassicBurger",
	"FreshSushi",
	"TropicalSmoothie",
	"SizzlingSteak",
	"CrabFeast",
}

local activeOrders: { [Player]: VIPOrderInfo } = {}
local isRunning = false
local loopThread: thread? = nil
local playerRemovingConn: RBXScriptConnection? = nil
local orderUpdatedCallback: ((player: Player, msg: string?) -> ())? = nil

function VIPOrderService.SetOrderUpdatedCallback(cb: (player: Player, msg: string?) -> ()): ()
	orderUpdatedCallback = cb
end

local function assignNewOrder(player: Player): VIPOrderInfo
	local recipeId = ORDER_POOL[math.random(1, #ORDER_POOL)]
	local spec = RecipeConfig.Recipes[recipeId]
	local order: VIPOrderInfo = {
		RecipeId = recipeId,
		DisplayName = if spec then spec.DisplayName else recipeId,
		BonusCoins = if spec then math.floor(spec.CoinsReward * 1.8) else 90,
		BonusRep = if spec then math.floor(spec.ReputationReward * 2.0) else 25,
		ExpiresAt = os.clock() + ORDER_DURATION,
	}
	activeOrders[player] = order
	return order
end

function VIPOrderService.GetOrderSnapshot(player: Player): { [string]: any }?
	local order = activeOrders[player]
	if not order then
		return nil
	end
	local remaining = math.max(0, math.ceil(order.ExpiresAt - os.clock()))
	if remaining <= 0 then
		order = assignNewOrder(player)
		remaining = ORDER_DURATION
	end
	return {
		RecipeId = order.RecipeId,
		DisplayName = order.DisplayName,
		BonusCoins = order.BonusCoins,
		BonusRep = order.BonusRep,
		Remaining = remaining,
	}
end

function VIPOrderService.TryFulfillFromServed(player: Player, servedRecipes: { [string]: number }): (boolean, string?)
	local order = activeOrders[player]
	if not order or os.clock() > order.ExpiresAt then
		return false, nil
	end
	local qty = servedRecipes[order.RecipeId] or 0
	if qty <= 0 then
		return false, nil
	end

	local bonusCoins = order.BonusCoins
	local bonusRep = order.BonusRep
	local dishName = order.DisplayName
	PlayerDataService.AddRewards(player, bonusCoins, 35, bonusRep)
	assignNewOrder(player)

	local msg = string.format("VIP CRITIC ORDER COMPLETE (%s)! +%d Bonus Coins, +%d Rep!", dishName, bonusCoins, bonusRep)
	print("[VIPOrderService]", player.Name, msg)
	if orderUpdatedCallback then
		orderUpdatedCallback(player, msg)
	end
	return true, msg
end

function VIPOrderService.Start(): ()
	if isRunning then
		return
	end
	isRunning = true

	playerRemovingConn = Players.PlayerRemoving:Connect(function(player)
		activeOrders[player] = nil
	end)

	for _, p in ipairs(Players:GetPlayers()) do
		assignNewOrder(p)
	end

	loopThread = task.spawn(function()
		while isRunning do
			task.wait(5)
			if not isRunning then
				break
			end
			local now = os.clock()
			for _, p in ipairs(Players:GetPlayers()) do
				local ord = activeOrders[p]
				if not ord or now >= ord.ExpiresAt then
					assignNewOrder(p)
					if orderUpdatedCallback then
						orderUpdatedCallback(p, nil)
					end
				end
			end
		end
	end)

	print("[Food Empire] VIPOrderService started (Timed VIP Food Critic Orders active)!")
end

function VIPOrderService.Stop(): ()
	isRunning = false
	if loopThread then
		task.cancel(loopThread)
		loopThread = nil
	end
	if playerRemovingConn then
		playerRemovingConn:Disconnect()
		playerRemovingConn = nil
	end
	table.clear(activeOrders)
end

return VIPOrderService
