local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local WorldVisuals = {}
local started = false

function WorldVisuals.start()
	if started then
		return
	end
	started = true

	local panes = {}
	local orbits = {}
	local elapsed = 0

	local function addPane(pane)
		if pane:IsA("BasePart") then
			panes[pane] = true
		end
	end
	local function addOrbit(orbit)
		if orbit:IsA("Model") then
			orbits[orbit] = { pivot = orbit:GetPivot(), speed = orbit:GetAttribute("AngularSpeed") or 0.5 }
		end
	end

	CollectionService:GetInstanceAddedSignal("PrivacyGlassExterior"):Connect(addPane)
	CollectionService:GetInstanceRemovedSignal("PrivacyGlassExterior"):Connect(function(pane)
		panes[pane] = nil
	end)
	CollectionService:GetInstanceAddedSignal("BuildBubbleOrbit"):Connect(addOrbit)
	CollectionService:GetInstanceRemovedSignal("BuildBubbleOrbit"):Connect(function(orbit)
		orbits[orbit] = nil
	end)
	for _, pane in CollectionService:GetTagged("PrivacyGlassExterior") do
		addPane(pane)
	end
	for _, orbit in CollectionService:GetTagged("BuildBubbleOrbit") do
		addOrbit(orbit)
	end

	RunService:BindToRenderStep("HouseWorldVisuals", Enum.RenderPriority.Camera.Value + 1, function(deltaTime)
		elapsed += deltaTime
		local camera = workspace.CurrentCamera
		if camera then
			for pane in panes do
				local normal = pane:GetAttribute("OutwardNormal")
				if typeof(normal) == "Vector3" and pane:IsDescendantOf(workspace) then
					-- Test each pane's viewing side, including the roof and rotated plots.
					local viewingSide = (camera.CFrame.Position - pane.Position):Dot(normal)
					local transparency = viewingSide < 0 and 1 or 0
					if pane.LocalTransparencyModifier ~= transparency then
						pane.LocalTransparencyModifier = transparency
					end
				end
			end
		end
		for orbit, state in orbits do
			if orbit:IsDescendantOf(workspace) then
				orbit:PivotTo(state.pivot * CFrame.Angles(0, elapsed * state.speed, 0))
			end
		end
	end)
end

return WorldVisuals
