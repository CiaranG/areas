

function areas:getByName(name)
    local lname = name:lower()
    for _, area in pairs(self.areas) do
        if area.name:lower() == lname then
            return area
        end
    end
    return nil
end

-- Returns the nearest area to the given position, optionally checking only
-- areas matching a given pattern (which is a lua regex). The pattern will
-- be amended to make it case-insensitive.
-- Returns nil if nothing could be found, otherwise the area and the
-- distance to it.
-- maxdist is the maximum distance at which to search.
function areas:findNearestArea(pos, pattern, maxdist)

	local nearest, nearestdist
	if pattern then
		-- Make the pattern case-insensitive...
		pattern = pattern:gsub("(%%?)(.)", function(percent, letter)
			if percent ~= "" or not letter:match("%a") then
				return percent .. letter
			else
				return string.format("[%s%s]", letter:lower(), letter:upper())
			end
		end)
	end
	for id, area in pairs(self.areas) do
		if (not pattern) or string.find(area.name, pattern) then
			local centre = vector.interpolate(area.pos1, area.pos2, 0.5)
			local dist = vector.distance(pos, centre)
			if ((not nearestdist) or dist < nearestdist) and ((not maxdist) or dist <= maxdist) then
				nearest = area
				nearestdist = dist
			end
		end
	end
	return nearest, nearestdist
end


-- Find all areas, optionally within a given range, optionally including only
-- areas matching a given pattern (which is a lua regex). The pattern will
-- be amended to make it case-insensitive.
-- Returns a list of matching areas.
-- maxdist is the maximum distance at which to search.
-- ids can be set to true to return the ids instead of the actual areas
function areas:getAreas(pos, pattern, maxdist, ids)

	local list = {}
	if pattern then
		-- Make the pattern case-insensitive...
		pattern = pattern:gsub("(%%?)(.)", function(percent, letter)
			if percent ~= "" or not letter:match("%a") then
				return percent .. letter
			else
				return string.format("[%s%s]", letter:lower(), letter:upper())
			end
		end)
	end
	for id, area in pairs(self.areas) do
		if (not pattern) or string.find(area.name, pattern) then
			local centre = vector.interpolate(area.pos1, area.pos2, 0.5)
			local dist = vector.distance(pos, centre)
			if (not maxdist) or dist <= maxdist then
                                if ids then
				    table.insert(list, id)
                                else
				    table.insert(list, area)
                                end
			end
		end
	end
	return list
end


-- Returns a list of areas that include the provided position
function areas:getAreasAtPos(pos)
	local a = {}
	local px, py, pz = pos.x, pos.y, pos.z
	for id, area in pairs(self.areas) do
		local ap1, ap2 = area.pos1, area.pos2
		if px >= ap1.x and px <= ap2.x and
		   py >= ap1.y and py <= ap2.y and
		   pz >= ap1.z and pz <= ap2.z then
			a[id] = area
		end
	end
	return a
end

-- Checks if the area is unprotected or owned by you
function areas:canInteract(pos, name)
	if minetest.check_player_privs(name, self.adminPrivs) then
		return true
	end
	local owned = false
	for _, area in pairs(self:getAreasAtPos(pos)) do
		if area.owner == name or area.open then
			return true
		else
			owned = true
		end
	end
	return not owned
end

-- Returns a table (list) of all players that own an area
function areas:getNodeOwners(pos)
	local owners = {}
	for _, area in pairs(self:getAreasAtPos(pos)) do
		table.insert(owners, area.owner)
	end
	return owners
end

--- Checks if the area intersects with an area that the player can't interact in.
-- Note that this fails and returns false when the specified area is fully
-- owned by the player, but with miltiple protection zones, none of which
-- cover the entire checked area.
-- @param name (optional) player name.  If not specified checks for any intersecting areas.
-- @return Boolean indicating whether the player can interact in that area.
-- @return Un-owned intersecting area id, if found.
function areas:canInteractInArea(pos1, pos2, name)
	if name and minetest.check_player_privs(name, self.adminPrivs) then
		return true
	end
	areas:sortPos(pos1, pos2)
	-- First check for a fully enclosing owned area
	if name then
		for id, area in pairs(self.areas) do
			-- A little optimization: isAreaOwner isn't necessary
			-- here since we're iterating through all areas.
			if area.owner == name and
					self:isSubarea(pos1, pos2, id) then
				return true
			end
		end
	end
	-- Then check for intersecting (non-owned) areas
	for id, area in pairs(self.areas) do
		local p1, p2 = area.pos1, area.pos2
		if (p1.x <= pos2.x and p2.x >= pos1.x) and
		   (p1.y <= pos2.y and p2.y >= pos1.y) and
		   (p1.z <= pos2.z and p2.z >= pos1.z) then
			-- Found an intersecting area
			if not name or not areas:isAreaOwner(id, name) then
				return false, id
			end
		end
	end
	return true
end

