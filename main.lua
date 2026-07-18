local repo = "https://raw.githubusercontent.com/mstudio45/LinoriaLib/main/"

local Library = loadstring(game:HttpGet(repo .. "Library.lua"))()
local ThemeManager = loadstring(game:HttpGet(repo .. "addons/ThemeManager.lua"))()
local SaveManager = loadstring(game:HttpGet(repo .. "addons/SaveManager.lua"))()

local Options = Library.Options
local Toggles = Library.Toggles

Library.ShowToggleFrameInKeybinds = true
Library.ShowCustomCursor = true
Library.NotifySide = "Right"

local Window = Library:CreateWindow({
	Title = "Axiom [Prison Life]",
	Center = true,
	AutoShow = true,
	Resizable = false,
	ShowCustomCursor = true,
	NotifySide = "Right",
	TabPadding = 8,
	MenuFadeTime = 0.2
})

local Tabs = {
	Main = Window:AddTab("Main"),
	Player = Window:AddTab("Player"),
	World = Window:AddTab("World"),
	Visual = Window:AddTab("Visual"),
	Misc = Window:AddTab("Misc"),
	["UI Settings"] = Window:AddTab("UI Settings"),
}

--[[ HELPERS ]]
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local Teams = game:GetService("Teams")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")

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

--[[ MAIN TAB ]]
local MainLeft = Tabs.Main:AddLeftGroupbox("Silent Aim")
MainLeft:AddToggle("SilentAim", { Text = "Silent Aim", Default = false })

local saDep = MainLeft:AddDependencyBox()
saDep:AddSlider("SilentAimFOV", { Text = "FOV", Default = 100, Min = 10, Max = 500, Rounding = 0, Suffix = "px" })
saDep:AddSlider("SilentAimHitchance", { Text = "Hitchance", Default = 100, Min = 0, Max = 100, Rounding = 0, Suffix = "%" })
saDep:AddDropdown("SilentAimHitpart", { Text = "Hitpart", Values = { "Head", "HumanoidRootPart" }, Default = "Head" })
saDep:AddToggle("SilentAimWallcheck", { Text = "Wallcheck", Default = false })
saDep:AddToggle("SilentAimShowFOV", { Text = "Show FOV", Default = false })

local saFovDep = saDep:AddDependencyBox()
saFovDep:AddToggle("SilentAimFovOutline", { Text = "FOV Outline", Default = false })
saFovDep:AddToggle("SilentAimFovFill", { Text = "FOV Fill", Default = false })
saFovDep:SetupDependencies({
	{ Toggles.SilentAimShowFOV, true }
})

saDep:SetupDependencies({
	{ Toggles.SilentAim, true }
})

local MainLeft2 = Tabs.Main:AddLeftGroupbox("Aimlock")
MainLeft2:AddToggle("Aimlock", { Text = "Aimlock", Default = false }):AddKeyPicker("AimlockKey", { Default = "MB2", Text = "Key", Mode = "Hold", Modes = { "Toggle", "Hold", "Always" } })

local alDep = MainLeft2:AddDependencyBox()
alDep:AddSlider("AimlockSmoothness", { Text = "Smoothness", Default = 50, Min = 0, Max = 100, Rounding = 0 })
alDep:AddSlider("AimlockFOV", { Text = "FOV", Default = 100, Min = 10, Max = 500, Rounding = 0, Suffix = "px" })
alDep:AddSlider("AimlockDistance", { Text = "Distance", Default = 100000, Min = 1, Max = 100000, Rounding = 0 })
alDep:AddDropdown("AimlockHitpart", { Text = "Hitpart", Values = { "Head", "HumanoidRootPart" }, Default = 2 })
alDep:AddToggle("AimlockWallcheck", { Text = "Wallcheck", Default = false })
alDep:AddToggle("AimlockShowFOV", { Text = "Show FOV", Default = false })

local alFovDep = alDep:AddDependencyBox()
alFovDep:AddToggle("AimlockFovOutline", { Text = "FOV Outline", Default = false })
alFovDep:AddToggle("AimlockFovFill", { Text = "FOV Fill", Default = false })
alFovDep:SetupDependencies({
	{ Toggles.AimlockShowFOV, true }
})

alDep:SetupDependencies({
	{ Toggles.Aimlock, true }
})

local MainRight1 = Tabs.Main:AddRightGroupbox("Player Teleports")
MainRight1:AddDropdown("PlayerTP", { Text = "Player", Values = {}, Default = nil })
MainRight1:AddButton({
	Text = "Refresh",
	Func = function()
		local names = {}
		for _, p in ipairs(Players:GetPlayers()) do if p ~= LocalPlayer then names[#names + 1] = p.Name end end
		if Options.PlayerTP then Options.PlayerTP:SetValues(names) end
	end
})
MainRight1:AddButton({
	Text = "Teleport",
	Func = function()
		local name = Options.PlayerTP and Options.PlayerTP.Value
		if not name then Library:Notify("Select a player") return end
		local target = Players:FindFirstChild(name)
		if not target then Library:Notify("Player not found") return end
		local pos = getBodyPos(target)
		local hrp = getHRP(LocalPlayer)
		if hrp and pos then hrp.CFrame = CFrame.new(pos) end
	end
})

local MainRight2 = Tabs.Main:AddRightGroupbox("Area Teleports")
MainRight2:AddButton({
	Text = "Prison Outer Wall",
	Func = function()
		local hrp = getHRP(LocalPlayer)
		local wall = Workspace:FindFirstChild("Prison_OuterWall") and Workspace.Prison_OuterWall:FindFirstChild("prison_wall")
		if hrp and wall then hrp.CFrame = CFrame.new(wall:GetPivot().Position) end
	end
})
MainRight2:AddButton({
	Text = "Criminal Spawn",
	Func = function()
		local hrp = getHRP(LocalPlayer)
		local spawn = Workspace:FindFirstChild("Criminals Spawn")
		if hrp and spawn then hrp.CFrame = CFrame.new(spawn:GetPivot().Position) end
	end
})
MainRight2:AddButton({
	Text = "Shipping Containers",
	Func = function()
		local hrp = getHRP(LocalPlayer)
		local sc = Workspace:FindFirstChild("Shippingcontainers")
		if hrp and sc then hrp.CFrame = CFrame.new(sc:GetPivot().Position) end
	end
})

local MainRight3 = Tabs.Main:AddRightGroupbox("Gun Teleports")
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
		Library:Notify(string.format("Could not find %s gun", namePattern))
		return
	end
	local origPos = hrp.CFrame
	hrp.CFrame = CFrame.new(part:GetPivot().Position)
	task.wait(0.3)
	hrp.CFrame = origPos
end
MainRight3:AddButton({ Text = "Shotgun", Func = function() tpToGun("Shotgun") end })
MainRight3:AddButton({ Text = "MP5", Func = function() tpToGun("MP5") end })
MainRight3:AddButton({ Text = "AK-47", Func = function() tpToGun("AK") end })
MainRight3:AddButton({ Text = "Shotgun (Criminal)", Func = function() tpToGun("Criminal") end })
MainRight3:AddButton({ Text = "M9", Func = function() tpToGun("M9") end })
MainRight3:AddDivider()
MainRight3:AddButton({
	Text = "List Guns",
	Func = function()
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
		Library:Notify("Guns counted. Check F9 for list.")
		for _, line in ipairs(list) do print("[GunTP]", line) end
	end
})

--[[ PLAYER TAB ]]
local PlayerLeft = Tabs.Player:AddLeftGroupbox("Movement")
PlayerLeft:AddToggle("Walkspeed", { Text = "Walkspeed", Default = false })

local wsDep = PlayerLeft:AddDependencyBox()
wsDep:AddSlider("WalkspeedAmount", { Text = "Walkspeed Amount", Default = 22, Min = 16, Max = 200, Rounding = 1 })
wsDep:SetupDependencies({
	{ Toggles.Walkspeed, true }
})

PlayerLeft:AddToggle("Jumpspeed", { Text = "Jumpspeed", Default = false })

local jsDep = PlayerLeft:AddDependencyBox()
jsDep:AddSlider("JumpspeedAmount", { Text = "Jumpspeed Amount", Default = 50, Min = 50, Max = 300, Rounding = 1 })
jsDep:SetupDependencies({
	{ Toggles.Jumpspeed, true }
})

PlayerLeft:AddDivider()
PlayerLeft:AddToggle("Fly", { Text = "Fly", Default = false }):AddKeyPicker("FlyKey", { Default = "F", Text = "Key", Mode = "Toggle", Modes = { "Toggle", "Hold", "Always" } })

local flyDep = PlayerLeft:AddDependencyBox()
flyDep:AddSlider("FlySpeed", { Text = "Fly Speed", Default = 50, Min = 1, Max = 200, Rounding = 1 })
flyDep:SetupDependencies({
	{ Toggles.Fly, true }
})

PlayerLeft:AddToggle("Noclip", { Text = "Noclip", Default = false })

local PlayerRight = Tabs.Player:AddRightGroupbox("Character")
PlayerRight:AddToggle("Godmode", { Text = "Godmode", Default = false })
PlayerRight:AddButton({
	Text = "Reset Character",
	Func = function()
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
	end
})

--[[ WORLD TAB ]]
local WorldLeft = Tabs.World:AddLeftGroupbox("Doors")
WorldLeft:AddToggle("AutoOpenDoors", { Text = "Auto Open Doors", Default = false, Tooltip = "Auto open doors with keycard (criminal)" })

local WorldRight1 = Tabs.World:AddRightGroupbox("World Settings")
WorldRight1:AddToggle("TimeOverride", { Text = "Override Time", Default = false })

local timeDep = WorldRight1:AddDependencyBox()
timeDep:AddSlider("TimeOfDay", { Text = "Time of Day", Default = 12, Min = 0, Max = 24, Rounding = 1, Suffix = ":00" })
timeDep:SetupDependencies({
	{ Toggles.TimeOverride, true }
})

WorldRight1:AddToggle("FogOverride", { Text = "Override Fog", Default = false })

local fogDep = WorldRight1:AddDependencyBox()
fogDep:AddSlider("FogEnd", { Text = "Fog End", Default = 10000, Min = 100, Max = 100000, Rounding = 0 })
fogDep:AddToggle("FogColorOverride", { Text = "Custom Fog Color", Default = false }):AddColorPicker("FogColor", { Default = Color3.new(1, 1, 1) })
fogDep:SetupDependencies({
	{ Toggles.FogOverride, true }
})

local WorldRight2 = Tabs.World:AddRightGroupbox("Camera")
WorldRight2:AddToggle("CustomFOV", { Text = "Custom FOV", Default = false })

local fovDep = WorldRight2:AddDependencyBox()
fovDep:AddSlider("FOVAmount", { Text = "FOV", Default = 90, Min = 20, Max = 180, Rounding = 0 })
fovDep:SetupDependencies({
	{ Toggles.CustomFOV, true }
})

--[[ VISUAL TAB ]]
local VisualLeft = Tabs.Visual:AddLeftGroupbox("ESP")
VisualLeft:AddToggle("ESP", { Text = "Enable ESP", Default = false })

local espDep = VisualLeft:AddDependencyBox()
espDep:AddToggle("ESPTeamCheck", { Text = "Team Colors", Default = false })
espDep:AddToggle("ESPTeamOnly", { Text = "Same Team Only", Default = false })

local teamOnlyDep = espDep:AddDependencyBox()
teamOnlyDep:SetupDependencies({
	{ Toggles.ESPTeamCheck, true }
})

espDep:AddDivider()
espDep:AddToggle("ESPBox", { Text = "Box", Default = true })
espDep:AddDropdown("ESPBoxStyle", { Text = "Box Style", Values = { "Box", "Corners" }, Default = "Box" })
espDep:AddToggle("ESPBoxOutline", { Text = "Box Outline", Default = true })
espDep:AddToggle("ESPName", { Text = "Name", Default = true })
espDep:AddToggle("ESPDistance", { Text = "Distance", Default = true })
espDep:AddToggle("ESPHealth", { Text = "Health Bar", Default = true })
espDep:AddToggle("ESPTracers", { Text = "Tracers", Default = false })
espDep:AddDropdown("ESPTracerOrigin", { Text = "Tracer Origin", Values = { "Bottom", "Top", "Mouse" }, Default = "Bottom" })
espDep:AddToggle("ESPSkeleton", { Text = "Skeleton", Default = false })
espDep:AddToggle("DamageNotifs", { Text = "Damage Notifications", Default = false })

espDep:SetupDependencies({
	{ Toggles.ESP, true }
})

local VisualRight = Tabs.Visual:AddRightGroupbox("Chams & Effects")
VisualRight:AddToggle("ESPChams", { Text = "Chams", Default = false }):AddColorPicker("ESPChamsColor", { Default = Color3.new(1, 1, 1) })

VisualRight:AddToggle("Crosshair", { Text = "Crosshair", Default = false })

local chDep = VisualRight:AddDependencyBox()
chDep:AddDropdown("CrosshairStyle", { Text = "Style", Values = { "Cross", "Dot", "Circle" }, Default = "Cross" })
chDep:AddSlider("CrosshairSize", { Text = "Size", Default = 10, Min = 2, Max = 50, Rounding = 1 })
chDep:AddLabel("Color"):AddColorPicker("CrosshairColor", { Default = Color3.new(1, 1, 1) })
chDep:SetupDependencies({
	{ Toggles.Crosshair, true }
})

VisualRight:AddToggle("StatusDisplay", { Text = "Status Display", Default = false })

--[[ MISC TAB ]]
local MiscLeft = Tabs.Misc:AddLeftGroupbox("Gun Modifications")
MiscLeft:AddToggle("InfiniteAmmo", { Text = "Infinite Ammo", Default = false })
MiscLeft:AddToggle("AutoReload", { Text = "Auto Reload", Default = false })
MiscLeft:AddToggle("InstaReload", { Text = "Instant Reload", Default = false })
MiscLeft:AddToggle("AutoFire", { Text = "Auto Fire", Default = false })
MiscLeft:AddDivider()
MiscLeft:AddToggle("RapidFire", { Text = "Rapid Fire", Default = false })

local rfDep = MiscLeft:AddDependencyBox()
rfDep:AddSlider("RapidFireRate", { Text = "Fire Rate", Default = 0.1, Min = 0.01, Max = 1, Rounding = 2, Suffix = "s" })
rfDep:SetupDependencies({
	{ Toggles.RapidFire, true }
})

MiscLeft:AddDivider()
MiscLeft:AddToggle("SpreadModifier", { Text = "Spread Modifier", Default = false })

local spDep = MiscLeft:AddDependencyBox()
spDep:AddSlider("SpreadAmount", { Text = "Spread", Default = 0, Min = 0, Max = 5, Rounding = 2 })
spDep:SetupDependencies({
	{ Toggles.SpreadModifier, true }
})

MiscLeft:AddToggle("CustomRange", { Text = "Custom Range", Default = false })

local crDep = MiscLeft:AddDependencyBox()
crDep:AddSlider("RangeAmount", { Text = "Range", Default = 1500, Min = 100, Max = 10000, Rounding = 0, Suffix = " studs" })
crDep:SetupDependencies({
	{ Toggles.CustomRange, true }
})

MiscLeft:AddToggle("CustomMaxAmmo", { Text = "Custom Max Ammo", Default = false })

local maDep = MiscLeft:AddDependencyBox()
maDep:AddSlider("MaxAmmoAmount", { Text = "Max Ammo", Default = 999, Min = 1, Max = 9999, Rounding = 0 })
maDep:SetupDependencies({
	{ Toggles.CustomMaxAmmo, true }
})

MiscLeft:AddDivider()
MiscLeft:AddToggle("DisableAnims", { Text = "Disable Animations", Default = false })

local daDep = MiscLeft:AddDependencyBox()
daDep:AddDropdown("DisableAnimsFilter", { Text = "Block", Values = { "All", "Shoot", "Reload", "Equip" }, Default = "All" })
daDep:SetupDependencies({
	{ Toggles.DisableAnims, true }
})

MiscLeft:AddDivider()
MiscLeft:AddToggle("DisableSounds", { Text = "Disable Sounds", Default = false })

local dsDep = MiscLeft:AddDependencyBox()
dsDep:AddDropdown("DisableSoundsFilter", { Text = "Block", Values = { "All", "Shoot", "Reload", "Equip" }, Default = "All" })
dsDep:SetupDependencies({
	{ Toggles.DisableSounds, true }
})

MiscLeft:AddToggle("CustomSounds", { Text = "Custom Sounds", Default = false })

local csDep = MiscLeft:AddDependencyBox()
csDep:AddLabel("Shoot Sound ID")
csDep:AddInput("CustomShootSound", { Text = "Shoot Sound ID", Default = "", Placeholder = "rbxassetid://..." })
csDep:AddLabel("Reload Sound ID")
csDep:AddInput("CustomReloadSound", { Text = "Reload Sound ID", Default = "", Placeholder = "rbxassetid://..." })
csDep:SetupDependencies({
	{ Toggles.CustomSounds, true }
})

MiscLeft:AddDivider()
MiscLeft:AddToggle("DisableTracers", { Text = "Disable Tracers", Default = false })
MiscLeft:AddToggle("CustomTracerColor", { Text = "Custom Tracer Color", Default = false }):AddColorPicker("TracerColor", { Default = Color3.fromRGB(0, 183, 255) })

local MiscRight = Tabs.Misc:AddRightGroupbox("Anti")
MiscRight:AddToggle("AntiAFK", { Text = "Anti AFK", Default = false })
MiscRight:AddToggle("AntiFallDamage", { Text = "Anti Fall Damage", Default = false })
MiscRight:AddToggle("AntiFlung", { Text = "Anti Flung", Default = false })

--[[ UI SETTINGS TAB ]]
local MenuGroup = Tabs["UI Settings"]:AddLeftGroupbox("Menu")
MenuGroup:AddToggle("KeybindMenuOpen", { Default = false, Text = "Open Keybind Menu", Callback = function(value) Library.KeybindFrame.Visible = value end })
MenuGroup:AddToggle("ShowCustomCursor", { Text = "Custom Cursor", Default = true, Callback = function(Value) Library.ShowCustomCursor = Value end })
MenuGroup:AddDivider()
MenuGroup:AddLabel("Menu bind"):AddKeyPicker("MenuKeybind", { Default = "RightControl", NoUI = true, Text = "Menu keybind" })
MenuGroup:AddButton("Unload", function()
	blur.Size = 0
	blur.Parent = nil
	blur:Destroy()
	Library:Unload()
end)

Library.ToggleKeybind = Options.MenuKeybind

-- Addons
ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)

SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({ "MenuKeybind" })
SaveManager:SetFolder("Axiom-PrisonLife")

ThemeManager:SetFolder("Axiom-PrisonLife")

SaveManager:BuildConfigSection(Tabs["UI Settings"])
ThemeManager:ApplyToTab(Tabs["UI Settings"])

-- Blur when menu open
local blur = Instance.new("BlurEffect")
blur.Size = 0
blur.Parent = Lighting

local blurTween
local blurConn = Library.Window.Holder:GetPropertyChangedSignal("Visible"):Connect(function()
	if blurTween then blurTween:Cancel() end
	if Library.Window.Holder.Visible then
		blur.Size = 0
		blurTween = TweenService:Create(blur, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = 12 })
		blurTween:Play()
	else
		blurTween = TweenService:Create(blur, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Size = 0 })
		blurTween:Play()
	end
end)

-- Snowflakes
local snowPart = Instance.new("Part")
snowPart.Name = "AxiomSnow"
snowPart.Anchored = true
snowPart.CanCollide = false
snowPart.Transparency = 1
snowPart.Size = Vector3.new(200, 1, 200)
snowPart.Position = Vector3.new(0, 100, 0)
snowPart.Parent = Workspace

local snow = Instance.new("ParticleEmitter")
snow.Rate = 20
snow.Speed = NumberRange.new(3, 8)
snow.VelocityInheritance = 0
snow.Lifetime = NumberRange.new(10, 20)
snow.Texture = "https://raw.githubusercontent.com/hevji/Axiom/main/snowflake.png"
snow.SpreadAngle = NumberRange.new(0, 360)
snow.Acceleration = Vector3.new(0, -3, 0)
snow.Drag = 3
snow.LightEmission = 0.2
snow.Size = NumberSequence.new(0.5, 0.2)
snow.Transparency = NumberSequence.new(0.3, 1)
snow.ZOffset = 2
snow.Rotation = NumberRange.new(0, 360)
snow.RotSpeed = NumberRange.new(-20, 20)
snow.Color = ColorSequence.new(Color3.fromRGB(230, 240, 255))
snow.Parent = snowPart

local snowFollow = task.spawn(function()
	while task.wait(3) do
		local cam = Workspace.CurrentCamera
		if cam then
			local cf = cam.CFrame
			snowPart.Position = cf.Position + cf.LookVector * 60 + Vector3.new(0, 60, 0)
		end
	end
end)

-- Watermark
Library:SetWatermarkVisibility(true)

local FrameTimer = tick()
local FrameCounter = 0
local FPS = 60
local WatermarkConnection = game:GetService("RunService").RenderStepped:Connect(function()
	FrameCounter += 1
	if (tick() - FrameTimer) >= 1 then
		FPS = FrameCounter
		FrameTimer = tick()
		FrameCounter = 0
	end
	Library:SetWatermark(("Axiom | %d fps"):format(math.floor(FPS)))
end)

Library:OnUnload(function()
	pcall(function()
		blur.Size = 0
		blur.Parent = nil
		blur:Destroy()
	end)
	pcall(WatermarkConnection.Disconnect, WatermarkConnection)
	pcall(blurConn.Disconnect, blurConn)
	if blurTween then pcall(blurTween.Cancel, blurTween) end
	coroutine.close(snowFollow)
	pcall(snow.Destroy, snow)
	pcall(snowPart.Destroy, snowPart)
	Library.Unloaded = true
end)

task.spawn(function()
	task.wait(1)
	if Options.PlayerTP then
		local names = {}
		for _, p in ipairs(Players:GetPlayers()) do if p ~= LocalPlayer then names[#names + 1] = p.Name end end
		Options.PlayerTP:SetValues(names)
	end
	while task.wait(10) do
		if Options.PlayerTP then
			local names = {}
			for _, p in ipairs(Players:GetPlayers()) do if p ~= LocalPlayer then names[#names + 1] = p.Name end end
			Options.PlayerTP:SetValues(names)
		end
	end
end)

SaveManager:LoadAutoloadConfig()

getgenv().AxiomPrisonLife = Library
