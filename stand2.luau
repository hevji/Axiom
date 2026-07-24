-- AXIOM STAND
-- Executed on a separate account. Controlled by owner + whitelisted users
-- via chat commands. No GUI. Fully headless.

--[[ ============================================================
	CONFIG
============================================================ ]]

-- Owner is set via getgenv before executing:
--   getgenv().AXIOM_STAND_OWNER = "username"
local STAND_OWNER = getgenv().AXIOM_STAND_OWNER
if not STAND_OWNER then
	error("AXIOM_STAND_OWNER not set in getgenv")
end

local STAND_NAME = "AxiomStand"

-- Whitelisted users can also issue commands. Managed in-game via .wl command.
local COMMAND_WHITELIST = {}

-- Players the stand should never target (owner is always included)
local TARGET_WHITELIST = {
	[STAND_OWNER] = true,
}

--[[ ============================================================
	SERVICES
============================================================ ]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")
local TweenService = game:GetService("TweenService")
local VirtualInputManager = game:GetService("VirtualInputManager")

local LocalPlayer = Players.LocalPlayer

-- Non-blocking remote resolution (WaitForChild hangs forever if path is wrong)
local MainGameEvent = ReplicatedStorage:FindFirstChild("GameRemotes")
if MainGameEvent then MainGameEvent = MainGameEvent:FindFirstChild("MainGameEvent") end

local Remotes = ReplicatedStorage:FindFirstChild("Remotes")

--[[ ============================================================
	STATE
============================================================ ]]

local STATE = {
	IDLE = "Idle",
	VOID = "Void",
	LOOPING = "Looping",
	PROTECTING = "Protecting",
	CARRYING = "Carrying",
	SAFE_MODE = "SafeMode",
	FOLLOW = "Follow",
}

local state = STATE.IDLE
local loopTarget = nil -- player object for .lk / .ls
local loopMode = nil -- "knock" or "stomp"
local protectTarget = nil -- player object for .p
local carryTarget = nil -- player object for .b / .c
local carryDestination = nil -- Vector3 for where to bring the target
local grabbedTarget = nil -- currently grabbed (physically carried) player
local isVoiding = false
local isReloading = false
local lastReloadTime = 0
local lastActionTime = 0

-- Damage tracking: tracks who damaged the owner
local damageLog = {} -- { [player] = lastDamageTime }
local damageThreshold = 10 -- minimum damage to register

--[[ ============================================================
	UTILITY FUNCTIONS
============================================================ ]]

local function getCharacter(player)
	return player and player.Character
end

local function getRoot(char)
	return char and char:FindFirstChild("HumanoidRootPart")
end

local function getHumanoid(char)
	return char and char:FindFirstChildOfClass("Humanoid")
end

local function isAlive(char)
	local hum = getHumanoid(char)
	return char and hum and hum.Health > 0
end

local function getBodyEffects(char)
	return char and char:FindFirstChild("BodyEffects")
end

local function isKO(char)
	if not char then return false end
	local be = getBodyEffects(char)
	if not be then return false end
	local ko = be:FindFirstChild("K.O")
	if not (ko and ko.Value == true) then return false end
	local dead = be:FindFirstChild("Dead")
	if dead and dead.Value == true then return false end
	return true
end

local function isDead(char)
	if not char then return true end
	local be = getBodyEffects(char)
	if not be then return true end
	local dead = be:FindFirstChild("Dead")
	return dead and dead.Value == true
end

local function getPlayerByName(name)
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Name:lower() == name:lower() or p.DisplayName:lower() == name:lower() then
			return p
		end
	end
	return nil
end

local function hasForceField(char)
	return char and char:FindFirstChildOfClass("ForceField") ~= nil
end

local function canTarget(p)
	if p == LocalPlayer then return false end
	return not TARGET_WHITELIST[p.Name] and not TARGET_WHITELIST[p.DisplayName]
end

-- Lenient gun detection: any Tool with a Handle is usable
local function getEquippedGun()
	local char = LocalPlayer.Character
	if not char then return nil end
	for _, t in ipairs(char:GetChildren()) do
		if t:IsA("Tool") and t:FindFirstChild("Handle") then
			return t
		end
	end
	return nil
end

local function getGuns()
	local char = LocalPlayer.Character
	local guns = {}
	if not char then return guns end
	for _, t in ipairs(char:GetChildren()) do
		if t:IsA("Tool") and t:FindFirstChild("Handle") then
			guns[#guns + 1] = t
		end
	end
	return guns
end

local function getMuzzlePos(tool)
	local handle = tool:FindFirstChild("Handle")
	if not handle then return nil end
	-- Try various muzzle locations
	local muzzle = tool:FindFirstChild("Default")
	if muzzle then
		local mesh = muzzle:FindFirstChild("Mesh")
		if mesh then
			local m = mesh:FindFirstChild("Muzzle")
			if m then return m.WorldPosition end
		end
	end
	return (handle.CFrame * CFrame.new(0, 0.35, -2.2)).Position
end

local function getHitPart(char)
	return char:FindFirstChild("Head") or getRoot(char)
end

local function buildShotEntry(part)
	local pos = part.Position
	return {
		AimPosition = pos,
		Result1 = pos,
		Result2 = part,
		Result3 = Vector3.new(0, 1, 0),
	}
end

local function getArmor(char)
	local be = getBodyEffects(char)
	if not be then return 0 end
	local armor = be:FindFirstChild("Armor")
	return armor and armor.Value or 0
end

local function getAmmo(tool)
	if not tool then return 0 end
	local ammo = tool:FindFirstChild("Ammo")
	return ammo and ammo.Value or 0
end

local function getMaxAmmo(tool)
	if not tool then return 0 end
	local max = tool:FindFirstChild("MaxAmmo")
	return max and max.Value or 0
end

--[[ ============================================================
	CHAT / NOTIFICATION FUNCTIONS
============================================================ ]]

local function notify(title, text, duration)
	pcall(function()
		game:GetService("StarterGui"):SetCore("SendNotification", {
			Title = title,
			Text = text,
			Duration = duration or 3,
		})
	end)
end

local function speak(text)
	pcall(function()
		local tcs = TextChatService
		if tcs and tcs.ChatInputBarConfiguration then
			local msg = Instance.new("TextChatMessage")
			msg.Text = text
			msg.MessageType = Enum.MessageType.System
			tcs:Display()
		end
	end)
	-- Fallback: use the legacy chat
	local chat = ReplicatedStorage:FindFirstChild("DefaultChatSystemChatEvents")
		and ReplicatedStorage.DefaultChatSystemChatEvents:FindFirstChild("SayMessageRequest")
	if chat then
		pcall(function() chat:FireServer(text, "All") end)
	end
end

--[[ ============================================================
	COMBAT FUNCTIONS
============================================================ ]]

local function fireAtChar(targetChar)
	local tool = getEquippedGun()
	if not tool then
		notify("Combat", "No gun equipped", 2)
		return false
	end
	local handle = tool:FindFirstChild("Handle")
	local muzzle = getMuzzlePos(tool)
	if not (handle and muzzle) then
		notify("Combat", "No muzzle found", 2)
		return false
	end
	local part = getHitPart(targetChar)
	if not part then return false end
	if hasForceField(targetChar) then return false end
	if not MainGameEvent then
		notify("Combat", "MainGameEvent nil", 3)
		return false
	end

	local shotTable = {}
	for i = 1, 12 do shotTable[i] = buildShotEntry(part) end

	local range = (tool:FindFirstChild("Range") and tool.Range.Value) or 500
	local damage = (tool:FindFirstChild("Damage") and tool.Damage.Value) or 20

	local ok = pcall(function()
		MainGameEvent:FireServer("ShootGun", handle, muzzle, shotTable, nil, nil, nil, range, damage)
	end)
	return ok
end

local function stompPlayer(player)
	if not player then return false end
	local char = player.Character
	if not (char and isKO(char)) then return false end
	if not MainGameEvent then return false end
	local ok = pcall(function()
		MainGameEvent:FireServer("Stomp", player)
	end)
	if ok then notify("Stomp", "Stomped " .. player.DisplayName, 2) end
	return ok
end

local function knockPlayer(targetPlayer)
	if not targetPlayer then
		notify("Combat", "No target specified", 2)
		return false
	end
	local char = targetPlayer.Character
	if not char then
		notify("Combat", "Target has no character", 2)
		return false
	end
	if not isAlive(char) then
		notify("Combat", "Target already down", 2)
		return false
	end
	if hasForceField(char) then
		notify("Combat", "Target has forcefield", 2)
		return false
	end
	local ok = fireAtChar(char)
	if ok then notify("Knock", "Knocked " .. targetPlayer.DisplayName, 2) end
	return ok
end

local function knockAndStomp(targetPlayer)
	if knockPlayer(targetPlayer) then
		task.wait(0.15)
		stompPlayer(targetPlayer)
		return true
	end
	return false
end

local function reloadWeapon()
	local tool = getEquippedGun()
	if not tool then return end
	pcall(function()
		MainGameEvent:FireServer("Reload", tool)
		isReloading = true
		lastReloadTime = tick()
		notify("Reload", "Reloading", 1.5)
	end)
end

--[[ ============================================================
	VOID LOGIC
============================================================ ]]

local voidAngle = 0
local voidActive = false
local voidRadius = 12500000
local voidConn = nil

local function startVoid()
	if voidConn then return end
	local char = LocalPlayer.Character
	if not char or not getRoot(char) then
		task.spawn(function()
			local ok, c = pcall(function() return LocalPlayer.CharacterAdded:Wait() end)
			if ok and c then startVoid() end
		end)
		return
	end
	voidActive = true
	voidAngle = 0
	voidConn = RunService.Stepped:Connect(function()
		local c = LocalPlayer.Character
		local root = getRoot(c)
		if not root then return end
		if not c.PrimaryPart then c.PrimaryPart = root end
		voidAngle = voidAngle + 2.5
		local theta = voidAngle
		local phi = math.acos(2 * ((voidAngle * 0.37) % 1) - 1)
		local x = voidRadius * math.sin(phi) * math.cos(theta)
		local y = voidRadius * math.cos(phi)
		local z = voidRadius * math.sin(phi) * math.sin(theta)
		pcall(function()
			root.CFrame = CFrame.new(x, y, z)
		end)
	end)
end

local function stopVoid()
	voidActive = false
	if voidConn then
		voidConn:Disconnect()
		voidConn = nil
	end
end

--[[ ============================================================
	TELEPORT / MOVEMENT FUNCTIONS
============================================================ ]]

local function teleportTo(position)
	local root = getRoot(LocalPlayer.Character)
	if root then
		root.CFrame = CFrame.new(position)
		root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
	end
end

local function teleportToPlayer(player, offset)
	local char = player.Character
	local root = getRoot(char)
	if root then
		teleportTo(root.Position + (offset or Vector3.new(0, 3, 4)))
	end
end

--[[ ============================================================
	AUTO BUY ARMOR
============================================================ ]]

local function getShop()
	return Workspace:FindFirstChild("Ignored")
		and Workspace.Ignored:FindFirstChild("Shop")
end

local function buyArmor()
	local char = LocalPlayer.Character
	local root = getRoot(char)
	if not root then return false end
	local shop = getShop()
	if not shop then return false end

	local candidates = {}
	for _, model in ipairs(shop:GetChildren()) do
		if model:IsA("Model") and model.Name:find("%[Full Armor%]") then
			local head = model:FindFirstChild("Head")
			local cd = model:FindFirstChildOfClass("ClickDetector")
			if head and cd then
				local nearby = 0
				for _, p in ipairs(Players:GetPlayers()) do
					if p ~= LocalPlayer then
						local pr = getRoot(p.Character)
						if pr and (pr.Position - head.Position).Magnitude < 30 then
							nearby = nearby + 1
						end
					end
				end
				candidates[#candidates + 1] = {
					model = model, head = head, cd = cd, nearby = nearby,
				}
			end
		end
	end
	if #candidates == 0 then return false end
	table.sort(candidates, function(a, b) return a.nearby < b.nearby end)
	local best = candidates[1]
	local origCF = root.CFrame
	local ok = pcall(function()
		root.CFrame = CFrame.new(best.head.Position) * CFrame.new(0, 3, 0)
		task.wait(0.2)
		fireclickdetector(best.cd)
		task.wait(0.3)
		root.CFrame = origCF
	end)
	if ok then
		notify("Armor", "Bought armor (" .. best.nearby .. " nearby)", 2)
	end
	return ok
end

--[[ ============================================================
	FLY LOGIC (rewrite - uses body velocity instead of platform stand)
============================================================ ]]

local flyConn = nil
local flyActive = false

local function startFly()
	if flyConn then return end
	flyActive = true
	local bodyV = Instance.new("BodyVelocity")
	bodyV.MaxForce = Vector3.new(1, 1, 1) * 9e9
	bodyV.Velocity = Vector3.new(0, 0, 0)
	bodyV.P = 5000

	flyConn = RunService.Heartbeat:Connect(function()
		local char = LocalPlayer.Character
		local root = getRoot(char)
		if not root then return end
		if not bodyV.Parent then bodyV.Parent = root end
		local speed = 100
		local moveDir = Vector3.new()
		if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveDir += Vector3.new(0, 0, -1) end
		if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveDir += Vector3.new(0, 0, 1) end
		if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveDir += Vector3.new(-1, 0, 0) end
		if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveDir += Vector3.new(1, 0, 0) end
		if UserInputService:IsKeyDown(Enum.KeyCode.Space) then moveDir += Vector3.new(0, 1, 0) end
		if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then moveDir += Vector3.new(0, -1, 0) end
		if moveDir.Magnitude > 0 then
			moveDir = root.CFrame:VectorToWorldSpace(moveDir.Unit * speed)
		end
		bodyV.Velocity = moveDir
	end)
end

local function stopFly()
	flyActive = false
	if flyConn then
		flyConn:Disconnect()
		flyConn = nil
	end
	local char = LocalPlayer.Character
	local root = getRoot(char)
	if root then
		for _, c in ipairs(root:GetChildren()) do
			if c:IsA("BodyVelocity") then c:Destroy() end
		end
	end
end

--[[ ============================================================
	EMOTE LOGIC (rewrite - fixed)
============================================================ ]]

local currentEmoteId = nil
local currentEmoteTrack = nil

local function stopEmote()
	if currentEmoteTrack then
		pcall(function() currentEmoteTrack:Stop() end)
		currentEmoteTrack = nil
	end
	currentEmoteId = nil
end

local function playEmote(animId)
	stopEmote()
	local char = LocalPlayer.Character
	if not char then return end
	local hum = getHumanoid(char)
	if not hum then return end
	if not LocalPlayer:HasAppearanceLoaded() then
		LocalPlayer.CharacterAppearanceLoaded:Wait()
	end
	local animator = hum:WaitForChild("Animator")
	local anim = Instance.new("Animation")
	anim.AnimationId = "rbxassetid://" .. tostring(animId)
	local ok, track = pcall(function()
		return animator:LoadAnimation(anim)
	end)
	if ok and track then
		currentEmoteId = animId
		currentEmoteTrack = track
		track.Priority = Enum.AnimationPriority.Action
		track.Looped = true
		task.wait(0.1)
		track:Play()
	end
end

LocalPlayer.CharacterAdded:Connect(function(char)
	if currentEmoteId then
		char:WaitForChild("Humanoid")
		char:WaitForChild("Animate")
		char:WaitForChild("HumanoidRootPart")
		if not LocalPlayer:HasAppearanceLoaded() then
			LocalPlayer.CharacterAppearanceLoaded:Wait()
		end
		task.wait(0.15)
		playEmote(currentEmoteId)
	end
end)

--[[ ============================================================
	CARRY / GRAB LOGIC (.b / .c)
	Knocks the target, stands on them, teleports to destination.
	The KO'd player's ragdoll body follows due to physics.
============================================================ ]]

local function executeCarry(targetPlayer, destination)
	if not targetPlayer then return end
	stopVoid()
	carryTarget = targetPlayer
	carryDestination = destination
	state = STATE.CARRYING
	speak("Carrying " .. targetPlayer.DisplayName .. " to destination")
	knockPlayer(targetPlayer)
end

--[[ ============================================================
	PROTECT MODE (.p)
	Attacks anyone who damages the protected target.
============================================================ ]]

local function setProtectMode(targetPlayer)
	protectTarget = targetPlayer
	state = STATE.PROTECTING
	speak("Protecting " .. (targetPlayer and targetPlayer.DisplayName or STAND_OWNER))
end

local function clearProtectMode()
	protectTarget = nil
	if state == STATE.PROTECTING then state = STATE.IDLE end
	speak("Protect mode off")
end

--[[ ============================================================
	SAFE MODE (.safe)
	When owner is KO'd, grab them and go to the safest armor shop.
============================================================ ]]

local function executeSafeMode()
	local owner = getPlayerByName(STAND_OWNER)
	if not owner then speak("Owner not found"); return end
	local char = owner.Character
	if not (char and isKO(char)) then speak("Owner is not KO'd"); return end
	local root = getRoot(char)
	if not root then return end

	-- Teleport to owner
	teleportTo(root.Position + Vector3.new(3, 0, 3))
	task.wait(0.3)

	-- Find armor shop with least people
	local shop = getShop()
	if not shop then speak("No shop found"); return end

	local candidates = {}
	for _, model in ipairs(shop:GetChildren()) do
		if model:IsA("Model") and model.Name:find("%[Full Armor%]") then
			local head = model:FindFirstChild("Head")
			local cd = model:FindFirstChildOfClass("ClickDetector")
			if head and cd then
				local nearby = 0
				for _, p in ipairs(Players:GetPlayers()) do
					if p ~= LocalPlayer then
						local pr = getRoot(p.Character)
						if pr and (pr.Position - head.Position).Magnitude < 30 then
							nearby = nearby + 1
						end
					end
				end
				candidates[#candidates + 1] = {
					model = model, head = head, cd = cd, nearby = nearby,
				}
			end
		end
	end
	if #candidates == 0 then speak("No armor found"); return end
	table.sort(candidates, function(a, b) return a.nearby < b.nearby end)
	local best = candidates[1]

	state = STATE.SAFE_MODE
	speak(string.format("Safe mode: going to armor (%d nearby)", best.nearby))
	teleportTo(best.head.Position + Vector3.new(0, 3, 0))
	task.wait(0.2)
	fireclickdetector(best.cd)
	state = STATE.IDLE
end

--[[ ============================================================
	DAMAGE TRACKER (who damaged who)
	Tracks health changes on all nearby players to detect who
	damaged the owner. Uses Humanoid.Health polling.
============================================================ ]]

local healthCache = {}

local function initDamageTracker()
	for _, p in ipairs(Players:GetPlayers()) do
		local hum = getHumanoid(p.Character)
		healthCache[p] = hum and hum.Health or 100
	end
	Players.PlayerAdded:Connect(function(p)
		p.CharacterAdded:Connect(function()
			task.wait(0.5)
			local hum = getHumanoid(p.Character)
			healthCache[p] = hum and hum.Health or 100
		end)
	end)
end

local function pollDamage()
	local owner = getPlayerByName(STAND_OWNER)
	if not owner then return end
	local ownerChar = owner.Character
	local ownerHum = getHumanoid(ownerChar)
	if not ownerHum then return end

	local curHealth = ownerHum.Health
	local prev = healthCache[owner] or curHealth
	if prev > curHealth and prev - curHealth >= damageThreshold then
		-- Someone damaged the owner — find who's nearby
		local ownerRoot = getRoot(ownerChar)
		if ownerRoot then
			for _, p in ipairs(Players:GetPlayers()) do
				if p == LocalPlayer or p == owner then continue end
				local pr = getRoot(p.Character)
				if pr and (pr.Position - ownerRoot.Position).Magnitude < 50 then
					damageLog[p] = tick()
				end
			end
		end
	end
	healthCache[owner] = curHealth
end

--[[ ============================================================
	COMMAND SYSTEM
============================================================ ]]

local function isAuthorized(speaker)
	if speaker.Name == STAND_OWNER then return true end
	if COMMAND_WHITELIST[speaker.Name] or COMMAND_WHITELIST[speaker.DisplayName] then
		return true
	end
	return false
end

-- Split a string into arguments
local function splitArgs(text)
	local args = {}
	for word in text:gmatch("%S+") do
		args[#args + 1] = word
	end
	return args
end

local function processCommand(speaker, text)
	if not isAuthorized(speaker) then return end
	local args = splitArgs(text)
	if #args == 0 then return end

	local cmd = args[1]:lower()
	local targetName = args[2]
	local target = targetName and getPlayerByName(targetName)

	-- .s {target} — kill and stomp once
	if cmd == ".s" then
		if not target then
			speak("Usage: .s {player}")
			return
		end
		stopVoid()
		speak("Killing " .. target.DisplayName)
		knockAndStomp(target)

	-- .k {target} — knock once (no stomp)
	elseif cmd == ".k" then
		if not target then
			speak("Usage: .k {player}")
			return
		end
		stopVoid()
		speak("Knocking " .. target.DisplayName)
		knockPlayer(target)

	-- .lk {target} — loop knock
	elseif cmd == ".lk" then
		if not target then
			speak("Usage: .lk {player}")
			return
		end
		stopVoid()
		loopTarget = target
		loopMode = "knock"
		state = STATE.LOOPING
		speak("Loop knocking " .. target.DisplayName)

	-- .ls {target} — loop kill with stomp
	elseif cmd == ".ls" then
		if not target then
			speak("Usage: .ls {player}")
			return
		end
		stopVoid()
		loopTarget = target
		loopMode = "stomp"
		state = STATE.LOOPING
		speak("Loop killing + stomping " .. target.DisplayName)

	-- .v — void
	elseif cmd == ".v" then
		state = STATE.VOID
		isVoiding = true
		startVoid()
		speak("Voiding")

	-- .b {target} — knock, grab, bring to owner
	elseif cmd == ".b" then
		if not target then
			speak("Usage: .b {player}")
			return
		end
		local owner = getPlayerByName(STAND_OWNER)
		if not owner then speak("Owner not found"); return end
		local ownerRoot = getRoot(owner.Character)
		if not ownerRoot then speak("Owner has no character"); return end
		executeCarry(target, ownerRoot.Position + Vector3.new(0, 0, 5))

	-- .c {target} — bring target to ground near command user
	elseif cmd == ".c" then
		if not target then
			speak("Usage: .c {player}")
			return
		end
		local userRoot = getRoot(speaker.Character)
		if not userRoot then speak("You have no character"); return end
		executeCarry(target, userRoot.Position + Vector3.new(0, 0, 5))

	-- .p {target} — protect mode
	elseif cmd == ".p" then
		stopVoid()
		setProtectMode(target or getPlayerByName(STAND_OWNER))

	-- .safe — safe mode (rescue KO'd owner)
	elseif cmd == ".safe" then
		stopVoid()
		executeSafeMode()

	-- .exit — kick the stand
	elseif cmd == ".exit" then
		speak("Shutting down")
		task.wait(0.5)
		local hum = getHumanoid(LocalPlayer.Character)
		if hum then hum.Health = 0 end

	-- .rj — rejoin server
	elseif cmd == ".rj" then
		speak("Rejoining")
		task.wait(0.5)
		pcall(function()
			local ts = game:GetService("TeleportService")
			ts:Teleport(game.PlaceId, LocalPlayer)
		end)

	-- .wl — whitelist management (owner only)
	elseif cmd == ".wl" and speaker.Name == STAND_OWNER then
		local sub = args[2] and args[2]:lower()
		local wlTarget = args[3] and getPlayerByName(args[3])
		if sub == "add" and wlTarget then
			COMMAND_WHITELIST[wlTarget.Name] = true
			speak("Whitelisted " .. wlTarget.DisplayName)
		elseif sub == "remove" and wlTarget then
			COMMAND_WHITELIST[wlTarget.Name] = nil
			speak("Unwhitelisted " .. wlTarget.DisplayName)
		elseif sub == "list" then
			local names = {}
			for name in pairs(COMMAND_WHITELIST) do names[#names + 1] = name end
			speak("Whitelist: " .. (#names > 0 and table.concat(names, ", ") or "(empty)"))
		else
			speak("Usage: .wl add/remove/list {player}")
		end

	-- .follow — follow the owner (5 behind, 2 above root)
	elseif cmd == ".follow" then
		state = STATE.FOLLOW
		stopVoid()
		notify("Follow", "Following " .. STAND_OWNER, 3)
		speak("Following " .. STAND_OWNER)

	elseif cmd == ".help" then
		speak(".s .k .lk .ls .v .b .c .p .follow .safe .wl .exit .rj")
	end
end

--[[ ============================================================
	CHAT LISTENER
	Uses the same de-duplication approach as main.lua's ChatSpy.
	Both Player.Chatted and TextChatService.MessageReceived fire
	for the same message, so we drop repeats within 300ms.
============================================================ ]]

local lastChat = nil

local function onPlayerChat(speaker, text)
	if not speaker or speaker.Name == LocalPlayer.Name then return end
	if not isAuthorized(speaker) then return end

	-- De-dupe
	local now = tick()
	if lastChat and lastChat.name == speaker.Name and lastChat.text == text and (now - lastChat.t) < 0.3 then
		return
	end
	lastChat = { name = speaker.Name, text = text, t = now }

	if text:sub(1, 1) == "." then
		processCommand(speaker, text)
	end
end

-- Legacy chat
for _, p in ipairs(Players:GetPlayers()) do
	p.Chatted:Connect(function(msg) onPlayerChat(p, msg) end)
end
Players.PlayerAdded:Connect(function(p)
	p.Chatted:Connect(function(msg) onPlayerChat(p, msg) end)
end)

-- Modern TextChatService
pcall(function()
	TextChatService.MessageReceived:Connect(function(msg)
		local source = msg.TextSource
		if not source then return end
		onPlayerChat(source, msg.Text)
	end)
end)

--[[ ============================================================
	WEAPON LOCK (auto-equip revolver, prevent unequip)
============================================================ ]]

local REVOLVER_NAME = "Revolver"

local function equipRevolver()
	local char = LocalPlayer.Character
	if not char then return end
	-- Already equipped
	if getEquippedGun() and getEquippedGun().Name == REVOLVER_NAME then return end
	-- Check backpack
	local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
	if bp then
		for _, item in ipairs(bp:GetChildren()) do
			if item:IsA("Tool") and item.Name == REVOLVER_NAME then
				item.Parent = char
				notify("Weapon", "Equipped " .. REVOLVER_NAME, 2)
				return
			end
		end
	end
	-- Check already in character but not detected by getEquippedGun
	for _, item in ipairs(char:GetChildren()) do
		if item:IsA("Tool") and item.Name == REVOLVER_NAME then
			return
		end
	end
end

local function isRevolverEquipped()
	local tool = getEquippedGun()
	return tool and tool.Name == REVOLVER_NAME
end

--[[ ============================================================
	MAIN LOOP
============================================================ ]]

local loopConn = RunService.Heartbeat:Connect(function()
	local char = LocalPlayer.Character
	local hum = getHumanoid(char)
	local alive = char and hum and hum.Health > 0

	if not alive then
		stopVoid()
		loopTarget = nil
		loopMode = nil
		state = STATE.IDLE
		return
	end

	local tool = getEquippedGun()
	local ammo = getAmmo(tool)
	local maxAmmo = getMaxAmmo(tool)
	local armor = getArmor(char)
	local now = tick()

	-- === AUTO EQUIP REVOLVER ===
	if not isRevolverEquipped() then
		equipRevolver()
	end

	-- === AUTO RELOAD (only when chamber empty) ===
	if tool and tool.Name == REVOLVER_NAME and ammo == 0 and maxAmmo > 0 and now - lastReloadTime > 1.5 then
		reloadWeapon()
	end

	-- Track reload state
	if isReloading and tool then
		if getAmmo(tool) > 0 then
			isReloading = false
		end
	end

	-- === AUTO VOID ===
	-- Void when: reloading, state is VOID, or IDLE with owner present
	local ownerPresent = getPlayerByName(STAND_OWNER) ~= nil
	local shouldVoid = isReloading or state == STATE.VOID or (state == STATE.IDLE and ownerPresent)
	if shouldVoid and not voidActive then
		startVoid()
	elseif not shouldVoid and voidActive and state ~= STATE.VOID then
		stopVoid()
	end

	-- === AUTO BUY ARMOR (when 30 or less, retry every heartbeat if needed) ===
	if armor <= 30 and now - lastActionTime > 2 then
		lastActionTime = now
		buyArmor()
	end

	-- === DAMAGE TRACKING ===
	pollDamage()

	-- === STATE-BASED BEHAVIOR ===

	-- LOOPING (.lk / .ls)
	if state == STATE.LOOPING and loopTarget then
		local tChar = loopTarget.Character
		if not tChar or not isAlive(tChar) then
			if loopMode == "stomp" then
				stompPlayer(loopTarget)
			end
		else
			if hasForceField(tChar) then
				-- skip this frame
			else
				fireAtChar(tChar)
			end
		end

	-- PROTECTING
	elseif state == STATE.PROTECTING and protectTarget then
		local recentDamager = nil
		local recentTime = 0
		for p, t in pairs(damageLog) do
			if t > recentTime and now - t < 5 then
				local pChar = p.Character
				if pChar and isAlive(pChar) and canTarget(p) and not hasForceField(pChar) then
					recentDamager = p
					recentTime = t
				end
			end
		end
		if recentDamager then
			fireAtChar(recentDamager.Character)
		end

	-- CARRYING (.b / .c)
	elseif state == STATE.CARRYING and carryTarget then
		local cChar = carryTarget.Character
		if cChar and isKO(cChar) then
			-- Stand on the KO'd player and move to destination
			local cRoot = getRoot(cChar)
			if cRoot then
				local myRoot = getRoot(char)
				if myRoot then
					teleportTo(cRoot.Position + Vector3.new(0, 3, 0))
					-- Gradually move toward destination
					local dir = (carryDestination - cRoot.Position)
					if dir.Magnitude > 10 then
						dir = dir.Unit * math.min(dir.Magnitude, 50)
						teleportTo(cRoot.Position + dir + Vector3.new(0, 3, 0))
					else
						-- Arrived
						teleportTo(carryDestination + Vector3.new(0, 0, 3))
						state = STATE.IDLE
						carryTarget = nil
						speak("Dropped target at destination")
					end
				end
			end
		elseif cChar and isAlive(cChar) then
			knockPlayer(carryTarget)
		else
			state = STATE.IDLE
			carryTarget = nil
		end

	-- FOLLOW — smoothly follow owner using BodyVelocity
	elseif state == STATE.FOLLOW then
		local owner = getPlayerByName(STAND_OWNER)
		if owner then
			local oChar = owner.Character
			local oRoot = oChar and getRoot(oChar)
			if oRoot then
				local myRoot = getRoot(char)
				if myRoot then
					local behind = oRoot.CFrame.LookVector * -5
					local targetPos = oRoot.Position + behind + Vector3.new(0, 2, 0)
					local dir = (targetPos - myRoot.Position)
					local dist = dir.Magnitude
					if dist > 3 then
						local bv = myRoot:FindFirstChildOfClass("BodyVelocity")
						if not bv then
							bv = Instance.new("BodyVelocity")
							bv.MaxForce = Vector3.new(1, 1, 1) * 9e9
							bv.P = 5000
							bv.Parent = myRoot
						end
						local speed = math.clamp(dist * 5, 15, 120)
						bv.Velocity = dir.Unit * speed
					else
						local bv = myRoot:FindFirstChildOfClass("BodyVelocity")
						if bv then bv:Destroy() end
						myRoot.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
					end
				end
			end
		end

	-- IDLE — default to void if reloading
	elseif state == STATE.IDLE then
		-- Nothing specific, void handles reloading
	end
end)

--[[ ============================================================
	INIT
============================================================ ]]

local __AX_OK, __AX_ERR = xpcall(function()

initDamageTracker()

if not MainGameEvent then
	speak("WARNING: MainGameEvent not found — combat disabled")
	notify(STAND_NAME .. " ERROR", "MainGameEvent not found", 8)
end

speak(STAND_NAME .. " online. Owner: " .. STAND_OWNER)

-- Auto-show chat (for legacy chat access)
local function ensureChatVisible()
	local pg = LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if not pg then return end
	local chat = pg:FindFirstChild("Chat")
	if chat and chat:IsA("Frame") then
		chat.Visible = true
	end
end
task.spawn(function()
	task.wait(2)
	ensureChatVisible()
end)

--[[ ============================================================
	CHARACTER RESET HANDLING
============================================================ ]]

LocalPlayer.CharacterAdded:Connect(function(char)
	stopVoid()
	char:WaitForChild("HumanoidRootPart")
	task.wait(0.3)
	equipRevolver()
end)

end, debug.traceback)

if __AX_OK then
	task.spawn(function()
		task.wait(0.5)
		notify(STAND_NAME, "Online. Owner: " .. STAND_OWNER, 5)
	end)
else
	getgenv().AxiomStandErr = __AX_ERR
	task.spawn(function()
		local errStr = tostring(__AX_ERR):sub(1, 200)
		pcall(setclipboard, errStr)
		local lp = LocalPlayer
		if lp and lp.Parent then
			lp:Kick("Axiom Stand Error (copied): " .. errStr)
		end
	end)
end
