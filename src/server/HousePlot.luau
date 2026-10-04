local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")

local HousePlot = {}

local DISTANCE_FROM_SPAWN = 36
local BUBBLE_SIZE = 8
local HOUSE_WIDTH = 48
local HOUSE_DEPTH = 40
local WALL_HEIGHT = 18
local WALL_THICKNESS = 0.4
local DOOR_WIDTH = 10
local DOOR_HEIGHT = 12
local FLOOR_THICKNESS = 0.75
local FRAME_WIDTH = 0.35

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

	local frameColor = Color3.fromRGB(42, 49, 54)
	local wallY = FLOOR_THICKNESS + WALL_HEIGHT / 2
	local frontZ = HOUSE_DEPTH / 2 - WALL_THICKNESS / 2
	local sideWidth = (HOUSE_WIDTH - DOOR_WIDTH) / 2
	local sideX = DOOR_WIDTH / 2 + sideWidth / 2

	local function addGlass(name, size, position, outward)
		local glass = addPart(name, size, position, Color3.fromRGB(178, 231, 237), Enum.Material.Glass)
		glass.Transparency = 0.78
		glass.Reflectance = 0.08
		glass.CastShadow = false

		local shellSize
		if outward.X ~= 0 then
			shellSize = Vector3.new(0.04, size.Y, size.Z)
		elseif outward.Y ~= 0 then
			shellSize = Vector3.new(size.X, 0.04, size.Z)
		else
			shellSize = Vector3.new(size.X, size.Y, 0.04)
		end
		local shell = addPart(name .. "Exterior", shellSize,
			position + outward * (WALL_THICKNESS / 2 + 0.025),
			Color3.fromRGB(145, 180, 193), Enum.Material.SmoothPlastic)
		shell.Reflectance = 0.55
		shell.CanCollide = false
		shell.CanTouch = false
		shell.CanQuery = false
		shell.CastShadow = false
		-- The client hides this reflective layer when viewing the inside of a pane.
		shell:SetAttribute("OutwardNormal", plotCFrame:VectorToWorldSpace(outward))
		CollectionService:AddTag(shell, "PrivacyGlassExterior")
	end

	local function addWall(name, center, length, bays, alongX, outward)
		local bayWidth = length / bays
		for index = 1, bays do
			local offset = -length / 2 + (index - 0.5) * bayWidth
			local position = center + (alongX and Vector3.new(offset, 0, 0) or Vector3.new(0, 0, offset))
			local size = alongX and Vector3.new(bayWidth, WALL_HEIGHT, WALL_THICKNESS)
				or Vector3.new(WALL_THICKNESS, WALL_HEIGHT, bayWidth)
			addGlass(name .. "Pane" .. index, size, position, outward)
		end
		for index = 0, bays do
			local offset = -length / 2 + index * bayWidth
			local position = center + (alongX and Vector3.new(offset, 0, 0) or Vector3.new(0, 0, offset))
			addPart(name .. "Post" .. index, Vector3.new(FRAME_WIDTH, WALL_HEIGHT, FRAME_WIDTH),
				position, frameColor, Enum.Material.Metal)
		end
		for _, height in { FLOOR_THICKNESS + FRAME_WIDTH / 2, FLOOR_THICKNESS + WALL_HEIGHT } do
			local position = Vector3.new(center.X, height, center.Z)
			local size = alongX and Vector3.new(length, FRAME_WIDTH, FRAME_WIDTH)
				or Vector3.new(FRAME_WIDTH, FRAME_WIDTH, length)
			addPart(name .. "Rail", size, position, frameColor, Enum.Material.Metal)
		end
	end

	house.PrimaryPart = addPart("Floor", Vector3.new(HOUSE_WIDTH, FLOOR_THICKNESS, HOUSE_DEPTH),
		Vector3.new(0, FLOOR_THICKNESS / 2, 0), Color3.fromRGB(225, 228, 230), Enum.Material.Marble)
	addWall("Back", Vector3.new(0, wallY, -frontZ), HOUSE_WIDTH, 6, true, Vector3.new(0, 0, -1))
	addWall("Left", Vector3.new(-HOUSE_WIDTH / 2 + WALL_THICKNESS / 2, wallY, 0),
		HOUSE_DEPTH - WALL_THICKNESS * 2, 5, false, Vector3.new(-1, 0, 0))
	addWall("Right", Vector3.new(HOUSE_WIDTH / 2 - WALL_THICKNESS / 2, wallY, 0),
		HOUSE_DEPTH - WALL_THICKNESS * 2, 5, false, Vector3.new(1, 0, 0))
	addWall("FrontLeft", Vector3.new(-sideX, wallY, frontZ), sideWidth, 3, true, Vector3.new(0, 0, 1))
	addWall("FrontRight", Vector3.new(sideX, wallY, frontZ), sideWidth, 3, true, Vector3.new(0, 0, 1))
	addGlass("DoorHeader", Vector3.new(DOOR_WIDTH, WALL_HEIGHT - DOOR_HEIGHT, WALL_THICKNESS),
		Vector3.new(0, FLOOR_THICKNESS + DOOR_HEIGHT + (WALL_HEIGHT - DOOR_HEIGHT) / 2, frontZ),
		Vector3.new(0, 0, 1))
	addPart("DoorLintel", Vector3.new(DOOR_WIDTH, FRAME_WIDTH, FRAME_WIDTH),
		Vector3.new(0, FLOOR_THICKNESS + DOOR_HEIGHT, frontZ), frameColor, Enum.Material.Metal)
	addPart("FrontTopRail", Vector3.new(HOUSE_WIDTH, FRAME_WIDTH, FRAME_WIDTH),
		Vector3.new(0, FLOOR_THICKNESS + WALL_HEIGHT, frontZ), frameColor, Enum.Material.Metal)
	local roofY = FLOOR_THICKNESS + WALL_HEIGHT + WALL_THICKNESS / 2
	for index = 1, 6 do
		local x = -HOUSE_WIDTH / 2 + (index - 0.5) * HOUSE_WIDTH / 6
		addGlass("RoofPane" .. index, Vector3.new(HOUSE_WIDTH / 6, WALL_THICKNESS, HOUSE_DEPTH),
			Vector3.new(x, roofY, 0), Vector3.new(0, 1, 0))
	end
	for index = 0, 6 do
		local x = -HOUSE_WIDTH / 2 + index * HOUSE_WIDTH / 6
		addPart("RoofBeam" .. index, Vector3.new(FRAME_WIDTH, WALL_THICKNESS + 0.1, HOUSE_DEPTH),
			Vector3.new(x, roofY, 0), frameColor, Enum.Material.Metal)
	end

	house.Parent = workspace
end

local function decorateBubble(bubble)
	local function decoration(name, size, frame, color, material)
		local part = Instance.new("Part")
		part.Name = name
		part.Size = size
		part.CFrame = frame
		part.Color = color
		part.Material = material
		part.Anchored = true
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.CastShadow = false
		part.Parent = bubble
		return part
	end

	local core = decoration("GlowingCore", Vector3.new(2.5, 2.5, 2.5), bubble.CFrame,
		Color3.fromRGB(110, 255, 226), Enum.Material.Neon)
	core.Shape = Enum.PartType.Ball
	core.Transparency = 0.15
	local light = Instance.new("PointLight")
	light.Color = core.Color
	light.Brightness = 2
	light.Range = 20
	light.Parent = core

	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Name = "Sparkles"
	sparkles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparkles.Color = ColorSequence.new(Color3.fromRGB(121, 255, 233), Color3.fromRGB(255, 205, 104))
	sparkles.LightEmission = 1
	sparkles.Rate = 12
	sparkles.Lifetime = NumberRange.new(1.2, 2)
	sparkles.Speed = NumberRange.new(1, 3)
	sparkles.SpreadAngle = Vector2.new(180, 180)
	sparkles.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.25, 0.25), NumberSequenceKeypoint.new(1, 0) })
	sparkles.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(1, 1) })
	sparkles.Parent = bubble

	for index = 1, 2 do
		local orbit = Instance.new("Model")
		orbit.Name = "Orbit" .. index
		local pivot = bubble.CFrame * CFrame.Angles(math.rad(30 + index * 25), 0, math.rad(index * 30))
		local anchor = decoration("OrbitPivot", Vector3.new(0.1, 0.1, 0.1),
			pivot, Color3.new(1, 1, 1), Enum.Material.SmoothPlastic)
		anchor.Transparency = 1
		anchor.Parent = orbit
		orbit.PrimaryPart = anchor
		orbit:SetAttribute("AngularSpeed", index == 1 and 0.7 or -0.5)
		local radius = BUBBLE_SIZE / 2 + index * 0.75
		for segment = 1, 32 do
			local angle = (segment - 1) * math.pi * 2 / 32
			local nextAngle = segment * math.pi * 2 / 32
			local first = Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
			local last = Vector3.new(math.cos(nextAngle) * radius, 0, math.sin(nextAngle) * radius)
			local color = segment <= 4 and Color3.fromRGB(255, 205, 104) or Color3.fromRGB(98, 218, 245)
			local arc = decoration("Arc", Vector3.new(0.12, 0.12, (last - first).Magnitude + 0.04),
				pivot * CFrame.lookAt((first + last) / 2, last), color, Enum.Material.Neon)
			arc.Parent = orbit
		end
		local satellite = decoration("Satellite", Vector3.new(0.6, 0.6, 0.6),
			pivot * CFrame.new(radius, 0, 0), Color3.fromRGB(255, 205, 104), Enum.Material.Neon)
		satellite.Shape = Enum.PartType.Ball
		satellite.Parent = orbit
		orbit.Parent = bubble
		CollectionService:AddTag(orbit, "BuildBubbleOrbit")
	end
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
	bubble.Material = Enum.Material.Glass
	bubble.Transparency = 0.55
	bubble.Reflectance = 0.2
	bubble.Anchored = true
	bubble.CanCollide = false
	bubble.CanTouch = true
	bubble.CanQuery = false
	decorateBubble(bubble)

	local label = Instance.new("BillboardGui")
	label.Name = "BuildLabel"
	label.Size = UDim2.fromOffset(240, 70)
	label.StudsOffset = Vector3.new(0, 8, 0)
	label.AlwaysOnTop = true
	label.MaxDistance = 80
	label.Parent = bubble

	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Text = "GLASS HOUSE"
	text.TextColor3 = Color3.new(1, 1, 1)
	text.TextStrokeTransparency = 0.3
	text.Font = Enum.Font.GothamBold
	text.TextSize = 26
	text.Parent = label

	local pulse = TweenService:Create(bubble, TweenInfo.new(1, Enum.EasingStyle.Sine,
		Enum.EasingDirection.InOut, -1, true), { Transparency = 0.75 })
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
