local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local player = Players.LocalPlayer

-- ================== CONFIG ==================
local TP_OFFSET = Vector3.new(0, 5, 0)

local itemColors = {
	Safe   = Color3.fromRGB(0, 255, 0),
	Key    = Color3.fromRGB(255, 255, 0),
	Airdrop = Color3.fromRGB(170, 0, 255),
	PARTS  = Color3.fromRGB(255, 165, 0),
	Cache  = Color3.fromRGB(0, 170, 255),
	Mines  = Color3.fromRGB(255, 0, 0),
	Flare  = Color3.fromRGB(255, 105, 180),
}

-- Ton détecteur original (reste le plus fiable chez toi)
local keywords = {"Safe", "Key", "Airdrop", "Cache", "PARTS", "Flare"}

-- Anti parasites (ajoute des mots si besoin)
local blacklistWords = {
	"circle", "light", "dust", "particle", "leaderboard", "spawn", "grass", "tree"
}

-- ================== GUI ==================
local gui = Instance.new("ScreenGui")
gui.Name = "ImGuiLikeMenu"
gui.Parent = player:WaitForChild("PlayerGui")
gui.DisplayOrder = 9999
gui.ResetOnSpawn = false

local frame = Instance.new("Frame", gui)
frame.Size = UDim2.new(0, 360, 0, 420)
frame.Position = UDim2.new(0, 15, 0, 15)
frame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
frame.BorderSizePixel = 0
frame.Active = true
frame.Draggable = true
frame.ZIndex = 10
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)

local title = Instance.new("TextLabel", frame)
title.Size = UDim2.new(1, 0, 0, 40)
title.BackgroundTransparency = 1
title.Text = "Toxyo Menu"
title.Font = Enum.Font.GothamBold
title.TextSize = 18
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.ZIndex = 11

local function createButton(text, yPos)
	local button = Instance.new("TextLabel", frame)
	button.Size = UDim2.new(0.9, 0, 0, 35)
	button.Position = UDim2.new(0.05, 0, 0, yPos)
	button.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	button.Text = text
	button.Font = Enum.Font.Gotham
	button.TextSize = 14
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	button.BorderSizePixel = 0
	button.ZIndex = 11
	Instance.new("UICorner", button).CornerRadius = UDim.new(0, 6)
	return button
end

-- 1 seul bouton
local btnESP = createButton("ESP : OFF", 55)
local buttons = {btnESP}

-- Liste scrollable sous le bouton
local listFrame = Instance.new("ScrollingFrame", frame)
listFrame.Position = UDim2.new(0.05, 0, 0, 95)
listFrame.Size = UDim2.new(0.9, 0, 0, 310)
listFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
listFrame.BorderSizePixel = 0
listFrame.ScrollBarThickness = 6
listFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
listFrame.ZIndex = 11
Instance.new("UICorner", listFrame).CornerRadius = UDim.new(0, 6)

local layout = Instance.new("UIListLayout", listFrame)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Padding = UDim.new(0, 4)

local padding = Instance.new("UIPadding", listFrame)
padding.PaddingTop = UDim.new(0, 6)
padding.PaddingBottom = UDim.new(0, 6)
padding.PaddingLeft = UDim.new(0, 6)
padding.PaddingRight = UDim.new(0, 6)

-- Sélection (même si 1 bouton)
local selectedIndex = 1
local function updateSelection()
	for i, btn in ipairs(buttons) do
		btn.BackgroundColor3 = (i == selectedIndex)
			and Color3.fromRGB(60, 60, 60)
			or Color3.fromRGB(40, 40, 40)
	end
end
updateSelection()

-- Insert: show/hide
local visible = true
UIS.InputBegan:Connect(function(input, gp)
	if gp then return end
	if input.KeyCode == Enum.KeyCode.Insert then
		visible = not visible
		frame.Visible = visible
	end
end)

-- ================== HELPERS ==================
local function isBlacklisted(name)
	local n = string.lower(name)
	for _, w in ipairs(blacklistWords) do
		if string.find(n, w) then
			return true
		end
	end
	return false
end

local function hasKeyword(name)
	for _, k in ipairs(keywords) do
		if string.find(name, k) then
			return true
		end
	end
	return false
end

local function getItemTypeFromName(name)
	local n = string.lower(name)
	if string.find(n, "flare") then return "Flare" end
	if string.find(n, "airdrop") then return "Airdrop" end
	if string.find(n, "key") or string.find(n, "cle") then return "Key" end
	if string.find(n, "safe") or string.find(n, "coffre") then return "Safe" end
	if string.find(n, "parts") then return "PARTS" end
	if string.find(n, "cache") then return "Cache" end
	return nil
end

local function isMine(obj)
	return (obj.Parent and obj.Parent.Name == "Mines") or (obj:FindFirstAncestor("Mines") ~= nil)
end

local function isTeleportable(o)
	if o:IsA("BasePart") then return true end
	if o:IsA("Model") then
		return o.PrimaryPart ~= nil or o:FindFirstChildWhichIsA("BasePart", true) ~= nil
	end
	return false
end

-- ✅ TP FIX (Model sans PrimaryPart)
local function getTeleportPart(obj)
	if obj:IsA("BasePart") then
		return obj
	end
	if obj:IsA("Model") then
		if obj.PrimaryPart then
			return obj.PrimaryPart
		end
		return obj:FindFirstChildWhichIsA("BasePart", true)
	end
	return nil
end

-- ================== ESP / LIST / TP ==================
local espEnabled = false
local espAdded = {}    -- [instance] = {highlight, billboard}
local espObjects = {}  -- TP list (sans mines)
local espIndex = 1

local listRows = {} -- pour auto-scroll

local function clearListUI()
	listRows = {}
	for _, c in ipairs(listFrame:GetChildren()) do
		if c:IsA("TextLabel") then
			c:Destroy()
		end
	end
end

local function scrollToSelected()
	local row = listRows[espIndex]
	if not row then return end

	-- Y de la row dans le canvas
	local y = row.AbsolutePosition.Y - listFrame.AbsolutePosition.Y + listFrame.CanvasPosition.Y
	local targetY = math.max(0, y - 50)

	listFrame.CanvasPosition = Vector2.new(0, targetY)
end

local function rebuildListUI()
	clearListUI()

	if not espEnabled then
		local row = Instance.new("TextLabel")
		row.BackgroundTransparency = 1
		row.Size = UDim2.new(1, -8, 0, 18)
		row.Font = Enum.Font.Gotham
		row.TextSize = 12
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.TextColor3 = Color3.fromRGB(220, 220, 220)
		row.ZIndex = 12
		row.Text = "ESP OFF"
		row.Parent = listFrame
		table.insert(listRows, row)

		listFrame.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 12)
		return
	end

	if #espObjects == 0 then
		local row = Instance.new("TextLabel")
		row.BackgroundTransparency = 1
		row.Size = UDim2.new(1, -8, 0, 18)
		row.Font = Enum.Font.Gotham
		row.TextSize = 12
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.TextColor3 = Color3.fromRGB(220, 220, 220)
		row.ZIndex = 12
		row.Text = "ESP ON — (Aucun item TP)"
		row.Parent = listFrame
		table.insert(listRows, row)

		listFrame.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 12)
		return
	end

	for i, o in ipairs(espObjects) do
		local row = Instance.new("TextLabel")
		row.BackgroundTransparency = 1
		row.Size = UDim2.new(1, -8, 0, 18)
		row.Font = Enum.Font.Gotham
		row.TextSize = 12
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.ZIndex = 12

		local itemType = getItemTypeFromName(o.Name)
		local baseColor = (itemType and itemColors[itemType]) or Color3.fromRGB(220, 220, 220)

		if i == espIndex then
			row.TextColor3 = baseColor
			row.TextStrokeTransparency = 0.2
		else
			row.TextColor3 = baseColor:Lerp(Color3.new(1,1,1), 0.35)
			row.TextStrokeTransparency = 1
		end

		local prefix = (i == espIndex) and ">> " or "   "
		row.Text = prefix .. o.Name
		row.Parent = listFrame
		table.insert(listRows, row)
	end

	task.defer(function()
		listFrame.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 12)
		scrollToSelected()
	end)
end

local function addESPVisual(o)
	if espAdded[o] then return end

	local itemType = getItemTypeFromName(o.Name)
	local color = itemColors[itemType] or Color3.new(1,1,1)

	-- mines en rouge
	if isMine(o) then
		color = itemColors.Mines
	end

	local highlight = Instance.new("Highlight")
	highlight.FillTransparency = 0.8
	highlight.FillColor = color
	highlight.OutlineColor = color
	highlight.Parent = o

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "ESP_Billboard"
	billboard.ClipsDescendants = false
	billboard.LightInfluence = 0
	billboard.Active = true
	billboard.AlwaysOnTop = true
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 1.6, 0)
	billboard.Size = UDim2.new(0, 220, 0, 40)
	billboard.Parent = o

	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.new(1, 0, 1, 0)
	holder.Parent = billboard

	local dot = Instance.new("Frame")
	dot.Size = UDim2.new(0, 10, 0, 10)
	dot.Position = UDim2.new(0.5, -5, 1, -10)
	dot.BorderSizePixel = 0
	dot.BackgroundColor3 = color
	dot.Parent = holder
	Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, 0, 1, -10)
	label.Font = Enum.Font.GothamBold
	label.TextSize = 14
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.2
	label.TextWrapped = true
	label.Text = o.Name
	label.Parent = holder

	espAdded[o] = {highlight, billboard}
end

local function sortEspObjects()
	table.sort(espObjects, function(a, b)
		local ta = getItemTypeFromName(a.Name) or "ZZZ"
		local tb = getItemTypeFromName(b.Name) or "ZZZ"
		if ta ~= tb then
			return ta < tb
		end
		return string.lower(a.Name) < string.lower(b.Name)
	end)
end

local function enableESP()
	espObjects = {}
	espIndex = 1

	for _, o in ipairs(workspace:GetDescendants()) do
		-- détecteur original + filtre parasites
		if hasKeyword(o.Name) and not isBlacklisted(o.Name) then
			if o:IsA("BasePart") or o:IsA("Model") then
				addESPVisual(o)

				-- TP list : pas de mines + TP-able
				if (not isMine(o)) and isTeleportable(o) then
					table.insert(espObjects, o)
				end
			end
		end
	end

	sortEspObjects()
	rebuildListUI()
end

local function disableESP()
	for _, items in pairs(espAdded) do
		for _, obj in ipairs(items) do
			if obj and obj.Parent then obj:Destroy() end
		end
	end
	espAdded = {}
	espObjects = {}
	espIndex = 1
	rebuildListUI()
end

local function teleportToSelected()
	if not espEnabled then return end
	if #espObjects == 0 then return end

	local o = espObjects[espIndex]
	if not o or not o.Parent or not o:IsDescendantOf(workspace) then return end

	local char = player.Character
	if not char then return end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	local p = getTeleportPart(o)
	if not p then return end

	hrp.CFrame = p.CFrame + TP_OFFSET
end

-- Nettoyage auto quand item ramassé/supprimé
local function cleanupMissing()
	if not espEnabled then return end

	local changed = false

	for i = #espObjects, 1, -1 do
		local o = espObjects[i]
		if (not o) or (not o.Parent) or (not o:IsDescendantOf(workspace)) then
			table.remove(espObjects, i)
			changed = true
		end
	end

	for o, items in pairs(espAdded) do
		if (not o) or (not o.Parent) or (not o:IsDescendantOf(workspace)) then
			for _, obj in ipairs(items) do
				if obj and obj.Parent then obj:Destroy() end
			end
			espAdded[o] = nil
			changed = true
		end
	end

	if #espObjects == 0 then
		espIndex = 1
	else
		if espIndex > #espObjects then espIndex = #espObjects end
		if espIndex < 1 then espIndex = 1 end
	end

	if changed then
		sortEspObjects()
		rebuildListUI()
	end
end

-- ================== MENU ACTION ==================
local function activateButton(index)
	if index == 1 then
		espEnabled = not espEnabled
		if espEnabled then
			btnESP.Text = "ESP : ON"
			enableESP()
		else
			btnESP.Text = "ESP : OFF"
			disableESP()
		end
	end
end

-- ================== INPUT ==================
UIS.InputBegan:Connect(function(input, gp)
	if gp then return end
	if input.UserInputType ~= Enum.UserInputType.Keyboard then return end

	-- Menu (H/G/Enter)
	if input.KeyCode == Enum.KeyCode.H then
		selectedIndex -= 1
		if selectedIndex < 1 then selectedIndex = #buttons end
		updateSelection()

	elseif input.KeyCode == Enum.KeyCode.G then
		selectedIndex += 1
		if selectedIndex > #buttons then selectedIndex = 1 end
		updateSelection()

	elseif input.KeyCode == Enum.KeyCode.Return then
		activateButton(selectedIndex)
	end

	-- Liste + TP (J/K/P)
	if espEnabled and #espObjects > 0 then
		if input.KeyCode == Enum.KeyCode.J then
			espIndex -= 1
			if espIndex < 1 then espIndex = #espObjects end
			rebuildListUI()
			scrollToSelected()

		elseif input.KeyCode == Enum.KeyCode.K then
			espIndex += 1
			if espIndex > #espObjects then espIndex = 1 end
			rebuildListUI()
			scrollToSelected()

		elseif input.KeyCode == Enum.KeyCode.P then
			teleportToSelected()
		end
	end
end)

-- Boucle nettoyage
task.spawn(function()
	while true do
		task.wait(0.25)
		cleanupMissing()
	end
end)

-- Init
rebuildListUI()


--BY Nyssir4
