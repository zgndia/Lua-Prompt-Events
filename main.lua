-- Game Services
local ProximityPromptService = game:GetService("ProximityPromptService")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

-- Remote Events
local remote = ReplicatedStorage:WaitForChild("ManagePrompt")
local localsound = ReplicatedStorage:WaitForChild("PlaySound")

-- SFX
local sound = SoundService:FindFirstChild("Coffee Pouring") or SoundService:WaitForChild("Coffee Pouring", 5)
local sound2 = SoundService:FindFirstChild("Milk Steaming") or SoundService:WaitForChild("Milk Steaming", 5)

-- Constants
local GLASS_OF_COFFEE_ID = 135433593829536
local EMPTY_PORTAFILTER_ID = 100506471402323
local FULL_PORTAFILTER_ID = 99077399115334

-- ModuleScripts
local management = require(ReplicatedStorage.CafeManagement)
local animate = require(ReplicatedStorage.Animate)
local ScriptUtils = require(ReplicatedStorage.ScriptUtils)
local ToolUtils = require(ReplicatedStorage.ToolUtils)
local GuiUtils = require(ReplicatedStorage.GuiUtils)

-- Per-player data table
local playerData = {}

-- Actions table where every Prompt Action is handled in
local ACTIONS = {}

local function handlePickRecipe(player, status)

	if not status or status.Value ~= "recipe-selection" then -- Don't start the next step unless a certain value is set
		warn("This isn't the current step for this player!")
		return
	end

	local recipeName = "Common" -- Example recipe type
	local duration = 3 -- The duration the text will display for

	if status then status.Value = "recipe-picked" end -- Change status value for the current coffee making status (The recipe is picked)

	GuiUtils.Text(player, "You've chosen the [" .. recipeName .. "] recipe!", duration, {76,0,153}) -- Uses GuiUtils module to display text on the screen

	task.wait(1)

	local portafilterPrompt = management.getPart(player, playerData, "Portafilter", "Union", "Attachment", "ProximityPrompt") -- Get portafilter proximity prompt object

	if not portafilterPrompt then -- Check if proximity prompt exists
		warn("portafilterPrompt doesn't exist!")
		return
	end

	portafilterPrompt.ActionText = "Take Portafilter" -- Rename it for the next step
	remote:FireClient(player, portafilterPrompt, true) -- Enable the proximity prompt for the client
end

local function handlePortafilterPickup(player, status, models, promptObject)

	if not status or status.Value ~= "recipe-picked" then -- Don't start the next step unless a certain value is set
		warn("This isn't the current step for this player!")
		return
	end

	if status then status.Value = "portafilter-picked-up" end -- Change status value for the current coffee making status (The portafilter is picked up)

	local tool = ToolUtils.Create(player, "PortafilterTool", EMPTY_PORTAFILTER_ID, models["empty_portafilter"]) -- Create tool for the player to act as the portafilter
	tool.Parent = player.Backpack -- Parent it to the player backpack

	ScriptUtils.cloneScript(ServerStorage ,"weldScript", tool) -- Clone the selected scripts and set their parent as the tool - Tells the game to how to weld the tool
	ScriptUtils.cloneScript(ServerStorage, "ToolPrompt", tool) -- Same as above - Tells the server to enable prompts when tool is equipped

	-- The original portafilter model is hidden while the tool is in use
	models["portafilter"].Transparency = 1
	models["portafilter"].CanCollide = false -- Refrain from colliding with anything while the model is invisible

	promptObject.ActionText = "Make Espresso" -- Change the prompt action text for the next step
end

local function handleCoffeeExtraction(player, status, models)
	-- Coffee extraction into the portafilter event

	if not status or status.Value ~= "portafilter-picked-up" then -- Don't start the next step unless a certain value is set
		warn("This isn't the current step for this player!")
		return
	end

	local char = player.Character -- Get player character because the tool is parented inside the character while the tool is equipped - This event only triggers while the tool is equipped
	local humanoid = char:FindFirstChildOfClass("Humanoid")
	local currentTool = char:FindFirstChild("PortafilterTool") -- Get the equipped tool object

	if not humanoid or not currentTool then -- Check if humanoid and currentTool exists
		warn("Either the humanoid or the equipped tool is nil.")
		return
	end

	local backpack = player:FindFirstChild("Backpack")

	-- Store current tool's Grip
	local gripPos = currentTool.Grip
	local gripForward = currentTool.GripForward
	local gripRight = currentTool.GripRight
	local gripUp = currentTool.GripUp

	-- Create a new tool with the filled portafilter handle
	local newTool = Instance.new("Tool")
	local handle = models["filled_portafilter"]:Clone() -- Clones the filled_portafilter as the handle

	-- Necessary properties for the tool to act as the way it is
	handle.Parent = newTool
	handle.Name = "Handle"
	handle.Anchored = false
	handle.CanCollide = true

	newTool.Name = "PortafilterTool"
	newTool.RequiresHandle = true
	newTool.CanBeDropped = false
	newTool.TextureId = "rbxassetid://" .. FULL_PORTAFILTER_ID

	-- Apply the old tool's Grip to the new one before equipping
	newTool.Grip = gripPos
	newTool.GripForward = gripForward
	newTool.GripRight = gripRight
	newTool.GripUp = gripUp

	newTool.Parent = backpack

	ScriptUtils.cloneScript(ServerStorage, "weldScript", newTool) -- Clone the selected scripts and set their parent as the tool - Tells the game to how to weld the tool

	currentTool:Destroy() -- Destroy the tool that was equipped before
	humanoid:EquipTool(newTool) -- Equip the new tool

	status.Value = "coffee-extracted" -- Change status value for the current coffee making status (The coffee is successfully extracted into the portafilter)

	local portafilterPrompt = management.getPart(player, playerData, "Portafilter", "Union", "Attachment", "ProximityPrompt") -- Get the required proximity prompt object for the next step

	if not portafilterPrompt then -- Check if the required proximity prompt exist
		warn("portafilterPrompt doesn't exist!")
		return
	end

	portafilterPrompt.ActionText = "Make Espresso"
	remote:FireClient(player, portafilterPrompt, true) -- Enable the proximity prompt for the client
end

local function handleEspressoMaking(player, status, models, data)
	-- Remove tool and make the portafilter model inside the cafe model visible to simulate brewing

	if not status or status.Value ~= "coffee-extracted" then -- Don't start the next step unless a certain value is set
		warn("This isn't the current step for this player!")
		return
	end

	ToolUtils.Remove(player, "PortafilterTool") -- Remove the equipped tool

	if status then status.Value = "pouring-espresso" end -- Change status value for the current coffee making status (The extracted coffee is being poured into a cup as the espresso)

	models["portafilter"].Transparency = 0 -- Set the transparency of the portafilter inside the cafe model to 0 for it to be visible
	models["portafilter"].CanCollide = true -- Return its collision back

	if not sound then -- Check if the required sound instance exists
		warn("'sound' doesn't exist!")
		return
	end

	local brewSound = sound:Clone()
	brewSound.Parent = models["portafilter"] -- Parent it into the workspace to simulate 3d sfx
	brewSound.Volume = 1
	brewSound.MaxDistance = 30
	brewSound:Play()

	local startCFrame = models["glass"].CFrame -- Save the start position of the glass into a variable

	-- Animate the glass to go under the espresso machine to simulate the espresso pouring into the glass
	animate.Model(startCFrame * CFrame.new(-0.154 * 50, 0, 0), 1.5, models["glass"])
	animate.Model(startCFrame * CFrame.new(-0.154 * 50, 0, -0.1 * 10), 0.36, models["glass"])

	task.wait(3.5)

	local espressoGlass = ServerStorage["Glass Forms"]:FindFirstChild("Glass of Espresso") -- Get the espresso poured glass model from the serverstorage

	if not espressoGlass then
		warn("espressoGlass doesn't exist!")
		return
	end

	data.clonedGlass = espressoGlass:Clone()
	data.clonedGlass:PivotTo(CFrame.new(models["glass"].Position)) -- Position it to the empty glass' position
	data.clonedGlass.Parent = models["cafeModel"] -- Parent it under player's cafe model

	models["glass"].Transparency = 1
	models["glass"].CanCollide = false -- Disable collision since the glass is invisible
	models["glass"].Position = data.glasspos -- Set the glass' position to where it was before it was moved

	if not brewSound then
		warn("brewSound doesn't exist!")
		return
	end

	-- Cleanup
	brewSound:Stop()
	brewSound:Destroy()
end

local function handleMilkSteaming(player, status, models, data)

	-- Add milk to the glass with espresso and get it ready to be served

	if not status or status.Value ~= "pouring-espresso" then -- Don't start the next step unless a certain value is set
		warn("This isn't the current step for this player!")
		return
	end

	if status then status.Value = "pouring-milk" end -- Change status value for the current coffee making status (Steamed milk pouring into the espresso cup to make coffee)

	local glass = data.clonedGlass -- Get the current glass instance set for the player (which is the glass with espresso in it for this function to be triggered)
	local primaryPart = glass.PrimaryPart -- Get primaryPart since every glass instance is a group model

	if not glass or not primaryPart then -- Check if the glass and the primaryPart of the glass exists
		warn("Either the glass model or the primaryPart of the glass model doesn't exist.")
		return
	end

	local startCFrame = primaryPart.CFrame -- Get the current CFrame of the primaryPart before moving it

	local isInverted = management.getCafeOrientation(player) -- Get cafe orientation for the player, some cafe's are rotated by 90 degrees so certain animations should be inverted
	local directionMultiplier = isInverted and -1 or 1 -- directionMultiplier is -1 if the cafe model is inverted, 1 if not

	-- Animate the model to go under the steaming machine to simulate steaming
	animate.Model(startCFrame * CFrame.new((0.0343 * 50) * directionMultiplier, 0, 0), 0.9, glass) -- Use directionMultiplier to prevent inverted animation issues
	animate.Model(startCFrame * CFrame.new((0.0343 * 50) * directionMultiplier, 0, (0.0495 * 10) * directionMultiplier), 0.36, glass) -- Use directionMultiplier to prevent inverted animation issues

	if not sound2 then -- Check if the second sound instance that will be used exists (steaming sound)
		warn("'sound2' doesn't exist.")
		return
	end

	-- Play steaming sound

	local steamSound = sound2:Clone()
	steamSound.Parent = glass:FindFirstChild("Glass") or glass -- Parent the sound to the glass model to simulate 3d sound effect
	steamSound.Volume = 1
	steamSound.MaxDistance = 30
	steamSound:Play()

	-- Wait for it to end before continuing
	steamSound.Ended:Wait()
	steamSound:Destroy()

	localsound:FireClient(player, "Ding", 1) -- Play the sound locally

	-- Clone the Glass with the coffee in it into the workspace after done steaming 

	local coffeeGlass = ServerStorage["Glass Forms"]:FindFirstChild("Glass of Coffee") -- Get the coffee glass model from serverstorage

	if not coffeeGlass then
		warn("coffeeGlass doesn't exist.")
		return
	end

	local currentPos = glass:GetPivot().Position
	glass:Destroy()
	data.clonedGlass = coffeeGlass:Clone()
	data.clonedGlass:PivotTo(CFrame.new(currentPos)) -- Uses the old glass pos for the new one
	data.clonedGlass.Parent = models["cafeModel"] -- Parents it to the player's cafe model
end

local function handleCoffeeServing(player, status, models, data)
	task.spawn(function()

		if not status or status.Value ~= "pouring-milk" then -- Don't start the next step unless a certain value is set
			warn("This isn't the current step for this player!")
			return
		end

		if status then status.Value = "serving-coffee" end -- Change status value for the current coffee making status (Coffee is ready to be served.)

		if data.clonedGlass then
			data.clonedGlass:Destroy() -- Destroy the coffee part inside the cafe model and add it as a tool to the player's backpack
			data.clonedGlass = nil -- Reset clonedGlass model for the player 
		end

		-- Make the empty (original) glass visible
		if models["glass"] then
			models["glass"].Transparency = 0.3
			models["glass"].CanCollide = true
		end

		-- Create coffee tool

		local coffeeModel = ServerStorage["Glass Forms"]:FindFirstChild("Glass of Coffee") -- Get the coffee model from serverstorage
		if not coffeeModel then
			warn("coffee model cannot be found")
			return
		end

		-- Some tool properties
		local tool = Instance.new("Tool")
		tool.Name = "Coffee"
		tool.CanBeDropped = false
		tool.RequiresHandle = true
		tool.TextureId = "rbxassetid://" .. GLASS_OF_COFFEE_ID

		-- Clone coffee model and make it a handle
		local modelClone = coffeeModel:Clone()
		local handle = modelClone:FindFirstChild("Handle")

		if not handle then
			tool:Destroy()
			warn("handle cannot be found")
			return
		end

		-- Some handle properties
		handle.Name = "Handle"
		handle.Anchored = false
		handle.CanCollide = false
		handle.Massless = true
		handle.Parent = tool

		handle:FindFirstChild("Attachment"):Destroy() -- Destroy the proximity prompt so it won't display the prompt when tool is equipped (the proximity prompt is parented under 'Attachment')

		for _, part in ipairs(modelClone:GetChildren()) do
			if part:IsA("BasePart") == false or part == handle then return end -- If the part isn't a BasePart or the part is the handle don't apply the codes below

			-- Apply the same properties for any other possible part that is parented to the cloned model
			part.Anchored = false
			part.CanCollide = false
			part.Massless = true
			part.Parent = tool

			local weld = Instance.new("WeldConstraint")
			weld.Part0 = handle
			weld.Part1 = part
			weld.Parent = handle
		end

		ScriptUtils.cloneScript(ServerStorage, "glassWeldScript", tool) -- Clones an already written weld script for the glass and parents it to the tool
		tool.Parent = player.Backpack -- Finally parents the tool into the players backpack

	end)
end

-- Add every function into the "ACTIONS" table
ACTIONS["Pick Recipe"] = handlePickRecipe
ACTIONS["Take Portafilter"] = handlePortafilterPickup
ACTIONS["Extract Coffee"] = handleCoffeeExtraction
ACTIONS["Make Espresso"] = handleEspressoMaking
ACTIONS["Add Milk"] = handleMilkSteaming
ACTIONS["Serve Coffee"] = handleCoffeeServing

-- Handles every proximity prompt trigger in the game
local function onPromptTriggered(promptObject, player)

	local status = player:FindFirstChild("CoffeeStatus") -- Get status instance for the functions inside the Actions table
	local data = playerData[player] -- Get player data for the functions inside the Actions table

	if not playerData[player] or not playerData[player].cafe then
		warn("Player has no cafe assigned: " .. player.Name)
		return -- Player needs to have a cafe assigned in order to trigger the prompts
	end

	local models = {
		empty_portafilter = ServerStorage.Portafilters:FindFirstChild("empty-portafilter"),
		filled_portafilter = ServerStorage.Portafilters:FindFirstChild("filled-portafilter"),
		portafilter = management.getPart(player, playerData, "Portafilter", "Union"), -- portafilter model inside the 
		glass = management.getPart(player, playerData, "Glass", "Union"),
		cafeModel = data.cafe -- The cafe model is already defined inside playerdata
	}

	if not management.checkOwnership(player, promptObject, playerData) then
		warn(`Security: {player.Name} tried to trigger foreign prompt`) -- Player tried to trigger someone else's prompt
		return
	end

	if not models["portafilter"] or not models["glass"] then -- check if cafe models exist
		warn("Missing cafe parts for: " .. player.Name)
		return
	end

	-- Initialize position cache
	data.glasspos = data.glasspos or models["glass"].Position

	-- Immediately disable prompt to prevent re-triggering
	remote:FireClient(player, promptObject, false) -- Disables prompt for the client

	local handler = ACTIONS[promptObject.ActionText] -- The action texts are set for every functions inside actions table

	if not handler then
		warn("Unknown action:", promptObject.ActionText)
		return
	end

	task.spawn(function() -- Task.spawn so that the functions won't have trouble when the onPromptTriggered function is triggered more than once at the same time
		handler(player, status, models, data, promptObject) -- Provide the variables required for each function
	end)
end

-- Player management
game.Players.PlayerAdded:Connect(function(player)

	local status = Instance.new("StringValue")
	status.Name = "CoffeeStatus"
	status.Value = "recipe-selection"
	status.Parent = player
	-- Wait for the player's character to load
	player.CharacterAdded:Connect(function(character)
		-- Give some time for everything to load
		task.wait(2)

		-- Get the cafe name from the player's MyCafe value
		local myCafeValue = player:WaitForChild("MyCafe") -- Wait up to 5 seconds
		if not myCafeValue then
			warn("MyCafe value not found for player: "..player.Name)
			return
		end

		local cafeName = tostring(myCafeValue.Value)
		if not cafeName or cafeName == "" then
			warn("Player "..player.Name.." has no cafe assigned in MyCafe value")
			return
		end

		-- Find the cafe model in workspace
		local cafe = workspace:FindFirstChild(cafeName)
		if not cafe then
			warn("Cafe model '"..cafeName.."' not found in workspace for "..player.Name)
			return
		end

		-- Assign playerData values for the player
		playerData[player] = {
			cafe = cafe,
			clonedGlass = nil,
			glasspos = nil
		}

		-- Disable all prompts in the cafe
		for _, descendant in ipairs(cafe:GetDescendants()) do
			if not descendant:IsA("ProximityPrompt") then return end
			remote:FireClient(player, descendant, false) -- Disables proximity prompt for the client
		end
		
		local model = playerData[player].cafe:FindFirstChild("Portafilter")
		local Portafilterprompt = model:FindFirstDescendant("ProximityPrompt")
		
		remote:FireClient(player, Portafilterprompt, true) -- Enable one of the prompts
		
	end)

	-- Handle cases where character loads before the MyCafe value is set
	player:WaitForChild("MyCafe").Changed:Connect(function()
		if player.Character then
			-- Re-run cafe assignment when MyCafe value changes
			player.CharacterAdded:Fire(player.Character)
		end
	end)
end)

game.Players.PlayerRemoving:Connect(function(player)
	if playerData[player] then
		if playerData[player].clonedGlass then -- If they left when there was a cloned glass, destroy it
			playerData[player].clonedGlass:Destroy()
		end
		playerData[player] = nil -- Reset each player's playerdata upon leaving
	end

	-- Clean up status values
	local status = player:FindFirstChild("CoffeeStatus")
	if status then status:Destroy() end
end)

-- Connect prompt handler
ProximityPromptService.PromptTriggered:Connect(onPromptTriggered)
