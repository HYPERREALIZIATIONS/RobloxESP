--[[
	Universal Roblox ESP — Executor Lua (Synapse/Krnl-style Drawing API)
	Self-contained. No remote loading / no auto-update.
	Intended for YOUR OWN or explicitly PERMITTED games only.

	Features: Box (corner/full/3D), Skeleton, Chams, Health bars, Tracers,
	Names, Team check, Rainbow, R6/R15 support, performance mode,
	in-game UI, config save/load, Ctrl minimize, clean Unload.
]]

-- ====================== Services / Globals ======================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- Drawing library (provided by executor). Fall back gracefully if missing.
local Drawing = Drawing or (typeof(syn) == "table" and syn and syn.draw) or nil
local hasDrawing = Drawing ~= nil and pcall(function() return Drawing.new("Square") end)

-- Config persistence helpers (executor-provided)
local function canFile()
	return (typeof(writefile) == "function") and (typeof(readfile) == "function")
end

-- ====================== Settings (tunable) ======================
local ESP = {
	Running = false,
	Settings = {
		Enabled = true,
		TeamCheck = true,
		DistanceLimit = 0,            -- 0 = off
		BoxMode = "corner",           -- corner | full | threed
		BoxColor = Color3.fromRGB(0, 255, 0),
		BoxThickness = 1,
		BoxTransparency = 1,
		Skeleton = true,
		SkeletonColor = Color3.fromRGB(255, 255, 255),
		SkeletonThickness = 1,
		Chams = false,
		ChamsColor = Color3.fromRGB(255, 0, 0),
		ChamsTransparency = 0.5,
		HealthBar = true,
		HealthColor = Color3.fromRGB(0, 255, 0),
		HealthColorBad = Color3.fromRGB(255, 0, 0),
		Tracer = true,
		TracerOrigin = "bottom",      -- bottom | center | mouse
		TracerColor = Color3.fromRGB(255, 255, 0),
		TracerThickness = 1,
		Names = true,
		NameColor = Color3.fromRGB(255, 255, 255),
		NameSize = 13,
		Rainbow = false,
		RainbowSpeed = 1,
		PerformanceMode = false,
		Minimized = false,
	},
	Players = {},          -- [Player] = record
	Connections = {},
	RainbowHue = 0,
}

-- ====================== Helpers ======================
local function SafeColor(c)
	if typeof(c) == "Color3" then return c end
	return Color3.fromRGB(255, 255, 255)
end

local function IsTeammate(plr)
	if not ESP.Settings.TeamCheck then return false end
	local myTeam = LocalPlayer.Team
	if myTeam == nil then return false end
	return plr.Team == myTeam
end

local function WorldToScreen(pos)
	local v, onScreen = Camera:WorldToViewportPoint(pos)
	return Vector2.new(v.X, v.Y), onScreen, v.Z
end

local function GetRoot(char)
	return char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso")
end

local function GetHumanoid(char)
	return char:FindFirstChildWhichIsA("Humanoid")
end

-- R6 / R15 bone pairs for skeleton
local R15_BONES = {
	{"Head", "UpperTorso"},
	{"UpperTorso", "LowerTorso"},
	{"UpperTorso", "LeftUpperArm"}, {"LeftUpperArm", "LeftLowerArm"}, {"LeftLowerArm", "LeftHand"},
	{"UpperTorso", "RightUpperArm"}, {"RightUpperArm", "RightLowerArm"}, {"RightLowerArm", "RightHand"},
	{"LowerTorso", "LeftUpperLeg"}, {"LeftUpperLeg", "LeftLowerLeg"}, {"LeftLowerLeg", "LeftFoot"},
	{"LowerTorso", "RightUpperLeg"}, {"RightUpperLeg", "RightLowerLeg"}, {"RightLowerLeg", "RightFoot"},
}
local R6_BONES = {
	{"Head", "Torso"},
	{"Torso", "Left Arm"}, {"Left Arm", "Left Leg"},
	{"Torso", "Right Arm"}, {"Right Arm", "Right Leg"},
}

local function GetBones(char, isR15)
	local list = isR15 and R15_BONES or R6_BONES
	local out = {}
	for _, pair in ipairs(list) do
		local a = char:FindFirstChild(pair[1])
		local b = char:FindFirstChild(pair[2])
		if a and b and a:IsA("BasePart") and b:IsA("BasePart") then
			table.insert(out, {a, b})
		end
	end
	return out
end

-- Build a small 3D box (8 corners) around a part
local function GetBoxCorners(part, expand)
	local cf = part.CFrame
	local size = part.Size * (expand or 1)
	local sx, sy, sz = size.X/2, size.Y/2, size.Z/2
	local corners = {
		cf * Vector3.new(-sx, sy, -sz),  cf * Vector3.new(sx, sy, -sz),
		cf * Vector3.new(sx, sy, sz),    cf * Vector3.new(-sx, sy, sz),
		cf * Vector3.new(-sx, -sy, -sz), cf * Vector3.new(sx, -sy, -sz),
		cf * Vector3.new(sx, -sy, sz),   cf * Vector3.new(-sx, -sy, sz),
	}
	return corners
end

local function newDraw(type, props)
	if not hasDrawing then return nil end
	local d = Drawing.new(type)
	if props then
		for k, v in pairs(props) do d[k] = v end
	end
	return d
end

-- ====================== Player record ======================
local function MakeRecord(plr)
	local rec = {
		Player = plr,
		Drawings = {},
		ChamsOriginal = {},
		Bones = {},
	}

	if hasDrawing then
		-- Box (full)
		rec.Drawings.Box = newDraw("Square", {Visible = false, Filled = false, Thickness = ESP.Settings.BoxThickness})
		-- 4 corner brackets
		rec.Drawings.CornerTL = newDraw("Line", {Visible = false, Thickness = ESP.Settings.BoxThickness})
		rec.Drawings.CornerTR = newDraw("Line", {Visible = false, Thickness = ESP.Settings.BoxThickness})
		rec.Drawings.CornerBL = newDraw("Line", {Visible = false, Thickness = ESP.Settings.BoxThickness})
		rec.Drawings.CornerBR = newDraw("Line", {Visible = false, Thickness = ESP.Settings.BoxThickness})
		-- 3D edges (12 lines)
		rec.Drawings.Box3D = {}
		for i = 1, 12 do
			rec.Drawings.Box3D[i] = newDraw("Line", {Visible = false, Thickness = ESP.Settings.BoxThickness})
		end
		-- Skeleton
		rec.Drawings.Skeleton = {}
		-- Health bar
		rec.Drawings.HealthBg = newDraw("Square", {Visible = false, Filled = true, Color = Color3.fromRGB(0,0,0), Thickness = 0})
		rec.Drawings.HealthFg = newDraw("Square", {Visible = false, Filled = true, Thickness = 0})
		-- Tracer
		rec.Drawings.Tracer = newDraw("Line", {Visible = false, Thickness = ESP.Settings.TracerThickness})
		-- Name
		rec.Drawings.Name = newDraw("Text", {Visible = false, Size = ESP.Settings.NameSize, Center = true, Outline = true})
	else
		warn("ESP: Drawing library unavailable; visuals disabled.")
	end

	return rec
end

local function ClearRecordDrawings(rec)
	if not rec or not rec.Drawings then return end
	for _, d in pairs(rec.Drawings) do
		if type(d) == "table" then
			for _, dd in pairs(d) do pcall(function() dd:Remove() end) end
		else
			pcall(function() d:Remove() end)
		end
	end
	rec.Drawings = {}
end

local function RestoreChams(rec)
	if not rec or not rec.ChamsOriginal then return end
	for part, orig in pairs(rec.ChamsOriginal) do
		pcall(function()
			part.Color = orig.Color
			part.Transparency = orig.Transparency
			if part:FindFirstChildOfClass("SurfaceAppearance") then
				part:FindFirstChildOfClass("SurfaceAppearance").Transparency = orig.SurfaceTransparency or 0
			end
		end)
	end
	rec.ChamsOriginal = {}
end

-- ====================== Chams ======================
local function ApplyChams(rec, char)
	if not ESP.Settings.Chams then return end
	rec.ChamsOriginal = rec.ChamsOriginal or {}
	for _, part in ipairs(char:GetDescendants()) do
		if part:IsA("BasePart") then
			if not rec.ChamsOriginal[part] then
				rec.ChamsOriginal[part] = {
					Color = part.Color,
					Transparency = part.Transparency,
				}
			end
			pcall(function()
				part.Color = SafeColor(ESP.Settings.ChamsColor)
				part.Transparency = ESP.Settings.ChamsTransparency
			end)
		end
	end
end

-- ====================== Rainbow ======================
local function UpdateRainbow(dt)
	if not ESP.Settings.Rainbow then return end
	ESP.RainbowHue = (ESP.RainbowHue + dt * ESP.Settings.RainbowSpeed) % 1
end

local function RainbowColor()
	-- simple HSV->RGB
	local h = ESP.RainbowHue
	local i = math.floor(h * 6)
	local f = h * 6 - i
	local q = 1 - f
	local function conv(n)
		local t = (n + i) % 6
		if t < 1 then return 1
		elseif t < 2 then return q
		elseif t < 4 then return 0
		elseif t < 5 then return f
		else return 1 end
	end
	local r, g, b = conv(5), conv(3), conv(1)
	return Color3.new(r, g, b)
end

-- ====================== Render ======================
function ESP:RenderPlayer(rec)
	local plr = rec.Player
	local char = plr.Character
	local hum = char and GetHumanoid(char)
	local root = char and GetRoot(char)
	if not (char and hum and root) then
		self:HideRecord(rec)
		return
	end

	if IsTeammate(plr) then
		self:HideRecord(rec)
		return
	end

	if ESP.Settings.DistanceLimit > 0 then
		local dist = (root.Position - Camera.CFrame.Position).Magnitude
		if dist > ESP.Settings.DistanceLimit then
			self:HideRecord(rec)
			return
		end
	end

	local rainbow = ESP.Settings.Rainbow and RainbowColor() or nil
	local boxColor = rainbow or SafeColor(ESP.Settings.BoxColor)
	local skelColor = rainbow or SafeColor(ESP.Settings.SkeletonColor)
	local tracerColor = rainbow or SafeColor(ESP.Settings.TracerColor)
	local nameColor = SafeColor(ESP.Settings.NameColor)
	local hbColor = SafeColor(ESP.Settings.HealthColor)

	-- Compute screen positions of key points
	local head = char:FindFirstChild("Head")
	local headPos = head and head.Position or (root.Position + Vector3.new(0, 2, 0))
	local headScreen, headOn = WorldToScreen(headPos)
	local rootScreen, rootOn = WorldToScreen(root.Position)
	if not (headOn or rootOn) then
		self:HideRecord(rec)
		return
	end

	local isR15 = hum.RigType == Enum.HumanoidRigType.R15
	local scale = (Camera:WorldToViewportPoint(root.Position + Vector3.new(0, 3, 0))).Y
		- (Camera:WorldToViewportPoint(root.Position)).Y
	scale = math.abs(scale)
	local boxH = math.max(scale, 20)
	local boxW = boxH * 0.55

	-- Center of box between head and feet
	local topY = headScreen.Y - boxH * 0.15
	local botY = topY + boxH
	local cx = rootScreen.X
	local left = cx - boxW / 2
	local right = cx + boxW / 2

	local D = rec.Drawings

	-- ---- Box modes ----
	local showBox = ESP.Settings.Enabled and not ESP.Settings.Minimized
	if showBox then
		if ESP.Settings.BoxMode == "full" then
			local b = D.Box
			if b then
				b.Visible = true
				b.Size = Vector2.new(boxW, boxH)
				b.Position = Vector2.new(left, topY)
				b.Color = boxColor
				b.Thickness = ESP.Settings.BoxThickness
				b.Transparency = ESP.Settings.BoxTransparency
			end
			self:HideCorners(rec); self:Hide3D(rec)
		elseif ESP.Settings.BoxMode == "corner" then
			self:ShowCorners(rec, left, right, topY, botY, boxColor)
			if D.Box then D.Box.Visible = false end
			self:Hide3D(rec)
		elseif ESP.Settings.BoxMode == "threed" then
			self:Show3D(rec, root, boxColor, boxW, boxH)
			if D.Box then D.Box.Visible = false end
			self:HideCorners(rec)
		end
	else
		if D.Box then D.Box.Visible = false end
		self:HideCorners(rec); self:Hide3D(rec)
	end

	-- ---- Skeleton ----
	if ESP.Settings.Skeleton and not ESP.Settings.PerformanceMode and not ESP.Settings.Minimized then
		local bones = rec.Bones
		if #bones == 0 then
			bones = GetBones(char, isR15)
			rec.Bones = bones
		end
		local need = #bones
		-- grow skeleton lines
		while #D.Skeleton < need do
			D.Skeleton[#D.Skeleton + 1] = newDraw("Line", {Visible = false, Thickness = ESP.Settings.SkeletonThickness})
		end
		for i = 1, #D.Skeleton do
			local ln = D.Skeleton[i]
			if i <= need then
				local a, b = bones[i][1], bones[i][2]
				local pa, onA = WorldToScreen(a.Position)
				local pb, onB = WorldToScreen(b.Position)
				if onA and onB then
					ln.Visible = true
					ln.From = pa; ln.To = pb
					ln.Color = skelColor
					ln.Thickness = ESP.Settings.SkeletonThickness
				else
					ln.Visible = false
				end
			else
				ln.Visible = false
			end
		end
	else
		for _, ln in ipairs(D.Skeleton) do ln.Visible = false end
	end

	-- ---- Chams ----
	if ESP.Settings.Chams and not ESP.Settings.Minimized then
		ApplyChams(rec, char)
	else
		RestoreChams(rec)
	end

	-- ---- Health bar ----
	if ESP.Settings.HealthBar and not ESP.Settings.Minimized and hum then
		local hp = hum.Health
		local maxhp = hum.MaxHealth > 0 and hum.MaxHealth or 1
		local ratio = math.clamp(hp / maxhp, 0, 1)
		local bw = 3
		local bx = left - 6
		local bg = D.HealthBg
		local fg = D.HealthFg
		bg.Visible = true; fg.Visible = true
		bg.Size = Vector2.new(bw, boxH); bg.Position = Vector2.new(bx, topY)
		fg.Size = Vector2.new(bw, boxH * ratio)
		fg.Position = Vector2.new(bx, botY - boxH * ratio)
		fg.Color = (ratio > 0.5) and hbColor or SafeColor(ESP.Settings.HealthColorBad)
	else
		if D.HealthBg then D.HealthBg.Visible = false end
		if D.HealthFg then D.HealthFg.Visible = false end
	end

	-- ---- Tracer ----
	if ESP.Settings.Tracer and not ESP.Settings.Minimized then
		local tr = D.Tracer
		local origin
		if ESP.Settings.TracerOrigin == "bottom" then
			origin = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
		elseif ESP.Settings.TracerOrigin == "center" then
			origin = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
		else
			local ms = LocalPlayer:GetMouse()
			origin = Vector2.new(ms.X, ms.Y)
		end
		tr.Visible = true
		tr.From = origin
		tr.To = Vector2.new(cx, botY)
		tr.Color = tracerColor
		tr.Thickness = ESP.Settings.TracerThickness
	else
		if D.Tracer then D.Tracer.Visible = false end
	end

	-- ---- Name ----
	if ESP.Settings.Names and not ESP.Settings.Minimized then
		local nm = D.Name
		nm.Visible = true
		nm.Position = Vector2.new(cx, topY - 16)
		local dist = math.floor((root.Position - Camera.CFrame.Position).Magnitude)
		nm.Text = ("%s [%dm]"):format(plr.Name, dist)
		nm.Color = nameColor
		nm.Size = ESP.Settings.NameSize
	else
		if D.Name then D.Name.Visible = false end
	end
end

function ESP:HideCorners(rec)
	local D = rec.Drawings
	for _, k in ipairs({"CornerTL", "CornerTR", "CornerBL", "CornerBR"}) do
		if D[k] then D[k].Visible = false end
	end
end

function ESP:Hide3D(rec)
	for _, ln in ipairs(rec.Drawings.Box3D or {}) do ln.Visible = false end
end

function ESP:ShowCorners(rec, left, right, topY, botY, color)
	local D = rec.Drawings
	local len = 8
	local t = ESP.Settings.BoxThickness
	local mk = function(line, x1, y1, x2, y2)
		line.Visible = true
		line.From = Vector2.new(x1, y1)
		line.To = Vector2.new(x2, y2)
		line.Color = color
		line.Thickness = t
	end
	-- top-left
	mk(D.CornerTL, left, topY, left + len, topY)
	mk(D.CornerTL, left, topY, left, topY + len)
	-- top-right
	mk(D.CornerTR, right, topY, right - len, topY)
	mk(D.CornerTR, right, topY, right, topY + len)
	-- bottom-left
	mk(D.CornerBL, left, botY, left + len, botY)
	mk(D.CornerBL, left, botY, left, botY - len)
	-- bottom-right
	mk(D.CornerBR, right, botY, right - len, botY)
	mk(D.CornerBR, right, botY, right, botY - len)
end

function ESP:Show3D(rec, root, color, boxW, boxH)
	local corners = GetBoxCorners(root, 1.1)
	local pts = {}
	for i = 1, 8 do
		local p, on = WorldToScreen(corners[i])
		pts[i] = p
		if not on then self:Hide3D(rec); return end
	end
	-- edges by corner index pairs
	local edges = {
		{1,2},{2,3},{3,4},{4,1},
		{5,6},{6,7},{7,8},{8,5},
		{1,5},{2,6},{3,7},{4,8},
	}
	local D = rec.Drawings.Box3D
	for i = 1, 12 do
		local e = edges[i]
		local ln = D[i]
		ln.Visible = true
		ln.From = pts[e[1]]; ln.To = pts[e[2]]
		ln.Color = color
		ln.Thickness = ESP.Settings.BoxThickness
	end
end

function ESP:HideRecord(rec)
	local D = rec.Drawings
	if not D then return end
	if D.Box then D.Box.Visible = false end
	self:HideCorners(rec); self:Hide3D(rec)
	for _, ln in ipairs(D.Skeleton or {}) do ln.Visible = false end
	if D.HealthBg then D.HealthBg.Visible = false end
	if D.HealthFg then D.HealthFg.Visible = false end
	if D.Tracer then D.Tracer.Visible = false end
	if D.Name then D.Name.Visible = false end
end

-- ====================== Main loop ======================
function ESP:Start()
	if self.Running then return end
	self.Running = true

	-- Track players
	self.Connections.PlayerAdded = Players.PlayerAdded:Connect(function(p)
		if p ~= LocalPlayer then self:AddPlayer(p) end
	end)
	self.Connections.PlayerRemoving = Players.PlayerRemoving:Connect(function(p)
		self:RemovePlayer(p)
	end)
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= LocalPlayer then self:AddPlayer(p) end
	end

	self.Connections.Render = RunService.RenderStepped:Connect(function(dt)
		if not self.Running then return end
		UpdateRainbow(dt)
		for plr, rec in pairs(self.Players) do
			local ok, err = pcall(function() self:RenderPlayer(rec) end)
			if not ok then
				warn("ESP render error for " .. tostring(plr) .. ": " .. tostring(err))
				self:HideRecord(rec)
			end
		end
		if self.UI then self.UI:Update() end
	end)

	self:SetupInput()
	self:BuildUI()
end

function ESP:AddPlayer(plr)
	if self.Players[plr] then return end
	local rec = MakeRecord(plr)
	self.Players[plr] = rec
	-- re-cache bones when character spawns
	plr.CharacterAdded:Connect(function()
		rec.Bones = {}
		RestoreChams(rec)
	end)
end

function ESP:RemovePlayer(plr)
	local rec = self.Players[plr]
	if rec then
		RestoreChams(rec)
		ClearRecordDrawings(rec)
		self.Players[plr] = nil
	end
end

-- ====================== Input (Ctrl minimize) ======================
function ESP:SetupInput()
	local UIS = game:GetService("UserInputService")
	self.Connections.InputBegan = UIS.InputBegan:Connect(function(input, gp)
		if gp then return end
		if input.KeyCode == Enum.KeyCode.LeftControl or input.KeyCode == Enum.KeyCode.RightControl then
			ESP.Settings.Minimized = not ESP.Settings.Minimized
			if self.UI then self.UI:SetMinimized(ESP.Settings.Minimized) end
		end
	end)
end

-- ====================== UI (Drawing-based) ======================
function ESP:BuildUI()
	if not hasDrawing then return end
	local S = self.Settings
	local x, y = 20, 20
	local w, rowH = 240, 22
	local ui = {Items = {}, Lines = {}, Minimized = false}

	local bg = newDraw("Square", {
		Visible = true, Filled = true,
		Position = Vector2.new(x - 6, y - 6), Size = Vector2.new(w + 12, 0),
		Color = Color3.fromRGB(15, 15, 20), Transparency = 0.85, Thickness = 0,
	})
	local title = newDraw("Text", {
		Visible = true, Position = Vector2.new(x, y - 4),
		Text = "ESP Settings  (Ctrl to minimize)", Size = 14, Color = Color3.fromRGB(255,255,255), Outline = true,
	})
	ui.Bg = bg; ui.Title = title

	local yy = y + 22
	local function addToggle(label, get, set)
		local t = newDraw("Text", {Visible = true, Position = Vector2.new(x, yy), Text = label, Size = 13, Color = Color3.fromRGB(200,200,200), Outline = true})
		local v = newDraw("Text", {Visible = true, Position = Vector2.new(x + w - 60, yy), Text = get() and "[ON]" or "[OFF]", Size = 13, Color = get() and Color3.fromRGB(0,255,0) or Color3.fromRGB(255,80,80), Outline = true})
		table.insert(ui.Items, {t, v, get, set})
		yy = yy + rowH
	end
	local function addLabel(label)
		local t = newDraw("Text", {Visible = true, Position = Vector2.new(x, yy), Text = label, Size = 12, Color = Color3.fromRGB(150,150,150), Outline = true})
		table.insert(ui.Items, {t})
		yy = yy + rowH
	end

	addLabel("--- Features ---")
	addToggle("Enabled", function() return S.Enabled end, function() S.Enabled = not S.Enabled end)
	addToggle("Team Check", function() return S.TeamCheck end, function() S.TeamCheck = not S.TeamCheck end)
	addToggle("Skeleton", function() return S.Skeleton end, function() S.Skeleton = not S.Skeleton end)
	addToggle("Chams", function() return S.Chams end, function() S.Chams = not S.Chams end)
	addToggle("Health Bar", function() return S.HealthBar end, function() S.HealthBar = not S.HealthBar end)
	addToggle("Tracer", function() return S.Tracer end, function() S.Tracer = not S.Tracer end)
	addToggle("Names", function() return S.Names end, function() S.Names = not S.Names end)
	addToggle("Rainbow", function() return S.Rainbow end, function() S.Rainbow = not S.Rainbow end)
	addToggle("Performance", function() return S.PerformanceMode end, function() S.PerformanceMode = not S.PerformanceMode end)
	addLabel("--- Box Mode (corner/full/threed) ---")
	addToggle("Box: corner", function() return S.BoxMode == "corner" end, function() S.BoxMode = "corner" end)
	addToggle("Box: full", function() return S.BoxMode == "full" end, function() S.BoxMode = "full" end)
	addToggle("Box: 3D", function() return S.BoxMode == "threed" end, function() S.BoxMode = "threed" end)
	addLabel("--- Tracer Origin ---")
	addToggle("Tracer bottom", function() return S.TracerOrigin == "bottom" end, function() S.TracerOrigin = "bottom" end)
	addToggle("Tracer center", function() return S.TracerOrigin == "center" end, function() S.TracerOrigin = "center" end)
	addToggle("Tracer mouse", function() return S.TracerOrigin == "mouse" end, function() S.TracerOrigin = "mouse" end)
	addLabel("--- Config ---")
	-- Save/Load handled via keys below

	-- Config hint
	local hint = newDraw("Text", {Visible = true, Position = Vector2.new(x, yy), Text = "[F9] Save  [F10] Load", Size = 12, Color = Color3.fromRGB(120,200,255), Outline = true})
	table.insert(ui.Items, {hint})
	yy = yy + rowH

	bg.Size = Vector2.new(w + 12, yy - (y - 6) + 6)

	-- Click handling (MouseButton1)
	local UIS = game:GetService("UserInputService")
	ui.ClickConn = UIS.InputBegan:Connect(function(input, gp)
		if gp then return end
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
		if ESP.Settings.Minimized then return end
		local mx, my = input.Position.X, input.Position.Y
		for _, it in ipairs(ui.Items) do
			if it[4] and mx >= x and mx <= x + w and my >= it[1].Position.Y and my <= it[1].Position.Y + 16 then
				it[4]()
				break
			end
		end
	end)
	ui.KeyConn = UIS.InputBegan:Connect(function(input, gp)
		if gp then return end
		if input.KeyCode == Enum.KeyCode.F9 then self:SaveConfig() end
		if input.KeyCode == Enum.KeyCode.F10 then self:LoadConfig() end
	end)

	function ui:Update()
		for _, it in ipairs(ui.Items) do
			if it[3] then
				it[2].Text = it[3]() and "[ON]" or "[OFF]"
				it[2].Color = it[3]() and Color3.fromRGB(0,255,0) or Color3.fromRGB(255,80,80)
			end
		end
		-- hide all if minimized
		local vis = not ESP.Settings.Minimized
		ui.Bg.Visible = vis
		ui.Title.Visible = vis
		for _, it in ipairs(ui.Items) do
			if it[1] then it[1].Visible = vis end
			if it[2] then it[2].Visible = vis end
		end
	end

	function ui:SetMinimized(m) ESP.Settings.Minimized = m; self:Update() end
	function ui:Destroy()
		pcall(function() ui.Bg:Remove() end)
		pcall(function() ui.Title:Remove() end)
		pcall(function() ui.ClickConn:Disconnect() end)
		pcall(function() ui.KeyConn:Disconnect() end)
		for _, it in ipairs(ui.Items) do
			pcall(function() if it[1] then it[1]:Remove() end end)
			pcall(function() if it[2] then it[2]:Remove() end end)
		end
	end

	self.UI = ui
end

-- ====================== Config ======================
function ESP:SaveConfig(path)
	if not canFile() then warn("ESP: file IO unavailable"); return end
	path = path or "esp_config.json"
	local copy = {}
	for k, v in pairs(self.Settings) do
		if typeof(v) == "Color3" then
			copy[k] = {r = v.R, g = v.G, b = v.B, _c = true}
		else
			copy[k] = v
		end
	end
	local ok, data = pcall(function() return HttpService:JSONEncode(copy) end)
	if ok then
		writefile(path, data)
		print("ESP: config saved to " .. path)
	end
end

function ESP:LoadConfig(path)
	if not canFile() then warn("ESP: file IO unavailable"); return end
	path = path or "esp_config.json"
	if not pcall(function() return readfile(path) end) then warn("ESP: no config"); return end
	local ok, data = pcall(function() return HttpService:JSONDecode(readfile(path)) end)
	if not ok then warn("ESP: bad config"); return end
	for k, v in pairs(data) do
		if self.Settings[k] ~= nil then
			if type(v) == "table" and v._c then
				self.Settings[k] = Color3.new(v.r, v.g, v.b)
			else
				self.Settings[k] = v
			end
		end
	end
	print("ESP: config loaded from " .. path)
end

-- ====================== Unload ======================
function ESP:Unload()
	self.Running = false
	for _, c in pairs(self.Connections) do pcall(function() c:Disconnect() end) end
	self.Connections = {}
	for plr, rec in pairs(self.Players) do
		RestoreChams(rec)
		ClearRecordDrawings(rec)
	end
	self.Players = {}
	if self.UI then self.UI:Destroy(); self.UI = nil end
	print("ESP: unloaded cleanly.")
end

-- ====================== Boot ======================
ESP:Start()
print("ESP loaded. Ctrl = minimize UI. F9 = save config. F10 = load config. Call ESP:Unload() to remove.")

return ESP
