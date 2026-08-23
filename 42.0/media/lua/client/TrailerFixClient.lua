-- TrailerFix client-side safety net.
--
-- The primary fix lives in this mod's vehicle scripts: tall trailers'
-- physics origins are lowered under BaseVehicle.isAtRest()'s 0.2 z-unit
-- height limit (via a model-offset shift with collision-shape compensation),
-- so the engine's own parked-vehicle freeze works natively again.
--
-- This pin is the backup for anything still restless (e.g. a trailer whose
-- self-sustained creep speed exceeds the at-rest speed limit): it applies the
-- same engine freeze (setPhysicsActive(false)) under sane conditions.
-- ARM: a chain must earn its first freeze via sustained calm (falling or
-- freshly spawned vehicles never qualify). MAINTAIN: once armed, re-frozen
-- every tick until genuinely disturbed (driver, hitch, real velocity).
--
-- Console diagnostics: TF_status() TF_freeze() TF_unfreeze() TF_autopin()

local function scriptIsTrailer(v)
	local name = v:getScriptName() or ""
	return string.find(name, "Trailer") ~= nil
end

local function chainHasTrailer(v)
	while v ~= nil do
		if scriptIsTrailer(v) then return true end
		v = v:getVehicleTowing()
	end
	return false
end

local function chainHasDriver(v)
	while v ~= nil do
		if v:getDriver() ~= nil then return true end
		v = v:getVehicleTowing()
	end
	return false
end

-- Calm = negligible horizontal speed AND vertical velocity near the normal
-- resting-contact band (~0.1, with jitter spikes). A falling body exceeds the
-- band within a few ticks of freefall and stays loud until it lands. Credit
-- accumulates on calm ticks and drains fast on loud ones, so resting-but-
-- jittery trailers freeze within a couple of seconds while spawned/falling
-- vehicles can never be pinned mid-air.
local CALM_CREDIT_REQUIRED = 300
local LOUD_PENALTY = 3

-- A body genuinely resting on its suspension always shows a small vertical
-- velocity (~0.08-0.12: per-frame gravity resolved by contact). Exactly zero
-- means physics is not integrating yet (spawn limbo, mid-air) - never treat
-- that as calm, or freshly spawned vehicles can be pinned before they fall.
local function chainIsCalm(v)
	while v ~= nil do
		if v:getSpeed2D() >= 0.08 then return false end
		local vy = math.abs(v:getLinearVelocity(Vector3f.new()):y())
		if vy < 0.02 or vy >= 0.35 then return false end
		v = v:getVehicleTowing()
	end
	return true
end

-- Two-phase pin. ARM: a chain must earn its first freeze via calm credit, so
-- freshly spawned / falling vehicles are never pinned mid-air. MAINTAIN: the
-- engine re-wakes non-at-rest vehicles every tick, so once armed the chain is
-- re-frozen every tick unconditionally until genuinely disturbed (driver,
-- hitched to something, or real velocity from an impact).
local DISTURB_SPEED = 0.3
local DISTURB_VELY = 0.6

local calmCredit = {}
local pinned = {}

local function chainIsDisturbed(v)
	while v ~= nil do
		if v:getSpeed2D() >= DISTURB_SPEED then return true end
		local vel = v:getLinearVelocity(Vector3f.new())
		if math.abs(vel:y()) >= DISTURB_VELY then return true end
		v = v:getVehicleTowing()
	end
	return false
end

local function autopinTick()
	local it = getCell():getVehicles():iterator()
	while it:hasNext() do
		local v = it:next()
		-- only heads of tow chains; freezing the head cascades to the trailer
		if v:getVehicleTowedBy() == nil and chainHasTrailer(v)
				and not chainHasDriver(v) then
			local id = v:getId()
			if pinned[id] then
				if chainIsDisturbed(v) then
					pinned[id] = nil
					calmCredit[id] = nil
				elseif v:isPhysicsActive() then
					v:setPhysicsActive(false)
				end
			elseif v:isPhysicsActive() then
				local sq = v:getSquare()
				if sq ~= nil and sq:hasFloor() and chainIsCalm(v) then
					local n = (calmCredit[id] or 0) + 1
					if n >= CALM_CREDIT_REQUIRED then
						pinned[id] = true
						calmCredit[id] = nil
						v:setPhysicsActive(false)
					else
						calmCredit[id] = n
					end
				else
					local n = (calmCredit[id] or 0) - LOUD_PENALTY
					calmCredit[id] = n > 0 and n or nil
				end
			end
		else
			-- driver present or hitched to something: chain is in use
			local id = v:getId()
			pinned[id] = nil
			calmCredit[id] = nil
		end
	end
end

local autopinOn = false

local function setAutopin(on)
	if on == autopinOn then return end
	autopinOn = on
	if on then
		Events.OnTick.Add(autopinTick)
	else
		Events.OnTick.Remove(autopinTick)
	end
end

Events.OnGameStart.Add(function()
	setAutopin(true)
	print("[TrailerFix] parked-trailer pin active")
end)

-- console diagnostics -------------------------------------------------------

local function eachTrailer(fn)
	local it = getCell():getVehicles():iterator()
	while it:hasNext() do
		local v = it:next()
		if scriptIsTrailer(v) then fn(v) end
	end
end

function TF_status()
	eachTrailer(function(v)
		local ok, err = pcall(function()
			local vel = v:getLinearVelocity(Vector3f.new())
			local sq = v:getSquare()
			local sqz = sq ~= nil and sq:getZ() or 0
			print(string.format("[TrailerFix] %s id=%d pos=%.2f,%.2f physActive=%s atRest=%s speed2D=%.4f velY=%.4f originZ=%.4f sqZ=%d heightAboveGround=%.4f (atRest needs <=0.2)",
				v:getScriptName(), v:getId(), v:getX(), v:getY(),
				tostring(v:isPhysicsActive()), tostring(v:isAtRest()),
				v:getSpeed2D(), vel:y(),
				v:getDebugZ(), sqz, v:getDebugZ() - sqz))
		end)
		if not ok then print("[TrailerFix] status error: " .. tostring(err)) end
	end)
end

function TF_freeze()
	local n = 0
	eachTrailer(function(v)
		if v:getDriver() == nil and v:getVehicleTowedBy() == nil then
			if pcall(function() v:setPhysicsActive(false) end) then n = n + 1 end
		end
	end)
	print("[TrailerFix] froze " .. n .. " trailers")
end

function TF_unfreeze()
	local n = 0
	eachTrailer(function(v)
		if pcall(function() v:setPhysicsActive(true) end) then n = n + 1 end
	end)
	print("[TrailerFix] reactivated " .. n .. " trailers")
end

function TF_autopin()
	setAutopin(not autopinOn)
	print("[TrailerFix] autopin " .. (autopinOn and "ON" or "OFF"))
end
