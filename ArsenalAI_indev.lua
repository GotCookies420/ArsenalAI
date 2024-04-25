local reactiontime = 0.0125
local rt_variance = 0.0025
local maxtravel = math.huge
local ts = game:GetService("TweenService")
local ai_host = game.Players.LocalPlayer
local pfs = game:GetService("PathfindingService")
local ai_settings = {
	['low_hp'] = 12.75;
}
local status = {
	['in_combat'] = false;
	['combat_host'] = nil;
	['status'] = "Loading AAI";
}

-- essentials

function get_hostcharacter(head:boolean)
	local c = ai_host.Character
	
	if c ~= nil then
		if head then
			return c:FindFirstChild("Head")
		end
		
		return c
	end
end

function getreact()
	return reactiontime - Random.new():NextNumber(-rt_variance, rt_variance)
end

function lookat(pos:Vector3)
	if get_hostcharacter(true) ~= nil then
		local cam = workspace.CurrentCamera
		local mouse_speed = 0.005
		local newcf = CFrame.lookAt(cam.Position, pos, cam.CFrame.UpVector)
		local tween = ts:Create(workspace.CurrentCamera, TweenInfo.new(mouse_speed, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut), {['CFrame'] = newcf})
		
		status.status = "Watching "..tostring(pos)
		
		tween:Play()
		tween.Completed:Wait()
	end
end

function pathto(pos)
	if get_hostcharacter(true) ~= nil and (pos - get_hostcharacter(true).Position).magnitude <= maxtravel then
		local path = pfs:ComputeSmoothPathAsync(get_hostcharacter(true).Position, pos, maxtravel)
		local root = get_hostcharacter(false):FindFirstChild("HumanoidRootPart")
		local h = get_hostcharacter(false):FindFirstChildOfClass("Humanoid")
		
		root.Touched:Connect(function(op)
			if not game.Players:GetPlayerFromCharacter(op.Parent) then
				if h.Jump ~= true then
					h.Jump = true
					status.status = "Jumping"
				end
			end
		end)
		
		for index, wp in pairs(path:GetChildren()) do
			status.status = "Traversing to waypoint #"..tostring(index).." of "..tostring(#path:GetChildren())
			h:MoveTo(wp.Position, wp)
		end
		
		status.status = "Goal reached"
	end
end

-- quick access actions

function quickScan()
	spawn(function()
		local h:BasePart = get_hostcharacter(true)
		local offset = Random.new():NextNumber()
		
		status.status = "QuickScan in progress"

		lookat(h.Position - Vector3.new(h.Position.X, offset, h.Position.Z))
		task.wait(getreact())
		lookat(h.Position - Vector3.new(h.Position.X, -(offset * 2), h.Position.Z))
		
		status.status = "QuickScan complete"
	end)
end

function engageCombat(p:Player)
	if not status.in_combat then
		local isTeammate = (p.Team == ai_host.Team)

		if not isTeammate then
			status.in_combat = true
			status.combat_host = p
			status.status = "Targetting "..p.Name
			
			task.delay(reactiontime, function()
				spawn(function()
					while status.in_combat and status.combat_host == p do
						lookat(p.Character:FindFirstChild("Head").Position)
						game["Run Service"].RenderStepped:Wait()
					end
				end)
			end)
		end
	end
end


-- the AI (more like a bot)

-- build UI

local ui = Instance.new("ScreenGui")
local statustext = Instance.new("TextLabel")

ui.Name = "AAI_HUD"
ui.ResetOnSpawn = false
ui.Parent = ai_host.PlayerGui

statustext.Size = UDim2.new(0, 1, 0, 0.1)
statustext.Position = UDim2.new(0, 0, 0, 0.9)
statustext.BackgroundTransparency = 1
statustext.TextScaled = true
statustext.Font = Enum.Font.SourceSansBold
statustext.Parent = ui

game["Run Service"].RenderStepped:Connect(function()
	statustext.Text = status.status.." (combat: "..tostring(status.in_combat)..", "..tostring(status.combat_host)..")"
end)

-- task tree

ai_host.CharacterAdded:Connect(function(c)
	local h = c:FindFirstChildOfClass("Humanoid")
	local old_hp = h.Health
	
	-- health changes
	
	h.Changed:Connect(function()
		if h.Health < old_hp then
			local dif = h.Health - old_hp
			local hp = h.Health
			
			if dif >= 0.25 then
				if not status.in_combat then
					status.in_combat = true
					
					quickScan()
					
					task.delay(0.75 - reactiontime, function()
						if status.in_combat then
							status.in_combat = false
						end
					end)
				end
			end
		end
	end)
	
	-- combat engagement
	
	
end)
