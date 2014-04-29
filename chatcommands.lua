

-- All chat commands are defined by simply adding the handler function to
-- this table. The handler receives the name of the player and the command
-- arguments, and it should return:
--  1. reply message (or nil)
--  2. success status (true or false)
local subcmd = {}

subcmd.help = {
    params = "[<subcmd>]",
    desc = "You're being silly, aren't you?",
    exec = function(playername, args)

        if args and args ~= "" then
            if not subcmd[args] then
                return "No such subcommand"
            end
            return "/area "..args.." "..subcmd[args].params.." - "..
                subcmd[args].desc, true
        end

        local msg = "Subcommands (use /area help <subcmd> for more):"
    for c, def in pairs(subcmd) do
        local has_privs
        if def.privs then
        has_privs, _ = minetest.check_player_privs(playername, def.privs)
        else
        has_privs = true
        end
        if has_privs then
        msg = msg.." "..c
        end
        end
        return msg, true
    end
}

subcmd.protect = {
    params = "<AreaName>",
    desc = "Protect your own area",
    privs = {[areas.self_protection_privilege]=true},
    exec = function(name, param)
        if param == "" then
            reutrn 'Invalid usage, see /area help protect'
        end
        local pos1, pos2 = areas:getPos1(name), areas:getPos2(name)
        if pos1 and pos2 then
            pos1, pos2 = areas:sortPos(pos1, pos2)
        else
            return 'You need to select an area first'
        end

        minetest.log("action", "/area protect invoked, owner="..name..
                " areaname="..param..
                " startpos="..minetest.pos_to_string(pos1)..
                " endpos="  ..minetest.pos_to_string(pos2))

        local canAdd, errMsg = areas:canPlayerAddArea(pos1, pos2, name)
        if not canAdd then
            return "You can't protect that area: "..errMsg
        end

        local id = areas:add(name, param, pos1, pos2, nil)
        areas:save()

        return "Area protected. ID: "..id, true
    end
}


subcmd.set_owner = {
    params = "<PlayerName> <AreaName>",
    desc = "Protect an area between two positions and give"
        .." a player access to it without setting the parent of the"
        .." area to any existing area",
    privs = {areas=true},
    exec = function(name, param)
        local found, _, ownername, areaname = param:find('^([^ ]+) (.+)$')

        if not found then
            return "Incorrect usage, see /area help set_owner"
        end

        local pos1, pos2 = areas:getPos1(name), areas:getPos2(name)
        if pos1 and pos2 then
            pos1, pos2 = areas:sortPos(pos1, pos2)
        else
            return "You need to select an area first"
        end

        if not areas:player_exists(ownername) then
            return "The player '"..ownername.."' does not exist"
        end

        minetest.log("action", name.." runs /set_owner. Owner = "..ownername..
                " AreaName = "..areaname..
                " StartPos = "..minetest.pos_to_string(pos1)..
                " EndPos = "  ..minetest.pos_to_string(pos2))

        local id = areas:add(ownername, areaname, pos1, pos2, nil)
        areas:save()
    
        minetest.chat_send_player(ownername,
                "You have been granted control over area #"..
                id..". Type /list_areas to show your areas.")
        return  "Area protected. ID: "..id, true
    end
}


subcmd.add_owner = {
    params = "<ParentID> <Player> <AreaName>",
    desc = "Give a player access to a sub-area between two"
        .." positions that have already been protected,"
        .." Use set_owner if you don't want the parent to be set.",
    privs = {},
    exec = function(name, param)
        local found, _, pid, ownername, areaname
                = param:find('^(%d+) ([^ ]+) (.+)$')

        if not found then
            return "Incorrect usage, see /area help add_owner"
        end

        local pos1, pos2 = areas:getPos1(name), areas:getPos2(name)
        if pos1 and pos2 then
            pos1, pos2 = areas:sortPos(pos1, pos2)
        else
            return 'You need to select an area first'
        end

        if not areas:player_exists(ownername) then
            return 'The player "'..ownername..'" does not exist'
        end

        minetest.log("action", name.." runs /add_owner. Owner = "..ownername..
                " AreaName = "..areaname.." ParentID = "..pid..
                " StartPos = "..pos1.x..","..pos1.y..","..pos1.z..
                " EndPos = "  ..pos2.x..","..pos2.y..","..pos2.z)

        -- Check if this new area is inside an area owned by the player
        pid = tonumber(pid)
        if (not areas:isAreaOwner(pid, name)) or
           (not areas:isSubarea(pos1, pos2, pid)) then
            return "You can't protect that area"
        end

        local id = areas:add(ownername, areaname, pos1, pos2, pid)
        areas:save()

        minetest.chat_send_player(ownername,
                "You have been granted control over area #"..
                id..". Type /list_areas to show your areas.")
        return "Area protected. ID: "..id, true
    end
}

subcmd.extend = {
    params = "<ID> <X>,<Y>,<Z>",
    desc = "Extend the area by the given amounts",
    privs = {areas=true},
    exec = function(name, param)
        local found, id
    local xp = {}
    found, _, id, xp['x'], xp['y'], xp['z'] = param:find("^(%d+) (%-?%d+),(%-?%d+),(%-?%d+)$")
        if not found then
            return "Invalid usage, see /area help extend"
        end

        id = tonumber(id)
        if not id then
            return "That area doesn't exist."
        end
    local area = areas.areas[id]

    for _, axis in pairs({'x', 'y', 'z'}) do
        local offset = tonumber(xp[axis])
        if offset < 0 then
        area.pos1[axis] = area.pos1[axis] + offset
        elseif offset > 0 then
        area.pos2[axis] = area.pos2[axis] + offset
        end
    end

        areas:save()
        return "Area extended.", true
    end
}

subcmd.rename = {
    params = "<ID> <newName>",
    desc = "Rename an area",
    privs = {},
    exec = function(name, param)
        local found, _, id, newName = param:find("^(%d+) (.+)$")
        if not found then
            return "Invalid usage, see /area help rename"
        end

        id = tonumber(id)
        if not id then
            return "That area doesn't exist."
        end

        if not areas:isAreaOwner(id, name) then
            return "You don't own that area."
        end

        areas.areas[id].name = newName
        areas:save()
        return "Area renamed.", true
    end
}

subcmd.find = {
    params = "<regexp>",
    desc = "Find areas using a Lua regular expression",
    privs = {},
    exec = function(name, param)
        if param == "" then
            return "A regular expression is required."
        end

        -- Check expression for validity
        local function testRegExp()
            ("Test [1]: Player (0,0,0) (0,0,0)"):find(param)
        end
        if not pcall(testRegExp) then
            return "Invalid regular expression."
        end

        local found = false
        for id, area in pairs(areas.areas) do
            if areas:isAreaOwner(id, name) and
               areas:toString(id):find(param) then
                minetest.chat_send_player(name, areas:toString(id))
                found = true
            end
        end
        if not found then
            return "No matches found", true
        end
        return None, true
    end
}

subcmd.list = {
    params = "",
    desc = "List your areas, or all areas if you are an admin.",
    privs = {},
    exec = function(name, param)
        local admin = minetest.check_player_privs(name, {areas=true})
        if admin then
            minetest.chat_send_player(name,
                    "Showing all areas.")
        else
            minetest.chat_send_player(name,
                    "Showing your areas.")
        end
        for id, area in pairs(areas.areas) do
            if admin or areas:isAreaOwner(id, name) then
                minetest.chat_send_player(name,
                        areas:toString(id))
            end
        end
        return None, True
    end
}

subcmd.recursive_remove = {
    params = "<id>",
    desc = "Recursively remove areas",
    privs = {},
    exec = function(name, param)
        local id = tonumber(param)
        if not id then
            return "Invalid usage, see /area help recursive_remove"
        end

        if not areas:isAreaOwner(id, name) then
            return "Area "..id
                    .." does not exist or is"
                    .." not owned by you."
        end

        areas:remove(id, true)
        areas:save()
        return "Removed area "..id.." and it's sub areas.", true
    end
}

subcmd.remove = {
    params = "<id>",
    desc = "Remove an area",
    privs = {},
    exec = function(name, param)
        local id = tonumber(param)
        if not id then
            return "Invalid usage, see /area help remove"
        end

        if not areas:isAreaOwner(id, name) then
            return "Area "..id
                    .." does not exist or"
                    .." is not owned by you"
        end

        areas:remove(id)
        areas:save()
        return 'Removed area '..id, true
    end
}

subcmd.edit = {
    params = "<id>",
    desc = "Edit an area",
    privs = {},
    exec = function(name, param)
        local id = tonumber(param)
        if not id then
            return "Invalid usage, see /area help edit"
        end

        if not markers then
            return "This command needs the markers mod"
        end

        if not areas:isAreaOwner(id, name) then
            return "Area "..id.." does not exist or"
                    .." is not owned by you"
        end

        local player = minetest.get_player_by_name(name)
        local formspec = markers.get_area_desc_formspec(id, player, player:getpos())
        minetest.show_formspec(name, "markers:info", formspec)
        return nil, true
    end
}

subcmd.change_owner = {
    params = "<id> <NewOwner>",
    desc = "Change the owner of an area",
    privs = {},
    exec = function(name, param)
        local found, _, id, new_owner =
                param:find('^(%d+) ([^ ]+)$')

        if not found then
            return "Invalid usage, see /area help change_owner"
        end
        
        if not areas:player_exists(new_owner) then
            return 'The player "'..new_owner..'" does not exist'
        end

        id = tonumber(id)
        if not areas:isAreaOwner(id, name) then
            return "Area "..id.." does not exist"
                    .." or is not owned by you."
        end
        areas.areas[id].owner = new_owner
        areas:save()
        minetest.chat_send_player(new_owner,
                name..'" has given you control over an area.')
        return 'Owner changed.', true
    end
}

subcmd.open = {
    params = "<id>",
    desc = "Toggle an area open (anyone can interact) or not",
    privs = {},
    exec = function(name, param)
        local id = tonumber(param)

        if not id then
            return "Invalid usage, see /area help open"
        end

        if not areas:isAreaOwner(id, name) then
            return "Area "..id.." does not exist"
                    .." or is not owned by you."
        end
        local open = not areas.areas[id].open
        -- Save false as nil to avoid inflating the DB.
        areas.areas[id].open = open or nil
        areas:save()
        return "Area "..(open and "opened" or "closed")..".", true
    end
}

subcmd.select = {
    params = "<id>",
    desc = "Select a area by id.",
    privs = {},
    exec = function(name, param)
	local id = tonumber(param)
	if not id then
	    return "Invalid usage, see /area help select."
	end
	if not areas.areas[id] then
	    return "The area "..id.." does not exist."
	end

	areas:setPos1(name, areas.areas[id].pos1)
	areas:setPos2(name, areas.areas[id].pos2)
	return "Area "..id.." selected.", true
    end
}

subcmd.pos1 = {
    params = "[X Y Z|X,Y,Z]",
    desc = "Set area protection region position 1 to your"
    .." location or the one specified",
    privs = {},
    exec = function(name, param)
	local pos = nil
	local found, _, x, y, z = param:find(
	"^(-?%d+)[, ](-?%d+)[, ](-?%d+)$")
	if found then
	    pos = {x=tonumber(x), y=tonumber(y), z=tonumber(z)}
	elseif param == "" then
	    player = minetest.get_player_by_name(name)
	    if player then
		pos = player:getpos()
	    else
		return "Unable to get position"
	    end
	else
	    return "Invalid usage, see /area pos1 help"
	end
	pos = vector.round(pos)
	areas:setPos1(name, pos)
	return "Area position 1 set to "..minetest.pos_to_string(pos), true
    end
}

subcmd.pos2 = {
    params = "[X Y Z|X,Y,Z]",
    desc = "Set area protection region position 2 to your"
    .." location or the one specified",
    privs = {},
    exec = function(name, param)
	local pos = nil
	local found, _, x, y, z = param:find(
	"^(-?%d+)[, ](-?%d+)[, ](-?%d+)$")
	if found then
	    pos = {x=tonumber(x), y=tonumber(y), z=tonumber(z)}
	elseif param == "" then
	    player = minetest.get_player_by_name(name)
	    if player then
		pos = player:getpos()
	    else
		return "Unable to get position"
	    end
	else
	    return "Invalid usage, see /area help pos2"
	end
	pos = vector.round(pos)
	areas:setPos2(name, pos)
	return "Area position 2 set to "..minetest.pos_to_string(pos), true
    end
}


subcmd.pos = {
    params = "set/set1/set2/get",
    desc = "Set area protection region, position 1, or position 2"
    .." by punching nodes, or display the region",
    privs = {},
    exec = function(name, param)
	if param == "set" then
	    areas.set_pos[name] = "pos1"
	    return "Select positions by punching two nodes", true
	elseif param == "set1" then
	    areas.set_pos[name] = "pos1only"
	    return "Select position 1 by punching a node", true
	elseif param == "set2" then
	    areas.set_pos[name] = "pos2"
	    return "Select position 2 by punching a node", true
	elseif param == "get" then
	    if areas.pos1[name] ~= nil then
		minetest.chat_send_player(name, "Position 1: "
		    ..minetest.pos_to_string(areas.pos1[name]))
	    else
		minetest.chat_send_player(name, "Position 1 not set")
	    end
	    if areas.pos2[name] ~= nil then
		minetest.chat_send_player(name, "Position 2: "
		    ..minetest.pos_to_string(areas.pos2[name]))
	    else
		minetest.chat_send_player(name, "Position 2 not set")
	    end
	    return None, true
	else
	    return "Unknown subcommand: "..param
	end
    end
}

minetest.register_chatcommand("area", {
    params = "<cmd> [name] [args]",
    description = "Commands for working with the areas module. '/area help <cmd>' for help.",
    func =  function(name, param)

        local cmd, args
        cmd, args = string.match(param, "^([^ ]+)(.*)")
        if not cmd then return subcmd.help.exec() end

        if subcmd[cmd] then

            if subcmd.privs then
                local has_privs, missing_privs = minetest.check_player_privs(name, subcmd.privs)
                if not has_privs then
                    return "You don't have permission"
                            .." to run this command (missing privileges: "
                            ..table.concat(missing_privs, ", ")..")"
                end
            end

            if args then args = string.sub(args, 2) end
            reply, success = subcmd[cmd].exec(name, args)
            return reply, success
        end
        return "No such area command '"..cmd.."' - see '/area help'"

    end

})


