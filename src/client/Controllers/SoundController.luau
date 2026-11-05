--!strict
--[[
	SoundController
	Client-side sound effects + optional background music. Respects the
	player's saved Sound / Music settings. Sound ids live in Config.Sounds.
]]

local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared").Config)
local StateController = require(script.Parent.StateController)

local SoundController = {}

local sounds: { [string]: Sound } = {}
local music: Sound? = nil
local lastPlayed: { [string]: number } = {}

local function soundEnabled(): boolean
	local snapshot = StateController.Current
	return snapshot == nil or snapshot.Settings.Sound
end

function SoundController.Play(key: string)
	if not soundEnabled() then
		return
	end
	local sound = sounds[key]
	if not sound then
		return
	end
	-- Avoid ear-piercing stacks when a kid taps very fast.
	local now = os.clock()
	if lastPlayed[key] and now - lastPlayed[key] < 0.06 then
		return
	end
	lastPlayed[key] = now
	sound.PlaybackSpeed = 0.95 + math.random() * 0.1
	SoundService:PlayLocalSound(sound)
end

local function refreshMusic()
	local track = music
	if not track then
		return
	end
	local snapshot = StateController.Current
	local wanted = snapshot == nil or snapshot.Settings.Music
	if wanted and not track.IsPlaying then
		track:Play()
	elseif not wanted and track.IsPlaying then
		track:Stop()
	end
end

function SoundController.Start()
	local folder = Instance.new("Folder")
	folder.Name = "BazarSounds"
	folder.Parent = SoundService

	for key, def in Config.Sounds :: any do
		if key ~= "Music" and type(def.Id) == "string" and def.Id ~= "" then
			local sound = Instance.new("Sound")
			sound.Name = key
			sound.SoundId = def.Id
			sound.Volume = def.Volume or 0.5
			sound.Parent = folder
			sounds[key] = sound
		end
	end

	local musicDef = Config.Sounds.Music
	if musicDef.Id ~= "" then
		local track = Instance.new("Sound")
		track.Name = "Music"
		track.SoundId = musicDef.Id
		track.Volume = musicDef.Volume
		track.Looped = true
		track.Parent = folder
		music = track
	end

	StateController.Changed:Connect(refreshMusic)
	refreshMusic()
end

return SoundController
