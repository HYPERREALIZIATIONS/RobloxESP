--[[
	sample_ingame_pipe_feed.lua  (Roblox Luau)
	Example feed for the external ESP overlay's PipeProvider.

	This is for AUTHORIZED use only: your own experience, or a friend's
	experience where you have permission (anti-cheat testing).

	It publishes a Frame (see README) to a local named pipe each frame so the
	external .exe can render ESP without scanning process memory.

	NOTE: Roblox does not expose named pipes directly. The realistic way to get
	data out of the client to an external program is:
	  1) a Lua bridges via a localhost TCP socket (use a Script with
	     HttpService isn't suitable for streaming; instead use a custom
	     loader that opens a socket through the executor's luasocket, or
	  2) have the external tool read the data your experience exposes through
	     an out-of-band channel you control.

	The simplest *legitimate* path for a controlled test environment is to run
	a small local proxy: the in-game script posts JSON to a localhost HTTP
	endpoint you host, and your external tool reads from that endpoint. Swap
	PipeProvider for the included TcpProvider accordingly.

	Below is the canonical Frame-building logic; wire the transport to whatever
	consented channel you and your friend agree on.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local function buildFrame()
	local ents = {}
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr == LocalPlayer then continue end
		local char = plr.Character
		local hum = char and char:FindFirstChildWhichIsA("Humanoid")
		local root = char and (char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso"))
		local head = char and char:FindFirstChild("Head")
		if not (hum and root and head) then continue end

		local isTeammate = LocalPlayer.Team and plr.Team == LocalPlayer.Team
		-- Occlusion: raycast from camera to the player's head; if something solid
		-- blocks it, mark Occluded. This is the ONLY place wall logic lives, since
		-- the external overlay has no game geometry.
		local occluded = false
		local camPos = Camera.CFrame.Position
		local dir = (head.Position - camPos)
		local ray = Ray.new(camPos, dir.Unit * dir.Magnitude)
		local params = RaycastParams.new()
		params.FilterDescendantsInstances = { char, LocalPlayer.Character }
		params.FilterType = Enum.RaycastFilterType.Blacklist
		local hit = workspace:Raycast(camPos, dir.Unit * dir.Magnitude, params)
		if hit and hit.Instance then
			occluded = true
		end
		table.insert(ents, {
			Name = plr.Name,
			Team = plr.Team and plr.Team.Name or "",
			IsTeammate = isTeammate or false,
			Occluded = occluded,
			Health = hum.Health,
			MaxHealth = hum.MaxHealth,
			Rig = (hum.RigType == Enum.HumanoidRigType.R15) and "R15" or "R6",
			Root = { X = root.Position.X, Y = root.Position.Y, Z = root.Position.Z },
			Head = { X = head.Position.X, Y = head.Position.Y, Z = head.Position.Z },
			Feet = { X = root.Position.X, Y = root.Position.Y - 3, Z = root.Position.Z },
			Height = 5, Width = 2,
			Bones = {},
		})
	end

	return {
		Camera = {
			Position = { X = Camera.CFrame.Position.X, Y = Camera.CFrame.Position.Y, Z = Camera.CFrame.Position.Z },
			Forward = { X = Camera.CFrame.LookVector.X, Y = Camera.CFrame.LookVector.Y, Z = Camera.CFrame.LookVector.Z },
			Up = { X = Camera.CFrame.UpVector.X, Y = Camera.CFrame.UpVector.Y, Z = Camera.CFrame.UpVector.Z },
			Right = { X = Camera.CFrame.RightVector.X, Y = Camera.CFrame.RightVector.Y, Z = Camera.CFrame.RightVector.Z },
			FovDegrees = Camera.FieldOfView,
			ViewW = Camera.ViewportSize.X,
			ViewH = Camera.ViewportSize.Y,
			Near = 0.1, Far = 1000,
		},
		Entities = ents,
	}
end

-- Build + serialize each frame. Transport is your consented channel.
RunService.RenderStepped:Connect(function()
	local frame = buildFrame()
	local json = game:GetService("HttpService"):JSONEncode(frame)
	-- TODO: send `json .. "\n"` to your consented local transport
	-- (named pipe / TCP socket / local HTTP). See README.
end)
