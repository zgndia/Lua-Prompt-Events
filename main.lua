local ProximityPromptService = game:GetService("ProximityPromptService")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local remote = ReplicatedStorage:WaitForChild("ManagePrompt")
local localsound = ReplicatedStorage:WaitForChild("PlaySound")

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
local TOOL_SCRIPTS = {
	"weldScript", -- Weld script for the portafilter
	"ToolPrompt", -- Script that hides the prompt when the tool is unequipped, and shows when equipped
	"glassWeldScript" -- Weld script for the glass
}

-- Preload tool scripts
for _, scriptName in ipairs(TOOL_SCRIPTS) do
	if not ServerStorage:FindFirstChild(scriptName) then
		warn("Missing required script: " .. scriptName)
	end
end

-- Handles every proximity prompt trigger in the game
local function onPromptTriggered(promptObject, player)
	
	local status = player:FindFirstChild("CoffeeStatus")
	
	if not playerData[player] or not playerData[player].cafe then
		warn("Player has no cafe assigned: " .. player.Name)
		return -- Player needs to have a cafe assigned in order to trigger the prompts
	end

	if not management.checkOwnership(player, promptObject, playerData) then
		warn(`Security: {player.Name} tried to trigger foreign prompt`) -- Player tried to trigger someone else's prompt
		return
	end
	
	-- Get every required model for the coffee brewing process
	local empty_portafilter = ServerStorage.Portafilters:FindFirstChild("empty-portafilter")
	local filled_portafilter = ServerStorage.Portafilters:FindFirstChild("filled-portafilter")
	local data = playerData[player]
	local portafilter = management.getPart(player, playerData, "Portafilter", "Union")
	local glass = management.getPart(player, playerData, "Glass", "Union")

	if not portafilter then warn("Missing portafilter for "..player.Name) end -- No portafilter model found under the cafe model
	if not glass then warn("Missing glass for "..player.Name) end -- No glass model found under the cafe model

	if not portafilter or not glass then
		warn("Missing cafe parts for: " .. player.Name)
		return
	end

	-- Initialize position cache
	data.glasspos = data.glasspos or glass.Position

	-- Immediately disable prompt to prevent re-triggering
	remote:FireClient(player, promptObject, false)
	
	if promptObject.ActionText == "Pick Recipe" and status.Value ==  "recipe-selection" then
		
		local recipeName = "Common" -- Recipe type (only Common for now)
		local duration = 3 -- Text duration
		
		status.Value = "ready-to-brew"
		
		GuiUtils.Text(player, "You've chosen the [" .. recipeName .. "] recipe!", duration, {76,0,153})
		
		task.wait(1)
		
		-- Enable the same prompt and rename it
		local brewPrompt = management.getPart(player, playerData, "Portafilter", "Union", "Attachment", "ProximityPrompt")
		if brewPrompt then
			brewPrompt.ActionText = "Take Portafilter"
			remote:FireClient(player, brewPrompt, true)
		end

	elseif promptObject.ActionText == "Take Portafilter" and status.Value == "ready-to-brew" then
		remote:FireClient(player, promptObject, false)
		-- Create tool and update state
		local tool = ToolUtils.Create(player, "PortafilterTool", EMPTY_PORTAFILTER_ID, empty_portafilter)
		tool.Parent = player.Backpack
		
		ScriptUtils.cloneScript(ServerStorage ,"weldScript", tool)
		ScriptUtils.cloneScript(ServerStorage, "ToolPrompt", tool)
		
		-- The original portafilter model is hidden while the tool is in use
		portafilter.Transparency = 1
		portafilter.CanCollide = false
		
		-- Change the same prompts action text
		promptObject.ActionText = "Make Espresso"
		status.Value = "empty"
		
	elseif promptObject.ObjectText == "Coffee Extractor" and status.Value == "empty" then
		-- Coffee extraction into the portafilter event
		
		local char = player.Character
		local humanoid = char:FindFirstChildOfClass("Humanoid")
		local currentTool = char:FindFirstChild("PortafilterTool")
		
		local extractorPrompt = management.getPart(player, playerData, "Extractor", "Union", "Attachment", "ProximityPrompt")
		remote:FireClient(player, extractorPrompt, false)

		if humanoid and currentTool then
			local backpack = player:FindFirstChild("Backpack")

			-- Store current tool's position
			local gripPos = currentTool.Grip
			local gripForward = currentTool.GripForward
			local gripRight = currentTool.GripRight
			local gripUp = currentTool.GripUp

			-- Clone the tool with the extracted coffee
			local newTool = Instance.new("Tool")
			local handle = filled_portafilter:Clone()
			
			handle.Parent = newTool
			handle.Name = "Handle"
			handle.Anchored = false
			handle.CanCollide = true
			
			newTool.Name = "PortafilterTool"
			newTool.RequiresHandle = true
			newTool.CanBeDropped = false
			newTool.TextureId = "rbxassetid://" .. FULL_PORTAFILTER_ID
			newTool.Grip = gripPos
			newTool.GripForward = gripForward
			newTool.GripRight = gripRight
			newTool.GripUp = gripUp

			-- Parent it first
			newTool.Parent = backpack
			
			ScriptUtils.cloneScript(ServerStorage, "weldScript", newTool)

			-- Remove old one and equip new
			currentTool:Destroy()
			humanoid:EquipTool(newTool)
		end
		
		local tool = char:FindFirstChild("PortafilterTool") or player.Backpack:FindFirstChild("PortafilterTool")
		if status and status.Value == "empty" and tool then
			tool.TextureId = "rbxassetid://" .. FULL_PORTAFILTER_ID -- Change tool icon
			status.Value = "filled" -- Change coffee state
			
			-- Enable the required prompt for the next step
			local espressoPrompt = management.getPart(player, playerData, "Portafilter", "Union", "Attachment", "ProximityPrompt")
			if espressoPrompt then
				espressoPrompt.ActionText = "Make Espresso"
				remote:FireClient(player, espressoPrompt, true)
			end
		end
	
	elseif promptObject.ActionText == "Make Espresso" and status.Value == "filled" then
		-- Remove tool and make the portafilter model inside the cafe model visible to simulate brewing
		remote:FireClient(player, promptObject, false)
		task.spawn(function()
			ToolUtils.Remove(player, "PortafilterTool")

			local playerCafe = game.Players:FindFirstChild(player.Name).MyCafe.Value
			status.Value = "brewing"

			portafilter.Transparency = 0
			portafilter.CanCollide = true

			-- Play brewing sound
			local brewSound
			if sound then
				brewSound = sound:Clone() -- Clone the sound and parent it into the workspace to simulate 3d sfx
				brewSound.Parent = portafilter
				brewSound.Volume = 1
				brewSound.MaxDistance = 30
				brewSound:Play()
			end

			local startCFrame = glass.CFrame
			
			-- Animate the glass to go under the espresso machine to simulate the espresso pouring into the glass
			animate.Model(startCFrame * CFrame.new(-0.154 * 50, 0, 0), 1.5, glass)
			animate.Model(startCFrame * CFrame.new(-0.154 * 50, 0, -0.1 * 10), 0.36, glass)

			task.wait(3.5)

			-- Disable glass prompt
			local glassPrompt = glass:FindFirstChild("Attachment") and glass.Attachment:FindFirstChild("ProximityPrompt")
			if glassPrompt then
				remote:FireClient(player, glassPrompt, false)
			end

			-- Create espresso glass
			local espressoGlass = ServerStorage["Glass Forms"]:FindFirstChild("Glass of Espresso")
			if espressoGlass then
				data.clonedGlass = espressoGlass:Clone()
				data.clonedGlass:PivotTo(CFrame.new(glass.Position))
				data.clonedGlass.Parent = game.workspace:FindFirstChild(tostring(playerCafe))
			end

			-- Hide empty glass and set its position to where it was before it was moved
			glass.Transparency = 1
			glass.CanCollide = false
			glass.Position = data.glasspos

			-- Cleanup
			if brewSound then
				brewSound:Stop()
				brewSound:Destroy()
			end
		end)

	elseif promptObject.ActionText == "Add Milk"  and status.Value == "brewing" then
		-- Add milk to the glass with espresso and get it ready to be served
		task.spawn(function()
			local playerCafe = game.Players:FindFirstChild(player.Name).MyCafe.Value -- Get player's string value 
			if status then status.Value = "adding-milk" end -- Change coffee status

			local glass = data.clonedGlass
			local primaryPart = glass.PrimaryPart
			if not glass then return end
			if not primaryPart then return end

			local startCFrame = primaryPart.CFrame
			
			local isInverted = management.getCafeOrientation(player)
			local directionMultiplier = isInverted and -1 or 1
			
			-- Animate the model to go under the steaming machine to simulate steaming
			animate.Model(startCFrame * CFrame.new((0.0343 * 50) * directionMultiplier, 0, 0), 0.9, glass)
			animate.Model(startCFrame * CFrame.new((0.0343 * 50) * directionMultiplier, 0, (0.0495 * 10) * directionMultiplier), 0.36, glass)

			-- Play steaming sound
			local steamSound
			if sound2 then
				steamSound = sound2:Clone()
				steamSound.Parent = glass:FindFirstChild("Glass") or glass
				steamSound.Volume = 1
				steamSound.MaxDistance = 30
				steamSound:Play()

				-- Wait for it to end before continuing
				steamSound.Ended:Wait()
				steamSound:Destroy()
			end

			localsound:FireClient(player, "Ding", 1) -- Play the sound locally

			-- Replace with coffee glass
			local coffeeGlass = ServerStorage["Glass Forms"]:FindFirstChild("Glass of Coffee")
			if coffeeGlass then
				local currentPos = glass:GetPivot().Position
				glass:Destroy()
				data.clonedGlass = coffeeGlass:Clone()
				data.clonedGlass:PivotTo(CFrame.new(currentPos))
				data.clonedGlass.Parent = game.workspace:FindFirstChild(tostring(playerCafe))
			end
		end)

	elseif promptObject.ActionText == "Serve Coffee" and status.Value == "adding-milk" then
		-- Serve the coffee
		task.spawn(function()
			if status then status.Value = "serving" end

			if data.clonedGlass then
				data.clonedGlass:Destroy() -- Destroy the coffee part to add the tool to the player's backpack
				data.clonedGlass = nil
			end
			
			-- Make the empty (original) glass visible
			local glass = management.getPart(player, playerData, "Glass", "Union")
			if glass then
				glass.Transparency = 0.3
				glass.CanCollide = true
			end

			-- Create coffee tool
			local coffeeModel = ServerStorage["Glass Forms"]:FindFirstChild("Glass of Coffee")
			if coffeeModel then
				local tool = Instance.new("Tool")
				tool.Name = "Coffee"
				tool.CanBeDropped = false
				tool.RequiresHandle = true
				tool.TextureId = "rbxassetid://" .. GLASS_OF_COFFEE_ID

				local modelClone = coffeeModel:Clone()
				local handle = modelClone:FindFirstChild("Handle")
				if handle then
					handle.Name = "Handle"
					handle.Anchored = false
					handle.CanCollide = false
					handle.Massless = true
					handle.Parent = tool

					handle.Attachment:Destroy()

					for _, part in ipairs(modelClone:GetChildren()) do
						if part:IsA("BasePart") and part ~= handle then
							part.Anchored = false
							part.CanCollide = false
							part.Massless = true
							part.Parent = tool

							local weld = Instance.new("WeldConstraint")
							weld.Part0 = handle
							weld.Part1 = part
							weld.Parent = handle
						end
					end

					ScriptUtils.cloneScript(ServerStorage, "glassWeldScript", tool)
					tool.Parent = player.Backpack
				else
					tool:Destroy()
				end
			end
		end)
	end
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

		-- Assign the cafe to the player
		playerData[player] = {
			cafe = cafe,
			clonedGlass = nil,
			glasspos = nil
		}

		-- Enable all prompts in the cafe
		for _, descendant in ipairs(cafe:GetDescendants()) do
			if descendant:IsA("ProximityPrompt") and descendant.Parent.Parent.Parent.Name ~= "Glass" and descendant.Parent.Parent.Parent.Name ~= "Extractor" then
				remote:FireClient(player, descendant, true)
			end
		end
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
		if playerData[player].clonedGlass then
			playerData[player].clonedGlass:Destroy()
		end
		playerData[player] = nil
	end

	-- Clean up status values
	local status = player:FindFirstChild("CoffeeStatus")
	if status then status:Destroy() end
end)

-- Connect prompt handler
ProximityPromptService.PromptTriggered:Connect(onPromptTriggered)
