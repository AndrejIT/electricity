
-- cache node conn data to use it when unloaded?
electricity.conn_cache = {}

-- Can i make "electricity" code simplier?

-- Get node face direction
function electricity.get_node_face_direction(pos)
    local node = minetest.get_node(pos)
    local node_reg = minetest.registered_nodes[node.name]

    local face_vector = nil
    if node_reg.paramtype2 == "wallmounted" then
        face_vector = vector.multiply(minetest.wallmounted_to_dir(node.param2), -1)
    elseif node_reg.paramtype2 == "facedir" then
        face_vector = vector.multiply(minetest.facedir_to_dir(node.param2), -1)
    else
        face_vector = vector.new(1,0,0)
    end
    return face_vector
end

-- check if first rule connects to pos
function electricity.check_relative_rule(self_pos, to_pos)
    local node = minetest.get_node(self_pos)
    local node_reg = minetest.registered_nodes[node.name]
    if  node_reg and
        node_reg.electricity and
        node_reg.electricity.rules
    then
        local allrules = node_reg.electricity.rules
        local face_vector = electricity.get_node_face_direction(self_pos)
        local down_vector = nil
        if allrules[1] and allrules[1].x then
            for _, rule in ipairs(allrules) do
                if vector.equals(electricity.get_pos_relative(self_pos, rule, face_vector, down_vector), to_pos) then
                    return true
                end
            end
        elseif allrules[1] then
            metarule = allrules[1]
        	for _, rule in ipairs(metarule) do
                if vector.equals(electricity.get_pos_relative(self_pos, rule, face_vector, down_vector), to_pos) then
                    return true
                end
            end
        end
    end
    return false
end

-- get list of all connected positions for first rule
function electricity.get_connected_pos(self_pos)
    local h = minetest.hash_node_position(self_pos)

    local node = minetest.get_node_or_nil(self_pos)

    -- return from cache when not loaded or has not loaded neighbor
    if electricity.conn_cache[h] then
        if not node then
            return electricity.conn_cache[h]
        end

        local n1 = minetest.get_node_or_nil({x=self_pos.x+1, y=self_pos.y, z=self_pos.z})
        local n2 = minetest.get_node_or_nil({x=self_pos.x-1, y=self_pos.y, z=self_pos.z})
        local n3 = minetest.get_node_or_nil({x=self_pos.x, y=self_pos.y, z=self_pos.z+1})
        local n4 = minetest.get_node_or_nil({x=self_pos.x, y=self_pos.y, z=self_pos.z-1})
        local n5 = minetest.get_node_or_nil({x=self_pos.x, y=self_pos.y+1, z=self_pos.z})
        local n6 = minetest.get_node_or_nil({x=self_pos.x, y=self_pos.y-1, z=self_pos.z})

        if not n1 or not n2 or not n3 or not n4 or not n5 or not n6 then
            return electricity.conn_cache[h]
        end
    end

    local node_reg = minetest.registered_nodes[node.name]
    if  node_reg and
        node_reg.electricity and
        node_reg.electricity.rules
    then
        local allrules = node_reg.electricity.rules
        local face_vector = electricity.get_node_face_direction(self_pos)
        local down_vector = nil
        local connected_pos_list = {}
        if allrules[1] and allrules[1].x then
            for _, rule in ipairs(allrules) do
                local to_pos = electricity.get_pos_relative(self_pos, rule, face_vector, down_vector)
                -- minetest.chat_send_all(minetest.serialize(rule))
                -- minetest.chat_send_all(minetest.serialize(face_vector))
                -- minetest.chat_send_all(minetest.serialize(to_pos))
                -- minetest.chat_send_all(minetest.serialize("-"))
                if electricity.check_relative_rule(to_pos, self_pos) then
                    table.insert(connected_pos_list, to_pos)
                end
            end
        elseif allrules[1] then
            metarule = allrules[1]
        	for _, rule in ipairs(metarule) do
                local to_pos = electricity.get_pos_relative(self_pos, rule, face_vector, down_vector)
                if electricity.check_relative_rule(to_pos, self_pos) then
                    table.insert(connected_pos_list, to_pos)
                end
            end
        end
        electricity.conn_cache[h] = connected_pos_list
        return connected_pos_list
    end
    return {}
end

-- tests if the node can be pushed into, e.g. air, water, grass
function electricity.node_replaceable(name)
	if name == "ignore" then return true end

	if minetest.registered_nodes[name] then
		return minetest.registered_nodes[name].buildable_to or false
	end

	return false
end

-- Trying optimize mesecons object move function
-- Move all objects in one node position to nev position
function electricity.get_move_objects(pos1, objects_near)
    if objects_near == nil then
        objects_near = minetest.get_objects_inside_radius(pos1, 2)
    end
	local objects_to_move = {}

    -- function from mesecoins
	for id, obj in pairs(objects_near) do
		local obj_pos = obj:getpos()
		local cbox = obj:get_properties().collisionbox
		local min_pos = vector.add(obj_pos, vector.new(cbox[1], cbox[2], cbox[3]))
		local max_pos = vector.add(obj_pos, vector.new(cbox[4], cbox[5], cbox[6]))
		local ok = true
		for k, v in pairs(pos1) do
			local edge1, edge2
			if k ~= dir_k then
				edge1 = v - 0.51 -- More than 0.5 to move objects near to the stack.
				edge2 = v + 0.51
			else
				edge1 = v - 0.5 * dir_l
				edge2 = v + (#nodestack + 0.5 * movefactor) * dir_l
				-- Make sure, edge1 is bigger than edge2:
				if edge1 > edge2 then
					edge1, edge2 = edge2, edge1
				end
			end
			if min_pos[k] > edge2 or max_pos[k] < edge1 then
				ok = false
				break
			end
		end
		if ok then
            objects_to_move[id] = obj
        end
    end

    return objects_to_move
end

function electricity.move_objects(objects_to_move, pos1, pos2)
    local dir = vector.subtract(pos2, pos1)
    if dir.y == 1 then
        -- Fix for player foot falling inside node
        dir.y = 1.1
    end
    for id, obj in pairs(objects_to_move) do
        local obj_pos = obj:getpos()
        local np = vector.add(obj_pos, dir)
        obj:move_to(np)
	end

end

-- this function is available separatelly in coordinate_helper mod
if _G['get_pos_relative'] then   --check global table if function already defined from coordinate_helper mod
    electricity.get_pos_relative = get_pos_relative
else
    -- x-FRONT/BACK, z-LEFT/RIGHT, y-UP/DOWN
    function electricity.get_pos_relative(position, rel_pos, face_vector, down_vector)
        local pos = {x=position.x,y=position.y,z=position.z}

        assert(vector.length(face_vector) == 1, "Incorrect face vector")

        -- oh no! "wallmounted" and "facedir" cannot store down vector. i choose defaults.
        if not down_vector then
            down_vector = {x=0, y=0, z=0}
            if face_vector.y == 1 then
                down_vector.x = 1
            elseif face_vector.y == -1 then
                down_vector.x = -1
            else
                down_vector.y = -1
            end
        end

        assert(vector.length(down_vector) == 1, "Incorrect down vector")
        assert(vector.length(vector.multiply(face_vector, down_vector)) == 0, "Down vector incompatible with face vector")

        if rel_pos.x == 0 and rel_pos.y == 0 and rel_pos.z == 0 then
            return {x=pos.x, y=pos.y, z=pos.z}
        end

        local fdir = face_vector
        local ddir = down_vector

        if fdir.x == 1 then -- NORD
            pos.x = pos.x + rel_pos.x
            if ddir.y == -1 then
                pos.y = pos.y + rel_pos.y
                pos.z = pos.z + rel_pos.z
            elseif ddir.x == 1 then
                assert(false, "Impossible vector combination!")
            elseif ddir.x == -1 then
                assert(false, "Impossible vector combination!")
            elseif ddir.z == 1 then
                pos.y = pos.y + rel_pos.z
                pos.z = pos.z - rel_pos.y
            elseif ddir.z == -1 then
                pos.y = pos.y - rel_pos.z
                pos.z = pos.z + rel_pos.y
            elseif ddir.y == 1 then
                pos.y = pos.y - rel_pos.y
                pos.z = pos.z - rel_pos.z
            end
        elseif fdir.z == -1 then -- EAST
            pos.z = pos.z - rel_pos.x
            if ddir.y == -1 then
                pos.y = pos.y + rel_pos.y
                pos.x = pos.x + rel_pos.z
            elseif ddir.x == 1 then
                pos.y = pos.y + rel_pos.z
                pos.x = pos.x - rel_pos.y
            elseif ddir.x == -1 then
                pos.y = pos.y - rel_pos.z
                pos.x = pos.x + rel_pos.y
            elseif ddir.z == 1 then
                assert(false, "Impossible vector combination!")
            elseif ddir.z == -1 then
                assert(false, "Impossible vector combination!")
            elseif ddir.y == 1 then
                pos.y = pos.y - rel_pos.y
                pos.x = pos.x - rel_pos.z
            end
        elseif fdir.x == -1 then -- SOUTH
            pos.x = pos.x - rel_pos.x
            if ddir.y == -1 then
                pos.y = pos.y + rel_pos.y
                pos.z = pos.z - rel_pos.z
            elseif ddir.x == 1 then
                assert(false, "Impossible vector combination!")
            elseif ddir.x == -1 then
                assert(false, "Impossible vector combination!")
            elseif ddir.z == 1 then
                pos.y = pos.y - rel_pos.z
                pos.z = pos.z - rel_pos.y
            elseif ddir.z == -1 then
                pos.y = pos.y + rel_pos.z
                pos.z = pos.z + rel_pos.y
            elseif ddir.y == 1 then
                pos.y = pos.y - rel_pos.y
                pos.z = pos.z + rel_pos.z
            end
        elseif fdir.z == 1 then -- WEST
            pos.z = pos.z + rel_pos.x
            if ddir.y == -1 then
                pos.y = pos.y + rel_pos.y
                pos.x = pos.x - rel_pos.z
            elseif ddir.x == 1 then
                pos.y = pos.y - rel_pos.z
                pos.x = pos.x - rel_pos.y
            elseif ddir.x == -1 then
                pos.y = pos.y + rel_pos.z
                pos.x = pos.x + rel_pos.y
            elseif ddir.z == 1 then
                assert(false, "Impossible vector combination!")
            elseif ddir.z == -1 then
                assert(false, "Impossible vector combination!")
            elseif ddir.y == 1 then
                pos.y = pos.y - rel_pos.y
                pos.x = pos.x + rel_pos.z
            end
        elseif fdir.y == 1 then -- UP
            pos.y = pos.y + rel_pos.x
            if ddir.y == -1 then
                assert(false, "Impossible vector combination!")
            elseif ddir.x == 1 then
                pos.x = pos.x - rel_pos.y
                pos.z = pos.z + rel_pos.z
            elseif ddir.x == -1 then
                pos.x = pos.x + rel_pos.y
                pos.z = pos.z - rel_pos.z
            elseif ddir.z == 1 then
                pos.x = pos.x - rel_pos.z
                pos.z = pos.z - rel_pos.y
            elseif ddir.z == -1 then
                pos.x = pos.x + rel_pos.z
                pos.z = pos.z + rel_pos.y
            elseif ddir.y == 1 then
                assert(false, "Impossible vector combination!")
            end
        elseif fdir.y == -1 then -- DOWN
            pos.y = pos.y - rel_pos.x
            if ddir.y == -1 then
                assert(false, "Impossible vector combination!")
            elseif ddir.x == 1 then
                pos.x = pos.x - rel_pos.y
                pos.z = pos.z - rel_pos.z
            elseif ddir.x == -1 then
                pos.x = pos.x + rel_pos.y
                pos.z = pos.z + rel_pos.z
            elseif ddir.z == 1 then
                pos.x = pos.x + rel_pos.z
                pos.z = pos.z - rel_pos.y
            elseif ddir.z == -1 then
                pos.x = pos.x - rel_pos.z
                pos.z = pos.z + rel_pos.y
            elseif ddir.y == 1 then
                assert(false, "Impossible vector combination!")
            end
        end
        return pos
    end
end
