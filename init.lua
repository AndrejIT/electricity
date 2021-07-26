


electricity = {}
-- nodes electricity level. store only until server restart.
electricity.rdata = {}
electricity.producers = {}   -- pos of all electricity producers.
electricity.not_producers = {}   -- pos of all other electricity nodes.
-- electricity.rdata2 = {}    -- additional rule sets
-- electricity.rdata3 = {}

dofile(minetest.get_modpath("electricity").."/internal.lua")

-- dofile(minetest.get_modpath("electricity").."/link_core.lua")

-- a little recursion to distribute voltage from producers
function electricity.traverse_connected_nodes(self_pos)
    local h = minetest.hash_node_position(self_pos)
    local volt = electricity.get(self_pos, self_pos)

    if volt == 0 then
        return
    end

    local neighbors = electricity.get_connected_pos(self_pos)
    for _, pos in ipairs(neighbors) do
        local volt_n = electricity.get(pos, self_pos)
        if volt_n == 0 then
            electricity.set(pos, self_pos, 1)
            -- recurse another nodes
            electricity.traverse_connected_nodes(pos)
        end
    end
end

-- Swap electricity node on or off
function electricity.swap_on_off(self_pos)
    local node = minetest.get_node(self_pos)
    local node_reg = minetest.registered_nodes[node.name]
    if  node_reg and
        node_reg.electricity
    then
        local volt = electricity.get(self_pos, self_pos)
        if volt == 1 and node.name == node_reg.electricity.name_off then
            node.name = node_reg.electricity.name_on
            minetest.swap_node(self_pos, node)
        elseif volt == 0 and node.name == node_reg.electricity.name_on then
            node.name = node_reg.electricity.name_off
            minetest.swap_node(self_pos, node)
        end
    end
end

function electricity.set(self_pos, from_pos, count)
    local h = minetest.hash_node_position(self_pos)
    electricity.rdata[h] = count
    return 0
end

function electricity.get(self_pos, from_pos)
    local h = minetest.hash_node_position(self_pos)
    local count = 0
    if electricity.rdata[h] ~= nil then
        count = electricity.rdata[h]
    end
    return count
end


-- electricity register nodes
minetest.register_abm{
    label = "electricity node setup",
	nodenames = {"group:electricity_conductor", "group:electricity_consumer"},
	interval = 5,
	chance = 1,
    catch_up = false,
	action = function(pos)
        local h = minetest.hash_node_position(pos)
        if electricity.not_producers[h] == nil then
            electricity.not_producers[h] = pos
            electricity.set(pos, pos, 0)
        end
	end,
}

minetest.register_abm{
    label = "electricity node setup",
	nodenames = {"group:electricity_producer"},
	interval = 5,
	chance = 1,
    catch_up = false,
	action = function(pos)
        local h = minetest.hash_node_position(pos)
        if electricity.producers[h] == nil then
            electricity.producers[h] = pos
            electricity.set(pos, pos, 0)
        end
	end,
}

-- electricity works
minetest.register_abm{
    label = "electricity contsumption",
	nodenames = {"group:electricity_consumer", "group:electricity_conductor"},
	interval = 1,
	chance = 1,
    catch_up = false,
	action = function(pos)
        electricity.swap_on_off(pos)
	end,
}


local timer = 0
minetest.register_globalstep(function(dtime)
	timer = timer + dtime;
	if timer >= 2 then
        -- recalculate vhere is voltage.
        for _, pos in pairs(electricity.not_producers) do
            electricity.set(pos, pos, 0)
        end
		for _, pos in pairs(electricity.producers) do
            electricity.traverse_connected_nodes(pos)
        end
		timer = 0
	end
end)


local wire_definition_base = {
    description = "Electricity wire",
    drop = "electricity:wire_off",
    inventory_image = "electricity_wire_inv.png",
    wield_image = "electricity_wire_inv.png",
    tiles = {"electricity_wire_off.png"},
    paramtype = "light",
    drawtype = "nodebox",
	node_box = {
		type = "fixed",
		fixed = {
				{-0.1, -0.5, -0.5, 0.1, -0.45, 0.5},
			},
		},
    paramtype2 = "facedir",
    is_ground_content = false,
    sunlight_propagates = true,
    walkable = false,
    on_construct = function(pos, node, digger)
        local h = minetest.hash_node_position(pos)
        electricity.not_producers[h] = pos
        electricity.set(pos, pos, 0)
    end,
    after_destruct = function(pos)
        local h = minetest.hash_node_position(pos)
        electricity.not_producers[h] = nil
        electricity.rdata[h] = nil
    end,
    electricity = {
        rules = {
            {x=1,y=0,z=0},  -- front
            {x=-1,y=0,z=0}, -- back
            {x=0,y=-1,z=0}, -- bottom?
        },
        name_on = "electricity:wire_on",
        name_off = "electricity:wire_off",
    },
    groups = {electricity = 1, electricity_conductor = 1, cracky = 3, oddly_breakable_by_hand = 3},    -- remove electricity = 1 to preserve resources
}

-- WIRE --
local wire_definition = table.copy(wire_definition_base)    -- careful, this copy is not deep
minetest.register_node("electricity:wire_off", wire_definition)
wire_definition = table.copy(wire_definition)
wire_definition.tiles = {"electricity_wire_on.png"}
wire_definition.groups["not_in_creative_inventory"] = 1
minetest.register_node("electricity:wire_on", wire_definition)

-- WIRE BEND --
local wire_bend_definition = table.copy(wire_definition_base)
wire_bend_definition.description = "Electricity wire bend"
wire_bend_definition.drop = "electricity:wire_bend_off"
wire_bend_definition.inventory_image = "electricity_wire_bend_inv.png"
wire_bend_definition.wield_image = "electricity_wire_bend_inv.png"
wire_bend_definition.node_box = {
    type = "fixed",
    fixed = {
        {-0.1, -0.5, -0.5, 0.1, -0.45, 0.1},    -- z=-1
        {-0.5, -0.5, -0.1, -0.1, -0.45, 0.1},   -- x=1
    },
}
wire_bend_definition.electricity = {
    rules = {
        {x=1,y=0,z=0},
        {x=0,y=0,z=-1},
        {x=0,y=-1,z=0},
    },
    name_on = "electricity:wire_bend_on",
    name_off = "electricity:wire_bend_off",
}
minetest.register_node("electricity:wire_bend_off", wire_bend_definition)
wire_bend_definition = table.copy(wire_bend_definition)
wire_bend_definition.tiles = {"electricity_wire_on.png"}
wire_bend_definition.groups["not_in_creative_inventory"] = 1
minetest.register_node("electricity:wire_bend_on", wire_bend_definition)

-- WIRE BRANCH --
local wire_branch_definition = table.copy(wire_definition_base)
wire_branch_definition.description = "Electricity wire branch"
wire_branch_definition.drop = "electricity:wire_branch_off"
wire_branch_definition.inventory_image = "electricity_wire_branch_inv.png"
wire_branch_definition.wield_image = "electricity_wire_branch_inv.png"
wire_branch_definition.node_box = {
    type = "fixed",
    fixed = {
        {-0.1, -0.5, -0.5, 0.1, -0.45, 0.1},    -- z=-1
        {-0.5, -0.5, -0.1, -0.1, -0.45, 0.1},   -- x=1
        {0.1, -0.5, -0.1, 0.5, -0.45, 0.1},     -- x=-1
    },
}
wire_branch_definition.electricity = {
    rules = {
        {x=1,y=0,z=0},
        {x=0,y=0,z=-1},
        {x=0,y=0,z=1},
        {x=0,y=-1,z=0},
    },
    name_on = "electricity:wire_branch_on",
    name_off = "electricity:wire_branch_off",
}
minetest.register_node("electricity:wire_branch_off", wire_branch_definition)
wire_branch_definition = table.copy(wire_branch_definition)
wire_branch_definition.tiles = {"electricity_wire_on.png"}
wire_branch_definition.groups["not_in_creative_inventory"] = 1
minetest.register_node("electricity:wire_branch_on", wire_branch_definition)

-- WIRE BEND UP --
local wire_bend_up_definition = table.copy(wire_definition_base)
wire_bend_up_definition.description = "Electricity wire bend up"
wire_bend_up_definition.drop = "electricity:wire_bend_up_off"
wire_bend_up_definition.inventory_image = "electricity_wire_bend_up_inv.png"
wire_bend_up_definition.wield_image = "electricity_wire_bend_up_inv.png"
wire_bend_up_definition.node_box = {
    type = "fixed",
    fixed = {
        {-0.1, -0.5, -0.5, 0.1, -0.45, -0.1},    -- z=-1
        {-0.1, -0.5, -0.1, 0.1, 0.5, 0.1},      -- y=1
    },
}
wire_bend_up_definition.electricity = {
    rules = {
        {x=1,y=0,z=0},
        {x=0,y=1,z=0},
        {x=0,y=-1,z=0},
    },
    name_on = "electricity:wire_bend_up_on",
    name_off = "electricity:wire_bend_up_off",
}
minetest.register_node("electricity:wire_bend_up_off", wire_bend_up_definition)
wire_bend_up_definition = table.copy(wire_bend_up_definition)
wire_bend_up_definition.tiles = {"electricity_wire_on.png"}
wire_bend_up_definition.groups["not_in_creative_inventory"] = 1
minetest.register_node("electricity:wire_bend_up_on", wire_bend_up_definition)

-- WIRE UP --
local wire_up_definition = table.copy(wire_definition_base)
wire_up_definition.description = "Electricity wire vertical"
wire_up_definition.drop = "electricity:wire_up_off"
wire_up_definition.inventory_image = "electricity_wire_up_inv.png"
wire_up_definition.wield_image = "electricity_wire_up_inv.png"
wire_up_definition.node_box = {
    type = "fixed",
    fixed = {
        {-0.1, -0.5, -0.1, 0.1, 0.5, 0.1},   -- y=1
    },
}
wire_up_definition.electricity = {
    rules = {
        {x=0,y=1,z=0},
        {x=0,y=-1,z=0},
    },
    name_on = "electricity:wire_up_on",
    name_off = "electricity:wire_up_off",
}
minetest.register_node("electricity:wire_up_off", wire_up_definition)
wire_up_definition = table.copy(wire_up_definition)
wire_up_definition.tiles = {"electricity_wire_on.png"}
wire_up_definition.groups["not_in_creative_inventory"] = 1
minetest.register_node("electricity:wire_up_on", wire_up_definition)

-- WIRE BRANCH UP --
local wire_branch_up_definition = table.copy(wire_definition_base)
wire_branch_up_definition.description = "Electricity wire branch up"
wire_branch_up_definition.drop = "electricity:wire_branch_up_off"
wire_branch_up_definition.inventory_image = "electricity_wire_branch_up_inv.png"
wire_branch_up_definition.wield_image = "electricity_wire_branch_up_inv.png"
wire_branch_up_definition.node_box = {
    type = "fixed",
    fixed = {
        {-0.1, -0.5, -0.5, 0.1, -0.45, -0.1},    -- z=-1
        {-0.1, -0.5, -0.1, 0.1, 0.5, 0.1},      -- y=1
        {-0.1, -0.5, 0.1, 0.1, -0.45, 0.5},    -- z=1
    },
}
wire_branch_up_definition.electricity = {
    rules = {
        {x=1,y=0,z=0},
        {x=-1,y=0,z=0},
        {x=0,y=1,z=0},
        {x=0,y=-1,z=0},
    },
    name_on = "electricity:wire_branch_up_on",
    name_off = "electricity:wire_branch_up_off",
}
minetest.register_node("electricity:wire_branch_up_off", wire_branch_up_definition)
wire_branch_up_definition = table.copy(wire_branch_up_definition)
wire_branch_up_definition.tiles = {"electricity_wire_on.png"}
wire_branch_up_definition.groups["not_in_creative_inventory"] = 1
minetest.register_node("electricity:wire_branch_up_on", wire_branch_up_definition)

-- WIRE HALF --
local wire_half_definition = table.copy(wire_definition_base)
wire_half_definition.description = "Electricity wire half"
wire_half_definition.drop = "electricity:wire_half_off"
wire_half_definition.inventory_image = "electricity_wire_half_inv.png"
wire_half_definition.wield_image = "electricity_wire_half_inv.png"
wire_half_definition.node_box = {
    type = "fixed",
    fixed = {
        {-0.1, -0.5, -0.5, 0.1, -0.45, 0.1},    -- z=-1
    },
}
wire_half_definition.electricity = {
    rules = {
        {x=1,y=0,z=0},
        {x=0,y=-1,z=0},
    },
    name_on = "electricity:wire_half_on",
    name_off = "electricity:wire_half_off",
}
minetest.register_node("electricity:wire_half_off", wire_half_definition)
wire_half_definition = table.copy(wire_half_definition)
wire_half_definition.tiles = {"electricity_wire_on.png"}
wire_half_definition.groups["not_in_creative_inventory"] = 1
minetest.register_node("electricity:wire_half_on", wire_half_definition)


-- LAMP --
local lamp_definition_base = {
    description = "Electricity lamp",
    drop = "electricity:lamp_off",
    inventory_image = "jeija_meselamp.png",
    wield_image = "jeija_meselamp.png",
    tiles = {"lamp_off.png","lamp_off.png","lamp_off.png"},
    paramtype = "light",
    drawtype = "nodebox",
	node_box = {
        type = "wallmounted",
        wall_top = { -0.5, 0.3, -0.5, 0.5, 0.5, 0.5 },
    	wall_bottom = { -0.5, -0.5, -0.5, 0.5, -0.3, 0.5 },
    	wall_side = { -0.3, -0.5, -0.5, -0.5, 0.5, 0.5 },
		},
    paramtype2 = "wallmounted",
    is_ground_content = false,
    on_construct = function(pos)
        local h = minetest.hash_node_position(pos)
        electricity.not_producers[h] = pos
        electricity.set(pos, pos, 0)
        -- minetest.get_node_timer(pos):start(1.0)
    end,
    after_destruct = function(pos)
        local h = minetest.hash_node_position(pos)
        electricity.not_producers[h] = nil
        electricity.rdata[h] = nil
    end,
    electricity = {
        rules = {
            {x=0,y=1,z=0},  -- left :|
            {x=-1,y=0,z=0}, -- bottom :|
            {x=0,y=0,z=1},
            {x=0,y=0,z=-1},
            {x=0,y=-1,z=0},
        },
        name_on = "electricity:lamp_on",
        name_off = "electricity:lamp_off",
    },
    groups = {electricity = 1, electricity_consumer = 1, cracky = 3, oddly_breakable_by_hand = 3},
    sounds = default.node_sound_stone_defaults(),
}

local lamp_definition = table.copy(lamp_definition_base)
minetest.register_node("electricity:lamp_off", lamp_definition)
lamp_definition = table.copy(lamp_definition)
lamp_definition.light_source = minetest.LIGHT_MAX
lamp_definition.tiles = {"lamp_on.png","lamp_on.png","lamp_on.png"}
lamp_definition.groups["not_in_creative_inventory"] = 1
minetest.register_node("electricity:lamp_on", lamp_definition)

-- PRESSURE PLATE --
function electricity.plate_on_timer(self_pos, elapsed)
	local node = minetest.get_node(self_pos)
    local node_reg = minetest.registered_nodes[node.name]
    if  node_reg and
        node_reg.electricity and
        node_reg.electricity.name_enabled
    then
    	local objs   = minetest.get_objects_inside_radius(self_pos, 1)
    	if objs[1] ~= nil then
            if node.name == node_reg.electricity.name_disabled then
                node.name = node_reg.electricity.name_enabled
                minetest.swap_node(self_pos, node)
            end
        else
            if node.name == node_reg.electricity.name_enabled then
                node.name = node_reg.electricity.name_disabled
                minetest.swap_node(self_pos, node)
            end
    	end
    end
end

local plate_definition_base = {
    description = "Electricity pressure plate",
    drop = "electricity:pressure_plate_off",
    inventory_image = "jeija_pressure_plate_stone_inv.png",
    wield_image = "jeija_pressure_plate_stone_wield.png",
    tiles = {"jeija_pressure_plate_stone_off.png","jeija_pressure_plate_stone_off.png","jeija_pressure_plate_stone_off_edges.png"},
    paramtype = "light",
    drawtype = "nodebox",
	node_box = {
        type = "fixed",
    	fixed = { -0.5, -0.5, -0.5, 0.5, -7/16, 0.5 },
		},
    paramtype2 = "facedir",
    is_ground_content = false,
    on_timer = function(pos, elapsed)
        electricity.plate_on_timer(pos, elapsed)
        return true
    end,
    on_construct = function(pos)
        local h = minetest.hash_node_position(pos)
        electricity.not_producers[h] = pos
        electricity.set(pos, pos, 0)
        minetest.get_node_timer(pos):start(0.5)
    end,
    after_destruct = function(pos)
        local h = minetest.hash_node_position(pos)
        electricity.not_producers[h] = nil
        electricity.rdata[h] = nil
    end,
    electricity = {
        rules = {
        },
        name_enabled = "electricity:pressure_plate_on",
        name_disabled = "electricity:pressure_plate_off",
    },
    groups = {electricity = 1, electricity_conductor = 1, cracky = 3, oddly_breakable_by_hand = 3},
    sounds = default.node_sound_stone_defaults(),
}

local plate_definition = table.copy(plate_definition_base)
minetest.register_node("electricity:pressure_plate_off", plate_definition)
plate_definition = table.copy(plate_definition)
plate_definition.tiles = {"jeija_pressure_plate_stone_on.png","jeija_pressure_plate_stone_on.png","jeija_pressure_plate_stone_on_edges.png"}
plate_definition.node_box.fixed = { -0.5, -0.5, -0.5, 0.5, -7.5/16, 0.5 }
plate_definition.electricity.rules = {
    {x=0,y=-1,z=0},  -- bottom :|
    {x=-1,y=0,z=0}, -- front :|
    {x=1,y=0,z=0},
    {x=0,y=0,z=-1},
    {x=0,y=0,z=1},
}
plate_definition.groups["not_in_creative_inventory"] = 1
minetest.register_node("electricity:pressure_plate_on", plate_definition)

-- SOLAR PANEL --
function electricity.solar_on_timer(self_pos, elapsed)
	local node = minetest.get_node(self_pos)
    local node_reg = minetest.registered_nodes[node.name]
    local light = minetest.get_node_light(self_pos, nil)
    local day = false
    if minetest.get_timeofday() > 0.25 and minetest.get_timeofday() < 0.75 then
        day = true
    end
    local altitude = self_pos.y -- More stable electricity if higher position
    if altitude < 0 then
        altitude = 0
    elseif altitude > 25 then
        altitude = 25
    end
    if  node_reg and
        node_reg.electricity and
        day and
        light >= 12 and
        altitude > 0 and
        math.random(0, 75+altitude) > 70
    then
        electricity.set(self_pos, self_pos, 1)  -- produce lectricity
    else
        electricity.set(self_pos, self_pos, 0)  -- no electricity
    end
end

local solar_definition_base = {
    description = "Electricity solar panel",
    inventory_image = "jeija_solar_panel.png",
    wield_image = "jeija_solar_panel.png",
    tiles = {"jeija_solar_panel.png","jeija_solar_panel.png","jeija_solar_panel.png"},
    paramtype = "light",
    drawtype = "nodebox",
	node_box = {
        type = "wallmounted",
        wall_top = { -0.5, 0.4, -0.5, 0.5, 0.5, 0.5 },
    	wall_bottom = { -0.5, -0.5, -0.5, 0.5, -0.4, 0.5 },
    	wall_side = { -0.4, -0.5, -0.5, -0.5, 0.5, 0.5 },
		},
    paramtype2 = "wallmounted",
    is_ground_content = false,
    on_timer = function(pos, elapsed)
        electricity.solar_on_timer(pos, elapsed)
        return true
    end,
    on_construct = function(pos)
        local h = minetest.hash_node_position(pos)
        electricity.producers[h] = pos
        electricity.set(pos, pos, 0)
        minetest.get_node_timer(pos):start(1.5)
    end,
    after_destruct = function(pos)
        local h = minetest.hash_node_position(pos)
        electricity.producers[h] = nil
        electricity.rdata[h] = nil
    end,
    electricity = {
        rules = {
            {x=0,y=1,z=0},  -- left :|
            {x=-1,y=0,z=0}, -- bottom :|
            {x=0,y=0,z=1},
            {x=0,y=0,z=-1},
            {x=0,y=-1,z=0},
        },
        name_enabled = "electricity:solar",
        -- name_disabled = "electricity:solar",
    },
    groups = {electricity = 1, electricity_producer = 1, cracky = 3, oddly_breakable_by_hand = 3},
    sounds = default.node_sound_stone_defaults(),
}

local solar_definition = table.copy(solar_definition_base)
minetest.register_node("electricity:solar", solar_definition)

-- LEVER --
function electricity:lever_on_rightclick(self_pos, node)
    -- local node = minetest.get_node(self_pos)
    local node_reg = minetest.registered_nodes[node.name]
    if node.name == node_reg.electricity.name_disabled then
        node.name = node_reg.electricity.name_enabled
        minetest.swap_node(self_pos, node)
    else
        node.name = node_reg.electricity.name_disabled
        minetest.swap_node(self_pos, node)
    end
    minetest.sound_play("mesecons_lever", {
        pos = self_pos,
        max_hear_distance = 16,
        gain = 10.0,
    })
end

local lever_definition_base = {
    description = "Electricity lever",
    drop = "electricity:lever_off",
    inventory_image = "jeija_wall_lever_inv.png",
    wield_image = "jeija_wall_lever_inv.png",
    tiles = {
		"jeija_wall_lever_lever_light_off.png",
		"jeija_wall_lever_front.png",
		"jeija_wall_lever_front_bump.png",
		"jeija_wall_lever_back_edges.png"
	},
    paramtype = "light",
    drawtype = "mesh",
	mesh = "jeija_wall_lever_off.obj",
    selection_box = {
        type = "fixed",
        fixed = { -0.5, -0.5, 0.2, 0.5, 0.5, 0.5 },
    },
    paramtype2 = "facedir",
    is_ground_content = false,
	sunlight_propagates = true,
	walkable = false,
    on_rightclick = function (pos, node)
        electricity:lever_on_rightclick(pos, node)
	end,
    on_construct = function(pos)
        local h = minetest.hash_node_position(pos)
        electricity.not_producers[h] = pos
        electricity.set(pos, pos, 0)
    end,
    after_destruct = function(pos)
        local h = minetest.hash_node_position(pos)
        electricity.not_producers[h] = nil
        electricity.rdata[h] = nil
    end,
    electricity = {
        rules = {
        },
        name_enabled = "electricity:lever_on",
        name_disabled = "electricity:lever_off",
    },
    groups = {electricity = 1, electricity_conductor = 1, cracky = 3, oddly_breakable_by_hand = 3},
    sounds = default.node_sound_wood_defaults(),
}

local lever_definition = table.copy(lever_definition_base)
minetest.register_node("electricity:lever_off", lever_definition)
lever_definition = table.copy(lever_definition)
lever_definition.tiles = {
    "jeija_wall_lever_lever_light_on.png",
    "jeija_wall_lever_front.png",
    "jeija_wall_lever_front_bump.png",
    "jeija_wall_lever_back_edges.png"
}
lever_definition.groups["not_in_creative_inventory"] = 1
lever_definition.mesh = "jeija_wall_lever_on.obj"
lever_definition.electricity.rules = {
    {x=0,y=1,z=0},
    {x=-1,y=0,z=0},
    {x=0,y=0,z=1},
    {x=0,y=0,z=-1},
    {x=0,y=-1,z=0},
}
minetest.register_node("electricity:lever_on", lever_definition)

-- TRANSISTOR
function electricity.transistor_on_timer(self_pos, elapsed)
	local node = minetest.get_node(self_pos)
    local node_reg = minetest.registered_nodes[node.name]
    if  node_reg and
        node_reg.electricity and
        node_reg.electricity.name_enabled
    then
        local face_vector = nil
        if node_reg.paramtype2 == "wallmounted" then
            face_vector = vector.multiply(minetest.wallmounted_to_dir(node.param2), -1)
        elseif node_reg.paramtype2 == "facedir" then
            face_vector = vector.multiply(minetest.facedir_to_dir(node.param2), -1)
        else
            face_vector = vector.new(1,0,0)
        end

    	local base_pos = get_pos_relative(self_pos, {x=0, y=0, z=-1}, face_vector)
        local h = minetest.hash_node_position(base_pos)
        local volt = 0
        if electricity.rdata[h] ~= nil then
            volt = electricity.rdata[h]
        end
    	if electricity.check_relative_rule(base_pos, self_pos) and volt == 1 then
            if node.name == node_reg.electricity.name_disabled then
                node.name = node_reg.electricity.name_enabled
                minetest.swap_node(self_pos, node)
            end
        else
            if node.name == node_reg.electricity.name_enabled then
                node.name = node_reg.electricity.name_disabled
                minetest.swap_node(self_pos, node)
            end
    	end
    end
end

local transistor_definition_base = {
    description = "Electricity transistor",
    drop = "electricity:transistor_off",
    inventory_image = "electricity_transistor.png",
    wield_image = "electricity_transistor.png",
    drawtype = "nodebox",
    selection_box = {
    	type = "fixed",
    	fixed = {{-8/16, -8/16, -8/16, 8/16, -7/16, 8/16 }},
    },
    node_box = {
    	type = "fixed",
    	fixed = {{-8/16, -8/16, -8/16, 8/16, -7/16, 8/16 }},
    },
    tiles = {"electricity_transistor.png^".."jeija_gate_off.png^"..
        "electricity_transistor.png"},
    paramtype = "light",
    paramtype2 = "facedir",
    is_ground_content = false,
	sunlight_propagates = true,
	walkable = false,
    on_timer = function(pos, elapsed)
        electricity.transistor_on_timer(pos, elapsed)
        return true
    end,
    on_construct = function(pos)
        local h = minetest.hash_node_position(pos)
        electricity.not_producers[h] = pos
        electricity.set(pos, pos, 0)
        minetest.get_node_timer(pos):start(0.5)
    end,
    after_destruct = function(pos)
        local h = minetest.hash_node_position(pos)
        electricity.not_producers[h] = nil
        electricity.rdata[h] = nil
    end,
    electricity = {
        rules = {
        },
        name_enabled = "electricity:transistor_on",
        name_disabled = "electricity:transistor_off",
    },
    groups = {electricity = 1, electricity_conductor = 1, cracky = 3, oddly_breakable_by_hand = 3},
    sounds = default.node_sound_wood_defaults(),
}

local transistor_definition = table.copy(transistor_definition_base)
minetest.register_node("electricity:transistor_off", transistor_definition)
transistor_definition = table.copy(transistor_definition)
transistor_definition.tiles = {"electricity_transistor.png^".."jeija_gate_on.png^"..
    "electricity_transistor.png"}
transistor_definition.groups["not_in_creative_inventory"] = 1
transistor_definition.electricity.rules = {
    {x=-1,y=0,z=0},
    {x=1,y=0,z=0},
    {x=0,y=-1,z=0}, -- also bottom

}
minetest.register_node("electricity:transistor_on", transistor_definition)


-- ##############
-- ## Crafting ##
-- ##############

minetest.register_craft({
	output = "electricity:wire_off",
	recipe = {
		{"default:copper_ingot", "", ""},
		{"default:copper_ingot", "", ""},
		{"default:copper_ingot", "", ""}
	}
})

minetest.register_craft({
	output = "electricity:wire_half_off",
	recipe = {
		{"default:copper_ingot", "", ""},
		{"default:copper_ingot", "", ""},
		{"", "", ""}
	}
})

minetest.register_craft({
    type = "shapeless",
	output = "electricity:wire_bend_off",
	recipe = {"electricity:wire_off"}
})

minetest.register_craft({
    type = "shapeless",
	output = "electricity:wire_branch_off",
    recipe = {"electricity:wire_off", "electricity:wire_half_off"}
})

minetest.register_craft({
    type = "shapeless",
	output = "electricity:wire_bend_up_off",
	recipe = {"electricity:wire_bend_off"}
})

minetest.register_craft({
    type = "shapeless",
	output = "electricity:wire_up_off",
	recipe = {"electricity:wire_bend_up_off"}
})

minetest.register_craft({
    type = "shapeless",
	output = "electricity:wire_off",
	recipe = {"electricity:wire_up_off"},
})

minetest.register_craft({
    type = "shapeless",
	output = "electricity:wire_branch_up_off",
	recipe = {"electricity:wire_branch_off"},
})

minetest.register_craft({
    type = "shapeless",
	output = "electricity:wire_branch_off",
	recipe = {"electricity:wire_branch_up_off"},
})

minetest.register_craft({
	output = "electricity:pressure_plate_off",
	recipe = {
		{"", "default:stonebrick", ""},
		{"electricity:wire_off", "default:copperblock", "electricity:wire_off"},
		{"", "default:steelblock", ""}
	}
})

minetest.register_craft({
	output = "electricity:solar",
	recipe = {
		{"default:glass", "default:glass", "default:glass"},
		{"electricity:wire_off", "default:coalblock", "electricity:wire_off"},
		{"default:obsidian", "default:obsidian", "default:obsidian"}
	}
})

minetest.register_craft({
	output = "electricity:lamp_off",
	recipe = {
		{"", "default:glass", ""},
		{"electricity:wire_off", "default:steelblock", "electricity:wire_off"},
		{"", "default:glass", ""}
	}
})

minetest.register_craft({
	output = "electricity:lever_off",
	recipe = {
		{"", "default:copperblock", ""},
		{"electricity:wire_off", "default:wood", "electricity:wire_off"},
		{"", "default:stick", ""}
	}
})

minetest.register_craft({
	output = "electricity:transistor_off",
	recipe = {
		{"", "electricity:wire_off", ""},
		{"electricity:wire_off", "default:mese_crystal", "electricity:wire_off"},
		{"", "default:obsidian", ""}
	}
})