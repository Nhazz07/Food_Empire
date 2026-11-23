--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

type RiderAnimState = {
	WheelAngle: number,
	CurrentBank: number,
	LastSpeed: number,
}

local MotorbikeController = {}

local WHEEL_RADIUS = 1.35
local MAX_BANK_RAD = math.rad(18)

local steppedConn: RBXScriptConnection? = nil
local riderStates: { [Model]: RiderAnimState } = {}

local function getMotor(char: Model, partName: string, motorName: string): Motor6D?
	local part = char:FindFirstChild(partName)
	if not part then
		return nil
	end
	local m = part:FindFirstChild(motorName)
	return if m and m:IsA("Motor6D") then m else nil
end

local function applySeatedBikePose(char: Model, bankRad: number, isSedan: boolean): ()
	-- Lower rider comfortably onto the leather saddle (or driver seat in Mafia Sedan) & lean into turns!
	local rootJoint = getMotor(char, "LowerTorso", "Root")
	if rootJoint then
		if isSedan then
			rootJoint.Transform = CFrame.new(-1.35, -1.05, -0.20) * CFrame.Angles(math.rad(-4), 0, bankRad * 0.35)
		else
			rootJoint.Transform = CFrame.new(0, -1.05, 0.35) * CFrame.Angles(math.rad(-10), 0, bankRad * 0.85)
		end
	end

	local waist = getMotor(char, "UpperTorso", "Waist")
	if waist then
		waist.Transform = CFrame.Angles(math.rad(-14), 0, 0)
	end

	local neck = getMotor(char, "Head", "Neck")
	if neck then
		neck.Transform = CFrame.Angles(math.rad(20), 0, 0)
	end

	-- Legs straddling the fuel tank with boots resting cleanly on the steel footpegs
	local lHip = getMotor(char, "LeftUpperLeg", "LeftHip")
	if lHip then
		lHip.Transform = CFrame.Angles(math.rad(62), 0, math.rad(-16))
	end
	local rHip = getMotor(char, "RightUpperLeg", "RightHip")
	if rHip then
		rHip.Transform = CFrame.Angles(math.rad(62), 0, math.rad(16))
	end

	local lKnee = getMotor(char, "LeftLowerLeg", "LeftKnee")
	if lKnee then
		lKnee.Transform = CFrame.Angles(math.rad(-76), 0, 0)
	end
	local rKnee = getMotor(char, "RightLowerLeg", "RightKnee")
	if rKnee then
		rKnee.Transform = CFrame.Angles(math.rad(-76), 0, 0)
	end

	-- Arms reaching forward gripping the rubber handlebars
	local lShoulder = getMotor(char, "LeftUpperArm", "LeftShoulder")
	if lShoulder then
		lShoulder.Transform = CFrame.Angles(math.rad(66), math.rad(10), math.rad(-10))
	end
	local rShoulder = getMotor(char, "RightUpperArm", "RightShoulder")
	if rShoulder then
		rShoulder.Transform = CFrame.Angles(math.rad(66), math.rad(-10), math.rad(10))
	end

	local lElbow = getMotor(char, "LeftLowerArm", "LeftElbow")
	if lElbow then
		lElbow.Transform = CFrame.Angles(math.rad(22), 0, 0)
	end
	local rElbow = getMotor(char, "RightLowerArm", "RightElbow")
	if rElbow then
		rElbow.Transform = CFrame.Angles(math.rad(22), 0, 0)
	end
end

function MotorbikeController.Start(): ()
	if steppedConn then
		return
	end

	-- Stepped runs right after Roblox's default Animator so our seated riding pose cleanly overrides walk/run legs!
	steppedConn = RunService.Stepped:Connect(function(_, dt: number)
		local clampedDt = math.min(dt, 0.05)

		for _, player in ipairs(Players:GetPlayers()) do
			local char = player.Character
			if not char then
				continue
			end

			if char:GetAttribute("RidingMotorbike") ~= true then
				riderStates[char] = nil
				continue
			end

			local root = char:FindFirstChild("HumanoidRootPart")
			local bike = char:FindFirstChild("FoodDeliveryMotorbike")
			local chassis = if bike then bike:FindFirstChild("BikeChassis") else nil
			if not root or not root:IsA("BasePart") or not chassis or not chassis:IsA("BasePart") then
				continue
			end

			local st = riderStates[char]
			if not st then
				st = { WheelAngle = 0, CurrentBank = 0, LastSpeed = 0 }
				riderStates[char] = st
			end

			-- 1. Forward velocity -> spin front & rear alloy wheels realistically
			local vel = root.AssemblyLinearVelocity
			local flatVel = Vector3.new(vel.X, 0, vel.Z)
			local forwardSpeed = flatVel:Dot(root.CFrame.LookVector)
			st.WheelAngle = (st.WheelAngle + (forwardSpeed * clampedDt) / WHEEL_RADIUS) % (math.pi * 2)

			local frontWheel = chassis:FindFirstChild("FrontWheelJoint")
			local rearWheel = chassis:FindFirstChild("RearWheelJoint")
			local frontRightWheel = chassis:FindFirstChild("FrontRightWheelJoint")
			local rearRightWheel = chassis:FindFirstChild("RearRightWheelJoint")
			local wheelSpinCF = CFrame.Angles(-st.WheelAngle, 0, 0)
			if frontWheel and frontWheel:IsA("Motor6D") then
				frontWheel.Transform = wheelSpinCF
			end
			if rearWheel and rearWheel:IsA("Motor6D") then
				rearWheel.Transform = wheelSpinCF
			end
			if frontRightWheel and frontRightWheel:IsA("Motor6D") then
				frontRightWheel.Transform = wheelSpinCF
			end
			if rearRightWheel and rearRightWheel:IsA("Motor6D") then
				rearRightWheel.Transform = wheelSpinCF
			end

			-- 2. Smooth cornering bank / lean into left & right turns + subtle acceleration wheelie pitch
			local isSedan = char:GetAttribute("RidingMafiaSedan") == true
			local yawRate = root.AssemblyAngularVelocity.Y
			local speedFactor = math.clamp(math.abs(forwardSpeed) / 28, 0, 1)
			local maxBank = if isSedan then (MAX_BANK_RAD * 0.22) else MAX_BANK_RAD
			local targetBank = math.clamp(yawRate * 0.14 * speedFactor, -maxBank, maxBank)
			st.CurrentBank += (targetBank - st.CurrentBank) * math.min(1, clampedDt * 10)

			local accel = math.clamp((forwardSpeed - st.LastSpeed) / math.max(0.01, clampedDt), -60, 60)
			st.LastSpeed = forwardSpeed
			local isTurbo = char:GetAttribute("BikeTurboActive") == true
			local turboPitch = if isTurbo then (if isSedan then math.rad(1.4) else math.rad(3.2)) else 0
			local pitchRad = math.clamp(accel * 0.0012 + turboPitch, math.rad(-3.5), math.rad(6.0))
			if isSedan then
				pitchRad *= 0.45
			end

			local tiltJoint = chassis:FindFirstChild("BikeTiltJoint")
			if tiltJoint and tiltJoint:IsA("Motor6D") then
				tiltJoint.Transform = CFrame.Angles(pitchRad, 0, st.CurrentBank)
			end

			-- 3. Scale exhaust smoke dynamically with throttle & Nitro Overdrive
			local exhaust = bike:FindFirstChild("ExhaustPipeR")
			local smoke = if exhaust then exhaust:FindFirstChild("ExhaustSmoke") else nil
			if smoke and smoke:IsA("ParticleEmitter") then
				smoke.Rate = if isTurbo then 38 else (4 + speedFactor * 16)
			end

			-- 4. Lock rider into realistic leaning seated posture!
			applySeatedBikePose(char, st.CurrentBank, isSedan)
		end
	end)
end

function MotorbikeController.Stop(): ()
	if steppedConn then
		steppedConn:Disconnect()
		steppedConn = nil
	end
	table.clear(riderStates)
end

return MotorbikeController
