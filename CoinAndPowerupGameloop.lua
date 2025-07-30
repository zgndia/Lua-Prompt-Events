-- Services
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PowerupUpdateEvent = ReplicatedStorage:WaitForChild("PowerupUpdateEvent")

-- SFX

local function createSound(parent, sound_id, volume)
	local sound = Instance.new("Sound")

	sound.Parent = parent
	sound.SoundId = "rbxassetid://" .. sound_id
	sound.Volume = volume

	return sound
end

-- Local Variables
local baseJump = 7.2
local baseWalk = 16

local colors = {
	["Jump Strength"] = "Dark blue", -- Jump strength for 5 seconds
	["High Speed"] = "Dark red", -- High speed for 5 seconds
	["Forcefield"] = "Bright yellow" -- Forcefield for 5 seconds
}

local textColors = {
	["Jump Strength"] = Color3.new(0, 0.0509804, 1), -- Jump strength for 5 seconds
	["High Speed"] = Color3.new(1, 0, 0), -- High speed for 5 seconds
	["Forcefield"] = Color3.new(1, 1, 0) -- Forcefield for 5 seconds
}

local intValues = {
	["Jump Strength"] = "js", -- Jump strength for 5 seconds
	["High Speed"] = "hs", -- High speed for 5 seconds
	["Forcefield"] = "ff" -- Forcefield for 5 seconds
}

-- Display text function to let the player know what power up they've gotten
local function displayText(player, content, color)

	local PlayerGui = player:WaitForChild("PlayerGui")

	if PlayerGui:FindFirstChild("display function") then -- If this function is called and the text is still displayed, destroy it before displaying the new one
		PlayerGui["display function"]:Destroy()
	end

	local screengui = Instance.new("ScreenGui")

	screengui.Parent = PlayerGui -- Set the screengui's parent to the players own PlayerGui
	screengui.Name = "display function"

	local textlabel = Instance.new("TextLabel")

	textlabel.BackgroundTransparency = 1
	textlabel.TextScaled = true
	textlabel.Text = content
	textlabel.TextColor3 = color

	textlabel.Font = Enum.Font.Ubuntu

	-- Resize and position the text to be centered at the bottom of the screen

	textlabel.AnchorPoint = Vector2.new(0.5,0.5)
	textlabel.Position = UDim2.new(0.5, 0, 0.96, 0)
	textlabel.Size = UDim2.new(0, 1182, 0, 50)

	local UIStroke = Instance.new("UIStroke") -- UIStroke for the TextLabel

	UIStroke.Thickness = 2
	UIStroke.Parent = textlabel

	textlabel.Parent = screengui -- Parent it after everything is done

	local function fadeOut()
		local animation = TweenService:Create(textlabel, TweenInfo.new(1), {TextTransparency = 1})
		animation:Play()

		local animation2 = TweenService:Create(UIStroke, TweenInfo.new(1), {Transparency = 1})
		animation2:Play()

		animation.Completed:Wait()
		if not animation2.Completed then
			animation2.Completed:Wait()
		end

		screengui:Destroy()
	end

	task.delay(3, fadeOut)

end

-- Give a forcefield that makes you immune to damage
local function giveForceField(character, duration)
	-- Remove existing ForceField if present
	local existingForceField = character:FindFirstChildOfClass("ForceField")
	if existingForceField then
		return -- forcefield exists already, no need to create another one
	end

	-- Create new ForceField instance
	local forceField = Instance.new("ForceField")
	forceField.Parent = character

end

-- Spawn a hitbox part to see where the coins can spawn on
local function spawnHitbox()
	local hitbox = Instance.new("Part")
	hitbox.Name = "Hitbox"
	hitbox.Size = Vector3.new(100, 1, 100)
	hitbox.Position = Vector3.new(50, 4, 50)
	hitbox.Anchored = true
	hitbox.CanCollide = false
	hitbox.Transparency = 0.9
	hitbox.Parent = workspace
end

local function coinTouched(hit, coin)
	local rootPart = hit:GetRootPart()
	local plr = Players:GetPlayerFromCharacter(rootPart and rootPart.Parent)

	if not plr then return end

	-- Get players coin value
	local stats = plr:FindFirstChild("leaderstats")
	local coins = stats and stats:FindFirstChild("Coins")

	if coins then
		coins.Value += 1 -- Increment coin count
	end

	-- Create the coin sound effect
	local sound = createSound(SoundService, 607665037, 0.5)

	-- Play 3d collection sound
	if not sound then
		return
	end

	local clonedSound = sound:Clone()
	clonedSound.Parent = coin
	coin.Transparency = 1
	clonedSound:Play()

	-- Destroy the coin after the sound finishes
	clonedSound.Ended:Connect(function()
		coin:Destroy()
	end)

end

-- Function to spawn a rotating coin and grant the player 1 gold upon colliding within the part
local function spawnCoin()
	local touched = false -- Track if the coin has been collected

	-- Create the coin part
	local coin = Instance.new("Part")
	coin.Name = "Coin"
	coin.BrickColor = BrickColor.new("Cool yellow")
	coin.Material = Enum.Material.Neon
	coin.Size = Vector3.new(1, 1, 1)
	coin.Position = Vector3.new(math.random(0, 100), 4, math.random(0, 100))
	coin.Anchored = true
	coin.CanCollide = false
	coin.Parent = workspace

	-- Continuously rotate the coin
	local rotateTween = TweenService:Create(
		coin,
		TweenInfo.new(3, Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1), --loop infinitely
		{Orientation = Vector3.new(0, 180, 0)}
	)
	rotateTween:Play()

	-- When the coin is touched
	coin.Touched:Once(function(hit)
		coinTouched(hit, coin)
		touched = true
	end)

	-- Despawn the coin after 15 seconds if not collected
	if not touched then
		Debris:AddItem(coin, 15) -- Disappears after 15 seconds if no one touches the partc
	end

end

local effects = {}

local function jumpStrengthEffect(humanoid, powerup)
	humanoid.JumpHeight = 14.4 -- 2x Higher jump
	powerup.Value += 5
end

local function fastSpeedEffect(humanoid, powerup)
	humanoid.WalkSpeed = 32 -- 2x faster walk
	powerup.Value += 5
end

local function forcefieldEffect(humanoid, powerup, character)
	powerup.Value += 5
	giveForceField(character)

	-- Make character parts semi-transparent to show effect
	for _, part in ipairs(character:GetChildren()) do
		if not part:IsA("BasePart") or part.Name == "HumanoidRootPart" then continue end

		part.Transparency = 0.5
	end
end

effects["Jump Strength"] = jumpStrengthEffect
effects["High Speed"] = fastSpeedEffect
effects["Forcefield"] = forcefieldEffect

local function powerupTouched(hit, chosenPowerUp, PowerUp)

	local rootPart = hit:GetRootPart()
	local plr = Players:GetPlayerFromCharacter(rootPart and rootPart.Parent)
	local character = rootPart.Parent

	if not plr or not character then return end

	displayText(plr, "You got the " .. chosenPowerUp .. " Power Up!", textColors[chosenPowerUp])

	local powerup = plr:FindFirstChild("Powerups"):FindFirstChild(intValues[chosenPowerUp])

	PowerupUpdateEvent:FireClient(plr, "Add", chosenPowerUp, powerup)

	local sound = createSound(SoundService, 3406813517, 0.1)

	-- Play 3d power up sound
	if sound then
		local clonedSound = sound:Clone()
		clonedSound.Parent = PowerUp
		PowerUp.Transparency = 1
		clonedSound:Play()

		-- Destroy the power up after the sound finishes
		clonedSound.Ended:Connect(function()
			PowerUp:Destroy()
		end)
	else
		PowerUp:Destroy()
	end

	local humanoid = rootPart.Parent:FindFirstChild("Humanoid")

	if not humanoid then return end

	local handler = effects[chosenPowerUp]

	if not handler then
		warn("Unknown powerup: " .. chosenPowerUp)
		return
	end

	task.spawn(function()
		handler(humanoid, powerup, character)
	end)

end

-- Has a 1 in 3 chance to spawn a powerup that gives various effects to the player
local function spawnPowerUp()

	local touched = false

	local PowerUp = Instance.new("Part")
	PowerUp.Name = "PowerUp"

	local keys = {}
	for k in pairs(colors) do
		table.insert(keys, k)
	end

	-- Pick a random power up
	local chosenPowerUp = keys[math.random(1, #keys)]

	PowerUp.BrickColor = BrickColor.new(colors[chosenPowerUp])
	PowerUp.Material = Enum.Material.Neon
	PowerUp.Size = Vector3.new(1, 1, 1)
	PowerUp.Position = Vector3.new(math.random(0, 100), 4, math.random(0, 100))
	PowerUp.Anchored = true
	PowerUp.CanCollide = false
	PowerUp.Parent = workspace

	-- Continuously rotate the power up just like the coin
	local rotateTween = TweenService:Create(
		PowerUp,
		TweenInfo.new(3, Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1), --loop infinitely
		{Orientation = Vector3.new(0, 180, 0)}
	)
	rotateTween:Play()

	-- When the power up is touched
	PowerUp.Touched:Once(function(hit)
		powerupTouched(hit, chosenPowerUp, PowerUp)
		touched = true
	end)

	if not touched then
		game.Debris:AddItem(PowerUp, 30) -- Disappears after 30 seconds if no one touches the partc
	end
end

--Event, setup Leaderstats When Player Joins
Players.PlayerAdded:Connect(function(plr)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = plr

	local coin = Instance.new("IntValue")
	coin.Name = "Coins"
	coin.Value = 0
	coin.Parent = leaderstats

	local PowerUpDurations = Instance.new("Folder")
	PowerUpDurations.Name = "Powerups"
	PowerUpDurations.Parent = plr

	local js = Instance.new("IntValue") -- jump strength
	js.Name = "js"
	js.Parent = PowerUpDurations

	local hs = Instance.new("IntValue") -- high speed
	hs.Name = "hs"
	hs.Parent = PowerUpDurations

	local ff = Instance.new("IntValue") -- Forcefield
	ff.Name = "ff"
	ff.Parent = PowerUpDurations
end)

if RunService:IsStudio() then
	spawnHitbox() -- Spawn the coin collection area (Only available in studio mode)
end

-- Power-up and coin spawn loop

local function coinAndPowerupSpawnLoop()
	while true do
		task.wait(1)
		spawnCoin()

		if math.random(1, 2) ~= 1 then continue end
		spawnPowerUp()
	end
end

local function modifyEveryPlayersValue(powerups, humanoid, character)
	for _, val in ipairs(powerups:GetChildren()) do
		if not val:IsA("IntValue") or val.Value <= 0 then continue end

		val.Value = math.max(val.Value - 1, 0)

		if val.Value > 0 then
			-- Still active, no reset needed
			continue
		end

		-- Reset humanoid stats based on powerup name
		if val.Name == "js" then
			humanoid.JumpHeight = baseJump
			return
		elseif val.Name == "hs" then
			humanoid.WalkSpeed = baseWalk
		end

		if not character then continue end

		-- Remove ForceField if any
		local ff = character:FindFirstChildOfClass("ForceField")

		if not ff then return end

		ff:Destroy()

		-- Reset transparency for all parts except HumanoidRootPart
		for _, part in ipairs(character:GetChildren()) do
			if not part:IsA("BasePart") or part.Name == "HumanoidRootPart" then continue end
			part.Transparency = 0
		end
	end
end

local function effectManager()  -- Power-up duration reducer and effect manager loop
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local humanoid = character and character:FindFirstChildWhichIsA("Humanoid")
		local powerups = player:WaitForChild("Powerups")

		if not humanoid or not powerups then continue end

		task.spawn(function()
			modifyEveryPlayersValue(powerups, humanoid, character)
		end)
	end
end

task.spawn(coinAndPowerupSpawnLoop)

task.spawn(function()
	while true do
		task.wait(1)
		effectManager()
	end
end)
