-- TrailerFix server watchdog.
-- B42's BaseVehicle.isAtRest() requires the physics origin to sit within 0.2
-- z-units of the floor. Tall vehicles (horsebox/livestock/advert trailers and
-- similar) can never satisfy that, so the engine never freezes their physics:
-- they simulate forever while parked, creep from a constant solver force, and
-- feed position desync in multiplayer. Dedicated servers never run
-- CarController.checkShouldBeActive(), so a manual freeze sticks until normal
-- interactions (towing, entering, collisions) reactivate the vehicle.
-- setPhysicsActive(false) cascades from a towing vehicle to its trailer, so
-- freezing the head of a parked rig freezes the whole chain.
--
-- Freezing requires accumulated calm credit (calm samples add, loud samples
-- drain fast) so that freshly spawned or falling vehicles are never frozen
-- mid-air: a resting body reads |velY| ~0.1 with occasional jitter spikes,
-- while a falling one exceeds the calm band continuously until it lands.
if not isServer() then return end

local SAMPLE_INTERVAL_TICKS = 10
local CALM_CREDIT_REQUIRED = 30
local LOUD_PENALTY = 3

local function chainHasDriver(v)
	while v ~= nil do
		if v:getDriver() ~= nil then return true end
		v = v:getVehicleTowing()
	end
	return false
end

-- Resting bodies show |velY| ~0.08-0.12 (gravity vs contact); exactly zero
-- means physics is not integrating (spawn limbo, mid-air) - not calm.
local function chainIsCalm(v)
	while v ~= nil do
		if v:getSpeed2D() >= 0.08 then return false end
		local vy = math.abs(v:getLinearVelocity(Vector3f.new()):y())
		if vy < 0.02 or vy >= 0.35 then return false end
		v = v:getVehicleTowing()
	end
	return true
end

local calmSamples = {}
local tickCount = 0

Events.OnTick.Add(function()
	tickCount = tickCount + 1
	if tickCount % SAMPLE_INTERVAL_TICKS ~= 0 then return end
	local it = getCell():getVehicles():iterator()
	while it:hasNext() do
		local v = it:next()
		-- only heads of chains: not towed by anything
		if v:getVehicleTowedBy() == nil and v:isPhysicsActive()
				and not chainHasDriver(v) then
			local id = v:getId()
			local sq = v:getSquare()
			if sq ~= nil and sq:hasFloor() and chainIsCalm(v) then
				local n = (calmSamples[id] or 0) + 1
				if n >= CALM_CREDIT_REQUIRED then
					v:setPhysicsActive(false)
					calmSamples[id] = nil
				else
					calmSamples[id] = n
				end
			else
				local n = (calmSamples[id] or 0) - LOUD_PENALTY
				calmSamples[id] = n > 0 and n or nil
			end
		end
	end
end)
