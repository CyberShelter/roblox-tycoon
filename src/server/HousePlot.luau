local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local HousePlot = {}

local DISTANCE_FROM_SPAWN = 24
local BUBBLE_SIZE = 6
local HOUSE_WIDTH = 24
local HOUSE_DEPTH = 20
local WALL_HEIGHT = 12
local WALL_THICKNESS = 1
local DOOR_WIDTH = 6
local DOOR_HEIGHT = 9
local FLOOR_THICKNESS = 0.5

local function findSpawn()
	for _, instance in workspace:GetDescendants() do
		if instance:IsA("SpawnLocation") and instance.Enabled then
			return instance
		end
	end

	local baseplate = workspace:FindFirstChild("Baseplate")
	local position = Vector3.new(0, 0.5, 0)
	if baseplate and baseplate:IsA("BasePart") then
		position = baseplate.Position + Vector3.new(0, baseplate.Size.Y / 2 + 0.5, 0)
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "SpawnLocation"
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.Position = position
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = workspace
	return spawn
end

local function getPlotCFrame(spawn)
	local forward = Vector3.new(spawn.CFrame.LookVector.X, 0, spawn.CFrame.LookVector.Z)
	if forward.Magnitude < 0.01 then
		forward = Vector3.new(0, 0, -1)
	end
	forward = forward.Unit
	local position = spawn.Position + forward * DISTANCE_FROM_SPAWN

	local parameters = RaycastParams.new()
	parameters.FilterType = Enum.RaycastFilterType.Exclude
	parameters.FilterDescendantsInstances = { spawn }
	local ground = workspace:Raycast(position + Vector3.new(0, 32, 0), Vector3.new(0, -128, 0), parameters)
	local groundY = spawn.Position.Y - spawn.Size.Y / 2
	if ground then
		groundY = ground.Position.Y
	end

	position = Vector3.new(position.X, groundY, position.Z)
	return CFrame.lookAt(position, position + forward)
end

local function buildHouse(plotCFrame, player)
	local house = Instance.new("Model")
	house.Name = "EmptyHouse"
	house:SetAttribute("BuiltByUserId", player.UserId)

	local function addPart(name, size, position, color, material)
		local part = Instance.new("Part")
		part.Name = name
		part.Size = size
		part.CFrame = plotCFrame * CFrame.new(position)
		part.Color = color
		part.Material = material
		part.Anchored = true
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.Parent = house
		return part
	end

	local wallColor = Color3.fromRGB(235, 239, 242)
	local wallY = FLOOR_THICKNESS + WALL_HEIGHT / 2
	local frontZ = HOUSE_DEPTH / 2 - WALL_THICKNESS / 2
	local sideWidth = (HOUSE_WIDTH - DOOR_WIDTH) / 2
	local sideX = DOOR_WIDTH / 2 + sideWidth / 2

	house.PrimaryPart = addPart("Floor", Vector3.new(HOUSE_WIDTH, FLOOR_THICKNESS, HOUSE_DEPTH),
		Vector3.new(0, FLOOR_THICKNESS / 2, 0), Color3.fromRGB(125, 132, 140), Enum.Material.Concrete)
	addPart("BackWall", Vector3.new(HOUSE_WIDTH, WALL_HEIGHT, WALL_THICKNESS),
		Vector3.new(0, wallY, -frontZ), wallColor, Enum.Material.Brick)
	addPart("LeftWall", Vector3.new(WALL_THICKNESS, WALL_HEIGHT, HOUSE_DEPTH - WALL_THICKNESS * 2),
		Vector3.new(-HOUSE_WIDTH / 2 + WALL_THICKNESS / 2, wallY, 0), wallColor, Enum.Material.Brick)
	addPart("RightWall", Vector3.new(WALL_THICKNESS, WALL_HEIGHT, HOUSE_DEPTH - WALL_THICKNESS * 2),
		Vector3.new(HOUSE_WIDTH / 2 - WALL_THICKNESS / 2, wallY, 0), wallColor, Enum.Material.Brick)
	addPart("FrontLeftWall", Vector3.new(sideWidth, WALL_HEIGHT, WALL_THICKNESS),
		Vector3.new(-sideX, wallY, frontZ), wallColor, Enum.Material.Brick)
	addPart("FrontRightWall", Vector3.new(sideWidth, WALL_HEIGHT, WALL_THICKNESS),
		Vector3.new(sideX, wallY, frontZ), wallColor, Enum.Material.Brick)
	addPart("DoorHeader", Vector3.new(DOOR_WIDTH, WALL_HEIGHT - DOOR_HEIGHT, WALL_THICKNESS),
		Vector3.new(0, FLOOR_THICKNESS + DOOR_HEIGHT + (WALL_HEIGHT - DOOR_HEIGHT) / 2, frontZ),
		wallColor, Enum.Material.Brick)
	addPart("Roof", Vector3.new(HOUSE_WIDTH + 2, 1, HOUSE_DEPTH + 2),
		Vector3.new(0, FLOOR_THICKNESS + WALL_HEIGHT + 0.5, 0), Color3.fromRGB(54, 72, 65), Enum.Material.Slate)

	house.Parent = workspace
end

function HousePlot.start()
	if workspace:FindFirstChild("HouseBuildBubble") or workspace:FindFirstChild("EmptyHouse") then
		return
	end

	local plotCFrame = getPlotCFrame(findSpawn())
	local bubble = Instance.new("Part")
	bubble.Name = "HouseBuildBubble"
	bubble.Shape = Enum.PartType.Ball
	bubble.Size = Vector3.new(BUBBLE_SIZE, BUBBLE_SIZE, BUBBLE_SIZE)
	bubble.CFrame = plotCFrame * CFrame.new(0, BUBBLE_SIZE / 2 + 0.5, 0)
	bubble.Color = Color3.fromRGB(76, 221, 235)
	bubble.Material = Enum.Material.Neon
	bubble.Transparency = 0.4
	bubble.Anchored = true
	bubble.CanCollide = false
	bubble.CanTouch = true
	bubble.CanQuery = false

	local label = Instance.new("BillboardGui")
	label.Name = "BuildLabel"
	label.Size = UDim2.fromOffset(180, 40)
	label.StudsOffset = Vector3.new(0, 5, 0)
	label.AlwaysOnTop = true
	label.MaxDistance = 80
	label.Parent = bubble

	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Text = "Build house"
	text.TextColor3 = Color3.new(1, 1, 1)
	text.TextStrokeTransparency = 0.3
	text.Font = Enum.Font.GothamBold
	text.TextSize = 24
	text.Parent = label

	local pulse = TweenService:Create(bubble, TweenInfo.new(1, Enum.EasingStyle.Sine,
		Enum.EasingDirection.InOut, -1, true), { Transparency = 0.65 })
	local built = false
	bubble.Touched:Connect(function(hit)
		if built then
			return
		end

		-- Walk through ancestors so accessory handles also resolve to the player.
		local character = hit.Parent
		local player
		while character and character ~= workspace do
			if character:IsA("Model") then
				player = Players:GetPlayerFromCharacter(character)
				if player then
					break
				end
			end
			character = character.Parent
		end
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not player or not humanoid or humanoid.Health <= 0 then
			return
		end

		-- Lock before building so simultaneous touches cannot create extra houses.
		built = true
		buildHouse(plotCFrame, player)
		pulse:Cancel()
		bubble:Destroy()
	end)

	bubble.Parent = workspace
	pulse:Play()
end

return HousePlot
