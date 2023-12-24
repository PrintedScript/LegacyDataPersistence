--[[
	LegacyDataPersistence V1.0
	Written by something.else on 11/8/2023
	
	This module is intended to be used on a roblox revival with DataStoreService working ( Like syntax.eco )
]]

if _G.LegacyDataPersistence == nil then _G.LegacyDataPersistence = {} end
if _G.GlobalLock == nil then _G.GlobalLock = {} end

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local LegacyDataStore = DataStoreService:GetDataStore("LegacyDataStore")
local HttpService = game:GetService("HttpService")

local LegacyDataPersistence = {}

local function AcquireGlobalLock( lockName, acquireTimeout, lockTimeout )
	if acquireTimeout == nil then acquireTimeout = 15 end
	if lockTimeout == nil then lockTimeout = 3 end
	
	if _G.GlobalLock[lockName] ~= nil then
		local StartWaitingTime = tick()
		repeat
			wait(0.02)
		until _G.GlobalLock[lockName] == nil or tick() - StartWaitingTime > acquireTimeout or tick() > _G.GlobalLock[lockName]["expire"]
		
		if tick() - StartWaitingTime > acquireTimeout then
			warn("Failed to acquire global lock on", lockName, "for", tostring(acquireTimeout).."secs")			
			return
		end
	end
	
	local UniqueLockIdentifier = HttpService:GenerateGUID(false)
	_G.GlobalLock[lockName] = {
		["uuid"] = UniqueLockIdentifier,
		["expire"] = tick() + lockTimeout	
	}
	wait(0.02)
	
	if _G.GlobalLock[lockName]["uuid"] ~= UniqueLockIdentifier then
		return AcquireGlobalLock(lockName, acquireTimeout, lockTimeout)
	end
	
	local LockClass = {}
	
	function LockClass:Unlock()
		if _G.GlobalLock[lockName] == nil then return end
		if _G.GlobalLock[lockName]["uuid"] ~= UniqueLockIdentifier then return end
		
		_G.GlobalLock[lockName] = nil
	end	
	
	return LockClass
end

function LegacyDataPersistence:GetPlayer( player )
	--[[
		Expects a Player object as the first argument
		returns a class which mimicks the player with all functions supported		
	]]
	local PlayerDataPersistence = {}
	local PlayerKey = tostring(player.UserId)
	
	coroutine.wrap(function() -- Allows for WaitForDataReady to run first
		if _G.LegacyDataPersistence[PlayerKey] == nil then
			local LoadingLock = AcquireGlobalLock(PlayerKey.."_Loading_LegacyDataPersistence")
			if LoadingLock then
				if _G.LegacyDataPersistence[PlayerKey] then LoadingLock:Unlock(); return end
				
				print("LegacyDataPersistence / Attempting to load Player Data ID:", PlayerKey)
				local success, PlayerData = pcall(function()
					return LegacyDataStore:GetAsync(PlayerKey)
				end)
				if success then
					print("LegacyDataPersistence / Successfully loaded Player Data from DataStoreService ID:", PlayerKey)
					if _G.LegacyDataPersistence[PlayerKey] ~= nil then
						_G.LegacyDataPersistence[PlayerKey] = PlayerData
					else
						_G.LegacyDataPersistence[PlayerKey] = {}					
					end
				else
					warn("LegacyDataPersistence / Failed to load Player Data from DataStoreService:", PlayerData)
				end
				
				LoadingLock:Unlock()
			end
		end
	end)()
	
	local ListenForPlayerLeaveConnection
	ListenForPlayerLeaveConnection = Players.PlayerRemoving:Connect(function( leavingPlayer )
		if leavingPlayer == player then
			-- Save the data then clear it
			ListenForPlayerLeaveConnection:disconnect()
			local SavingLock = AcquireGlobalLock(PlayerKey.."_Saving_LegacyDataPersistence")
			if SavingLock == nil then return end
			if _G.LegacyDataPersistence[PlayerKey] == nil then SavingLock:Unlock(); return end			
			LegacyDataStore:SetAsync(PlayerKey, _G.LegacyDataPersistence[PlayerKey])
			_G.LegacyDataPersistence[PlayerKey] = nil
			SavingLock:Unlock()
		end
	end)
	
	function PlayerDataPersistence:WaitForDataReady()
		if _G.LegacyDataPersistence[PlayerKey] then return end
		repeat
			wait(0.25)
		until _G.LegacyDataPersistence[PlayerKey] ~= nil
	end
	
	local function AssertDataReady()
		if _G.LegacyDataPersistence[PlayerKey] == nil then error("Data for player not yet loaded, wait for DataReady") end
	end	
	
	local function LoadKeyFromMemory(key)
		AssertDataReady()
		return _G.LegacyDataPersistence[PlayerKey][key]
	end	
	
	local function AssertValueType(value, expectedType)
		if type(value) ~= expectedType then
			error("Expected Data type is",expectedType,"but got",type(value),"instead")
		end
		return
	end
	
	function PlayerDataPersistence:LoadBoolean(key) return LoadKeyFromMemory(key) end
	function PlayerDataPersistence:loadBoolean(key) return PlayerDataPersistence:LoadBoolean(key) end
	function PlayerDataPersistence:SaveBoolean(key, value)
		AssertDataReady()
		if value == nil then _G.LegacyDataPersistence[PlayerKey][key] = nil end
		AssertValueType(value, 'boolean')
		
		_G.LegacyDataPersistence[PlayerKey][key] = value
	end
	function PlayerDataPersistence:saveBoolean(key, value) return PlayerDataPersistence:SaveBoolean(key, value) end
	
	function PlayerDataPersistence:LoadNumber(key) return LoadKeyFromMemory(key) end
	function PlayerDataPersistence:loadNumber(key) return PlayerDataPersistence:LoadNumber(key) end
	function PlayerDataPersistence:SaveNumber(key, value)
		AssertDataReady()
		if value == nil then _G.LegacyDataPersistence[PlayerKey][key] = nil end
		AssertValueType(value, 'number')
		
		_G.LegacyDataPersistence[PlayerKey][key] = value
	end
	function PlayerDataPersistence:saveNumber(key, value) return PlayerDataPersistence:SaveNumber(key, value) end
	
	function PlayerDataPersistence:LoadString(key) return LoadKeyFromMemory(key) end
	function PlayerDataPersistence:loadString(key) return PlayerDataPersistence:LoadString(key) end
	function PlayerDataPersistence:SaveString(key, value)
		AssertDataReady()
		if value == nil then _G.LegacyDataPersistence[PlayerKey][key] = nil end
		AssertValueType(value, 'string')
		
		_G.LegacyDataPersistence[PlayerKey][key] = value
	end
	function PlayerDataPersistence:saveString(key, value) return PlayerDataPersistence:SaveString(key, value) end
	
	return PlayerDataPersistence
end

return LegacyDataPersistence
