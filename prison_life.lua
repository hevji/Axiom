local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer or Players:GetPropertyChangedSignal("LocalPlayer"):Wait() and Players.LocalPlayer
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local CoreGui = game:GetService("CoreGui")
local Teams = game:GetService("Teams")
local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local StarterGui = game:GetService("StarterGui")
local TeleportService = game:GetService("TeleportService")

local executor = identifyexecutor and identifyexecutor() or "Unknown"

local repo = "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/"
local Library = loadstring(game:HttpGet(repo .. "Library.lua"))()
local SaveManager = loadstring(game:HttpGet(repo .. "addons/SaveManager.lua"))()
local ThemeManager = loadstring(game:HttpGet(repo .. "addons/ThemeManager.lua"))()
local Toggles = Library.Toggles
local Options = Library.Options

local loadingTimeout = 30
local loadComplete = false

local Loading = Library:CreateLoading({
	Title = "Meridian [BETA]",
	Icon = 100455085,
	TotalSteps = 6,
})

local loadFailed = false

task.delay(loadingTimeout, function()
	if not loadComplete then
		loadFailed = true
		Loading:SetCurrentStep(6)
		Loading:SetMessage("Failed to load")
		Loading:ShowErrorPage(true)
		Loading:SetErrorMessage("Timed out after " .. loadingTimeout .. "s.")
		Loading:SetErrorButtons({
			Retry = {
				Title = "Retry",
				Variant = "Primary",
				Callback = function()
					loadFailed = false
					loadComplete = false
					Loading:ShowErrorPage(false)
					Loading:SetCurrentStep(1)
					Loading:SetMessage("Reloading...")
					task.spawn(function()
						task.wait(1)
						Library:Unload()
						task.wait(0.5)
						loadstring(game:HttpGet("https://raw.githubusercontent.com/hevji/Meridian/main/prison_life.lua"))()
					end)
				end,
			},
			Quit = {
				Title = "Quit",
				Variant = "Destructive",
				Callback = function() Library:Unload() end,
			},
		})
	end
end)

Loading:SetMessage("Creating window...")
Loading:SetCurrentStep(1)
Loading:ShowSidebarPage(true)
Loading.Sidebar:AddLabel("User: " .. LocalPlayer.Name)
Loading.Sidebar:AddLabel("Executor: " .. executor)

local function UIStep(func)
	local ok, result = pcall(func)
	task.wait()
	if not ok then warn("[Meridian] UI Error:", result) end
	return result
end

local Window = Library:CreateWindow({
	Title = "Meridian [Prison Life]",
	Footer = "MeridianUI",
	NotifySide = "Right",
	ShowCustomCursor = true,
	Resizable = false,
})

local LoadStart = os.clock()
local Main = UIStep(function() return Window:AddTab("Main", "crosshair") end)
local Player = UIStep(function() return Window:AddTab("Player", "user") end)
local WorldT = UIStep(function() return Window:AddTab("World", "globe") end)
local Visual = UIStep(function() return Window:AddTab("Visual", "eye") end)
local Misc = UIStep(function() return Window:AddTab("Misc", "list") end)
local Settings = UIStep(function() return Window:AddTab("Settings", "settings") end)

-- dsc.gg/meridianui

--[[ HELPERS ]]
local function getCharacter(plr)
	return plr and plr.Character
end

local function getHRP(plr)
	local char = getCharacter(plr)
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hum then
			local torso = hum.Parent and hum.Parent:FindFirstChild("Torso")
			if torso then hrp = torso end
		end
	end
	return hrp
end

local function getHumanoid(plr)
	local char = getCharacter(plr)
	return char and char:FindFirstChildOfClass("Humanoid")
end

local function getTeamColor(plr)
	local team = plr.Team
	if team then
		if team == Teams.Guards then return BrickColor.new("Bright blue").Color
		elseif team == Teams.Inmates then return BrickColor.new("Bright orange").Color
		elseif team == Teams.Criminals then return BrickColor.new("Bright red").Color end
	end
	return Color3.new(1, 1, 1)
end

local function canDamage(plr)
	if plr.Team == LocalPlayer.Team then return false end
	local char = getCharacter(plr)
	if not char then return false end
	if LocalPlayer.Team == Teams.Guards and (plr.Team == Teams.Inmates and not char:GetAttribute("Hostile")) then return false end
	if char:FindFirstChildOfClass("ForceField") then return false end
	local hum = getHumanoid(plr)
	if hum and hum.Health > 0 then return true end
	return false
end

local function getBodyPos(plr)
	local hrp = getHRP(plr)
	if hrp then return hrp.Position end
	local char = getCharacter(plr)
	if char then
		local hum = char:FindFirstChildOfClass("Humanoid")
		if hum then
			local root = hum.RootPart
			if root then return root.Position end
		end
		local torso = char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso")
		if torso then return torso.Position end
		local head = char:FindFirstChild("Head")
		if head then return head.Position end
	end
	return nil
end

Loading:SetMessage("Loading Main tab...")
Loading:SetCurrentStep(2)

--[[ MAIN TAB ]]
UIStep(function()
	local g = Main:AddLeftGroupbox("Silent Aim", "crosshair")
	g:AddToggle("SilentAim", { Text = "Silent Aim", Default = false })
	g:AddSlider("SilentAimFOV", { Text = "FOV", Default = 100, Min = 10, Max = 500, Rounding = 0, Suffix = "px" })
	g:AddSlider("SilentAimHitchance", { Text = "Hitchance", Default = 100, Min = 0, Max = 100, Rounding = 0, Suffix = "%" })
	g:AddDropdown("SilentAimHitpart", { Text = "Hitpart", Values = { "Head", "HumanoidRootPart" }, Default = "Head" })
	g:AddToggle("SilentAimWallcheck", { Text = "Wallcheck", Default = false })
	g:AddToggle("SilentAimShowFOV", { Text = "Show FOV", Default = false })
	g:AddToggle("SilentAimFovOutline", { Text = "FOV Outline", Default = false })
	g:AddToggle("SilentAimFovFill", { Text = "FOV Fill", Default = false })
end)

UIStep(function()
	local g = Main:AddLeftGroupbox("Aimlock", "swords")
	g:AddToggle("Aimlock", { Text = "Aimlock", Default = false }):AddKeyPicker("AimlockKey", { Text = "Key", Mode = "Hold", Modes = { "Toggle", "Hold", "Always" } })
	g:AddSlider("AimlockSmoothness", { Text = "Smoothness", Default = 50, Min = 0, Max = 100, Rounding = 0 })
	g:AddSlider("AimlockFOV", { Text = "FOV", Default = 100, Min = 10, Max = 500, Rounding = 0, Suffix = "px" })
	g:AddSlider("AimlockDistance", { Text = "Distance", Default = 100000, Min = 1, Max = 100000, Rounding = 0 })
	g:AddDropdown("AimlockHitpart", { Text = "Hitpart", Values = { "Head", "HumanoidRootPart" }, Default = 2 })
	g:AddToggle("AimlockWallcheck", { Text = "Wallcheck", Default = false })
	g:AddToggle("AimlockShowFOV", { Text = "Show FOV", Default = false })
	g:AddToggle("AimlockFovOutline", { Text = "FOV Outline", Default = false })
	g:AddToggle("AimlockFovFill", { Text = "FOV Fill", Default = false })
end)

UIStep(function()
	local g = Main:AddRightGroupbox("Player Teleports", "users")
	g:AddDropdown("PlayerTP", { Text = "Player", Values = {}, Default = nil })
	local ptpTimer
	g:AddButton({ Text = "Refresh", Callback = function()
		local names = {}
		for _, p in ipairs(Players:GetPlayers()) do if p ~= LocalPlayer then names[#names + 1] = p.Name end end
		if Options.PlayerTP then Options.PlayerTP:SetValues(names) end
	end })
	g:AddButton({ Text = "Teleport", Callback = function()
		local name = Options.PlayerTP and Options.PlayerTP.Value
		if not name then Library:Notify({ Title = "Meridian", Description = "Select a player", Time = 3 }) return end
		local target = Players:FindFirstChild(name)
		if not target then Library:Notify({ Title = "Meridian", Description = "Player not found", Time = 3 }) return end
		local pos = getBodyPos(target)
		local hrp = getHRP(LocalPlayer)
		if hrp and pos then hrp.CFrame = CFrame.new(pos) end
	coroutine.wrap(function()
		task.wait(2)
		local names = {}
		for _, p in ipairs(Players:GetPlayers()) do if p ~= LocalPlayer then names[#names + 1] = p.Name end end
		if Options.PlayerTP then Options.PlayerTP:SetValues(names) end
		while task.wait(10) do
			local names = {}
			for _, p in ipairs(Players:GetPlayers()) do if p ~= LocalPlayer then names[#names + 1] = p.Name end end
			if Options.PlayerTP then Options.PlayerTP:SetValues(names) end
		end
	end)()
end})
end)

UIStep(function()
	local g = Main:AddRightGroupbox("Area Teleports", "zap")
	g:AddButton({ Text = "Prison Outer Wall", Callback = function()
		local hrp = getHRP(LocalPlayer)
		local wall = Workspace:FindFirstChild("Prison_OuterWall") and Workspace.Prison_OuterWall:FindFirstChild("prison_wall")
		if hrp and wall then hrp.CFrame = CFrame.new(wall:GetPivot().Position) end
	end })
	g:AddButton({ Text = "Criminal Spawn", Callback = function()
		local hrp = getHRP(LocalPlayer)
		local spawn = Workspace:FindFirstChild("Criminals Spawn")
		if hrp and spawn then hrp.CFrame = CFrame.new(spawn:GetPivot().Position) end
	end })
	g:AddButton({ Text = "Shipping Containers", Callback = function()
		local hrp = getHRP(LocalPlayer)
		local sc = Workspace:FindFirstChild("Shippingcontainers")
		if hrp and sc then hrp.CFrame = CFrame.new(sc:GetPivot().Position) end
	end })
end)

UIStep(function()
	local g = Main:AddRightGroupbox("Gun Teleports", "gun")
	local function findGun(namePattern)
		local pat = namePattern:lower()
		for _, obj in ipairs(Workspace:GetChildren()) do
			if obj.Name:lower():find(pat, 1, true) then
				local tg = obj:FindFirstChild("TouchGiver", true)
				if tg then return tg, obj.Name end
			end
		end
		for _, obj in ipairs(Workspace:GetChildren()) do
			if obj.Name:lower():find("criminal", 1, true) or obj.Name:lower():find("spawn", 1, true) then
				local tg = obj:FindFirstChild("TouchGiver", true)
				if tg then return tg, obj.Name end
			end
		end
		return nil, nil
	end
	local function tpToGun(namePattern)
		local hrp = getHRP(LocalPlayer)
		if not hrp then return end
		local part, gunName = findGun(namePattern)
		if not part then
			Library:Notify({ Title = "Meridian", Description = string.format("Could not find %s gun", namePattern), Time = 3 })
			return
		end
		local origPos = hrp.CFrame
		hrp.CFrame = CFrame.new(part:GetPivot().Position)
		task.wait(0.3)
		hrp.CFrame = origPos
	end
	g:AddButton({ Text = "Shotgun", Callback = function() tpToGun("Shotgun") end })
	g:AddButton({ Text = "MP5", Callback = function() tpToGun("MP5") end })
	g:AddButton({ Text = "AK-47", Callback = function() tpToGun("AK") end })
	g:AddButton({ Text = "Shotgun (Criminal)", Callback = function() tpToGun("Criminal") end })
	g:AddButton({ Text = "M9", Callback = function() tpToGun("M9") end })
	g:AddDivider()
	g:AddButton({ Text = "List Guns", Callback = function()
		local list = {}
		for idx, obj in ipairs(Workspace:GetChildren()) do
			local tg = obj:FindFirstChild("TouchGiver")
			if tg then
				list[#list + 1] = string.format("[%d] %s", idx, obj.Name)
			end
			local nested = tg and tg:FindFirstChild("TouchGiver")
			if nested then
				list[#list + 1] = string.format("[%d] %s (nested)", idx, obj.Name)
			end
		end
		Library:Notify({ Title = "Meridian", Description = "Guns counted. Check F9 for list.", Time = 3 })
		for _, line in ipairs(list) do print("[GunTP]", line) end
	end })
end)

Loading:SetMessage("Loading Player tab...")
Loading:SetCurrentStep(3)

--[[ PLAYER TAB ]]
local flyConn = nil
local noclipConn = nil
local walkspeedConn = nil

UIStep(function()
	local g = Player:AddLeftGroupbox("Movement", "activity")
	g:AddToggle("Walkspeed", { Text = "Walkspeed", Default = false, Callback = function(v)
		if walkspeedConn then walkspeedConn:Disconnect(); walkspeedConn = nil end
		if v then
			walkspeedConn = RunService.Heartbeat:Connect(function()
				if not Toggles.Walkspeed or not Toggles.Walkspeed.Value then return end
				local hum = getHumanoid(LocalPlayer)
				if hum then hum.WalkSpeed = Options.WalkspeedAmount and Options.WalkspeedAmount.Value or 22 end
			end)
		else
			local hum = getHumanoid(LocalPlayer)
			if hum then hum.WalkSpeed = 16 end
		end
	end })
	g:AddSlider("WalkspeedAmount", { Text = "Walkspeed Amount", Default = 22, Min = 16, Max = 200, Rounding = 1 })
	g:AddToggle("Jumpspeed", { Text = "Jumpspeed", Default = false, Callback = function(v)
		local hum = getHumanoid(LocalPlayer)
		if hum then hum.JumpPower = v and (Options.JumpspeedAmount and Options.JumpspeedAmount.Value or 50) or 50 end
	end })
	g:AddSlider("JumpspeedAmount", { Text = "Jumpspeed Amount", Default = 50, Min = 50, Max = 300, Rounding = 1 })
	g:AddDivider()
	g:AddToggle("Fly", { Text = "Fly", Default = false, Callback = function(v)
		if flyConn then flyConn:Disconnect(); flyConn = nil end
		if v then
			local char = getCharacter(LocalPlayer)
			if char then
				local hum = char:FindFirstChildOfClass("Humanoid")
				if hum then hum.PlatformStand = true end
			end
			flyConn = RunService.Heartbeat:Connect(function()
				local char = getCharacter(LocalPlayer)
				if not char then return end
				local hrp = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso") or (char:FindFirstChildOfClass("Humanoid") and char:FindFirstChildOfClass("Humanoid").RootPart)
				local hum = char:FindFirstChildOfClass("Humanoid")
				if not hrp or not hum then return end
				local speed = Options.FlySpeed and Options.FlySpeed.Value or 50
				local dir = Vector3.new()
				if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir = dir + workspace.CurrentCamera.CFrame.LookVector end
				if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir = dir - workspace.CurrentCamera.CFrame.LookVector end
				if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir = dir - workspace.CurrentCamera.CFrame.RightVector end
				if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir = dir + workspace.CurrentCamera.CFrame.RightVector end
				if UserInputService:IsKeyDown(Enum.KeyCode.Space) then dir = dir + Vector3.new(0, 1, 0) end
				if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then dir = dir + Vector3.new(0, -1, 0) end
				hrp.AssemblyLinearVelocity = dir.Magnitude > 0 and dir.Unit * speed or Vector3.new()
				hum.PlatformStand = true
			end)
		else
			local char = getCharacter(LocalPlayer)
			if char then
				local hum = char:FindFirstChildOfClass("Humanoid")
				if hum then hum.PlatformStand = false end
				local hrp = getHRP(LocalPlayer)
				if hrp then hrp.AssemblyLinearVelocity = Vector3.new() end
			end
		end
	end }):AddKeyPicker("FlyKey", { Text = "Key", Mode = "Toggle", Modes = { "Toggle", "Hold", "Always" } })
	g:AddSlider("FlySpeed", { Text = "Fly Speed", Default = 50, Min = 1, Max = 200, Rounding = 1 })
	g:AddToggle("Noclip", { Text = "Noclip", Default = false, Callback = function(v)
		if noclipConn then noclipConn:Disconnect(); noclipConn = nil end
		if v then
			local function killAntiNoclip(char)
				if not char then return end
				for _, part in ipairs(char:GetDescendants()) do
					if part:IsA("BasePart") then
						part.CanCollide = false
						local sig = pcall(getconnections, part:GetPropertyChangedSignal("CanCollide"))
						if sig and type(sig) == "table" then
							for _, conn in ipairs(sig) do pcall(conn.Disable, conn) end
						end
					end
				end
			end
			local char = getCharacter(LocalPlayer)
			if char then killAntiNoclip(char) end
			noclipConn = RunService.Stepped:Connect(function()
				local char = getCharacter(LocalPlayer)
				if not char then return end
				for _, part in ipairs(char:GetDescendants()) do
					if part:IsA("BasePart") then part.CanCollide = false end
				end
			end)
			LocalPlayer.CharacterAdded:Connect(killAntiNoclip)
		end
	end })
end)

UIStep(function()
	local g = Player:AddRightGroupbox("Character", "user")
	g:AddToggle("Godmode", { Text = "Godmode", Default = false })
	g:AddButton({ Text = "Reset Character", Callback = function()
		local char = getCharacter(LocalPlayer)
		if char then
			local hum = char:FindFirstChildOfClass("Humanoid")
			if hum then
				hum:BreakJoints()
			else
				for _, part in ipairs(char:GetDescendants()) do
					if part:IsA("BasePart") then part:BreakJoints() end
				end
			end
		end
	end })
end)

Loading:SetMessage("Loading World tab...")
Loading:SetCurrentStep(4)

--[[ WORLD TAB ]]
local doorConn = nil

local function setupDoorListener(char)
	task.wait(1)
	local hrp = char:WaitForChild("HumanoidRootPart", 10) or char:WaitForChild("Torso", 10) or (char:FindFirstChildOfClass("Humanoid") and char:FindFirstChildOfClass("Humanoid"):WaitForChild("RootPart", 5))
	if not hrp then return end
	hrp.Touched:Connect(function(hit)
		if not Toggles.AutoOpenDoors or not Toggles.AutoOpenDoors.Value then return end
		if hit.Name ~= "hitbox" then return end
		local door = hit.Parent and hit.Parent.Parent
		if not (door and CollectionService:HasTag(door, "Door")) then return end
		door:SetAttribute("LocalPlayerOpened", true)
		local glow = door:FindFirstChild("scn") and door.scn:FindFirstChild("glow")
		if glow then glow.BrickColor = BrickColor.new("Bright green"); glow.Material = Enum.Material.Neon end
		local cardScanner = door:FindFirstChild("scn") and door.scn:FindFirstChild("cardScanner")
		if cardScanner then
			local sound = cardScanner:FindFirstChildOfClass("Sound")
			if sound then sound:Play() end
		end
		task.wait(2)
		door:SetAttribute("LocalPlayerOpened", false)
		if glow then glow.BrickColor = BrickColor.new("Bright red"); glow.Material = Enum.Material.SmoothPlastic end
	end)
end

UIStep(function()
	local g = WorldT:AddLeftGroupbox("Doors", "door-open")
	g:AddToggle("AutoOpenDoors", { Text = "Auto Open Doors", Default = false, Tooltip = "Auto open doors with keycard (criminal)", Callback = function(v)
		if doorConn then doorConn:Disconnect(); doorConn = nil end
		if v then
			doorConn = LocalPlayer.CharacterAdded:Connect(setupDoorListener)
			local char = getCharacter(LocalPlayer)
			if char then setupDoorListener(char) end
		end
	end })
end)

UIStep(function()
	local g = WorldT:AddRightGroupbox("World Settings", "globe")
	g:AddToggle("TimeOverride", { Text = "Override Time", Default = false })
	g:AddSlider("TimeOfDay", { Text = "Time of Day", Default = 12, Min = 0, Max = 24, Rounding = 1, Suffix = ":00" })
	g:AddToggle("FogOverride", { Text = "Override Fog", Default = false })
	g:AddSlider("FogEnd", { Text = "Fog End", Default = 10000, Min = 100, Max = 100000, Rounding = 0 })
	g:AddToggle("FogColorOverride", { Text = "Custom Fog Color", Default = false }):AddColorPicker("FogColor", { Default = Color3.new(1, 1, 1) })
end)

UIStep(function()
	local g = WorldT:AddRightGroupbox("Camera", "eye")
	g:AddToggle("CustomFOV", { Text = "Custom FOV", Default = false })
	g:AddSlider("FOVAmount", { Text = "FOV", Default = 90, Min = 20, Max = 180, Rounding = 0, Callback = function(v)
		if Toggles.CustomFOV and Toggles.CustomFOV.Value then
			local cam = workspace.CurrentCamera
			if cam then cam.FieldOfView = v end
		end
	end })
end)

Toggles.CustomFOV:OnChanged(function(v)
	if v then
		local cam = workspace.CurrentCamera
		if cam then cam.FieldOfView = Options.FOVAmount and Options.FOVAmount.Value or 90 end
	else
		local cam = workspace.CurrentCamera
		if cam then cam.FieldOfView = 70 end
	end
end)

Loading:SetMessage("Loading Visual tab...")
Loading:SetCurrentStep(5)

--[[ VISUAL TAB ]]
local ESPDrawings = {}
local ESPConn = nil
local ChamsInstances = {}
local CrosshairConn = nil

local function newDraw(t, props)
	local d = Drawing.new(t)
	for k, v in pairs(props) do d[k] = v end
	return d
end

local function getESP(plr)
	if ESPDrawings[plr] then return ESPDrawings[plr] end
	local o = {}
	o.box = newDraw("Square", { Thickness = 2.5, Filled = false, Color = Color3.new(1, 1, 1), Visible = false })
	o.out = newDraw("Square", { Thickness = 1, Filled = false, Color = Color3.new(0, 0, 0), Visible = false })
	o.corners = {}
	for i = 1, 8 do
		o.corners[i] = newDraw("Line", { Thickness = 2.5, Color = Color3.new(1, 1, 1), Visible = false })
	end
	o.cornersOut = {}
	for i = 1, 8 do
		o.cornersOut[i] = newDraw("Line", { Thickness = 1, Color = Color3.new(0, 0, 0), Visible = false })
	end
	o.name = newDraw("Text", { Size = 13, Center = true, Outline = true, Color = Color3.new(1, 1, 1), Font = 2, Visible = false })
	o.dist = newDraw("Text", { Size = 12, Center = true, Outline = true, Color = Color3.fromRGB(190, 190, 200), Font = 2, Visible = false })
	o.tracer = newDraw("Line", { Thickness = 1, Color = Color3.fromRGB(120, 170, 255), Visible = false })
	o.hpbg = newDraw("Square", { Thickness = 1, Filled = true, Color = Color3.new(0, 0, 0), Transparency = 0.6, Visible = false })
	o.hp = newDraw("Square", { Thickness = 1, Filled = true, Color = Color3.fromRGB(80, 220, 120), Visible = false })
	o.skel = {}
	ESPDrawings[plr] = o
	return o
end

local function hideESP(o)
	for _, d in pairs(o) do
		if type(d) == "userdata" then pcall(function() d.Visible = false end)
		elseif type(d) == "table" then
			for _, l in ipairs(d) do pcall(function() l.Visible = false end) end
		end
	end
end

local function removeESP(plr)
	local o = ESPDrawings[plr]
	if o then
		for _, d in pairs(o) do
			if type(d) == "userdata" then pcall(d.Remove, d)
			elseif type(d) == "table" then for _, l in ipairs(d) do pcall(l.Remove, l) end end
		end
		ESPDrawings[plr] = nil
	end
end

local function fullESPCleanup()
	for plr in pairs(ESPDrawings) do removeESP(plr) end
end

local function isR6(char)
	return char and char:FindFirstChild("Torso") ~= nil and char:FindFirstChild("UpperTorso") == nil
end

local r15Skel = {
	{ "Head", "UpperTorso" }, { "UpperTorso", "LowerTorso" },
	{ "UpperTorso", "LeftUpperArm" }, { "LeftUpperArm", "LeftLowerArm" }, { "LeftLowerArm", "LeftHand" },
	{ "UpperTorso", "RightUpperArm" }, { "RightUpperArm", "RightLowerArm" }, { "RightLowerArm", "RightHand" },
	{ "LowerTorso", "LeftUpperLeg" }, { "LeftUpperLeg", "LeftLowerLeg" }, { "LeftLowerLeg", "LeftFoot" },
	{ "LowerTorso", "RightUpperLeg" }, { "RightUpperLeg", "RightLowerLeg" }, { "RightLowerLeg", "RightFoot" },
}
local r6Skel = {
	{ "Head", "Torso" },
	{ "Torso", "Left Arm" }, { "Torso", "Right Arm" },
	{ "Torso", "Left Leg" }, { "Torso", "Right Leg" },
}

local function getSkelPairs(char)
	if isR6(char) then return r6Skel end
	return r15Skel
end

local function getFoot(char)
	if isR6(char) then
		return char:FindFirstChild("Left Leg") or char:FindFirstChild("Right Leg")
	end
	return char:FindFirstChild("LeftFoot") or char:FindFirstChild("RightFoot")
end

UIStep(function()
	local g = Visual:AddLeftGroupbox("ESP", "eye")
	g:AddToggle("ESP", { Text = "Enable ESP", Default = false, Callback = function(v)
		if ESPConn then ESPConn:Disconnect(); ESPConn = nil end
		if not v then fullESPCleanup() return end
		ESPConn = RunService.RenderStepped:Connect(function()
			pcall(function()
				local cam = workspace.CurrentCamera
				if not cam then return end
				local vpSize = cam.ViewportSize
				local showTeams = Toggles.ESPTeamCheck and Toggles.ESPTeamCheck.Value
				local teamOnly = Toggles.ESPTeamOnly and Toggles.ESPTeamOnly.Value
				local showBox = Toggles.ESPBox and Toggles.ESPBox.Value
				local boxStyle = Options.ESPBoxStyle and Options.ESPBoxStyle.Value or "Box"
				local showOutline = Toggles.ESPBoxOutline and Toggles.ESPBoxOutline.Value
				local showName = Toggles.ESPName and Toggles.ESPName.Value
				local showDist = Toggles.ESPDistance and Toggles.ESPDistance.Value
				local showHealth = Toggles.ESPHealth and Toggles.ESPHealth.Value
				local showTracers = Toggles.ESPTracers and Toggles.ESPTracers.Value
				local showSkeleton = Toggles.ESPSkeleton and Toggles.ESPSkeleton.Value
				local tracerOrigin = Options.ESPTracerOrigin and Options.ESPTracerOrigin.Value or "Bottom"

				for _, plr in ipairs(Players:GetPlayers()) do
					if plr == LocalPlayer then continue end
					local o = getESP(plr)
					local char = getCharacter(plr)
					local hum = getHumanoid(plr)
					local hrp = getHRP(plr)
					local head = char and (char:FindFirstChild("Head") or hrp)
					if not (hum and hrp and head and hum.Health > 0) then hideESP(o) continue end
					if showTeams and teamOnly and plr.Team ~= LocalPlayer.Team then hideESP(o) continue end
					if showTeams and not plr.Team then hideESP(o) continue end
					local col = showTeams and getTeamColor(plr) or Color3.new(1, 1, 1)
					local headPos2d = cam:WorldToViewportPoint(head.Position + Vector3.new(0, 0.5, 0))
					local foot = getFoot(char)
					local footPos2d = foot and cam:WorldToViewportPoint(foot.Position - Vector3.new(0, 0.5, 0))
					local bottomPos = footPos2d or cam:WorldToViewportPoint(hrp.Position - Vector3.new(0, isR6(char) and 1 or 1.5, 0))
					local topPos = headPos2d or cam:WorldToViewportPoint(hrp.Position + Vector3.new(0, isR6(char) and 2 or 3, 0))
					if topPos.Z < 0 or bottomPos.Z < 0 then hideESP(o) continue end
					local h = math.abs(bottomPos.Y - topPos.Y)
					if h < 10 then hideESP(o) continue end
					local w = h * 0.55
					local x = topPos.X - w / 2
					local y = topPos.Y

					o.name.Visible = showName; o.name.Text = plr.DisplayName; o.name.Position = Vector2.new(topPos.X, y - 16); o.name.Color = col
					local dist = math.floor((cam.CFrame.Position - hrp.Position).Magnitude)
					o.dist.Visible = showDist; o.dist.Text = dist .. " studs"; o.dist.Position = Vector2.new(topPos.X, y + h + 2); o.dist.Color = col
					o.tracer.Visible = showTracers
					if tracerOrigin == "Top" then o.tracer.From = Vector2.new(vpSize.X / 2, 0)
					elseif tracerOrigin == "Mouse" then o.tracer.From = UserInputService:GetMouseLocation()
					else o.tracer.From = Vector2.new(vpSize.X / 2, vpSize.Y) end
					o.tracer.To = Vector2.new(topPos.X, y + h); o.tracer.Color = col

					if showBox and boxStyle == "Corners" then
						local len = w * 0.25
						local corners = {
							{ Vector2.new(x, y), Vector2.new(x + len, y) },
							{ Vector2.new(x, y), Vector2.new(x, y + len) },
							{ Vector2.new(x + w, y), Vector2.new(x + w - len, y) },
							{ Vector2.new(x + w, y), Vector2.new(x + w, y + len) },
							{ Vector2.new(x, y + h), Vector2.new(x + len, y + h) },
							{ Vector2.new(x, y + h), Vector2.new(x, y + h - len) },
							{ Vector2.new(x + w, y + h), Vector2.new(x + w - len, y + h) },
							{ Vector2.new(x + w, y + h), Vector2.new(x + w, y + h - len) },
						}
						for i = 1, 8 do
							o.corners[i].Visible = true; o.corners[i].From = corners[i][1]; o.corners[i].To = corners[i][2]; o.corners[i].Color = col
							if showOutline then
								o.cornersOut[i].Visible = true; o.cornersOut[i].From = corners[i][1] + Vector2.new(-1, -1); o.cornersOut[i].To = corners[i][2] + Vector2.new(-1, -1); o.cornersOut[i].Color = Color3.new(0, 0, 0)
							else o.cornersOut[i].Visible = false end
						end
						o.box.Visible = false; o.out.Visible = false
					elseif showBox then
						for i = 1, 8 do o.corners[i].Visible = false; o.cornersOut[i].Visible = false end
						o.box.Color = col; o.box.Size = Vector2.new(w, h); o.box.Position = Vector2.new(x, y); o.box.Visible = true
						if showOutline then
							o.out.Color = Color3.new(0, 0, 0); o.out.Size = Vector2.new(w + 2, h + 2); o.out.Position = Vector2.new(x - 1, y - 1); o.out.Visible = true
						else o.out.Visible = false end
					else
						for i = 1, 8 do o.corners[i].Visible = false; o.cornersOut[i].Visible = false end
						o.box.Visible = false; o.out.Visible = false
					end

					if showHealth and hum then
						local r = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
						o.hpbg.Visible = true; o.hp.Visible = true
						o.hpbg.Size = Vector2.new(4, h); o.hpbg.Position = Vector2.new(x - 8, y)
						o.hp.Size = Vector2.new(4, h * r); o.hp.Position = Vector2.new(x - 8, y + h * (1 - r)); o.hp.Color = Color3.new(1 - r, r, 0)
					else o.hpbg.Visible = false; o.hp.Visible = false end

					if showSkeleton then
						local pairs = getSkelPairs(char)
						for idx, pair in ipairs(pairs) do
							local a, b = char:FindFirstChild(pair[1]), char:FindFirstChild(pair[2])
							if a and b then
								local aPos = cam:WorldToViewportPoint(a.Position)
								local bPos = cam:WorldToViewportPoint(b.Position)
								if aPos.Z >= 0 and bPos.Z >= 0 then
									if not o.skel[idx] then o.skel[idx] = Drawing.new("Line"); o.skel[idx].Thickness = 1; o.skel[idx].Color = col end
									o.skel[idx].Visible = true; o.skel[idx].From = Vector2.new(aPos.X, aPos.Y); o.skel[idx].To = Vector2.new(bPos.X, bPos.Y)
								elseif o.skel[idx] then o.skel[idx].Visible = false end
							elseif o.skel[idx] then o.skel[idx].Visible = false end
						end
					else for _, l in ipairs(o.skel) do pcall(function() l.Visible = false end) end end
				end
			end)
		end)
	end })
	g:AddToggle("ESPTeamCheck", { Text = "Team Colors", Default = false })
	g:AddToggle("ESPTeamOnly", { Text = "Same Team Only", Default = false })
	g:AddDivider()
	g:AddToggle("ESPBox", { Text = "Box", Default = true })
	g:AddDropdown("ESPBoxStyle", { Text = "Box Style", Values = { "Box", "Corners" }, Default = "Box" })
	g:AddToggle("ESPBoxOutline", { Text = "Box Outline", Default = true })
	g:AddToggle("ESPName", { Text = "Name", Default = true })
	g:AddToggle("ESPDistance", { Text = "Distance", Default = true })
	g:AddToggle("ESPHealth", { Text = "Health Bar", Default = true })
	g:AddToggle("ESPTracers", { Text = "Tracers", Default = false })
	g:AddDropdown("ESPTracerOrigin", { Text = "Tracer Origin", Values = { "Bottom", "Top", "Mouse" }, Default = "Bottom" })
	g:AddToggle("ESPSkeleton", { Text = "Skeleton", Default = false })
	g:AddToggle("DamageNotifs", { Text = "Damage Notifications", Default = false })
end)

UIStep(function()
	local g = Visual:AddRightGroupbox("Chams & Effects", "eye")
	g:AddToggle("ESPChams", { Text = "Chams", Default = false }):AddColorPicker("ESPChamsColor", { Default = Color3.new(1, 1, 1) })
	g:AddToggle("Crosshair", { Text = "Crosshair", Default = false, Callback = function(v)
		if CrosshairConn then CrosshairConn:Disconnect(); CrosshairConn = nil end
		if v then
			local style = Options.CrosshairStyle and Options.CrosshairStyle.Value or "Cross"
			local size = Options.CrosshairSize and Options.CrosshairSize.Value or 10
			local color = Options.CrosshairColor and Options.CrosshairColor.Value or Color3.new(1, 1, 1)
			local dot = Drawing.new("Circle"); dot.NumSides = 16; dot.Thickness = 1; dot.Color = color; dot.Visible = false
			local lines = {}
			for i = 1, 4 do lines[i] = Drawing.new("Line"); lines[i].Thickness = 1; lines[i].Color = color; lines[i].Visible = false end
			CrosshairConn = RunService.RenderStepped:Connect(function()
				local mousePos = UserInputService:GetMouseLocation()
				local gap = size * 0.4
				if style == "Cross" then
					lines[1].Visible = true; lines[1].From = Vector2.new(mousePos.X, mousePos.Y - size); lines[1].To = Vector2.new(mousePos.X, mousePos.Y - gap)
					lines[2].Visible = true; lines[2].From = Vector2.new(mousePos.X, mousePos.Y + gap); lines[2].To = Vector2.new(mousePos.X, mousePos.Y + size)
					lines[3].Visible = true; lines[3].From = Vector2.new(mousePos.X - size, mousePos.Y); lines[3].To = Vector2.new(mousePos.X - gap, mousePos.Y)
					lines[4].Visible = true; lines[4].From = Vector2.new(mousePos.X + gap, mousePos.Y); lines[4].To = Vector2.new(mousePos.X + size, mousePos.Y)
					dot.Visible = false
				elseif style == "Dot" then
					dot.Visible = true; dot.Position = mousePos; dot.Radius = size * 0.3
					for i = 1, 4 do lines[i].Visible = false end
				elseif style == "Circle" then
					dot.Visible = true; dot.Position = mousePos; dot.Radius = size; dot.Filled = false
					for i = 1, 4 do lines[i].Visible = false end
				end
			end)
		end
	end })
	g:AddDropdown("CrosshairStyle", { Text = "Style", Values = { "Cross", "Dot", "Circle" }, Default = "Cross" })
	g:AddSlider("CrosshairSize", { Text = "Size", Default = 10, Min = 2, Max = 50, Rounding = 1 })
	g:AddLabel("Color"):AddColorPicker("CrosshairColor", { Default = Color3.new(1, 1, 1) })
	g:AddToggle("StatusDisplay", { Text = "Status Display", Default = false })
end)

Loading:SetMessage("Loading Misc tab...")
Loading:SetCurrentStep(6)

--[[ MISC TAB ]]
local gunControllerHooked = false

UIStep(function()
	local g = Misc:AddLeftGroupbox("Gun Modifications", "gun")
	g:AddToggle("InfiniteAmmo", { Text = "Infinite Ammo", Default = false })
	g:AddToggle("AutoReload", { Text = "Auto Reload", Default = false })
	g:AddToggle("InstaReload", { Text = "Instant Reload", Default = false })
	g:AddToggle("AutoFire", { Text = "Auto Fire", Default = false })
	g:AddDivider()
	g:AddToggle("RapidFire", { Text = "Rapid Fire", Default = false })
	g:AddSlider("RapidFireRate", { Text = "Fire Rate", Default = 0.1, Min = 0.01, Max = 1, Rounding = 2, Suffix = "s" })
	g:AddDivider()
	g:AddToggle("SpreadModifier", { Text = "Spread Modifier", Default = false })
	g:AddSlider("SpreadAmount", { Text = "Spread", Default = 0, Min = 0, Max = 5, Rounding = 2 })
	g:AddToggle("CustomRange", { Text = "Custom Range", Default = false })
	g:AddSlider("RangeAmount", { Text = "Range", Default = 1500, Min = 100, Max = 10000, Rounding = 0, Suffix = " studs" })
	g:AddToggle("CustomMaxAmmo", { Text = "Custom Max Ammo", Default = false })
	g:AddSlider("MaxAmmoAmount", { Text = "Max Ammo", Default = 999, Min = 1, Max = 9999, Rounding = 0 })
	g:AddDivider()
	g:AddToggle("DisableAnims", { Text = "Disable Animations", Default = false })
	g:AddDropdown("DisableAnimsFilter", { Text = "Block", Values = { "All", "Shoot", "Reload", "Equip" }, Default = "All" })
	g:AddDivider()
	g:AddToggle("DisableSounds", { Text = "Disable Sounds", Default = false })
	g:AddDropdown("DisableSoundsFilter", { Text = "Block", Values = { "All", "Shoot", "Reload", "Equip" }, Default = "All" })
	g:AddToggle("CustomSounds", { Text = "Custom Sounds", Default = false })
	g:AddLabel("Shoot Sound ID")
	g:AddInput("CustomShootSound", { Text = "Shoot Sound ID", Default = "", Placeholder = "rbxassetid://..." })
	g:AddLabel("Reload Sound ID")
	g:AddInput("CustomReloadSound", { Text = "Reload Sound ID", Default = "", Placeholder = "rbxassetid://..." })
	g:AddDivider()
	g:AddToggle("DisableTracers", { Text = "Disable Tracers", Default = false })
	g:AddToggle("CustomTracerColor", { Text = "Custom Color", Default = false }):AddColorPicker("TracerColor", { Default = Color3.fromRGB(0, 183, 255) })
end)

UIStep(function()
	local g = Misc:AddRightGroupbox("Anti", "shield")
	g:AddToggle("AntiAFK", { Text = "Anti AFK", Default = false })
	g:AddToggle("AntiFallDamage", { Text = "Anti Fall Damage", Default = false })
	g:AddToggle("AntiFlung", { Text = "Anti Flung", Default = false })
end)

--[[ SETTINGS TAB ]]
pcall(function() SaveManager:SetLibrary(Library) end)
pcall(function() SaveManager:IgnoreThemeSettings() end)
pcall(function() SaveManager:SetIgnoreIndexes({ "MenuKeybind" }) end)
pcall(function() SaveManager:SetFolder("Meridian-PrisonLife") end)

pcall(function() ThemeManager:SetLibrary(Library) end)
pcall(function() ThemeManager:SetFolder("Meridian-PrisonLife") end)

UIStep(function()
	local g = Settings:AddLeftGroupbox("Menu", "menu")
	g:AddLabel("Menu keybind"):AddKeyPicker("MenuKeybind", { Default = "RightShift", NoUI = true, Text = "Menu keybind" })
	Library.ToggleKeybind = Library.Options.MenuKeybind
	g:AddDivider()
	g:AddToggle("Watermark", { Text = "Watermark", Default = true, Callback = function(v)
		if v then
			Library:Notify({ Title = "Meridian", Description = "Watermark enabled", Time = 2 })
		end
	end })
	g:AddToggle("Notifications", { Text = "Notifications", Default = true, Callback = function(v)
		Library.NotifyOnError = v
		if v then
			Library:Notify({ Title = "Meridian", Description = "Notifications enabled", Time = 2 })
		end
	end })
	Library.NotifyOnError = true
end)

UIStep(function()
	pcall(function() ThemeManager:ApplyToTab(Settings) end)
	pcall(function() SaveManager:BuildConfigSection(Settings) end)
end)

UIStep(function()
	local g = Settings:AddRightGroupbox("Info", "info")
	g:AddLabel("Meridian [Prison Life]")
	g:AddLabel("dsc.gg/meridianui")
	g:AddLabel("Executor: " .. executor)
	g:AddDivider()
	g:AddButton({ Text = "Reset Settings", Callback = function() Library:Notify({ Title = "Meridian", Description = "Settings reset", Time = 3 }) end })
	g:AddButton({ Text = "Rejoin Server", Callback = function()
		Library:Unload()
		TeleportService:Teleport(game.PlaceId, LocalPlayer)
	end })
	g:AddButton({ Text = "Unload", Callback = function() Library:Unload() end })
end)

--[[ GUN CONTROLLER HOOK ]]
local function hookGunController()
	if gunControllerHooked then return end
	gunControllerHooked = true

	local toolConn = nil
	local attributeConns = {}
	local soundConns = {}
	local toolSoundObjs = {}

	local function patchU7Table()
		local char = getCharacter(LocalPlayer)
		if not char then return end
		local tool = char:FindFirstChildOfClass("Tool")
		if not tool or tool:GetAttribute("ToolType") ~= "Gun" then return end
		for _, v in ipairs(getgc(true)) do
			if type(v) == "table" and rawget(v, "Behavior") and rawget(v, "FireRate") and rawget(v, "SpreadRadius") and rawget(v, "ToolType") == "Gun" then
				if Toggles.RapidFire and Toggles.RapidFire.Value then
					v.FireRate = Options.RapidFireRate and Options.RapidFireRate.Value or 0.1
				end
				if Toggles.SpreadModifier and Toggles.SpreadModifier.Value then
					v.SpreadRadius = Options.SpreadAmount and Options.SpreadAmount.Value or 0
				end
				if Toggles.CustomRange and Toggles.CustomRange.Value then
					v.Range = Options.RangeAmount and Options.RangeAmount.Value or 1500
				end
				if Toggles.CustomMaxAmmo and Toggles.CustomMaxAmmo.Value then
					v.MaxAmmo = Options.MaxAmmoAmount and Options.MaxAmmoAmount.Value or 999
				end
				if Toggles.AutoFire and Toggles.AutoFire.Value then
					v.AutoFire = true
				end
				break
			end
		end
	end

	local function refreshToolSounds(tool)
		if not tool then return end
		if toolSoundObjs[tool] then
			for _, c in ipairs(toolSoundObjs[tool]) do pcall(c.Disconnect, c) end
			toolSoundObjs[tool] = nil
		end
		local conns = {}
		local function processSound(snd)
			if not snd:IsA("Sound") then return end
			if Toggles.DisableSounds and Toggles.DisableSounds.Value then
				snd.Volume = 0
			else
				snd.Volume = 1
			end
			if Toggles.CustomSounds and Toggles.CustomSounds.Value then
				local isReload = snd.Name:lower():find("reload")
				local isShoot = snd.Name:lower():find("shoot") or snd.Name:lower():find("fire") or snd.Name:lower():find("shot")
				if isShoot then
					local id = Options.CustomShootSound and Options.CustomShootSound.Value
					if id and id ~= "" then pcall(function() snd.SoundId = id end) end
				elseif isReload then
					local id = Options.CustomReloadSound and Options.CustomReloadSound.Value
					if id and id ~= "" then pcall(function() snd.SoundId = id end) end
				end
			end
		end
		local function processTracers(obj)
			if obj:IsA("Beam") or obj:IsA("Trail") then
				if Toggles.DisableTracers and Toggles.DisableTracers.Value then
					obj.Enabled = false
				else
					obj.Enabled = true
				end
				if Toggles.CustomTracerColor and Toggles.CustomTracerColor.Value then
					local col = Options.TracerColor and Options.TracerColor.Value
					if col then pcall(function() obj.Color = ColorSequence.new(col) end) end
				end
			end
		end
		for _, snd in ipairs(tool:GetDescendants()) do processSound(snd); processTracers(snd) end
		table.insert(conns, tool.DescendantAdded:Connect(function(desc)
			processSound(desc); processTracers(desc)
		end))
		toolSoundObjs[tool] = conns
	end

	local function applyMods(tool)
		if not tool or tool:GetAttribute("ToolType") ~= "Gun" then return end

		for _, conn in ipairs(attributeConns) do pcall(conn.Disconnect, conn) end
		attributeConns = {}

		refreshToolSounds(tool)

		local function onChanged()
			if not tool then return end
			if Toggles.InfiniteAmmo and Toggles.InfiniteAmmo.Value then
				task.spawn(function() tool:SetAttribute("Local_CurrentAmmo", tool:GetAttribute("MaxAmmo") or 30) end)
			end
			if Toggles.AutoReload and Toggles.AutoReload.Value then
				local ammo = tool:GetAttribute("Local_CurrentAmmo")
				local stored = tool:GetAttribute("StoredAmmo")
				if ammo and ammo <= 0 and stored and stored > 0 then
					local reloadFunc = ReplicatedStorage:FindFirstChild("GunRemotes") and ReplicatedStorage.GunRemotes:FindFirstChild("FuncReload")
					if reloadFunc then task.spawn(reloadFunc.InvokeServer, reloadFunc) end
				end
			end
			if Toggles.InstaReload and Toggles.InstaReload.Value then
				tool:SetAttribute("Local_ReloadSession", 0)
				tool:SetAttribute("Local_CurrentAmmo", tool:GetAttribute("MaxAmmo") or 30)
			end
			if Toggles.RapidFire and Toggles.RapidFire.Value then
				tool:SetAttribute("FireRate", Options.RapidFireRate and Options.RapidFireRate.Value or 0.1)
			end
			if Toggles.AutoFire and Toggles.AutoFire.Value then tool:SetAttribute("AutoFire", true) end
			if Toggles.SpreadModifier and Toggles.SpreadModifier.Value then
				tool:SetAttribute("SpreadRadius", Options.SpreadAmount and Options.SpreadAmount.Value or 0)
			end
			if Toggles.CustomRange and Toggles.CustomRange.Value then
				tool:SetAttribute("Range", Options.RangeAmount and Options.RangeAmount.Value or 1500)
			end
			if Toggles.CustomMaxAmmo and Toggles.CustomMaxAmmo.Value then
				local ammo = Options.MaxAmmoAmount and Options.MaxAmmoAmount.Value or 999
				tool:SetAttribute("MaxAmmo", ammo)
				tool:SetAttribute("Local_CurrentAmmo", ammo)
			end
			if Toggles.DisableAnims and Toggles.DisableAnims.Value then
				local hum = getHumanoid(LocalPlayer)
				if hum then
					local filter = Toggles.DisableAnimsFilter and Toggles.DisableAnimsFilter.Value or "All"
					for _, track in ipairs(hum:GetPlayingAnimationTracks()) do
						local name = track.Animation and track.Animation.Name:lower() or ""
						if filter == "All" then track:Stop()
						elseif filter == "Shoot" and (name:find("shoot") or name:find("fire")) then track:Stop()
						elseif filter == "Reload" and name:find("reload") then track:Stop()
						elseif filter == "Equip" and (name:find("equip") or name:find("draw")) then track:Stop()
						end
					end
				end
			end
			refreshToolSounds(tool)
			patchU7Table()
		end

		local attrList = { "Local_CurrentAmmo", "StoredAmmo", "Local_ReloadSession", "FireRate", "AutoFire", "SpreadRadius", "Range", "MaxAmmo" }
		for _, attr in ipairs(attrList) do
			table.insert(attributeConns, tool:GetAttributeChangedSignal(attr):Connect(onChanged))
		end
		onChanged()
	end

	local function onToolAdded(tool)
		if toolConn then toolConn:Disconnect() end
		if tool:GetAttribute("ToolType") == "Gun" then
			applyMods(tool)
			toolConn = tool:GetAttributeChangedSignal("ToolType"):Connect(function()
				if tool:GetAttribute("ToolType") == "Gun" then applyMods(tool) end
			end)
		end
	end

	local char = getCharacter(LocalPlayer)
	if char then
		char.ChildAdded:Connect(onToolAdded)
		for _, tool in ipairs(char:GetChildren()) do
			if tool:IsA("Tool") and tool:GetAttribute("ToolType") == "Gun" then
				applyMods(tool)
				toolConn = tool:GetAttributeChangedSignal("ToolType"):Connect(function()
					if tool:GetAttribute("ToolType") == "Gun" then applyMods(tool) end
				end)
			end
		end
	end

	LocalPlayer.CharacterAdded:Connect(function(newChar)
		task.wait(1)
		if toolConn then toolConn:Disconnect(); toolConn = nil end
		newChar.ChildAdded:Connect(onToolAdded)
		for _, tool in ipairs(newChar:GetChildren()) do
			if tool:IsA("Tool") and tool:GetAttribute("ToolType") == "Gun" then
				applyMods(tool)
				toolConn = tool:GetAttributeChangedSignal("ToolType"):Connect(function()
					if tool:GetAttribute("ToolType") == "Gun" then applyMods(tool) end
				end)
			end
		end
	end)

	-- Also hook the tool equip detection through PlayerScripts
	local playerScripts = LocalPlayer:FindFirstChild("PlayerScripts")
	if playerScripts then
		local clientFighter = playerScripts:FindFirstChild("Modules") and playerScripts.Modules:FindFirstChild("ClientReplicatedClasses") and playerScripts.Modules.ClientReplicatedClasses:FindFirstChild("ClientFighter")
		if clientFighter then
			local clientItem = clientFighter:FindFirstChild("ClientItem")
			if clientItem then
				pcall(function()
					local origInput = clientItem.Input
					if origInput then
						clientItem.Input = function(self, ...)
							local results = {origInput(self, ...)}
							local tool = self and self._itemRef and self._itemRef:FindFirstChild("Tool")
							if tool then
								if Toggles.InfiniteAmmo and Toggles.InfiniteAmmo.Value then
									tool:SetAttribute("Local_CurrentAmmo", tool:GetAttribute("MaxAmmo") or 30)
								end
								if Toggles.RapidFire and Toggles.RapidFire.Value then
									tool:SetAttribute("FireRate", Options.RapidFireRate and Options.RapidFireRate.Value or 0.1)
								end
								if Toggles.AutoFire and Toggles.AutoFire.Value then
									tool:SetAttribute("AutoFire", true)
								end
							end
							return unpack(results)
						end
					end
				end)
			end
		end
	end
end

	-- Snapshot attribute toggle connections
	local function connectSnapshotPatches()
		local tl = { "RapidFire", "SpreadModifier", "CustomRange", "CustomMaxAmmo", "AutoFire" }
		for _, n in ipairs(tl) do
			if Toggles[n] then Toggles[n]:OnChanged(function() pcall(patchU7Table) end) end
		end
		local ol = { "RapidFireRate", "SpreadAmount", "RangeAmount", "MaxAmmoAmount" }
		for _, n in ipairs(ol) do
			if Options[n] then Options[n]:OnChanged(function() pcall(patchU7Table) end) end
		end
	end
	task.spawn(function() task.wait(3) connectSnapshotPatches() end)

--[[ SILENT AIM - castRay hook ]]
local silentAimFOVConn = nil
local silentAimFovCircle = Drawing.new("Circle")
silentAimFovCircle.Visible = false; silentAimFovCircle.Filled = false; silentAimFovCircle.Thickness = 1; silentAimFovCircle.NumSides = 64; silentAimFovCircle.Color = Color3.new(1, 1, 1)
local silentAimFovOutline = Drawing.new("Circle")
silentAimFovOutline.Visible = false; silentAimFovOutline.Color = Color3.new(0, 0, 0); silentAimFovOutline.Thickness = 2; silentAimFovOutline.NumSides = 64; silentAimFovOutline.Filled = false
local silentAimFovFill = Drawing.new("Circle")
silentAimFovFill.Visible = false; silentAimFovFill.Color = Color3.new(1, 1, 1); silentAimFovFill.NumSides = 64; silentAimFovFill.Filled = true; silentAimFovFill.Transparency = 0.8

local function updateSilentAimFOV()
	if silentAimFOVConn then silentAimFOVConn:Disconnect(); silentAimFOVConn = nil end
	local isOn = Toggles.SilentAimShowFOV and Toggles.SilentAimShowFOV.Value
	silentAimFovCircle.Visible = isOn
	silentAimFovOutline.Visible = isOn and Toggles.SilentAimFovOutline and Toggles.SilentAimFovOutline.Value
	silentAimFovFill.Visible = isOn and Toggles.SilentAimFovFill and Toggles.SilentAimFovFill.Value
	if isOn then
		local fov = Options.SilentAimFOV and Options.SilentAimFOV.Value or 100
		silentAimFovCircle.Radius = fov; silentAimFovOutline.Radius = fov; silentAimFovFill.Radius = fov
		silentAimFOVConn = RunService.RenderStepped:Connect(function()
			local pos = UserInputService:GetMouseLocation()
			silentAimFovCircle.Position = pos; silentAimFovOutline.Position = pos; silentAimFovFill.Position = pos
		end)
	end
end

Toggles.SilentAimShowFOV:OnChanged(function() updateSilentAimFOV() end)
Toggles.SilentAimFovOutline:OnChanged(function() updateSilentAimFOV() end)
Toggles.SilentAimFovFill:OnChanged(function() updateSilentAimFOV() end)
Options.SilentAimFOV:OnChanged(function() updateSilentAimFOV() end)

local function silentAimGetClosestPlayer(part_name, fov, wallcheck)
	fov = fov or math.huge
	local closest_player = nil
	local closest_position = nil
	local closest_distance = fov

	for _, player in Players:GetPlayers() do
		if player == LocalPlayer or player.Team == LocalPlayer.Team then continue end
		local character = player.Character
		if not character then continue end
		local part = character:FindFirstChild(part_name)
		if not part then continue end
		local screen_position = workspace.CurrentCamera:WorldToViewportPoint(part.Position)
		if screen_position.Z <= 0 then continue end
		local screen_center = UserInputService:GetMouseLocation()
		local screen_distance = (Vector2.new(screen_position.X, screen_position.Y) - screen_center).Magnitude
		if screen_distance < closest_distance then
			if wallcheck then
				local origin = getCharacter(LocalPlayer) and (getCharacter(LocalPlayer):FindFirstChild("Head") or getHRP(LocalPlayer))
				if origin then
					local ray = workspace:Raycast(origin.Position, (part.Position - origin.Position).Unit * 1500, RaycastParams.new())
					if ray and ray.Instance then
						local hitPlr = Players:GetPlayerFromCharacter(ray.Instance:FindFirstAncestorOfClass("Model"))
						if hitPlr ~= player then continue end
					end
				end
			end
			closest_player = player
			closest_position = part.Position
			closest_distance = screen_distance
		end
	end

	return closest_player, closest_position
end

--[[ SILENT AIM — __namecall hook ]]
local silentAimOrigNamecall = nil

silentAimOrigNamecall = hookmetamethod(game, "__namecall", function(self, ...)
	local method = getnamecallmethod() or ""
	if method == "FireServer" and typeof(self) == "Instance" and self.Name == "ShootEvent" then
		if Toggles.DamageNotifs and Toggles.DamageNotifs.Value then
			damageLastShot = tick()
		end
		if Toggles.SilentAim and Toggles.SilentAim.Value then
			local data = select(1, ...)
			if data and type(data) == "table" then
				local hitpart = Options.SilentAimHitpart and Options.SilentAimHitpart.Value or "Head"
				local fov = Options.SilentAimFOV and Options.SilentAimFOV.Value or 100
				local wallcheck = Toggles.SilentAimWallcheck and Toggles.SilentAimWallcheck.Value
				local hitchance = Options.SilentAimHitchance and Options.SilentAimHitchance.Value or 100
				if hitchance >= 100 or math.random(1, 100) <= hitchance then
					local target, tpos = silentAimGetClosestPlayer(hitpart, fov, wallcheck)
					if target and tpos then
						local tp = target.Character and target.Character:FindFirstChild(hitpart)
						if tp then
							for i, shot in ipairs(data) do
								data[i] = { shot[1], tpos, tp }
							end
						end
					end
				end
			end
		end
	end
	return silentAimOrigNamecall(self, ...)
end)

--[[ AIMLOCK FOV CIRCLE ]]
local aimlockFOVConn = nil
local aimlockFovCircle = Drawing.new("Circle")
aimlockFovCircle.Visible = false; aimlockFovCircle.Filled = false; aimlockFovCircle.Thickness = 1; aimlockFovCircle.NumSides = 64; aimlockFovCircle.Color = Color3.new(1, 0, 0)

local aimlockFovOutline = Drawing.new("Circle")
aimlockFovOutline.Visible = false; aimlockFovOutline.Color = Color3.new(0, 0, 0); aimlockFovOutline.Thickness = 2; aimlockFovOutline.NumSides = 64; aimlockFovOutline.Filled = false

local aimlockFovFill = Drawing.new("Circle")
aimlockFovFill.Visible = false; aimlockFovFill.Color = Color3.new(1, 0, 0); aimlockFovFill.NumSides = 64; aimlockFovFill.Filled = true; aimlockFovFill.Transparency = 0.8

local function updateAimlockFOV()
	if aimlockFOVConn then aimlockFOVConn:Disconnect(); aimlockFOVConn = nil end
	local isOn = Toggles.AimlockShowFOV and Toggles.AimlockShowFOV.Value
	if isOn then
		local showOutline = Toggles.AimlockFovOutline and Toggles.AimlockFovOutline.Value
		local showFill = Toggles.AimlockFovFill and Toggles.AimlockFovFill.Value
		aimlockFovCircle.Visible = true
		aimlockFovOutline.Visible = showOutline
		aimlockFovFill.Visible = showFill
		aimlockFOVConn = RunService.RenderStepped:Connect(function()
			local mPos = UserInputService:GetMouseLocation()
			local radius = Options.AimlockFOV and Options.AimlockFOV.Value or 100
			aimlockFovCircle.Position = mPos
			aimlockFovCircle.Radius = radius
			if showOutline then
				aimlockFovOutline.Position = mPos
				aimlockFovOutline.Radius = radius
			end
			if showFill then
				aimlockFovFill.Position = mPos
				aimlockFovFill.Radius = radius
			end
		end)
	else
		aimlockFovCircle.Visible = false
		aimlockFovOutline.Visible = false
		aimlockFovFill.Visible = false
	end
end

Toggles.AimlockShowFOV:OnChanged(function(v) updateAimlockFOV() end)
Options.AimlockFOV:OnChanged(function() updateAimlockFOV() end)
Toggles.AimlockFovOutline:OnChanged(function() updateAimlockFOV() end)
Toggles.AimlockFovFill:OnChanged(function() updateAimlockFOV() end)

--[[ AIMLOCK ]]
local aimlockConn = nil

Toggles.Aimlock:OnChanged(function(v)
	if aimlockConn then aimlockConn:Disconnect(); aimlockConn = nil end
	if not v then return end
	aimlockConn = RunService.Heartbeat:Connect(function()
		if not Toggles.Aimlock or not Toggles.Aimlock.Value then return end
		local cam = workspace.CurrentCamera
		if not cam then return end
		local hitpart = Options.AimlockHitpart and Options.AimlockHitpart.Value or "HumanoidRootPart"
		local fov = Options.AimlockFOV and Options.AimlockFOV.Value or 100
		local smooth = Options.AimlockSmoothness and Options.AimlockSmoothness.Value or 50
		local wallcheck = Toggles.AimlockWallcheck and Toggles.AimlockWallcheck.Value
		local mousePos = UserInputService:GetMouseLocation()
		local target = nil; local targetPos = nil; local closestDist = fov
		for _, plr in ipairs(Players:GetPlayers()) do
			if plr == LocalPlayer or not canDamage(plr) then continue end
			local part = getCharacter(plr) and getCharacter(plr):FindFirstChild(hitpart)
			if not part then continue end
			local sp = cam:WorldToViewportPoint(part.Position)
			if sp.Z < 0 then continue end
			local dist = (Vector2.new(sp.X, sp.Y) - mousePos).Magnitude
			if dist < closestDist then
				if wallcheck then
					local origin = getCharacter(LocalPlayer) and getCharacter(LocalPlayer):FindFirstChild("Head")
					if origin then
						local ray = workspace:Raycast(origin.Position, (part.Position - origin.Position).Unit * 1500, RaycastParams.new())
						if ray and ray.Instance then
							local hitPlr = Players:GetPlayerFromCharacter(ray.Instance:FindFirstAncestorOfClass("Model"))
							if hitPlr ~= plr then continue end
						end
					end
				end
				target = plr; targetPos = part.Position; closestDist = dist
			end
		end
		if target and targetPos then
			local lookAt = CFrame.lookAt(cam.CFrame.Position, targetPos)
			local factor = math.max(smooth > 0 and (1 - smooth / 100) or 1, 0.05)
			cam.CFrame = cam.CFrame:Lerp(lookAt, factor)
		end
	end)
end)

--[[ WORLD TIME/FOG ]]
Toggles.TimeOverride:OnChanged(function(v)
	local t = Options.TimeOfDay and Options.TimeOfDay.Value or 12
	Lighting.TimeOfDay = v and (t % 24) * 3600 or "12:00:00"
end)

Toggles.FogOverride:OnChanged(function(v)
	Lighting.FogEnd = v and (Options.FogEnd and Options.FogEnd.Value or 10000) or 100000
end)

Options.FogEnd:OnChanged(function(v)
	if Toggles.FogOverride and Toggles.FogOverride.Value then Lighting.FogEnd = v end
end)

Options.FogColor:OnChanged(function(v)
	if Toggles.FogColorOverride and Toggles.FogColorOverride.Value then Lighting.FogColor = v end
end)

Toggles.FogColorOverride:OnChanged(function(v)
	if v then Lighting.FogColor = Options.FogColor and Options.FogColor.Value or Color3.new(1, 1, 1) end
end)

--[[ CHAMS UPDATE ]]
local function updateChams()
	for _, inst in ChamsInstances do if inst and inst.Destroy then pcall(inst.Destroy, inst) end end
	ChamsInstances = {}
	if not Toggles.ESPChams or not Toggles.ESPChams.Value then return end
	local color = Options.ESPChamsColor and Options.ESPChamsColor.Value or Color3.new(1, 1, 1)
	local showTeams = Toggles.ESPTeamCheck and Toggles.ESPTeamCheck.Value
	local teamOnly = Toggles.ESPTeamOnly and Toggles.ESPTeamOnly.Value
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr == LocalPlayer then continue end
		if showTeams and teamOnly and plr.Team ~= LocalPlayer.Team then continue end
		local char = getCharacter(plr)
		if char and getHumanoid(plr) and getHumanoid(plr).Health > 0 then
			local hl = Instance.new("Highlight")
			hl.Adornee = char
			hl.FillColor = showTeams and getTeamColor(plr) or color
			hl.FillTransparency = 0.7
			hl.OutlineColor = Color3.new(0, 0, 0)
			hl.OutlineTransparency = 0.3
			hl.Parent = char
			ChamsInstances[#ChamsInstances + 1] = hl
		end
	end
end

Toggles.ESPChams:OnChanged(function(v)
	if v then
		if updateChams then updateChams() end
	else
		for _, inst in ChamsInstances do
			if inst and inst.Destroy then pcall(inst.Destroy, inst) end
		end
		ChamsInstances = {}
	end
end)
Options.ESPChamsColor:OnChanged(function() updateChams() end)
Toggles.ESPTeamCheck:OnChanged(function() updateChams() end)
Toggles.ESPTeamOnly:OnChanged(function() updateChams() end)

Players.PlayerAdded:Connect(function() task.wait(0.5) updateChams() end)
Players.PlayerRemoving:Connect(function(plr) removeESP(plr) end)

--[[ ANTI AFK ]]
local antiAFKRunning = false
Toggles.AntiAFK:OnChanged(function(v)
	antiAFKRunning = v
	if v then
		task.spawn(function()
			while antiAFKRunning do
				task.wait(30)
				local hrp = getHRP(LocalPlayer)
				if hrp then hrp.CFrame = hrp.CFrame * CFrame.Angles(0, math.rad(1), 0) end
			end
		end)
	end
end)

--[[ ANTI FALL DAMAGE ]]
local oldFallDamage = nil
Toggles.AntiFallDamage:OnChanged(function(v)
	if v then
		local char = getCharacter(LocalPlayer)
		if char then
			local hum = char:FindFirstChildOfClass("Humanoid")
			if hum then oldFallDamage = hum:GetAttribute("FallDamage"); hum:SetAttribute("FallDamage", 0) end
		end
	else
		local char = getCharacter(LocalPlayer)
		if char then
			local hum = char:FindFirstChildOfClass("Humanoid")
			if hum then hum:SetAttribute("FallDamage", oldFallDamage or 1) end
		end
	end
end)

--[[ ANTI FLUNG ]]
local antiFlungPos = nil; local antiFlungConn = nil
Toggles.AntiFlung:OnChanged(function(v)
	if antiFlungConn then antiFlungConn:Disconnect(); antiFlungConn = nil end
	if v then
		local hrp = getHRP(LocalPlayer)
		antiFlungPos = hrp and hrp.Position
		antiFlungConn = RunService.Heartbeat:Connect(function()
			if not Toggles.AntiFlung or not Toggles.AntiFlung.Value then return end
			local hrp = getHRP(LocalPlayer)
			if not hrp then return end
			if antiFlungPos and (hrp.Position - antiFlungPos).Magnitude > 500 then hrp.CFrame = CFrame.new(antiFlungPos) end
			antiFlungPos = hrp.Position
		end)
	end
end)

--[[ STATUS DISPLAY ]]
local statusConn = nil; local statusText1 = nil; local statusText2 = nil
Toggles.StatusDisplay:OnChanged(function(v)
	if statusConn then statusConn:Disconnect(); statusConn = nil end
	if statusText1 then pcall(statusText1.Remove, statusText1); statusText1 = nil end
	if statusText2 then pcall(statusText2.Remove, statusText2); statusText2 = nil end
	if v then
		statusText1 = Drawing.new("Text"); statusText1.Size = 20; statusText1.Font = 2; statusText1.Center = true; statusText1.Outline = true; statusText1.Color = Color3.new(1, 1, 1)
		statusText2 = Drawing.new("Text"); statusText2.Size = 16; statusText2.Font = 2; statusText2.Center = true; statusText2.Outline = true; statusText2.Color = Color3.fromRGB(190, 190, 200)
		statusConn = RunService.RenderStepped:Connect(function()
			local vp = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1920, 1080)
			statusText1.Position = Vector2.new(vp.X / 2, vp.Y * 0.72); statusText1.Text = "meridian.nl"; statusText1.Visible = true
			statusText2.Position = Vector2.new(vp.X / 2, vp.Y * 0.72 + 22); statusText2.Text = "Prison Life"; statusText2.Visible = true
		end)
	end
end)

--[[ DAMAGE NOTIFICATIONS ]]
local damageNotifConn = nil
local damageNotifHealths = {}
local damageLastShot = 0

local function getTeamName(plr)
	local t = plr.Team
	if t == Teams.Guards then return "Guard"
	elseif t == Teams.Inmates then return "Inmate"
	elseif t == Teams.Criminals then return "Criminal" end
	return "Unknown"
end

Toggles.DamageNotifs:OnChanged(function(v)
	if damageNotifConn then damageNotifConn:Disconnect(); damageNotifConn = nil end
	damageNotifHealths = {}
	if v then
		for _, plr in ipairs(Players:GetPlayers()) do
			if plr ~= LocalPlayer then
				local hum = getHumanoid(plr)
				if hum then damageNotifHealths[plr] = hum.Health end
			end
		end
		damageNotifConn = RunService.RenderStepped:Connect(function()
			if not Toggles.DamageNotifs or not Toggles.DamageNotifs.Value then return end
			if tick() - damageLastShot > 1 then return end
			for _, plr in ipairs(Players:GetPlayers()) do
				if plr == LocalPlayer or not canDamage(plr) then continue end
				local hum = getHumanoid(plr)
				if not hum then continue end
				local old = damageNotifHealths[plr]
				local cur = hum.Health
				if old and cur < old then
					Library:Notify({
						Title = "Meridian",
						Description = string.format("Hit %s [%s] for %.0f damage", plr.DisplayName, getTeamName(plr), old - cur),
						Time = 2,
					})
				end
				damageNotifHealths[plr] = cur
			end
		end)
	end
end)

--[[ INIT DEFERRED MODULES ]]
task.spawn(function() task.wait(3) hookGunController() end)

--[[ CLEANUP ]]
Library:OnUnload(function()
	if ESPConn then ESPConn:Disconnect(); ESPConn = nil end
	if CrosshairConn then CrosshairConn:Disconnect(); CrosshairConn = nil end
	if flyConn then flyConn:Disconnect(); flyConn = nil end
	if noclipConn then noclipConn:Disconnect(); noclipConn = nil end
	if aimlockConn then aimlockConn:Disconnect(); aimlockConn = nil end
	if walkspeedConn then walkspeedConn:Disconnect(); walkspeedConn = nil end
	if aimlockFOVConn then aimlockFOVConn:Disconnect(); aimlockFOVConn = nil end
	if doorConn then doorConn:Disconnect(); doorConn = nil end
	if antiAFKRunning then antiAFKRunning = false end
	if antiFlungConn then antiFlungConn:Disconnect(); antiFlungConn = nil end
	if statusConn then statusConn:Disconnect(); statusConn = nil end
	if damageNotifConn then damageNotifConn:Disconnect(); damageNotifConn = nil end
	if silentAimFOVConn then silentAimFOVConn:Disconnect(); silentAimFOVConn = nil end
	fullESPCleanup()
	for _, inst in ChamsInstances do pcall(inst.Destroy, inst) end; ChamsInstances = {}
	pcall(silentAimFovCircle.Remove, silentAimFovCircle)
	pcall(silentAimFovOutline.Remove, silentAimFovOutline)
	pcall(silentAimFovFill.Remove, silentAimFovFill)
	pcall(aimlockFovCircle.Remove, aimlockFovCircle)
	pcall(aimlockFovOutline.Remove, aimlockFovOutline)
	pcall(aimlockFovFill.Remove, aimlockFovFill)
	if statusText1 then pcall(statusText1.Remove, statusText1) end
	if statusText2 then pcall(statusText2.Remove, statusText2) end
	local char = getCharacter(LocalPlayer)
	if char then
		local hum = char:FindFirstChildOfClass("Humanoid")
		if hum then hum.PlatformStand = false; hum.WalkSpeed = 16; hum.JumpPower = 50 end
		for _, part in ipairs(char:GetDescendants()) do
			if part:IsA("BasePart") then pcall(function() part.CanCollide = true end) end
		end
	end
	pcall(function()
		local cam = workspace.CurrentCamera
		if cam then cam.FieldOfView = 70 end
	end)
	Lighting.TimeOfDay = "12:00:00"; Lighting.FogEnd = 100000; Lighting.FogColor = Color3.new(1, 1, 1)
end)

if not loadFailed then
	pcall(function() SaveManager:LoadAutoloadConfig() end)
	pcall(function() ThemeManager:LoadDefault() end)
end

do
	local origDelete = SaveManager.Delete
	SaveManager.Delete = function(self, name)
		if not name then return false, "no config" end
		Window:AddDialog("ConfirmDelete", {
			Title = "Delete Config",
			Description = string.format("Are you sure you want to delete \"%s\"?", name),
			OutsideClickDismiss = true,
			FooterButtons = {
				{ Title = "Cancel", Variant = "Secondary", Order = 1 },
				{ Title = "Delete", Variant = "Destructive", Order = 2, Callback = function(dialog)
					local success, err = origDelete(self, name)
					if success then
						Library:Notify({ Title = "Meridian", Description = string.format("Deleted config %q", name), Time = 3 })
						if Options.SaveManager_ConfigList then
							Options.SaveManager_ConfigList:SetValues(SaveManager:RefreshConfigList())
							Options.SaveManager_ConfigList:SetValue(nil)
						end
					end
					dialog:Dismiss()
				end },
			},
		})
		return true
	end
end

loadComplete = true
if not loadFailed then
	Loading:Continue()
	Library:Notify({
		Title = "Meridian",
		Description = string.format("UI loaded in %.2fs", os.clock() - LoadStart),
		Time = 5,
	})
	getgenv().MeridianPrisonLife = Library
end
