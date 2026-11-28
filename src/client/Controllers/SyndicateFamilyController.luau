--!strict

-- SyndicateFamilyController:
-- Brings Syndicate Families directly onto the Main Screen HUD (beside TopStatsBar, mirroring Scoreboard)
-- with an always-visible Family Crest status pill + a dedicated, user-friendly On-Screen Family Modal
-- for founding named families, browsing & joining active server families, viewing live member rosters,
-- and tracking Co-op Alliance buffs (Zero Friendly Fire + +20% Raid Dividends).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local SectorConfig = require(
	ReplicatedStorage:WaitForChild("shared"):WaitForChild("config"):WaitForChild("SectorConfig")
)
local ModelPreviewHelper = require(script.Parent:WaitForChild("ModelPreviewHelper"))

local SyndicateFamilyController = {}

local FONT_TITLE = Enum.Font.GothamBlack
local FONT_BODY = Enum.Font.GothamBold
local FONT_REG = Enum.Font.Gotham

-- Luxury "Noir Syndicate Bistro" Palette (matches HUDController & ScoreboardController)
local C_OBS = Color3.fromRGB(15, 18, 25)
local C_OBS_DEEP = Color3.fromRGB(10, 12, 18)
local C_INNER = Color3.fromRGB(22, 26, 36)
local C_CARD = Color3.fromRGB(19, 23, 33)
local C_BORDER = Color3.fromRGB(54, 60, 74)
local C_GOLD = Color3.fromRGB(228, 186, 92)
local C_GOLD_HI = Color3.fromRGB(255, 224, 128)
local C_GOLD_DIM = Color3.fromRGB(122, 102, 58)
local C_BONE = Color3.fromRGB(242, 240, 234)
local C_ASH = Color3.fromRGB(156, 164, 182)
local C_MUTED = Color3.fromRGB(104, 112, 130)

local C_GREEN = Color3.fromRGB(48, 198, 116)
local C_GREEN_BG = Color3.fromRGB(18, 48, 34)
local C_BLUE = Color3.fromRGB(54, 148, 242)
local C_RED = Color3.fromRGB(218, 66, 78)
local C_RED_BG = Color3.fromRGB(52, 20, 26)
local C_LOCAL_BG = Color3.fromRGB(36, 31, 20)

local PRESET_NAMES = {
	"CORLEONE",
	"DRAGON CARTEL",
	"GOLD SYNDICATE",
	"SHADOW CLAN",
}

local initialized = false
local isOpen = false
local dispatchAction: ((string, any?) -> ())? = nil
local onClickSfx: (() -> ())? = nil
local onBeforeOpen: (() -> ())? = nil

local overlayGui: ScreenGui? = nil
local overlayScale: UIScale? = nil
local backdrop: TextButton? = nil
local cardFrame: Frame? = nil
local cardScale: UIScale? = nil

-- On-Screen HUD Pill widgets
local hudBtn: TextButton? = nil
local hudStroke: UIStroke? = nil
local hudTitleLbl: TextLabel? = nil
local hudSubLbl: TextLabel? = nil
local hudKeyCap: TextLabel? = nil

-- Modal Header widgets
local headerTitleLbl: TextLabel? = nil
local headerStatusPill: TextLabel? = nil

-- Body View containers
local soloView: Frame? = nil
local memberView: Frame? = nil
local nameInputBox: TextBox? = nil
local openListHeaderLbl: TextLabel? = nil
local openListScroll: ScrollingFrame? = nil

-- Member View widgets
local myFamNameLbl: TextLabel? = nil
local myFamMetaLbl: TextLabel? = nil
local rosterHeaderLbl: TextLabel? = nil
local rosterScroll: ScrollingFrame? = nil
local rivalFooterLbl: TextLabel? = nil

local latestFamilySnap: { [string]: any }? = nil
local avatarCache: { [number]: string } = {}
local avatarPending: { [number]: boolean } = {}

local function makeCorner(parent: Instance, radius: number): UICorner
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
	return c
end

local function makeStroke(parent: Instance, color: Color3, thickness: number, transparency: number?): UIStroke
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness
	s.Transparency = transparency or 0
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
	return s
end

local function addGradient(parent: Instance, topCol: Color3, botCol: Color3): UIGradient
	local g = Instance.new("UIGradient")
	g.Rotation = 90
	g.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, topCol),
		ColorSequenceKeypoint.new(1, botCol),
	})
	g.Parent = parent
	return g
end

local function makeActionBtn(
	parent: Instance,
	text: string,
	bg: Color3,
	pos: UDim2,
	size: UDim2,
	onClick: () -> ()
): TextButton
	local b = Instance.new("TextButton")
	b.Position = pos
	b.Size = size
	b.BackgroundColor3 = bg
	b.BorderSizePixel = 0
	b.Font = FONT_TITLE
	b.Text = text
	b.TextSize = 11
	b.TextColor3 = Color3.new(1, 1, 1)
	b.AutoButtonColor = false
	b.Parent = parent
	makeCorner(b, 7)
	makeStroke(b, bg:Lerp(Color3.new(1, 1, 1), 0.35), 1.1, 0.25)
	addGradient(b, bg:Lerp(Color3.new(1, 1, 1), 0.14), bg:Lerp(Color3.new(0, 0, 0), 0.18))

	b.MouseEnter:Connect(function()
		b.BackgroundColor3 = bg:Lerp(Color3.new(1, 1, 1), 0.12)
	end)
	b.MouseLeave:Connect(function()
		b.BackgroundColor3 = bg
	end)
	b.MouseButton1Click:Connect(function()
		if onClickSfx then
			onClickSfx()
		end
		onClick()
	end)
	return b
end

local function createCrestPreview(parent: Instance, size: UDim2, pos: UDim2, zIndex: number?): GuiObject
	local host = Instance.new("Frame")
	host.Name = "FamilyCrestHost"
	host.Position = pos
	host.Size = size
	host.BackgroundTransparency = 1
	host.BorderSizePixel = 0
	host.Active = false
	if zIndex then
		host.ZIndex = zIndex
	end
	host.Parent = parent

	local prev = ModelPreviewHelper.CreatePreview(
		host,
		"Empire",
		"FAM",
		UDim2.fromScale(1, 1),
		UDim2.new(),
		C_OBS_DEEP
	)
	prev.BackgroundTransparency = 1
	prev.Active = false
	if zIndex then
		prev.ZIndex = zIndex
	end
	local st = prev:FindFirstChildOfClass("UIStroke")
	if st then
		st:Destroy()
	end
	for _, desc in ipairs(prev:GetDescendants()) do
		if desc:IsA("GuiObject") then
			desc.Active = false
			if zIndex then
				desc.ZIndex = zIndex
			end
		end
	end
	return host
end

local function loadAvatarAsync(userId: number, img: ImageLabel, fallback: TextLabel): ()
	if userId <= 0 then
		img.Visible = false
		fallback.Visible = true
		return
	end
	local cached = avatarCache[userId]
	if cached then
		if cached ~= "" then
			img.Image = cached
			img.Visible = true
			fallback.Visible = false
		else
			img.Visible = false
			fallback.Visible = true
		end
		return
	end
	img.Visible = false
	fallback.Visible = true
	if avatarPending[userId] then
		return
	end
	avatarPending[userId] = true
	task.spawn(function()
		local ok, content, isReady = pcall(function()
			return Players:GetUserThumbnailAsync(userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
		end)
		avatarPending[userId] = nil
		if ok and isReady and typeof(content) == "string" and content ~= "" then
			avatarCache[userId] = content
			if img.Parent then
				img.Image = content
				img.Visible = true
				fallback.Visible = false
			end
		else
			avatarCache[userId] = ""
		end
	end)
end

local function clearListChildren(container: Instance): ()
	for _, ch in ipairs(container:GetChildren()) do
		if not ch:IsA("UIListLayout") and not ch:IsA("UIPadding") then
			ch:Destroy()
		end
	end
end

local function updateResponsiveLayout(): ()
	local cam = Workspace.CurrentCamera
	if not cam then
		return
	end
	local vp = cam.ViewportSize
	if vp.X <= 1 or vp.Y <= 1 then
		return
	end

	local playerGui = Players.LocalPlayer:FindFirstChild("PlayerGui")
	local scaleAttr = if playerGui then playerGui:GetAttribute("FoodEmpireHUDScale") else nil
	local hudScale = if typeof(scaleAttr) == "number" and scaleAttr > 0.1
		then scaleAttr
		else math.clamp(math.min(vp.X / 1360, vp.Y / 760), 0.62, 1.15)
	if overlayScale then
		overlayScale.Scale = hudScale
	end

	local logicalW = vp.X / hudScale
	local logicalH = vp.Y / hudScale

	-- Mirror ScoreboardToggleBtn cleanly on the LEFT of TopStatsBar (zero overlap on all screen widths!)
	if hudBtn and hudSubLbl and hudKeyCap then
		if logicalW >= 1180 then
			hudBtn.AnchorPoint = Vector2.new(1, 0)
			hudBtn.Position = UDim2.new(0.5, -308, 0, 8)
			hudBtn.Size = UDim2.fromOffset(168, 44)
			hudSubLbl.Visible = true
			hudKeyCap.Visible = true
		else
			-- On compact/narrow viewports, sit cleanly left of ScoreboardToggleBtn (which centers at X=0.5, W=132, Y=84)
			hudBtn.AnchorPoint = Vector2.new(1, 0)
			hudBtn.Position = UDim2.new(0.5, -74, 0, 84)
			hudBtn.Size = UDim2.fromOffset(146, 28)
			hudSubLbl.Visible = false
			hudKeyCap.Visible = false
		end
	end

	if cardFrame then
		local cardW = math.clamp(math.floor(logicalW - 48), 420, 640)
		local cardH = math.clamp(math.floor(logicalH - 44), 380, 488)
		cardFrame.Size = UDim2.fromOffset(cardW, cardH)
	end
end

local function renderFamilyState(): ()
	local fam = latestFamilySnap
	local inFam = typeof(fam) == "table" and fam.InFamily == true
	local famName = if inFam and typeof(fam.FamilyName) == "string" then fam.FamilyName else ""
	local founderName = if inFam and typeof(fam.FounderName) == "string" then fam.FounderName else "DON"
	local maxMembers = if typeof(fam) == "table" and typeof(fam.MaxMembers) == "number" then fam.MaxMembers else 4
	local memberDetails: { any } = if typeof(fam) == "table" and typeof(fam.MemberDetails) == "table"
		then fam.MemberDetails
		else {}
	local membersFallback: { any } = if typeof(fam) == "table" and typeof(fam.Members) == "table"
		then fam.Members
		else {}
	local openFamilies: { any } = if typeof(fam) == "table" and typeof(fam.OpenFamilies) == "table"
		then fam.OpenFamilies
		else {}
	local memberCount = if #memberDetails > 0 then #memberDetails else #membersFallback

	-- 1. Update On-Screen HUD Pill
	if hudTitleLbl and hudSubLbl and hudStroke then
		if inFam then
			hudTitleLbl.Text = famName
			hudTitleLbl.TextColor3 = C_GOLD_HI
			hudSubLbl.Text = string.format("%d/%d ALLIES • +20%% RAID", memberCount, maxMembers)
			hudSubLbl.TextColor3 = C_GREEN
			hudStroke.Color = if isOpen then C_GOLD_HI else C_GOLD
		else
			hudTitleLbl.Text = "FAMILY"
			hudTitleLbl.TextColor3 = C_BONE
			if #openFamilies > 0 then
				hudSubLbl.Text = string.format("%d OPEN • JOIN / FOUND", #openFamilies)
				hudSubLbl.TextColor3 = C_GREEN
			else
				hudSubLbl.Text = "FOUND / JOIN • +20%"
				hudSubLbl.TextColor3 = C_GOLD
			end
			hudStroke.Color = if isOpen then C_GOLD else C_GOLD_DIM
		end
	end

	-- 2. Update Modal Header
	if headerTitleLbl and headerStatusPill then
		if inFam then
			headerTitleLbl.Text = famName
			headerStatusPill.Text = string.format("%d / %d ALLIES", memberCount, maxMembers)
			headerStatusPill.TextColor3 = C_GREEN
			headerStatusPill.BackgroundColor3 = C_GREEN_BG
		else
			headerTitleLbl.Text = "SYNDICATE FAMILIES"
			headerStatusPill.Text = if #openFamilies > 0
				then string.format("%d ACTIVE IN SERVER", #openFamilies)
				else "NO FAMILY YET"
			headerStatusPill.TextColor3 = if #openFamilies > 0 then C_GOLD_HI else C_ASH
			headerStatusPill.BackgroundColor3 = C_INNER
		end
	end

	-- 3. Toggle Solo vs Member Body Views
	if soloView and memberView then
		soloView.Visible = not inFam
		memberView.Visible = inFam
	end

	-- 4. Populate Solo View: Open Server Families Browser
	if not inFam and openListScroll and openListHeaderLbl then
		clearListChildren(openListScroll)
		openListHeaderLbl.Text = string.format("ACTIVE FAMILIES IN SERVER (%d)", #openFamilies)

		if #openFamilies == 0 then
			local emptyCard = Instance.new("Frame")
			emptyCard.Name = "EmptyOpenFamilies"
			emptyCard.LayoutOrder = 1
			emptyCard.Size = UDim2.new(1, 0, 0, 74)
			emptyCard.BackgroundColor3 = C_CARD
			emptyCard.BorderSizePixel = 0
			emptyCard.Parent = openListScroll
			makeCorner(emptyCard, 9)
			makeStroke(emptyCard, C_BORDER, 1, 0.35)

			local eTitle = Instance.new("TextLabel")
			eTitle.Position = UDim2.new(0, 14, 0, 14)
			eTitle.Size = UDim2.new(1, -28, 0, 18)
			eTitle.BackgroundTransparency = 1
			eTitle.Font = FONT_TITLE
			eTitle.Text = "NO ACTIVE FAMILIES IN THIS SERVER YET"
			eTitle.TextSize = 11
			eTitle.TextColor3 = C_GOLD
			eTitle.Parent = emptyCard

			local eSub = Instance.new("TextLabel")
			eSub.Position = UDim2.new(0, 14, 0, 34)
			eSub.Size = UDim2.new(1, -28, 0, 30)
			eSub.BackgroundTransparency = 1
			eSub.Font = FONT_REG
			eSub.TextWrapped = true
			eSub.Text = "Pick a preset or type your Mafia Family name above and click FOUND FAMILY to launch the first alliance!"
			eSub.TextSize = 10
			eSub.TextColor3 = C_ASH
			eSub.Parent = emptyCard
		else
			for idx, of in ipairs(openFamilies) do
				if typeof(of) == "table" and typeof(of.Id) == "string" then
					local fid = of.Id
					local fname = tostring(of.Name or "SYNDICATE FAMILY")
					local fdon = tostring(of.FounderName or "Don")
					local fcount = tonumber(of.Count) or 1
					local fmax = tonumber(of.MaxCount) or maxMembers
					local isFull = fcount >= fmax

					local row = Instance.new("Frame")
					row.Name = "OpenFam_" .. fid
					row.LayoutOrder = idx
					row.Size = UDim2.new(1, 0, 0, 56)
					row.BackgroundColor3 = C_CARD
					row.BorderSizePixel = 0
					row.Parent = openListScroll
					makeCorner(row, 9)
					makeStroke(row, if isFull then C_BORDER else C_GOLD_DIM, 1.1, 0.25)

					createCrestPreview(row, UDim2.fromOffset(36, 36), UDim2.new(0, 10, 0.5, -18), 65)

					local nLbl = Instance.new("TextLabel")
					nLbl.Position = UDim2.new(0, 54, 0, 9)
					nLbl.Size = UDim2.new(1, -220, 0, 18)
					nLbl.BackgroundTransparency = 1
					nLbl.Font = FONT_TITLE
					nLbl.TextXAlignment = Enum.TextXAlignment.Left
					nLbl.TextTruncate = Enum.TextTruncate.AtEnd
					nLbl.Text = fname
					nLbl.TextSize = 13
					nLbl.TextColor3 = C_GOLD_HI
					nLbl.Parent = row

					local dLbl = Instance.new("TextLabel")
					dLbl.Position = UDim2.new(0, 54, 0, 29)
					dLbl.Size = UDim2.new(1, -220, 0, 16)
					dLbl.BackgroundTransparency = 1
					dLbl.Font = FONT_REG
					dLbl.TextXAlignment = Enum.TextXAlignment.Left
					dLbl.TextTruncate = Enum.TextTruncate.AtEnd
					dLbl.Text = string.format("Don: %s  ·  No Friendly Fire & +20%% Dividends", fdon)
					dLbl.TextSize = 10
					dLbl.TextColor3 = C_ASH
					dLbl.Parent = row

					local slotPill = Instance.new("TextLabel")
					slotPill.AnchorPoint = Vector2.new(1, 0.5)
					slotPill.Position = UDim2.new(1, -108, 0.5, 0)
					slotPill.Size = UDim2.fromOffset(48, 24)
					slotPill.BackgroundColor3 = if isFull then C_RED_BG else C_GREEN_BG
					slotPill.Font = FONT_TITLE
					slotPill.Text = string.format("%d/%d", fcount, fmax)
					slotPill.TextSize = 11
					slotPill.TextColor3 = if isFull then C_RED else C_GREEN
					slotPill.Parent = row
					makeCorner(slotPill, 6)

					if isFull then
						local fullLbl = Instance.new("TextLabel")
						fullLbl.AnchorPoint = Vector2.new(1, 0.5)
						fullLbl.Position = UDim2.new(1, -12, 0.5, 0)
						fullLbl.Size = UDim2.fromOffset(88, 32)
						fullLbl.BackgroundColor3 = C_INNER
						fullLbl.Font = FONT_TITLE
						fullLbl.Text = "FULL"
						fullLbl.TextSize = 11
						fullLbl.TextColor3 = C_MUTED
						fullLbl.Parent = row
						makeCorner(fullLbl, 7)
					else
						makeActionBtn(
							row,
							"JOIN FAMILY",
							C_BLUE,
							UDim2.new(1, -100, 0.5, -16),
							UDim2.fromOffset(88, 32),
							function()
								if dispatchAction then
									dispatchAction("JoinFamily", fid)
								end
							end
						)
					end
				end
			end
		end
		openListScroll.CanvasSize = UDim2.fromOffset(0, math.max(80, #openFamilies * 62 + 8))
	end

	-- 5. Populate Member View: Family Header + Live Member Roster
	if inFam and myFamNameLbl and myFamMetaLbl and rosterHeaderLbl and rosterScroll and rivalFooterLbl then
		myFamNameLbl.Text = famName
		myFamMetaLbl.Text = string.format("DON: %s   ·   %d / %d ALLIES ONLINE", string.upper(founderName), memberCount, maxMembers)
		rosterHeaderLbl.Text = string.format("FAMILY ROSTER (%d / %d)", memberCount, maxMembers)

		clearListChildren(rosterScroll)
		local localUserId = Players.LocalPlayer.UserId

		for idx, md in ipairs(memberDetails) do
			if typeof(md) == "table" then
				local uid = tonumber(md.UserId) or 0
				local dname = tostring(md.DisplayName or "Member")
				local baseSlot = tostring(md.BaseSlot or "Unassigned")
				local isFounder = md.IsFounder == true
				local isSelf = uid == localUserId
				local slotCol = SectorConfig.FactionColors[baseSlot] or C_ASH

				local row = Instance.new("Frame")
				row.Name = "MemberRow_" .. tostring(idx)
				row.LayoutOrder = idx
				row.Size = UDim2.new(1, 0, 0, 52)
				row.BackgroundColor3 = if isSelf then C_LOCAL_BG else C_CARD
				row.BorderSizePixel = 0
				row.Parent = rosterScroll
				makeCorner(row, 8)
				makeStroke(row, if isSelf then C_GOLD else C_BORDER, if isSelf then 1.3 else 1.0, 0.25)

				-- Avatar circle
				local avWrap = Instance.new("Frame")
				avWrap.Position = UDim2.new(0, 10, 0.5, -18)
				avWrap.Size = UDim2.fromOffset(36, 36)
				avWrap.BackgroundColor3 = C_INNER
				avWrap.ClipsDescendants = true
				avWrap.Parent = row
				makeCorner(avWrap, 18)
				makeStroke(avWrap, if isFounder then C_GOLD else C_GREEN, 1.3, 0.2)

				local avImg = Instance.new("ImageLabel")
				avImg.Size = UDim2.fromScale(1, 1)
				avImg.BackgroundTransparency = 1
				avImg.ScaleType = Enum.ScaleType.Crop
				avImg.Visible = false
				avImg.Parent = avWrap
				makeCorner(avImg, 18)

				local avFallback = Instance.new("TextLabel")
				avFallback.Size = UDim2.fromScale(1, 1)
				avFallback.BackgroundTransparency = 1
				avFallback.Font = FONT_TITLE
				avFallback.Text = string.upper(string.sub(dname, 1, 2))
				avFallback.TextSize = 12
				avFallback.TextColor3 = C_GOLD
				avFallback.Parent = avWrap
				loadAvatarAsync(uid, avImg, avFallback)

				-- Name + Badges row
				local nameWrap = Instance.new("Frame")
				nameWrap.Position = UDim2.new(0, 56, 0, 8)
				nameWrap.Size = UDim2.new(1, -210, 0, 19)
				nameWrap.BackgroundTransparency = 1
				nameWrap.Parent = row

				local nList = Instance.new("UIListLayout")
				nList.FillDirection = Enum.FillDirection.Horizontal
				nList.VerticalAlignment = Enum.VerticalAlignment.Center
				nList.SortOrder = Enum.SortOrder.LayoutOrder
				nList.Padding = UDim.new(0, 6)
				nList.Parent = nameWrap

				local nameLbl = Instance.new("TextLabel")
				nameLbl.LayoutOrder = 1
				nameLbl.AutomaticSize = Enum.AutomaticSize.X
				nameLbl.Size = UDim2.fromOffset(0, 18)
				nameLbl.BackgroundTransparency = 1
				nameLbl.Font = FONT_TITLE
				nameLbl.Text = dname
				nameLbl.TextSize = 13
				nameLbl.TextColor3 = if isSelf then C_GOLD_HI else C_BONE
				nameLbl.Parent = nameWrap

				local roleTag = Instance.new("TextLabel")
				roleTag.LayoutOrder = 2
				roleTag.Size = UDim2.fromOffset(if isFounder then 42 else 40, 16)
				roleTag.BackgroundColor3 = if isFounder then C_GOLD else C_GREEN_BG
				roleTag.Font = FONT_TITLE
				roleTag.Text = if isFounder then "DON" else "ALLY"
				roleTag.TextSize = 8
				roleTag.TextColor3 = if isFounder then C_OBS_DEEP else C_GREEN
				roleTag.Parent = nameWrap
				makeCorner(roleTag, 4)

				if isSelf then
					local youTag = Instance.new("TextLabel")
					youTag.LayoutOrder = 3
					youTag.Size = UDim2.fromOffset(32, 16)
					youTag.BackgroundColor3 = C_INNER
					youTag.Font = FONT_TITLE
					youTag.Text = "YOU"
					youTag.TextSize = 8
					youTag.TextColor3 = C_GOLD_HI
					youTag.Parent = nameWrap
					makeCorner(youTag, 4)
					makeStroke(youTag, C_GOLD, 1, 0.3)
				end

				local subRowLbl = Instance.new("TextLabel")
				subRowLbl.Position = UDim2.new(0, 56, 0, 29)
				subRowLbl.Size = UDim2.new(1, -210, 0, 15)
				subRowLbl.BackgroundTransparency = 1
				subRowLbl.Font = FONT_BODY
				subRowLbl.TextXAlignment = Enum.TextXAlignment.Left
				subRowLbl.Text = "PROTECTED ALLY  ·  SHARES +20% RAID DIVIDENDS"
				subRowLbl.TextSize = 9
				subRowLbl.TextColor3 = C_ASH
				subRowLbl.Parent = row

				-- Base Slot Pill on Right
				local basePill = Instance.new("TextLabel")
				basePill.AnchorPoint = Vector2.new(1, 0.5)
				basePill.Position = UDim2.new(1, -12, 0.5, 0)
				basePill.Size = UDim2.fromOffset(102, 24)
				basePill.BackgroundColor3 = slotCol:Lerp(C_OBS_DEEP, 0.78)
				basePill.Font = FONT_TITLE
				basePill.Text = if baseSlot == "Unassigned" then "NO BASE" else (string.upper(baseSlot) .. " BASE")
				basePill.TextSize = 9
				basePill.TextColor3 = slotCol:Lerp(Color3.new(1, 1, 1), 0.28)
				basePill.Parent = row
				makeCorner(basePill, 6)
				makeStroke(basePill, slotCol, 1, 0.35)
			end
		end

		-- Show open invitation slots up to MaxMembers
		for slotIdx = memberCount + 1, maxMembers do
			local openRow = Instance.new("Frame")
			openRow.Name = "OpenSlot_" .. tostring(slotIdx)
			openRow.LayoutOrder = slotIdx
			openRow.Size = UDim2.new(1, 0, 0, 42)
			openRow.BackgroundColor3 = C_OBS_DEEP
			openRow.BackgroundTransparency = 0.25
			openRow.BorderSizePixel = 0
			openRow.Parent = rosterScroll
			makeCorner(openRow, 8)
			makeStroke(openRow, C_BORDER, 1, 0.5)

			local oLbl = Instance.new("TextLabel")
			oLbl.Position = UDim2.new(0, 14, 0, 0)
			oLbl.Size = UDim2.new(1, -28, 1, 0)
			oLbl.BackgroundTransparency = 1
			oLbl.Font = FONT_BODY
			oLbl.TextXAlignment = Enum.TextXAlignment.Left
			oLbl.Text = string.format("OPEN ALLY SLOT #%d  ·  Friends in this server can join %s from their HUD!", slotIdx, famName)
			oLbl.TextSize = 10
			oLbl.TextColor3 = C_MUTED
			oLbl.Parent = openRow
		end

		rosterScroll.CanvasSize = UDim2.fromOffset(0, memberCount * 58 + math.max(0, maxMembers - memberCount) * 48 + 8)

		if #openFamilies > 0 then
			local names: { string } = {}
			for i = 1, math.min(3, #openFamilies) do
				local rf = openFamilies[i]
				if typeof(rf) == "table" then
					table.insert(names, string.format("%s (%d/%d)", tostring(rf.Name), tonumber(rf.Count) or 1, tonumber(rf.MaxCount) or maxMembers))
				end
			end
			rivalFooterLbl.Text = "OTHER SERVER FAMILIES:  " .. table.concat(names, "   ·   ")
			rivalFooterLbl.TextColor3 = C_GOLD
		else
			rivalFooterLbl.Text = "YOUR FAMILY RULES THIS SERVER  ·  Tell friends to press [O] or click FAMILY on the top bar to join!"
			rivalFooterLbl.TextColor3 = C_ASH
		end
	end
end

function SyndicateFamilyController.IsOpen(): boolean
	return isOpen
end

function SyndicateFamilyController.Open(): ()
	if isOpen or not backdrop or not cardScale then
		return
	end
	if onBeforeOpen then
		onBeforeOpen()
	end
	isOpen = true
	if onClickSfx then
		onClickSfx()
	end
	renderFamilyState()
	updateResponsiveLayout()

	backdrop.Visible = true
	cardScale.Scale = 0.94
	TweenService:Create(
		cardScale,
		TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Scale = 1 }
	):Play()
end

function SyndicateFamilyController.Close(): ()
	if not isOpen or not backdrop or not cardScale then
		return
	end
	isOpen = false
	local bd = backdrop
	local sc = cardScale
	local tw = TweenService:Create(
		sc,
		TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ Scale = 0.95 }
	)
	tw.Completed:Connect(function()
		if not isOpen and bd then
			bd.Visible = false
		end
	end)
	tw:Play()
	renderFamilyState()
end

function SyndicateFamilyController.Toggle(): ()
	if isOpen then
		SyndicateFamilyController.Close()
	else
		SyndicateFamilyController.Open()
	end
end

function SyndicateFamilyController.Update(state: { [string]: any }): ()
	if typeof(state) == "table" then
		local snap = if typeof(state.SyndicateFamily) == "table"
			then state.SyndicateFamily
			elseif typeof(state.Family) == "table" then state.Family
			else nil
		if snap then
			latestFamilySnap = snap
			renderFamilyState()
		end
	end
end

function SyndicateFamilyController.Init(
	parentGui: ScreenGui,
	actionCallback: (string, any?) -> (),
	clickSfxCallback: (() -> ())?,
	beforeOpenCallback: (() -> ())?
): ()
	if initialized then
		return
	end
	initialized = true
	dispatchAction = actionCallback
	onClickSfx = clickSfxCallback
	onBeforeOpen = beforeOpenCallback

	-- =========================================================================
	-- 1. ALWAYS-VISIBLE ON-SCREEN SYNDICATE FAMILY HUD PILL (Left of TopStatsBar)
	-- =========================================================================
	local btn = Instance.new("TextButton")
	btn.Name = "SyndicateFamilyHudBtn"
	btn.AnchorPoint = Vector2.new(1, 0)
	btn.Position = UDim2.new(0.5, -308, 0, 8)
	btn.Size = UDim2.fromOffset(168, 44)
	btn.BackgroundColor3 = C_OBS
	btn.BackgroundTransparency = 0.05
	btn.Text = ""
	btn.AutoButtonColor = false
	btn.ZIndex = 12
	btn.Parent = parentGui
	makeCorner(btn, 8)
	hudStroke = makeStroke(btn, C_GOLD_DIM, 1.3, 0.08)
	addGradient(btn, Color3.fromRGB(26, 28, 40), C_OBS_DEEP)
	hudBtn = btn

	createCrestPreview(btn, UDim2.fromOffset(30, 30), UDim2.new(0, 7, 0.5, -15), 13)

	local hTitle = Instance.new("TextLabel")
	hTitle.Name = "FamilyHudTitle"
	hTitle.Position = UDim2.new(0, 41, 0, 5)
	hTitle.Size = UDim2.new(1, -74, 0, 17)
	hTitle.BackgroundTransparency = 1
	hTitle.Font = FONT_TITLE
	hTitle.Text = "FAMILY"
	hTitle.TextSize = 11
	hTitle.TextXAlignment = Enum.TextXAlignment.Left
	hTitle.TextTruncate = Enum.TextTruncate.AtEnd
	hTitle.TextColor3 = C_BONE
	hTitle.Active = false
	hTitle.ZIndex = 13
	hTitle.Parent = btn
	hudTitleLbl = hTitle

	local hSub = Instance.new("TextLabel")
	hSub.Name = "FamilyHudSub"
	hSub.Position = UDim2.new(0, 41, 0, 23)
	hSub.Size = UDim2.new(1, -74, 0, 13)
	hSub.BackgroundTransparency = 1
	hSub.Font = FONT_BODY
	hSub.Text = "FOUND / JOIN • +20%"
	hSub.TextSize = 8
	hSub.TextXAlignment = Enum.TextXAlignment.Left
	hSub.TextTruncate = Enum.TextTruncate.AtEnd
	hSub.TextColor3 = C_GOLD
	hSub.Active = false
	hSub.ZIndex = 13
	hSub.Parent = btn
	hudSubLbl = hSub

	local keyCap = Instance.new("TextLabel")
	keyCap.Name = "FamilyKeyCap"
	keyCap.AnchorPoint = Vector2.new(1, 0.5)
	keyCap.Position = UDim2.new(1, -7, 0.5, 0)
	keyCap.Size = UDim2.fromOffset(22, 20)
	keyCap.BackgroundColor3 = C_INNER
	keyCap.Font = FONT_TITLE
	keyCap.Text = "O"
	keyCap.TextSize = 10
	keyCap.TextColor3 = C_GOLD_HI
	keyCap.Active = false
	keyCap.ZIndex = 13
	keyCap.Parent = btn
	makeCorner(keyCap, 5)
	makeStroke(keyCap, C_GOLD_DIM, 1, 0.25)
	hudKeyCap = keyCap

	btn.MouseEnter:Connect(function()
		if hudStroke then
			hudStroke.Color = C_GOLD_HI
		end
	end)
	btn.MouseLeave:Connect(function()
		renderFamilyState()
	end)
	btn.MouseButton1Click:Connect(function()
		SyndicateFamilyController.Toggle()
	end)

	-- =========================================================================
	-- 2. DEDICATED ON-SCREEN SYNDICATE FAMILY MODAL (DisplayOrder = 52)
	-- =========================================================================
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local existing = playerGui:FindFirstChild("FoodEmpireFamilyGui")
	if existing then
		existing:Destroy()
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "FoodEmpireFamilyGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 52
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = playerGui
	overlayGui = gui

	local sc = Instance.new("UIScale")
	sc.Name = "ResponsiveFamilyScale"
	sc.Scale = 1
	sc.Parent = gui
	overlayScale = sc

	local scrim = Instance.new("TextButton")
	scrim.Name = "SyndicateFamilyBackdrop"
	scrim.Size = UDim2.fromScale(1, 1)
	scrim.BackgroundColor3 = Color3.fromRGB(6, 8, 13)
	scrim.BackgroundTransparency = 0.42
	scrim.BorderSizePixel = 0
	scrim.Text = ""
	scrim.AutoButtonColor = false
	scrim.Visible = false
	scrim.ZIndex = 60
	scrim.Parent = gui
	backdrop = scrim

	scrim.MouseButton1Click:Connect(function()
		SyndicateFamilyController.Close()
	end)

	local card = Instance.new("TextButton")
	card.Name = "SyndicateFamilyCard"
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.fromScale(0.5, 0.5)
	card.Size = UDim2.fromOffset(640, 480)
	card.BackgroundColor3 = C_OBS_DEEP
	card.BackgroundTransparency = 0.02
	card.BorderSizePixel = 0
	card.Text = ""
	card.AutoButtonColor = false
	card.ClipsDescendants = true
	card.ZIndex = 62
	card.Parent = scrim
	makeCorner(card, 13)
	makeStroke(card, C_GOLD, 1.8, 0.1)
	addGradient(card, Color3.fromRGB(20, 24, 36), C_OBS_DEEP)
	cardFrame = card

	local cScale = Instance.new("UIScale")
	cScale.Scale = 1
	cScale.Parent = card
	cardScale = cScale

	-- Header (60px)
	local header = Instance.new("Frame")
	header.Name = "Header"
	header.Size = UDim2.new(1, 0, 0, 60)
	header.BackgroundColor3 = Color3.fromRGB(22, 26, 38)
	header.BorderSizePixel = 0
	header.Parent = card

	local hLine = Instance.new("Frame")
	hLine.AnchorPoint = Vector2.new(0, 1)
	hLine.Position = UDim2.fromScale(0, 1)
	hLine.Size = UDim2.new(1, 0, 0, 1)
	hLine.BackgroundColor3 = C_GOLD_DIM
	hLine.BackgroundTransparency = 0.3
	hLine.BorderSizePixel = 0
	hLine.Parent = header

	createCrestPreview(header, UDim2.fromOffset(44, 44), UDim2.new(0, 14, 0.5, -22), 64)

	local mTitle = Instance.new("TextLabel")
	mTitle.Name = "ModalTitle"
	mTitle.Position = UDim2.new(0, 66, 0, 10)
	mTitle.Size = UDim2.new(1, -248, 0, 22)
	mTitle.BackgroundTransparency = 1
	mTitle.Font = FONT_TITLE
	mTitle.Text = "SYNDICATE FAMILIES"
	mTitle.TextSize = 17
	mTitle.TextXAlignment = Enum.TextXAlignment.Left
	mTitle.TextTruncate = Enum.TextTruncate.AtEnd
	mTitle.TextColor3 = C_GOLD_HI
	mTitle.Parent = header
	headerTitleLbl = mTitle

	local mSub = Instance.new("TextLabel")
	mSub.Position = UDim2.new(0, 66, 0, 34)
	mSub.Size = UDim2.new(1, -248, 0, 15)
	mSub.BackgroundTransparency = 1
	mSub.Font = FONT_BODY
	mSub.Text = "CO-OP MAFIA ALLIANCE  ·  [O] TOGGLE  ·  [ESC] CLOSE"
	mSub.TextSize = 9
	mSub.TextXAlignment = Enum.TextXAlignment.Left
	mSub.TextColor3 = C_ASH
	mSub.Parent = header

	local statusPill = Instance.new("TextLabel")
	statusPill.Name = "FamilyStatusPill"
	statusPill.AnchorPoint = Vector2.new(1, 0.5)
	statusPill.Position = UDim2.new(1, -56, 0.5, 0)
	statusPill.Size = UDim2.fromOffset(124, 28)
	statusPill.BackgroundColor3 = C_INNER
	statusPill.Font = FONT_TITLE
	statusPill.Text = "NO FAMILY YET"
	statusPill.TextSize = 10
	statusPill.TextColor3 = C_ASH
	statusPill.Parent = header
	makeCorner(statusPill, 7)
	makeStroke(statusPill, C_GOLD_DIM, 1, 0.25)
	headerStatusPill = statusPill

	local closeBtn = Instance.new("TextButton")
	closeBtn.Name = "CloseBtn"
	closeBtn.AnchorPoint = Vector2.new(1, 0.5)
	closeBtn.Position = UDim2.new(1, -14, 0.5, 0)
	closeBtn.Size = UDim2.fromOffset(32, 32)
	closeBtn.BackgroundColor3 = C_RED
	closeBtn.Font = FONT_TITLE
	closeBtn.Text = "X"
	closeBtn.TextSize = 14
	closeBtn.TextColor3 = Color3.new(1, 1, 1)
	closeBtn.AutoButtonColor = false
	closeBtn.Parent = header
	makeCorner(closeBtn, 7)
	makeStroke(closeBtn, Color3.fromRGB(255, 130, 140), 1, 0.35)
	closeBtn.MouseButton1Click:Connect(function()
		if onClickSfx then
			onClickSfx()
		end
		SyndicateFamilyController.Close()
	end)

	-- Perk Banner Strip (36px)
	local perkBar = Instance.new("Frame")
	perkBar.Name = "PerkBanner"
	perkBar.Position = UDim2.fromOffset(16, 68)
	perkBar.Size = UDim2.new(1, -32, 0, 32)
	perkBar.BackgroundTransparency = 1
	perkBar.Parent = card

	local perkLayout = Instance.new("UIListLayout")
	perkLayout.FillDirection = Enum.FillDirection.Horizontal
	perkLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	perkLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	perkLayout.Padding = UDim.new(0, 8)
	perkLayout.Parent = perkBar

	local function addPerkBadge(title: string, accent: Color3, bg: Color3): ()
		local badge = Instance.new("TextLabel")
		badge.Size = UDim2.new(0.32, 0, 1, 0)
		badge.BackgroundColor3 = bg
		badge.Font = FONT_TITLE
		badge.Text = title
		badge.TextSize = 9
		badge.TextColor3 = accent
		badge.Parent = perkBar
		makeCorner(badge, 6)
		makeStroke(badge, accent, 1, 0.45)
	end

	addPerkBadge("NO FRIENDLY FIRE", C_GREEN, C_GREEN_BG)
	addPerkBadge("+20% RAID DIVIDENDS", C_GOLD_HI, C_LOCAL_BG)
	addPerkBadge("UP TO 4 ALLIES", Color3.fromRGB(124, 194, 255), Color3.fromRGB(18, 32, 52))

	-- =========================================================================
	-- VIEW A: SOLO VIEW (Found Custom Family + Join Active Families Browser)
	-- =========================================================================
	local sView = Instance.new("Frame")
	sView.Name = "SoloFamilyView"
	sView.Position = UDim2.fromOffset(16, 108)
	sView.Size = UDim2.new(1, -32, 1, -122)
	sView.BackgroundTransparency = 1
	sView.Visible = true
	sView.Parent = card
	soloView = sView

	-- Found Family Card (top 132px)
	local createCard = Instance.new("Frame")
	createCard.Name = "FoundFamilyCard"
	createCard.Size = UDim2.new(1, 0, 0, 130)
	createCard.BackgroundColor3 = C_CARD
	createCard.BorderSizePixel = 0
	createCard.Parent = sView
	makeCorner(createCard, 10)
	makeStroke(createCard, C_GOLD, 1.3, 0.25)

	local cHead = Instance.new("TextLabel")
	cHead.Position = UDim2.fromOffset(14, 10)
	cHead.Size = UDim2.new(1, -28, 0, 18)
	cHead.BackgroundTransparency = 1
	cHead.Font = FONT_TITLE
	cHead.TextXAlignment = Enum.TextXAlignment.Left
	cHead.Text = "FOUND YOUR OWN SYNDICATE FAMILY (FREE)"
	cHead.TextSize = 12
	cHead.TextColor3 = C_GOLD_HI
	cHead.Parent = createCard

	local inputBox = Instance.new("TextBox")
	inputBox.Name = "FamilyNameInput"
	inputBox.Position = UDim2.fromOffset(14, 34)
	inputBox.Size = UDim2.new(1, -168, 0, 38)
	inputBox.BackgroundColor3 = C_OBS_DEEP
	inputBox.Font = FONT_TITLE
	inputBox.PlaceholderText = "Enter Mafia Family name (e.g. CORLEONE)..."
	inputBox.PlaceholderColor3 = C_MUTED
	inputBox.Text = ""
	inputBox.TextSize = 13
	inputBox.TextColor3 = C_BONE
	inputBox.TextXAlignment = Enum.TextXAlignment.Left
	inputBox.ClearTextOnFocus = false
	inputBox.Parent = createCard
	makeCorner(inputBox, 7)
	local inputStroke = makeStroke(inputBox, C_BORDER, 1.2, 0.15)
	local inputPad = Instance.new("UIPadding")
	inputPad.PaddingLeft = UDim.new(0, 12)
	inputPad.PaddingRight = UDim.new(0, 10)
	inputPad.Parent = inputBox
	nameInputBox = inputBox

	inputBox.Focused:Connect(function()
		inputStroke.Color = C_GOLD_HI
	end)
	inputBox.FocusLost:Connect(function(enterPressed: boolean)
		inputStroke.Color = C_BORDER
		if enterPressed and dispatchAction then
			dispatchAction("CreateFamily", inputBox.Text)
		end
	end)
	inputBox:GetPropertyChangedSignal("Text"):Connect(function()
		if #inputBox.Text > 20 then
			inputBox.Text = string.sub(inputBox.Text, 1, 20)
		end
	end)

	makeActionBtn(
		createCard,
		"FOUND FAMILY",
		C_GREEN,
		UDim2.new(1, -146, 0, 34),
		UDim2.fromOffset(132, 38),
		function()
			if dispatchAction then
				dispatchAction("CreateFamily", if nameInputBox then nameInputBox.Text else nil)
			end
		end
	)

	-- Quick-Pick Preset Name Chips
	local presetLbl = Instance.new("TextLabel")
	presetLbl.Position = UDim2.fromOffset(14, 78)
	presetLbl.Size = UDim2.fromOffset(82, 16)
	presetLbl.BackgroundTransparency = 1
	presetLbl.Font = FONT_BODY
	presetLbl.TextXAlignment = Enum.TextXAlignment.Left
	presetLbl.Text = "QUICK NAMES:"
	presetLbl.TextSize = 9
	presetLbl.TextColor3 = C_ASH
	presetLbl.Parent = createCard

	local presetRow = Instance.new("Frame")
	presetRow.Position = UDim2.fromOffset(14, 96)
	presetRow.Size = UDim2.new(1, -28, 0, 24)
	presetRow.BackgroundTransparency = 1
	presetRow.Parent = createCard

	local pLayout = Instance.new("UIListLayout")
	pLayout.FillDirection = Enum.FillDirection.Horizontal
	pLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	pLayout.Padding = UDim.new(0, 6)
	pLayout.Parent = presetRow

	for _, preset in ipairs(PRESET_NAMES) do
		local chip = Instance.new("TextButton")
		chip.AutomaticSize = Enum.AutomaticSize.X
		chip.Size = UDim2.fromOffset(0, 22)
		chip.BackgroundColor3 = C_INNER
		chip.Font = FONT_BODY
		chip.Text = preset
		chip.TextSize = 9
		chip.TextColor3 = C_GOLD
		chip.AutoButtonColor = false
		chip.Parent = presetRow
		makeCorner(chip, 5)
		makeStroke(chip, C_GOLD_DIM, 1, 0.35)
		local cPad = Instance.new("UIPadding")
		cPad.PaddingLeft = UDim.new(0, 9)
		cPad.PaddingRight = UDim.new(0, 9)
		cPad.Parent = chip

		chip.MouseButton1Click:Connect(function()
			if onClickSfx then
				onClickSfx()
			end
			if nameInputBox then
				nameInputBox.Text = preset
			end
		end)
	end

	-- Active Families Browser
	local olHead = Instance.new("TextLabel")
	olHead.Name = "OpenFamiliesHeader"
	olHead.Position = UDim2.fromOffset(2, 140)
	olHead.Size = UDim2.new(1, -4, 0, 18)
	olHead.BackgroundTransparency = 1
	olHead.Font = FONT_TITLE
	olHead.TextXAlignment = Enum.TextXAlignment.Left
	olHead.Text = "ACTIVE FAMILIES IN SERVER (0)"
	olHead.TextSize = 11
	olHead.TextColor3 = C_ASH
	olHead.Parent = sView
	openListHeaderLbl = olHead

	local olScroll = Instance.new("ScrollingFrame")
	olScroll.Name = "OpenFamiliesScroll"
	olScroll.Position = UDim2.fromOffset(0, 162)
	olScroll.Size = UDim2.new(1, 0, 1, -162)
	olScroll.BackgroundTransparency = 1
	olScroll.BorderSizePixel = 0
	olScroll.ScrollBarThickness = 4
	olScroll.ScrollBarImageColor3 = C_GOLD_DIM
	olScroll.CanvasSize = UDim2.fromOffset(0, 100)
	olScroll.Parent = sView
	openListScroll = olScroll

	local olLayout = Instance.new("UIListLayout")
	olLayout.SortOrder = Enum.SortOrder.LayoutOrder
	olLayout.Padding = UDim.new(0, 6)
	olLayout.Parent = olScroll

	-- =========================================================================
	-- VIEW B: IN-FAMILY VIEW (Banner + Live Member Roster + Leave Family)
	-- =========================================================================
	local mView = Instance.new("Frame")
	mView.Name = "MemberFamilyView"
	mView.Position = UDim2.fromOffset(16, 108)
	mView.Size = UDim2.new(1, -32, 1, -122)
	mView.BackgroundTransparency = 1
	mView.Visible = false
	mView.Parent = card
	memberView = mView

	local famBanner = Instance.new("Frame")
	famBanner.Name = "MyFamilyBanner"
	famBanner.Size = UDim2.new(1, 0, 0, 74)
	famBanner.BackgroundColor3 = C_LOCAL_BG
	famBanner.BorderSizePixel = 0
	famBanner.Parent = mView
	makeCorner(famBanner, 10)
	makeStroke(famBanner, C_GOLD, 1.5, 0.15)
	addGradient(famBanner, Color3.fromRGB(48, 38, 22), Color3.fromRGB(22, 20, 26))

	createCrestPreview(famBanner, UDim2.fromOffset(52, 52), UDim2.new(0, 12, 0.5, -26), 65)

	local mfName = Instance.new("TextLabel")
	mfName.Position = UDim2.new(0, 74, 0, 12)
	mfName.Size = UDim2.new(1, -220, 0, 24)
	mfName.BackgroundTransparency = 1
	mfName.Font = FONT_TITLE
	mfName.TextXAlignment = Enum.TextXAlignment.Left
	mfName.TextTruncate = Enum.TextTruncate.AtEnd
	mfName.Text = "CORLEONE"
	mfName.TextSize = 18
	mfName.TextColor3 = C_GOLD_HI
	mfName.Parent = famBanner
	myFamNameLbl = mfName

	local mfMeta = Instance.new("TextLabel")
	mfMeta.Position = UDim2.new(0, 74, 0, 38)
	mfMeta.Size = UDim2.new(1, -220, 0, 18)
	mfMeta.BackgroundTransparency = 1
	mfMeta.Font = FONT_BODY
	mfMeta.TextXAlignment = Enum.TextXAlignment.Left
	mfMeta.Text = "DON: PLAYER   ·   1 / 4 ALLIES ONLINE"
	mfMeta.TextSize = 10
	mfMeta.TextColor3 = C_GREEN
	mfMeta.Parent = famBanner
	myFamMetaLbl = mfMeta

	makeActionBtn(
		famBanner,
		"LEAVE FAMILY",
		C_RED,
		UDim2.new(1, -134, 0.5, -17),
		UDim2.fromOffset(120, 34),
		function()
			if dispatchAction then
				dispatchAction("LeaveFamily", nil)
			end
		end
	)

	local rHead = Instance.new("TextLabel")
	rHead.Position = UDim2.fromOffset(2, 84)
	rHead.Size = UDim2.new(1, -4, 0, 18)
	rHead.BackgroundTransparency = 1
	rHead.Font = FONT_TITLE
	rHead.TextXAlignment = Enum.TextXAlignment.Left
	rHead.Text = "FAMILY ROSTER (1 / 4)"
	rHead.TextSize = 11
	rHead.TextColor3 = C_ASH
	rHead.Parent = mView
	rosterHeaderLbl = rHead

	local rScroll = Instance.new("ScrollingFrame")
	rScroll.Name = "MemberRosterScroll"
	rScroll.Position = UDim2.fromOffset(0, 106)
	rScroll.Size = UDim2.new(1, 0, 1, -134)
	rScroll.BackgroundTransparency = 1
	rScroll.BorderSizePixel = 0
	rScroll.ScrollBarThickness = 4
	rScroll.ScrollBarImageColor3 = C_GOLD_DIM
	rScroll.CanvasSize = UDim2.fromOffset(0, 220)
	rScroll.Parent = mView
	rosterScroll = rScroll

	local rLayout = Instance.new("UIListLayout")
	rLayout.SortOrder = Enum.SortOrder.LayoutOrder
	rLayout.Padding = UDim.new(0, 6)
	rLayout.Parent = rScroll

	local rivalFoot = Instance.new("TextLabel")
	rivalFoot.Name = "RivalFamiliesFooter"
	rivalFoot.AnchorPoint = Vector2.new(0, 1)
	rivalFoot.Position = UDim2.new(0, 2, 1, 0)
	rivalFoot.Size = UDim2.new(1, -4, 0, 22)
	rivalFoot.BackgroundColor3 = C_INNER
	rivalFoot.Font = FONT_BODY
	rivalFoot.Text = "YOUR FAMILY RULES THIS SERVER"
	rivalFoot.TextSize = 9
	rivalFoot.TextColor3 = C_ASH
	rivalFoot.Parent = mView
	makeCorner(rivalFoot, 6)
	rivalFooterLbl = rivalFoot

	-- Responsive viewport & HUD scale binding
	local function bindResize(): ()
		local cam = Workspace.CurrentCamera
		if cam then
			cam:GetPropertyChangedSignal("ViewportSize"):Connect(updateResponsiveLayout)
		end
	end
	bindResize()
	Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(bindResize)
	local pg = Players.LocalPlayer:FindFirstChild("PlayerGui")
	if pg then
		pg:GetAttributeChangedSignal("FoodEmpireHUDScale"):Connect(updateResponsiveLayout)
	end

	renderFamilyState()
	updateResponsiveLayout()
end

return SyndicateFamilyController
