


electricity = {}
-- nodes electricity level. store only until server restart.
electricity.rdata = {}
electricity.producers = {}   -- pos of all electricity producers.
electricity.not_producers = {}   -- pos of all other electricity nodes.
-- electricity.rdata2 = {}    -- additional rule sets
-- electricity.rdata3 = {}

dofile(minetest.get_modpath("electricity").."/internal.lua")

-- dofile(minetest.get_modpath("electricity").."/link_core.lua")


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

function electricity.conductor_swap_on_off(self_pos)
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

minetest.register_abm{
    label = "electricity conductor",
	nodenames = {"group:electricity_conductor"},
	interval = 1,
	chance = 1,
    catch_up = false,
	action = function(pos)
        electricity.conductor_swap_on_off(pos)
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
        {x=1,y=0,z=0},  -- front
        {x=0,y=0,z=-1}, -- right
        {x=0,y=-1,z=0}, -- bottom
    },
    name_on = "electricity:wire_bend_on",
    name_off = "electricity:wire_bend_off",
}
minetest.register_node("electricity:wire_bend_off", wire_bend_definition)
wire_bend_definition = table.copy(wire_bend_definition)
wire_bend_definition.tiles = {"electricity_wire_on.png"}
wire_bend_definition.groups["not_in_creative_inventory"] = 1
minetest.register_node("electricity:wire_bend_on", wire_bend_definition)

-- WIRE CORNER --
local wire_corner_definition = table.copy(wire_definition_base)
wire_corner_definition.description = "Electricity wire corner"
wire_corner_definition.drop = "electricity:wire_corner_off"
wire_corner_definition.inventory_image = "electricity_wire_corner_inv.png"
wire_corner_definition.wield_image = "electricity_wire_corner_inv.png"
wire_corner_definition.node_box = {
    type = "fixed",
    fixed = {
        {-0.1, -0.5, -0.5, 0.1, -0.45, 0.5},    --
        {-0.1, -0.45, 0.45, 0.1, 0.5, 0.5},    --
        -- {-0.5, -0.5, -0.1, -0.1, -0.45, 0.1},   -- x=1
    },
}
wire_corner_definition.electricity = {
    rules = {
        {x=1,y=0,z=0},  -- front
        {x=-1,y=0,z=0}, -- back
        {x=0,y=1,z=0},  -- top
        {x=0,y=-1,z=0}, -- bottom
    },
    name_on = "electricity:wire_corner_on",
    name_off = "electricity:wire_corner_off",
}
minetest.register_node("electricity:wire_corner_off", wire_corner_definition)
wire_corner_definition = table.copy(wire_corner_definition)
wire_corner_definition.tiles = {"electricity_wire_on.png"}
wire_corner_definition.groups["not_in_creative_inventory"] = 1
minetest.register_node("electricity:wire_corner_on", wire_corner_definition)

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
        {x=1,y=0,z=0},  -- front
        {x=0,y=0,z=-1}, -- right
        {x=0,y=0,z=1},  -- left
        {x=0,y=-1,z=0}, -- bottom
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

-- WIRE IN STONE --
local stone_with_wire_definition = table.copy(wire_definition_base)
stone_with_wire_definition.description = "Electricity wire in stone"
stone_with_wire_definition.drop = "electricity:wire_off"
stone_with_wire_definition.tiles = {
	"default_stone.png",
	"default_stone.png",
	"default_stone.png",
	"default_stone.png",
	"electricity_stone_with_wire_off.png",
	"electricity_stone_with_wire_off.png"
}

stone_with_wire_definition.inventory_image = nil
stone_with_wire_definition.wield_image = nil

stone_with_wire_definition.sounds = default.node_sound_stone_defaults()
stone_with_wire_definition.paramtype = nil
stone_with_wire_definition.drawtype = nil
stone_with_wire_definition.node_box = nil
stone_with_wire_definition.sunlight_propagates = false
stone_with_wire_definition.walkable = true
stone_with_wire_definition.groups = {electricity = 1, electricity_conductor = 1, cracky = 3}

stone_with_wire_definition.electricity = {
    rules = {
        {x=1,y=0,z=0},
        {x=-1,y=0,z=0},
    },
    name_on = "electricity:stone_with_wire_on",
    name_off = "electricity:stone_with_wire_off",
}
minetest.register_node("electricity:stone_with_wire_off", stone_with_wire_definition)
stone_with_wire_definition = table.copy(stone_with_wire_definition)
stone_with_wire_definition.tiles = {
	"default_stone.png",
	"default_stone.png",
	"default_stone.png",
	"default_stone.png",
	"electricity_stone_with_wire_on.png",
	"electricity_stone_with_wire_on.png"
}
stone_with_wire_definition.groups["not_in_creative_inventory"] = 1
minetest.register_node("electricity:stone_with_wire_on", stone_with_wire_definition)


-- LAMP --
function electricity.lamp_on_timer(self_pos, elapsed)
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

local lamp_definition_base = {
    description = "Electricity lamp",
    drop = "electricity:lamp_off",
    inventory_image = "electricity_lamp.png",
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
    on_timer = function(pos, elapsed)
        electricity.lamp_on_timer(pos, elapsed)
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
            {x=0,y=1,z=0},  -- left :|
            {x=-1,y=0,z=0}, -- bottom :|
            {x=0,y=0,z=1},
            {x=0,y=0,z=-1},
            {x=0,y=-1,z=0},
        },
        name_on = "electricity:lamp_on",
        name_off = "electricity:lamp_off",
    },
    groups = {electricity = 1, electricity_consumer = 1, electricity_lamp = 1, cracky = 3, oddly_breakable_by_hand = 3},
    sounds = default.node_sound_stone_defaults(),
}

local lamp_definition = table.copy(lamp_definition_base)
minetest.register_node("electricity:lamp_off", lamp_definition)
lamp_definition = table.copy(lamp_definition)
lamp_definition.light_source = minetest.LIGHT_MAX
lamp_definition.tiles = {"lamp_on.png","lamp_on.png","lamp_on.png"}
lamp_definition.groups["not_in_creative_inventory"] = 1
minetest.register_node("electricity:lamp_on", lamp_definition)

-- All colored lamps only one connection
lamp_definition_base.electricity.rules = {
    {x=-1,y=0,z=0}, -- bottom
};

-- LAMP RED --
local lamp_red_definition = table.copy(lamp_definition_base)
lamp_red_definition.description = "Electricity lamp red";
lamp_red_definition.drop = "electricity:lamp_red_off";
lamp_red_definition.inventory_image = "electricity_lamp_red.png";
-- lamp_red_definition.wield_image = "jeija_meselamp.png";
-- lamp_red_definition.tiles = {"lamp_off.png","lamp_off.png","lamp_off.png"};
lamp_red_definition.electricity.name_on = "electricity:lamp_red_on";
lamp_red_definition.electricity.name_off = "electricity:lamp_red_off";
minetest.register_node("electricity:lamp_red_off", lamp_red_definition)

lamp_red_definition = table.copy(lamp_red_definition)
lamp_red_definition.light_source = minetest.LIGHT_MAX
lamp_red_definition.tiles = {"lamp_red_on.png","lamp_red_on.png","lamp_red_on.png"}
lamp_red_definition.groups["not_in_creative_inventory"] = 1
minetest.register_node("electricity:lamp_red_on", lamp_red_definition)

-- LAMP GREEN --
local lamp_green_definition = table.copy(lamp_definition_base)
lamp_green_definition.description = "Electricity lamp green";
lamp_green_definition.drop = "electricity:lamp_green_off";
lamp_green_definition.inventory_image = "electricity_lamp_green.png";
lamp_green_definition.electricity.name_on = "electricity:lamp_green_on";
lamp_green_definition.electricity.name_off = "electricity:lamp_green_off";
minetest.register_node("electricity:lamp_green_off", lamp_green_definition)

lamp_green_definition = table.copy(lamp_green_definition)
lamp_green_definition.light_source = minetest.LIGHT_MAX
lamp_green_definition.tiles = {"lamp_green_on.png","lamp_green_on.png","lamp_green_on.png"}
lamp_green_definition.groups["not_in_creative_inventory"] = 1
minetest.register_node("electricity:lamp_green_on", lamp_green_definition)

-- LAMP BLUE --
local lamp_blue_definition = table.copy(lamp_definition_base)
lamp_blue_definition.description = "Electricity lamp blue";
lamp_blue_definition.drop = "electricity:lamp_blue_off";
lamp_blue_definition.inventory_image = "electricity_lamp_blue.png";
lamp_blue_definition.electricity.name_on = "electricity:lamp_blue_on";
lamp_blue_definition.electricity.name_off = "electricity:lamp_blue_off";
minetest.register_node("electricity:lamp_blue_off", lamp_blue_definition)

lamp_blue_definition = table.copy(lamp_blue_definition)
lamp_blue_definition.light_source = minetest.LIGHT_MAX
lamp_blue_definition.tiles = {"lamp_blue_on.png","lamp_blue_on.png","lamp_blue_on.png"}
lamp_blue_definition.groups["not_in_creative_inventory"] = 1
minetest.register_node("electricity:lamp_blue_on", lamp_blue_definition)

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
    inventory_image = "electricity_pressure_plate_stone_inv.png",
    wield_image = "electricity_pressure_plate_stone_wield.png",
    tiles = {"jeija_pressure_plate_stone_off.png","jeija_pressure_plate_stone_off.png","electricity_pressure_plate_stone_off_edges.png"},
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
plate_definition.tiles = {"jeija_pressure_plate_stone_on.png","jeija_pressure_plate_stone_on.png","electricity_pressure_plate_stone_on_edges.png"}
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
    description = "Electricity solar panel (put array of solar panels under the sun to get stable electricity source)",
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
        max_hear_distance = 12,
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
        local face_vector = electricity.get_node_face_direction(self_pos)
        local down_vector = electricity.get_node_down_direction(self_pos)

    	local base_pos = electricity.get_pos_relative(self_pos, {x=0, y=0, z=-1}, face_vector, down_vector)
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

function electricity.transistor_nc_on_timer(self_pos, elapsed)
	local node = minetest.get_node(self_pos)
    local node_reg = minetest.registered_nodes[node.name]
    if  node_reg and
        node_reg.electricity and
        node_reg.electricity.name_enabled
    then
        local face_vector = electricity.get_node_face_direction(self_pos)
        local down_vector = electricity.get_node_down_direction(self_pos)

    	local base_pos = electricity.get_pos_relative(self_pos, {x=0, y=0, z=-1}, face_vector, down_vector)
        local h = minetest.hash_node_position(base_pos)
        local volt = 0
        if electricity.rdata[h] ~= nil then
            volt = electricity.rdata[h]
        end
    	if electricity.check_relative_rule(base_pos, self_pos) and volt == 1 then
            if node.name == node_reg.electricity.name_enabled then
                node.name = node_reg.electricity.name_disabled
                minetest.swap_node(self_pos, node)
            end
        else
            if node.name == node_reg.electricity.name_disabled then
                node.name = node_reg.electricity.name_enabled
                minetest.swap_node(self_pos, node)
            end
    	end
    end
end

local transistor_definition_base = {
    description = "Electricity transistor",
    drop = "electricity:transistor_off",
    inventory_image = "electricity_transistor_inv.png",
    wield_image = "electricity_transistor_inv.png",
    drawtype = "nodebox",
    selection_box = {
    	type = "fixed",
    	fixed = {{-8/16, -8/16, -8/16, 8/16, -7/16, 8/16 }},
    },
    node_box = {
    	type = "fixed",
    	fixed = {{-8/16, -8/16, -8/16, 8/16, -7/16, 8/16 }},
    },
    tiles = {"electricity_transistor.png^".."electricity_gate_off.png^".."electricity_transistor.png",
            "electricity_transistor.png^".."electricity_gate_off.png^".."electricity_transistor.png",
            "electricity_gate_side.png", "electricity_gate_side_off.png", "electricity_gate_side_off.png", "electricity_gate_side_off.png"},
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

-- PNP? normally opened?
local transistor_definition = table.copy(transistor_definition_base)
minetest.register_node("electricity:transistor_off", transistor_definition)
transistor_definition = table.copy(transistor_definition)
transistor_definition.tiles = {"electricity_transistor.png^".."jeija_gate_on.png^".."electricity_transistor.png",
    "electricity_transistor.png^".."jeija_gate_on.png^".."electricity_transistor.png",
    "electricity_gate_side.png", "electricity_gate_side_on.png", "electricity_gate_side_on.png", "electricity_gate_side_on.png"}
transistor_definition.groups["not_in_creative_inventory"] = 1
transistor_definition.electricity.rules = {
    {x=-1,y=0,z=0},
    {x=1,y=0,z=0},
    -- {x=0,y=-1,z=0}, -- also bottom
}
minetest.register_node("electricity:transistor_on", transistor_definition)

-- Normally Closed
local transistor_definition = table.copy(transistor_definition_base)
transistor_definition.description = "Electricity transistor (Normally Closed)"
transistor_definition.inventory_image = "electricity_transistor_nc_inv.png"
transistor_definition.wield_image = "electricity_transistor_nc_inv.png"
transistor_definition.on_timer = function(pos, elapsed)
    electricity.transistor_nc_on_timer(pos, elapsed)
    return true
end
transistor_definition.tiles = {"electricity_transistor_nc.png^".."electricity_gate_off.png^".."electricity_transistor_nc.png",
    "electricity_transistor_nc.png^".."electricity_gate_off.png^".."electricity_transistor_nc.png",
    "electricity_gate_side.png", "electricity_gate_side_off.png", "electricity_gate_side_off.png", "electricity_gate_side_off.png"}
transistor_definition.electricity.name_enabled = "electricity:transistor_nc_on"
transistor_definition.electricity.name_disabled = "electricity:transistor_nc_off"
minetest.register_node("electricity:transistor_nc_off", transistor_definition)
transistor_definition = table.copy(transistor_definition)
transistor_definition.tiles = {"electricity_transistor_nc.png^".."jeija_gate_on.png^".."electricity_transistor_nc.png",
    "electricity_transistor_nc.png^".."jeija_gate_on.png^".."electricity_transistor_nc.png",
    "electricity_gate_side.png", "electricity_gate_side_on.png", "electricity_gate_side_on.png", "electricity_gate_side_on.png"}
transistor_definition.groups["not_in_creative_inventory"] = 1
transistor_definition.electricity.rules = {
    {x=-1,y=0,z=0},
    {x=1,y=0,z=0},
    -- {x=0,y=-1,z=0}, -- also bottom
}
minetest.register_node("electricity:transistor_nc_on", transistor_definition)


-- PISTONS
-- Swap electricity node on or off
function electricity.piston_on_timer(self_pos, elapsed)
    local node = minetest.get_node(self_pos)
    local node_reg = minetest.registered_nodes[node.name]
    if  node_reg and
        node_reg.electricity
    then
        local volt = electricity.get(self_pos, self_pos)
        if volt == 1 and node.name == node_reg.electricity.name_off then
            node.name = node_reg.electricity.name_on
            if node.name == "electricity:piston_on" then
                electricity.piston_on(self_pos, node)
            end
        elseif volt == 0 and node.name == node_reg.electricity.name_on then
            node.name = node_reg.electricity.name_off
            if node.name == "electricity:piston_off" then
                electricity.piston_off(self_pos, node)
            end
        end
    end
end

function electricity.piston_on(pos, node)
    local face_vector = electricity.get_node_face_direction(pos)
	local node0_pos = electricity.get_pos_relative(pos, {x=1,y=0,z=0}, face_vector, nil)
    local node1_pos = electricity.get_pos_relative(pos, {x=2,y=0,z=0}, face_vector, nil)
    local node0 = minetest.get_node(node0_pos)
    local node1 = minetest.get_node(node1_pos)

    -- Permission check?
    local meta = minetest.get_meta(pos)
    local owner = meta:get_string("owner")
    if
        minetest.is_protected(node0_pos, owner) or
        minetest.is_protected(node1_pos, owner)
    then
        return false
    end

    -- Free space check
    if not electricity.node_replaceable(node0.name) and not electricity.node_replaceable(node1.name) then

        -- Actions
        -- Why not use mesecons compatibility? :)
        local node0_reg = minetest.registered_nodes[node0.name]
        if
            node0_reg.mesecons and
            node0_reg.mesecons.effector and
            node0_reg.mesecons.effector.action_on
        then
            node0_reg.mesecons.effector.action_on(node0_pos, node0)
        end

        return false
    end

    -- Stoppers?
    -- unknown nodes are always stoppers
    if not minetest.registered_nodes[node0.name] then
        return false
    end

    if
        node0.name == "protector:protect" or
        node0.name == "protector:protect2" or
        node0.name == "protector_mese:protect" or
        node0.name == "protector_mese:brazier_bronze" or
        node0.name == "protector_mese:brazier_gold" or
        node0.name == "default:chest_locked_open" or
        node0.name == "default:chest_open" or
        node0.name == "doors:door_steel_b_1" or
        node0.name == "doors:door_steel_t_1" or
        node0.name == "doors:door_steel_b_2" or
        node0.name == "doors:door_steel_t_2" or
        node0.name == "electricity:piston_on" or
        node0.name == "electricity:piston2_on" or
        node0.name == "electricity:piston_pusher_sticky" or
        node0.name == "electricity:piston_pusher_part"
    then
        return false
    end

    -- Move objects if there is place for them
    if electricity.node_replaceable(node0.name) and electricity.node_replaceable(node1.name) then
        local objects_to_move = electricity.get_move_objects(node0_pos)
        electricity.move_objects(objects_to_move, node0_pos, node1_pos)
    elseif electricity.node_replaceable(node1.name) then
        local node2_pos = electricity.get_pos_relative(pos, {x=3,y=0,z=0}, face_vector, nil)
        local node2 = minetest.get_node(node2_pos)
        if electricity.node_replaceable(node2.name) then
            local objects_to_move = electricity.get_move_objects(node1_pos)
            electricity.move_objects(objects_to_move, node1_pos, node2_pos)
        end
    end


    if not electricity.node_replaceable(node0.name) then    -- do not replace nodes with air
    	local meta0 = minetest.get_meta(node0_pos):to_table()
    	minetest.set_node(node1_pos, node0)
    	minetest.get_meta(node1_pos):from_table(meta0)
    end
    -- Add pusher
	minetest.set_node(node0_pos, {name = "electricity:piston_pusher_sticky", param2 = node.param2})

    minetest.swap_node(pos, node)

	minetest.sound_play("piston_extend", {
		pos = pos,
		max_hear_distance = 12,
		gain = 0.3,
	})

    return true
end

function electricity.piston_off(pos, node)
    local face_vector = electricity.get_node_face_direction(pos)
    local node0_pos = electricity.get_pos_relative(pos, {x=1,y=0,z=0}, face_vector, nil)
    local node1_pos = electricity.get_pos_relative(pos, {x=2,y=0,z=0}, face_vector, nil)
    local node0 = minetest.get_node(node0_pos)
    local node1 = minetest.get_node(node1_pos)

    -- Permission check?
    local meta = minetest.get_meta(pos)
    local owner = meta:get_string("owner")
    if
        minetest.is_protected(node0_pos, owner) or
        minetest.is_protected(node1_pos, owner)
    then
        minetest.swap_node(pos, node)
        if node0.name == "electricity:piston_pusher_sticky" then
            minetest.set_node(node0_pos, { name = "air" })
        end
        return false
    end

    -- Stoppers?
    -- unknown nodes are always stoppers
    if not minetest.registered_nodes[node1.name] then
        return true
    end

    if
        node1.name == "protector:protect" or
        node1.name == "protector:protect2" or
        node1.name == "protector_mese:protect" or
        node1.name == "protector_mese:brazier_bronze" or
        node1.name == "protector_mese:brazier_gold" or
        node1.name == "default:chest_locked_open" or
        node1.name == "default:chest_open" or
        node1.name == "doors:door_steel_b_1" or
        node1.name == "doors:door_steel_t_1" or
        node1.name == "doors:door_steel_b_2" or
        node1.name == "doors:door_steel_t_2" or
        node1.name == "electricity:piston_on" or
        node1.name == "electricity:piston2_on" or
        node1.name == "electricity:piston_pusher_sticky" or
        node1.name == "electricity:piston_pusher_part"
    then
        minetest.swap_node(pos, node)
        if node0.name == "electricity:piston_pusher_sticky" then
            minetest.set_node(node0_pos, { name = "air" })
        end
        return false
    end

    local meta1 = minetest.get_meta(node1_pos):to_table()
    minetest.set_node(node1_pos, { name = "air" })
    minetest.set_node(node0_pos, node1)
    minetest.get_meta(node0_pos):from_table(meta1)

    minetest.swap_node(pos, node)

    minetest.sound_play("piston_retract", {
        pos = pos,
        max_hear_distance = 12,
        gain = 0.3,
    })
    minetest.check_for_falling(node1_pos)

    return true
end

-- Boxes:
local pt = 3/16 -- pusher thickness

local piston_pusher_box = {
	type = "fixed",
	fixed = {
		{-2/16, -2/16, -.5 + pt, 2/16, 2/16,  .5 + pt},
		{-.5  , -.5  , -.5     , .5  , .5  , -.5 + pt},
	},
}

local piston_on_box = {
	type = "fixed",
	fixed = {
		{-.5, -.5, -.5 + pt, .5, .5, .5}
	},
}

local piston_definition_base = {
    description = "Electricity piston (move node)", -- sticky, 1 node long, also works as activator.
    drop = "electricity:piston_off",
    tiles = {
		"electricity_piston_top.png",
		"electricity_piston_bottom.png",
		"electricity_piston_left.png",
		"electricity_piston_right.png",
		"electricity_piston_back.png",
		"mesecons_piston_pusher_front_sticky.png"
	},
    paramtype2 = "facedir",
    is_ground_content = false,
    on_timer = function(pos, elapsed)
        electricity.piston_on_timer(pos, elapsed)
        return true
    end,
    on_construct = function(pos)
        local h = minetest.hash_node_position(pos)
        electricity.not_producers[h] = pos
        electricity.set(pos, pos, 0)
        minetest.get_node_timer(pos):start(0.5)
    end,
	after_place_node = function(pos, placer)
		local meta = minetest.get_meta(pos)
		meta:set_string("owner", placer:get_player_name() or "")
	end,
    after_destruct = function(pos)
        local h = minetest.hash_node_position(pos)
        electricity.not_producers[h] = nil
        electricity.rdata[h] = nil
    end,
    electricity = {
        rules = {
            {x=0,y=1,z=0},
            {x=-1,y=0,z=0},
            {x=0,y=0,z=1},
            {x=0,y=0,z=-1},
            {x=0,y=-1,z=0},
        },
        name_on = "electricity:piston_on",
        name_off = "electricity:piston_off",
    },
    groups = {electricity = 1, electricity_consumer= 1, cracky = 3},
    sounds = default.node_sound_wood_defaults(),
}

local piston_definition = table.copy(piston_definition_base)
minetest.register_node("electricity:piston_off", piston_definition)

piston_definition = table.copy(piston_definition)
piston_definition.drawtype = "nodebox"
piston_definition.tiles = {
    "electricity_piston_top.png",
    "electricity_piston_bottom.png",
    "electricity_piston_left.png",
    "electricity_piston_right.png",
    "electricity_piston_back.png",
    "mesecons_piston_on_front.png"
}
piston_definition.node_box = piston_on_box
piston_definition.selection_box = piston_on_box
piston_definition.paramtype = "light"
piston_definition.groups["not_in_creative_inventory"] = 1
piston_definition.electricity.rules = {
    {x=0,y=1,z=0},
    {x=-1,y=0,z=0},
    {x=0,y=0,z=1},
    {x=0,y=0,z=-1},
    {x=0,y=-1,z=0},
}
piston_definition.on_rotate = function(pos, node, player, mode)
    return false
end
piston_definition.on_destruct = function(pos)
    local face_vector = electricity.get_node_face_direction(pos)
    local node0_pos = electricity.get_pos_relative(pos, {x=1,y=0,z=0}, face_vector, nil)
    local node0_name = minetest.get_node(node0_pos).name
    -- make sure there actually is a pusher
	if node0_name ~= "electricity:piston_pusher_sticky" then
		return
	end

    minetest.remove_node(node0_pos)
	minetest.sound_play("piston_retract", {
		pos = pos,
		max_hear_distance = 12,
		gain = 0.3,
	})
end
minetest.register_node("electricity:piston_on", piston_definition)

-- pusher (part of piston)
minetest.register_node("electricity:piston_pusher_sticky", {
	description = "Sticky Piston Pusher",
	drawtype = "nodebox",
	tiles = {
		"mesecons_piston_pusher_top.png",
		"mesecons_piston_pusher_bottom.png",
		"mesecons_piston_pusher_left.png",
		"mesecons_piston_pusher_right.png",
		"mesecons_piston_pusher_back.png",
		"mesecons_piston_pusher_front_sticky.png"
	},
	groups = {not_in_creative_inventory = 1, cracky = 3},
	paramtype = "light",
	paramtype2 = "facedir",
	is_ground_content = false,
	diggable = false,
	selection_box = piston_pusher_box,
	node_box = piston_pusher_box,
	drop = "",
	sounds = default.node_sound_wood_defaults(),
})

-- PISTONS X2
-- Swap electricity node on or off
function electricity.piston2_on_timer(self_pos, elapsed)
    local node = minetest.get_node(self_pos)
    local node_reg = minetest.registered_nodes[node.name]
    if  node_reg and
        node_reg.electricity
    then
        local volt = electricity.get(self_pos, self_pos)
        if volt == 1 and node.name == node_reg.electricity.name_off then
            node.name = node_reg.electricity.name_on
            if node.name == "electricity:piston2_on" then
                electricity.piston2_on(self_pos, node)
            end
        elseif volt == 0 and node.name == node_reg.electricity.name_on then
            node.name = node_reg.electricity.name_off
            if node.name == "electricity:piston2_off" then
                electricity.piston2_off(self_pos, node)
            end
        end
    end
end

function electricity.piston2_on(pos, node)
    local face_vector = electricity.get_node_face_direction(pos)
	local node0_pos = electricity.get_pos_relative(pos, {x=1,y=0,z=0}, face_vector, nil)
    local node1_pos = electricity.get_pos_relative(pos, {x=2,y=0,z=0}, face_vector, nil)
    local node2_pos = electricity.get_pos_relative(pos, {x=3,y=0,z=0}, face_vector, nil)
    local node3_pos = electricity.get_pos_relative(pos, {x=4,y=0,z=0}, face_vector, nil)
    local node0 = minetest.get_node(node0_pos)
    local node1 = minetest.get_node(node1_pos)
    local node2 = minetest.get_node(node2_pos)
    local node3 = minetest.get_node(node3_pos)

    -- Permission check?
    local meta = minetest.get_meta(pos)
    local owner = meta:get_string("owner")
    if
        minetest.is_protected(node0_pos, owner) or
        minetest.is_protected(node1_pos, owner) or
        minetest.is_protected(node2_pos, owner) or
        minetest.is_protected(node3_pos, owner)
    then
        return false
    end

    -- Free space check
    -- For now, move only both nodes at once. Or first one. Or second one. Or when all empty. ignore other cases
    if
        not(
            not electricity.node_replaceable(node0.name) and
            not electricity.node_replaceable(node1.name) and
            electricity.node_replaceable(node2.name) and
            electricity.node_replaceable(node3.name)
        )
        and not(
            electricity.node_replaceable(node0.name) and
            not electricity.node_replaceable(node1.name) and
            electricity.node_replaceable(node2.name) and
            electricity.node_replaceable(node3.name)
        )
        and not(
            not electricity.node_replaceable(node0.name) and
            electricity.node_replaceable(node1.name) and
            electricity.node_replaceable(node2.name) and
            electricity.node_replaceable(node3.name)
        )
        and not(
            electricity.node_replaceable(node0.name) and
            electricity.node_replaceable(node1.name) and
            not electricity.node_replaceable(node2.name) and
            not electricity.node_replaceable(node3.name)
        )
        and not(
            electricity.node_replaceable(node0.name) and
            electricity.node_replaceable(node1.name) and
            electricity.node_replaceable(node2.name) and
            electricity.node_replaceable(node3.name)
        )
    then
        return false
    end

    -- Stoppers?
    -- unknown nodes are always stoppers
    if not minetest.registered_nodes[node0.name] and not minetest.registered_nodes[node1.name] then
        return false
    end

    if
        node0.name == "protector:protect" or
        node0.name == "protector:protect2" or
        node0.name == "protector_mese:protect" or
        node0.name == "protector_mese:brazier_bronze" or
        node0.name == "protector_mese:brazier_gold" or
        node0.name == "default:chest_locked_open" or
        node0.name == "default:chest_open" or
        node0.name == "doors:door_steel_b_1" or
        node0.name == "doors:door_steel_t_1" or
        node0.name == "doors:door_steel_b_2" or
        node0.name == "doors:door_steel_t_2" or
        node0.name == "electricity:piston_on" or
        node0.name == "electricity:piston2_on" or
        node0.name == "electricity:piston_pusher_sticky" or
        node0.name == "electricity:piston_pusher_part"
        or
        node1.name == "protector:protect" or
        node1.name == "protector:protect2" or
        node1.name == "protector_mese:protect" or
        node1.name == "protector_mese:brazier_bronze" or
        node1.name == "protector_mese:brazier_gold" or
        node1.name == "default:chest_locked_open" or
        node1.name == "default:chest_open" or
        node1.name == "doors:door_steel_b_1" or
        node1.name == "doors:door_steel_t_1" or
        node1.name == "doors:door_steel_b_2" or
        node1.name == "doors:door_steel_t_2" or
        node1.name == "electricity:piston_on" or
        node1.name == "electricity:piston2_on" or
        node1.name == "electricity:piston_pusher_sticky" or
        node1.name == "electricity:piston_pusher_part"
    then
        return false
    end

    -- Move objects if there is place for them
    if electricity.node_replaceable(node0.name) and electricity.node_replaceable(node1.name) and electricity.node_replaceable(node2.name) then
        -- to move from both positions, move objects twice
        local objects_near = minetest.get_objects_inside_radius(node0_pos, 3)
        local objects_to_move = electricity.get_move_objects(node0_pos, objects_near)
        electricity.move_objects(objects_to_move, node0_pos, node1_pos)
        objects_to_move = electricity.get_move_objects(node1_pos, objects_near)
        electricity.move_objects(objects_to_move, node1_pos, node2_pos)
    elseif not electricity.node_replaceable(node0.name) and electricity.node_replaceable(node1.name) and electricity.node_replaceable(node3.name) then
        local objects_near = minetest.get_objects_inside_radius(node1_pos, 3)
        local objects_to_move = electricity.get_move_objects(node1_pos, objects_near)
        electricity.move_objects(objects_to_move, node1_pos, node2_pos)
        objects_to_move = electricity.get_move_objects(node2_pos, objects_near)
        electricity.move_objects(objects_to_move, node2_pos, node3_pos)
    elseif not electricity.node_replaceable(node0.name) and not electricity.node_replaceable(node1.name) and electricity.node_replaceable(node2.name) then
        local node4_pos = electricity.get_pos_relative(pos, {x=5,y=0,z=0}, face_vector, nil)
        local node4 = minetest.get_node(node4_pos)
        if electricity.node_replaceable(node4.name) then
            local objects_near = minetest.get_objects_inside_radius(node2_pos, 3)
            local objects_to_move = electricity.get_move_objects(node2_pos, objects_near)
            electricity.move_objects(objects_to_move, node2_pos, node3_pos)
            objects_to_move = electricity.get_move_objects(node3_pos, objects_near)
            electricity.move_objects(objects_to_move, node3_pos, node4_pos)
        end
    end

    -- Move nodes if there is space
    if not electricity.node_replaceable(node0.name) and electricity.node_replaceable(node1.name) then
    	local meta0 = minetest.get_meta(node0_pos):to_table()
    	minetest.set_node(node2_pos, node0)
    	minetest.get_meta(node2_pos):from_table(meta0)
        local meta1 = minetest.get_meta(node1_pos):to_table()
    	minetest.set_node(node3_pos, node1)
    	minetest.get_meta(node3_pos):from_table(meta1)
    elseif electricity.node_replaceable(node0.name) and not electricity.node_replaceable(node1.name) then
    	local meta1 = minetest.get_meta(node1_pos):to_table()
    	minetest.set_node(node2_pos, node1)
    	minetest.get_meta(node2_pos):from_table(meta1)
    elseif not electricity.node_replaceable(node0.name) and not electricity.node_replaceable(node1.name) then    -- do not replace nodes with air
    	local meta0 = minetest.get_meta(node0_pos):to_table()
    	minetest.set_node(node2_pos, node0)
    	minetest.get_meta(node2_pos):from_table(meta0)
        local meta1 = minetest.get_meta(node1_pos):to_table()
    	minetest.set_node(node3_pos, node1)
    	minetest.get_meta(node3_pos):from_table(meta1)
    end
    -- Add pusher
	minetest.set_node(node0_pos, {name = "electricity:piston_pusher_part", param2 = node.param2})
    minetest.set_node(node1_pos, {name = "electricity:piston_pusher_sticky", param2 = node.param2})

    minetest.swap_node(pos, node)

	minetest.sound_play("piston_extend", {
		pos = pos,
		max_hear_distance = 12,
		gain = 0.3,
	})

    return true
end

function electricity.piston2_off(pos, node)
    local face_vector = electricity.get_node_face_direction(pos)
    local node0_pos = electricity.get_pos_relative(pos, {x=1,y=0,z=0}, face_vector, nil)
    local node1_pos = electricity.get_pos_relative(pos, {x=2,y=0,z=0}, face_vector, nil)
    local node2_pos = electricity.get_pos_relative(pos, {x=3,y=0,z=0}, face_vector, nil)
    local node3_pos = electricity.get_pos_relative(pos, {x=4,y=0,z=0}, face_vector, nil)
    local node0 = minetest.get_node(node0_pos)
    local node1 = minetest.get_node(node1_pos)
    local node2 = minetest.get_node(node2_pos)
    local node3 = minetest.get_node(node3_pos)

    -- Permission check?
    local meta = minetest.get_meta(pos)
    local owner = meta:get_string("owner")
    if
        minetest.is_protected(node0_pos, owner) or
        minetest.is_protected(node1_pos, owner) or
        minetest.is_protected(node2_pos, owner) or
        minetest.is_protected(node3_pos, owner)
    then
        minetest.swap_node(pos, node)
        if node0.name == "electricity:piston_pusher_part" then
            minetest.set_node(node0_pos, { name = "air" })
        end
        if node1.name == "electricity:piston_pusher_sticky" then
            minetest.set_node(node1_pos, { name = "air" })
        end
        return false
    end

    -- Stoppers?
    -- unknown nodes are always stoppers
    if not minetest.registered_nodes[node2.name] or not minetest.registered_nodes[node3.name] then
        return true
    end

    if
        node2.name == "protector:protect" or
        node2.name == "protector:protect2" or
        node2.name == "protector_mese:protect" or
        node2.name == "protector_mese:brazier_bronze" or
        node2.name == "protector_mese:brazier_gold" or
        node2.name == "doors:door_steel_b_1" or
        node2.name == "doors:door_steel_t_1" or
        node2.name == "doors:door_steel_b_2" or
        node2.name == "doors:door_steel_t_2" or
        node2.name == "electricity:piston2_on" or
        node2.name == "electricity:piston_pusher_sticky"
        or
        node3.name == "protector:protect" or
        node3.name == "protector:protect2" or
        node3.name == "protector_mese:protect" or
        node3.name == "protector_mese:brazier_bronze" or
        node3.name == "protector_mese:brazier_gold" or
        node3.name == "doors:door_steel_b_1" or
        node3.name == "doors:door_steel_t_1" or
        node3.name == "doors:door_steel_b_2" or
        node3.name == "doors:door_steel_t_2" or
        node3.name == "electricity:piston2_on" or
        node3.name == "electricity:piston_pusher_sticky"

    then
        minetest.swap_node(pos, node)
        if node0.name == "electricity:piston_pusher_part" then
            minetest.set_node(node0_pos, { name = "air" })
        end
        if node1.name == "electricity:piston_pusher_sticky" then
            minetest.set_node(node1_pos, { name = "air" })
        end
        return false
    end

    local meta2 = minetest.get_meta(node2_pos):to_table()
    minetest.set_node(node2_pos, { name = "air" })
    minetest.set_node(node0_pos, node2)
    minetest.get_meta(node0_pos):from_table(meta2)

    local meta3 = minetest.get_meta(node3_pos):to_table()
    minetest.set_node(node3_pos, { name = "air" })
    minetest.set_node(node1_pos, node3)
    minetest.get_meta(node1_pos):from_table(meta3)

    minetest.swap_node(pos, node)

    minetest.sound_play("piston_retract", {
        pos = pos,
        max_hear_distance = 12,
        gain = 0.3,
    })
    minetest.check_for_falling(node1_pos)

    return true
end

-- Boxes:
local pt = 3/16 -- pusher thickness

local piston_pusher_part_box = {
	type = "fixed",
	fixed = {
		{-3/16, -3/16, -.5 + pt, 3/16, 3/16,  .5 + pt},
	},
}

local piston2_definition_base = {
    description = "Electricity piston x2 (move 2 nodes)", -- sticky, 1 node long, also works as activator.
    drop = "electricity:piston2_off",
    tiles = {
		"electricity_piston_top.png",
		"electricity_piston_bottom.png",
		"electricity_piston2_left.png",
		"electricity_piston_right.png",
		"electricity_piston_back.png",
		"mesecons_piston_pusher_front_sticky.png"
	},
    paramtype2 = "facedir",
    is_ground_content = false,
    on_timer = function(pos, elapsed)
        electricity.piston2_on_timer(pos, elapsed)
        return true
    end,
    on_construct = function(pos)
        local h = minetest.hash_node_position(pos)
        electricity.not_producers[h] = pos
        electricity.set(pos, pos, 0)
        minetest.get_node_timer(pos):start(0.5)
    end,
	after_place_node = function(pos, placer)
		local meta = minetest.get_meta(pos)
		meta:set_string("owner", placer:get_player_name() or "")
	end,
    after_destruct = function(pos)
        local h = minetest.hash_node_position(pos)
        electricity.not_producers[h] = nil
        electricity.rdata[h] = nil
    end,
    electricity = {
        rules = {
            {x=0,y=1,z=0},
            {x=-1,y=0,z=0},
            {x=0,y=0,z=1},
            {x=0,y=0,z=-1},
            {x=0,y=-1,z=0},
        },
        name_on = "electricity:piston2_on",
        name_off = "electricity:piston2_off",
    },
    groups = {electricity = 1, electricity_consumer= 1, cracky = 3},
    sounds = default.node_sound_wood_defaults(),
}

local piston2_definition = table.copy(piston2_definition_base)
minetest.register_node("electricity:piston2_off", piston2_definition)

piston2_definition = table.copy(piston2_definition)
piston2_definition.drawtype = "nodebox"
piston2_definition.tiles = {
    "electricity_piston_top.png",
    "electricity_piston_bottom.png",
    "electricity_piston2_left.png",
    "electricity_piston_right.png",
    "electricity_piston_back.png",
    "mesecons_piston_on_front.png"
}
piston2_definition.node_box = piston_on_box
piston2_definition.selection_box = piston_on_box
piston2_definition.paramtype = "light"
piston2_definition.groups["not_in_creative_inventory"] = 1
piston2_definition.electricity.rules = {
    {x=0,y=1,z=0},
    {x=-1,y=0,z=0},
    {x=0,y=0,z=1},
    {x=0,y=0,z=-1},
    {x=0,y=-1,z=0},
}
piston2_definition.on_rotate = function(pos, node, player, mode)
    return false
end
piston2_definition.on_destruct = function(pos)
    local face_vector = electricity.get_node_face_direction(pos)
    local node0_pos = electricity.get_pos_relative(pos, {x=1,y=0,z=0}, face_vector, nil)
    local node0_name = minetest.get_node(node0_pos).name
    local node1_pos = electricity.get_pos_relative(pos, {x=2,y=0,z=0}, face_vector, nil)
    local node1_name = minetest.get_node(node1_pos).name
    -- make sure there actually is a pusher
	if node0_name ~= "electricity:piston_pusher_part" then
		return
	end
    minetest.remove_node(node0_pos)
	if node1_name ~= "electricity:piston_pusher_sticky" then
		return
	end
    minetest.remove_node(node1_pos)

	minetest.sound_play("piston_retract", {
		pos = pos,
		max_hear_distance = 12,
		gain = 0.3,
	})
end
minetest.register_node("electricity:piston2_on", piston2_definition)

-- pusher (part of piston)
minetest.register_node("electricity:piston_pusher_part", {
	description = "Sticky Piston Pusher extender",
	drawtype = "nodebox",
	tiles = {
		"mesecons_piston_pusher_top.png",
		"mesecons_piston_pusher_bottom.png",
		"mesecons_piston_pusher_left.png",
		"mesecons_piston_pusher_right.png",
		"mesecons_piston_pusher_back.png",
		"mesecons_piston_pusher_front_sticky.png"
	},
	groups = {not_in_creative_inventory = 1, cracky = 3},
	paramtype = "light",
	paramtype2 = "facedir",
	is_ground_content = false,
	diggable = false,
	selection_box = piston_pusher_part_box,
	node_box = piston_pusher_part_box,
	drop = "",
	sounds = default.node_sound_wood_defaults(),
})

-- TORCH
function electricity.torch_on_timer(self_pos, elapsed)
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

local torch_selectionbox = {
	type = "wallmounted",
	wall_top = {-0.1, 0.5-0.6, -0.1, 0.1, 0.5, 0.1},
	wall_bottom = {-0.1, -0.5, -0.1, 0.1, -0.5+0.6, 0.1},
	wall_side = {-0.5, -0.1, -0.1, -0.5+0.6, 0.1, 0.1},
}

local torch_definition_base = {
    description = "Electricity torch (protector)",
    drop = "electricity:torch_off",
    inventory_image = "jeija_torches_off.png",
    tiles = {"torch_off.png","torch_off.png","torch_off.png"},
    paramtype = "light",
    drawtype = "torchlike",
	tiles = {"jeija_torches_off.png", "jeija_torches_off_ceiling.png", "jeija_torches_off_side.png"},
    paramtype2 = "wallmounted",
    is_ground_content = false,
	walkable = false,
    selection_box = torch_selectionbox,
    sounds = default.node_sound_defaults(),
    on_timer = function(pos, elapsed)
        electricity.torch_on_timer(pos, elapsed)
        return true
    end,
	after_place_node = function(pos, placer)
		local meta = minetest.get_meta(pos)
		meta:set_string("owner", placer:get_player_name() or "")
        meta:set_string("infotext", "Torch (owned by "..
				meta:get_string("owner")..")")
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
            -- {x=0,y=1,z=0},  -- left :|
            {x=-1,y=0,z=0}, -- bottom :|
            -- {x=0,y=0,z=1},
            -- {x=0,y=0,z=-1},
            -- {x=0,y=-1,z=0},
        },
        name_on = "electricity:torch_on",
        name_off = "electricity:torch_off",
    },
    groups = {electricity = 1, electricity_consumer = 1, cracky = 3, oddly_breakable_by_hand = 3, protector = 1},
    sounds = default.node_sound_stone_defaults(),
}

local torch_definition = table.copy(torch_definition_base)
minetest.register_node("electricity:torch_off", torch_definition)
torch_definition = table.copy(torch_definition)
torch_definition.light_source = minetest.LIGHT_MAX-3
torch_definition.sunlight_propagates = true
torch_definition.tiles = {"jeija_torches_on.png", "jeija_torches_on_ceiling.png", "jeija_torches_on_side.png"}
torch_definition.groups["not_in_creative_inventory"] = 1
minetest.register_node("electricity:torch_on", torch_definition)

-- E-CHEST --
function electricity.echest_on_timer(self_pos, elapsed)
    local node = minetest.get_node(self_pos)
    local node_reg = minetest.registered_nodes[node.name]
    if  node_reg and
        node_reg.electricity
    then
        local volt = electricity.get(self_pos, self_pos)
        if volt == 1 and node.name == node_reg.electricity.name_off and not electricity.echest_lid_obstructed(self_pos) then
            node.name = node_reg.electricity.name_on
            minetest.swap_node(self_pos, node)
            minetest.sound_play("mesecons_lever", {
                pos = self_pos,
                max_hear_distance = 7,
                gain = 10.0,
            })
        elseif volt == 0 and node.name == node_reg.electricity.name_on then
            node.name = node_reg.electricity.name_off
            minetest.swap_node(self_pos, node)
            minetest.sound_play("mesecons_lever", {
                pos = self_pos,
                max_hear_distance = 7,
                gain = 10.0,
            })
        end
    end
end

function electricity.echest_lid_obstructed(pos)
	local above = {x = pos.x, y = pos.y + 1, z = pos.z}
	local def = minetest.registered_nodes[minetest.get_node(above).name]
	-- allow ladders, signs, wallmounted things and torches to not obstruct
	if def and
			(def.drawtype == "airlike" or
			def.drawtype == "signlike" or
			def.drawtype == "torchlike" or def.name == 'default:torch_wall' or
			(def.drawtype == "nodebox" and def.paramtype2 == "wallmounted")) then
		return false
	end
	return true
end

function electricity.get_echest_formspec(pos)
	local spos = pos.x .. "," .. pos.y .. "," .. pos.z
	local formspec =
		"size[14,10]" ..
		"list[nodemeta:" .. spos .. ";main;0,0;14,5;]" ..
		"list[current_player;main;3,5.85;8,1;]" ..
		"list[current_player;main;3,7.08;8,3;8]" ..
		"listring[nodemeta:" .. spos .. ";main]" ..
		"listring[current_player;main]" ..
		default.get_hotbar_bg(3,5.85)
	return formspec
end

local echest_definition_base = {
    description = "Electricity chest",
	tiles = {
		"electricity_echest_top.png",
		"electricity_echest_top.png",
		"electricity_echest.png".."^[transformFX",
		"electricity_echest.png",
		"electricity_echest_back.png",
		"electricity_echest_front.png",
	},
    paramtype2 = "facedir",
	is_ground_content = false,
    on_timer = function(pos, elapsed)
        electricity.echest_on_timer(pos, elapsed)
        return true
    end,
    electricity = {
        rules = {
            {x=-1,y=0,z=0},
            {x=0,y=-1,z=0},
        },
        name_on = "electricity:echest_open",
        name_off = "electricity:echest_closed",
    },
	groups = {cracky=1, level=3, electricity = 1, electricity_consumer = 1},
	sounds = default.node_sound_stone_defaults(),
    on_construct = function(pos)
		local meta = minetest.get_meta(pos)
        meta:set_string("infotext", "Electricity chest")
		local inv = meta:get_inventory()
		inv:set_size("main", 14*5)

        local h = minetest.hash_node_position(pos)
        electricity.not_producers[h] = pos
        electricity.set(pos, pos, 0)
        minetest.get_node_timer(pos):start(0.5)
    end,
    on_rightclick = function(pos, node, clicker, itemstack, pointed_thing)
		return itemstack
	end,
    allow_metadata_inventory_move = function(pos, from_list, from_index, to_list, to_index, count, player)
        return 0
    end,
    allow_metadata_inventory_put = function(pos, listname, index, stack, player)
        return 0
    end,
    allow_metadata_inventory_take = function(pos, listname, index, stack, player)
        return 0
    end,
    after_dig_node = function(pos, oldnode, oldmetadata, digger)
        local meta = minetest.get_meta(pos)
        meta:from_table(oldmetadata)
        local inv = meta:get_inventory()
        for i=1,inv:get_size("main") do
            local stk = inv:get_stack("main", i)
            minetest.add_item(pos, stk)
        end
    end,
}

echest_closed_definition = table.copy(echest_definition_base)
minetest.register_node('electricity:echest_closed', echest_closed_definition)

echest_open_definition = table.copy(echest_definition_base)

echest_open_definition.tiles = {
    {name = "electricity_echest_top.png", backface_culling = true},
    {name = "electricity_echest_top.png", backface_culling = true},
    {name = "electricity_echest.png", backface_culling = true},
    {name = "electricity_echest_back.png", backface_culling = true},
    {name = "electricity_echest_front.png", backface_culling = true},
    {name = "electricity_echest_inside.png", backface_culling = true},
}
echest_open_definition.drawtype = "mesh"
echest_open_definition.visual = "mesh"
echest_open_definition.mesh = "chest_open.obj"
echest_open_definition.selection_box = {
    type = "fixed",
    fixed = { -1/2, -1/2, -1/2, 1/2, 3/16, 1/2 },
}
echest_open_definition.groups.not_in_creative_inventory = 1
echest_open_definition.drop = 'electricity:echest_closed'
echest_open_definition.on_rightclick = function(pos, node, clicker, itemstack, pointed_thing)
    minetest.after(0.2, minetest.show_formspec,
        clicker:get_player_name(), "electricity:echest open", electricity.get_echest_formspec(pos)
    )
end
echest_open_definition.allow_metadata_inventory_move = function(pos, from_list, from_index, to_list, to_index, count, player)
    return count
end
echest_open_definition.allow_metadata_inventory_put = function(pos, listname, index, stack, player)
    return stack:get_count()
end
echest_open_definition.allow_metadata_inventory_take = function(pos, listname, index, stack, player)
    return stack:get_count()
end

minetest.register_node('electricity:echest_open', echest_open_definition)

-- BIOMETRICS --
function electricity:biometrics_on_rightclick(self_pos, node, clicker)

    local meta = minetest.get_meta(self_pos)
    local owner_name = meta:get_string("owner")
    local player_name = clicker:get_player_name()

    local has_access = false
    if owner_name == player_name then
        has_access = true
    end

    if electricity.biometrics_is_member(meta, player_name) then
        has_access = true
    end

    local node_reg = minetest.registered_nodes[node.name]
    if
        has_access and (
            node.name == node_reg.electricity.name_disabled or
            node.name == node_reg.electricity.name_disabled2
        )
    then
        node.name = node_reg.electricity.name_enabled
        minetest.swap_node(self_pos, node)
        minetest.sound_play("mesecons_lever", {
            pos = self_pos,
            max_hear_distance = 6,
            gain = 10.0,
        })
    elseif has_access and node.name == node_reg.electricity.name_enabled then
        node.name = node_reg.electricity.name_disabled
        minetest.swap_node(self_pos, node)
        minetest.sound_play("mesecons_lever", {
            pos = self_pos,
            max_hear_distance = 6,
            gain = 10.0,
        })
    elseif
        node.name == node_reg.electricity.name_disabled
    then
        node.name = node_reg.electricity.name_disabled2
        minetest.swap_node(self_pos, node)
        minetest.sound_play("piston_extend", {
            pos = self_pos,
            max_hear_distance = 6,
            gain = 10.0,
        })
    end
end

function electricity.biometrics_on_timer(self_pos, elapsed)
    local node = minetest.get_node(self_pos)
    local node_reg = minetest.registered_nodes[node.name]

	local meta = minetest.get_meta(self_pos)
	local reset = (meta:get_int("biometrics_reset") == 1)

    if  node_reg and
        node_reg.electricity
    then
        local volt = electricity.get(self_pos, self_pos)
        if volt == 0 and (
                node.name == node_reg.electricity.name_enabled or
                node.name == node_reg.electricity.name_disabled2
            )
        then
            if reset then
                node.name = node_reg.electricity.name_disabled
                minetest.swap_node(self_pos, node)
                meta:set_int("biometrics_reset", 0)
            else
                meta:set_int("biometrics_reset", 1)
            end
        elseif reset then
            meta:set_int("biometrics_reset", 0)
        end
    end
end

electricity.biometrics_get_member_list = function(meta)
	local s = meta:get_string("members")
	local list = s:split(" ")
	return list
end

electricity.biometrics_set_member_list = function(meta, list)
	meta:set_string("members", table.concat(list, " "))
end

electricity.biometrics_is_member = function (meta, name)
	local list = electricity.biometrics_get_member_list(meta)
	for _, n in ipairs(list) do
		if n == name then
			return true
		end
	end
	return false
end

electricity.biometrics_add_member = function(meta, name)
	name=string.sub(name, 1, 30)	--protection
	if electricity.biometrics_is_member(meta, name) then return end
	local list = electricity.biometrics_get_member_list(meta)
	table.insert(list, name)
	electricity.biometrics_set_member_list(meta, list)
end

electricity.biometrics_del_member = function(meta, name)
	local list = electricity.biometrics_get_member_list(meta)
	for i, n in ipairs(list) do
		if n == name then
			table.remove(list, i)
			break
		end
	end
	electricity.biometrics_set_member_list(meta, list)
end

electricity.biometrics_generate_formspec = function (meta)
	local formspec = "size[8,8]"
		.."label[0,0;-- biometrics interface --]"
		.."label[0,2;Current members:]"
	local members = electricity.biometrics_get_member_list(meta)

	local npp = 15 -- names per page, for the moment is 4*4 (-1 for the + button)
	--no pages. 15 members max
	local i = 0
	for _, member in ipairs(members) do
		if i < 15 then
			formspec = formspec .. "button["..(i%4*2)..","..math.floor(i/4+3)..";1.5,.5;electricity_biometrics_member;"..member.."]"
			formspec = formspec .. "button["..(i%4*2+1.25)..","..math.floor(i/4+3)..";.75,.5;electricity_biometrics_del_member_"..member..";X]"
		end
		i = i +1
	end
	if i < npp then
		formspec = formspec
			.."field["..(i%4*2+1/3)..","..(math.floor(i/4+3)+1/3)..";1.433,.5;electricity_biometrics_add_member;;]"
			.."button["..(i%4*2+1.25)..","..math.floor(i/4+3)..";.75,.5;electricity_biometrics_submit;+]"
	end

	formspec = formspec .. "button_exit[1,7;3,1;electricity_biometrics_close;CLOSE]"

	return formspec
end

minetest.register_on_player_receive_fields(function(player, formname, fields)
	if string.sub(formname, 0, string.len("electricity_biometrics_")) == "electricity_biometrics_" then
		local pos_s = string.sub(formname,string.len("electricity_biometrics_")+1)
		local pos = minetest.string_to_pos(pos_s)
		local meta = minetest.get_meta(pos)

        local owner_name = meta:get_string("owner")
        local player_name = player:get_player_name()

		if not player_name == owner_name then
			return
		end

		if fields.electricity_biometrics_add_member then
			for _, i in ipairs(fields.electricity_biometrics_add_member:split(" ")) do
				electricity.biometrics_add_member(meta, i)
			end
		end
		for field, value in pairs(fields) do
			if string.sub(field,0,string.len("electricity_biometrics_del_member_"))=="electricity_biometrics_del_member_" then
				electricity.biometrics_del_member(meta, string.sub(field,string.len("electricity_biometrics_del_member_")+1))
			end
		end
		if fields.electricity_biometrics_close then
			return
		end
		if not fields["quit"] then
			minetest.show_formspec(
				player_name, formname,
				electricity.biometrics_generate_formspec(meta)
			)
		end
	end
end)

local biometrics_definition_base = {
    description = "Electricity biometrics",
    drop = "electricity:biometrics_off",
    -- inventory_image = "electricity_stone_with_biometrics_off.png",
    -- wield_image = "electricity_stone_with_biometrics_off.png",
    tiles = {
        "electricity_stone_with_wire_off.png",
        "electricity_stone_with_wire_off.png",
        "default_stone.png",
        "default_stone.png",
        "electricity_stone_with_wire_off.png",
    	"electricity_stone_with_biometrics_off.png",
	},
    paramtype2 = "facedir",
    is_ground_content = false,
    on_timer = function(pos, elapsed)
        electricity.biometrics_on_timer(pos, elapsed)
        return true
    end,
	after_place_node = function(pos, placer)
		local meta = minetest.get_meta(pos)
		meta:set_string("owner", placer:get_player_name() or "")
        meta:set_string("members", "")

        minetest.after(
            0.2,
            minetest.show_formspec,
            placer:get_player_name(), "electricity_biometrics_"..minetest.pos_to_string(pos), electricity.biometrics_generate_formspec(meta)
        )
	end,
    on_rightclick = function (pos, node, clicker)
        electricity:biometrics_on_rightclick(pos, node, clicker)
	end,
    on_construct = function(pos)
        local h = minetest.hash_node_position(pos)
        electricity.not_producers[h] = pos
        electricity.set(pos, pos, 0)
        minetest.get_node_timer(pos):start(2)
    end,
    after_destruct = function(pos)
        local h = minetest.hash_node_position(pos)
        electricity.not_producers[h] = nil
        electricity.rdata[h] = nil
    end,
    electricity = {
        rules = {
        },
        name_enabled = "electricity:biometrics_on",
        name_disabled = "electricity:biometrics_off",
        name_disabled2 = "electricity:biometrics_denied_off",
    },
    groups = {electricity = 1, electricity_conductor = 1, cracky = 3},
    sounds = default.node_sound_stone_defaults(),
}

biometrics_definition_off = table.copy(biometrics_definition_base)
minetest.register_node('electricity:biometrics_off', biometrics_definition_off)

biometrics_definition_denied_off = table.copy(biometrics_definition_base)
biometrics_definition_denied_off.groups["not_in_creative_inventory"] = 1
biometrics_definition_denied_off.tiles = {
    "electricity_stone_with_wire_off.png",
    "electricity_stone_with_wire_off.png",
    "default_stone.png",
    "default_stone.png",
    "electricity_stone_with_wire_off.png",
    "electricity_stone_with_biometrics_denied_off.png",
}
minetest.register_node('electricity:biometrics_denied_off', biometrics_definition_denied_off)

biometrics_definition_on = table.copy(biometrics_definition_base)
biometrics_definition_on.groups["not_in_creative_inventory"] = 1
biometrics_definition_on.electricity.rules = {
    {x=0,y=1,z=0},
    {x=-1,y=0,z=0},
    {x=0,y=-1,z=0},
}
biometrics_definition_on.tiles = {
    "electricity_stone_with_wire_off.png",
    "electricity_stone_with_wire_off.png",
    "default_stone.png",
    "default_stone.png",
    "electricity_stone_with_wire_off.png",
    "electricity_stone_with_biometrics_on.png",
}
minetest.register_node('electricity:biometrics_on', biometrics_definition_on)

-- BATTERY --
function electricity.battery_on_timer(self_pos, elapsed)
	local node = minetest.get_node(self_pos)
    local node_reg = minetest.registered_nodes[node.name]

    local meta = minetest.get_meta(self_pos)
    local wear = meta:get_int("wear")

    wear = wear + 5

    local itemname = node.name

    if itemname == 'electricity:battery' and wear > (65535/4 * 1) then
        node.name = 'electricity:battery_75'
        minetest.swap_node(self_pos, node)
    elseif itemname == 'electricity:battery_75' and wear > (65535/4 * 2) then
        node.name = 'electricity:battery_50'
        minetest.swap_node(self_pos, node)
    elseif itemname == 'electricity:battery_50' and wear > (65535/4 * 3) then
        node.name = 'electricity:battery_25'
        minetest.swap_node(self_pos, node)
    elseif itemname == 'electricity:battery_25' and wear > (65535/4 * 4) then
        node.name = 'electricity:battery_depleted'
        minetest.swap_node(self_pos, node)
    end

    if
        node_reg and
        node_reg.electricity and
        node.name ~= 'electricity:battery_depleted'
    then
        meta:set_int("wear", wear)
        electricity.set(self_pos, self_pos, 1)  -- produce electricity
    else
        electricity.set(self_pos, self_pos, 0)  -- no electricity
        if wear > (65535 + 10) then
            --explode
        else
            -- minetest.sound_play("tnt_ignite", {
            --     pos = self_pos,
            --     max_hear_distance = 12,
            --     gain = 10.0,
            -- })
            meta:set_int("wear", wear)
        end
    end
end

local battery_definition_base = {
    description = "Electricity battery.  DO NOT SHORT-CIRCUIT!  DO NOT RECHARGE!",
    tiles = {"electricity_battery_top.png", "electricity_battery_bottom.png", "electricity_battery_side.png"},
    is_ground_content = false,
    on_timer = function(pos, elapsed)
        electricity.battery_on_timer(pos, elapsed)
        return true
    end,
    after_place_node = function(pos, placer, itemstack)
        local wear = 0
        local itemname = itemstack:get_name()
        if itemname == 'electricity:battery_75' then
            wear = 65535/4 * 1;
        elseif itemname == 'electricity:battery_50' then
            wear = 65535/4 * 2;
        elseif itemname == 'electricity:battery_25' then
            wear = 65535/4 * 3;
        elseif itemname == 'electricity:battery_depleted' then
            wear = 65535;
        end

        local meta = minetest.get_meta(pos)
        meta:set_int("wear", wear)
    end,
    -- after_dig_node = function(pos, oldnode, oldmetadata, digger)
    --
    -- end,
    on_construct = function(pos)
        local h = minetest.hash_node_position(pos)
        electricity.producers[h] = pos
        electricity.set(pos, pos, 0)
        minetest.get_node_timer(pos):start(5)
    end,
    after_destruct = function(pos)
        local h = minetest.hash_node_position(pos)
        electricity.producers[h] = nil
        electricity.rdata[h] = nil
    end,
    electricity = {
        rules = {
            {x=0,y=1,z=0},
        },
        name_enabled = "electricity:battery",
        name_disabled = "electricity:battery_depleted",
    },
    groups = {electricity = 1, electricity_producer = 1, cracky = 3, oddly_breakable_by_hand = 3},
    sounds = default.node_sound_stone_defaults(),
}

local battery_definition = table.copy(battery_definition_base)
minetest.register_node("electricity:battery", battery_definition)


battery_definition_base.groups.not_in_creative_inventory = 1

local battery_definition_75 = table.copy(battery_definition_base)
battery_definition_75.tiles = {"electricity_battery_top.png", "electricity_battery_bottom.png", "electricity_battery_side_75.png"}
minetest.register_node("electricity:battery_75", battery_definition_75)

local battery_definition_50 = table.copy(battery_definition_base)
battery_definition_50.tiles = {"electricity_battery_top.png", "electricity_battery_bottom.png", "electricity_battery_side_50.png"}
minetest.register_node("electricity:battery_50", battery_definition_50)

local battery_definition_25 = table.copy(battery_definition_base)
battery_definition_25.tiles = {"electricity_battery_top.png", "electricity_battery_bottom.png", "electricity_battery_side_25.png"}
minetest.register_node("electricity:battery_25", battery_definition_25)

local battery_definition_depleted = table.copy(battery_definition_base)
battery_definition_depleted.tiles = {"electricity_battery_top_depleted.png", "electricity_battery_bottom.png", "electricity_battery_side_depleted.png"}
minetest.register_node("electricity:battery_depleted", battery_definition_depleted)

-- electric shock
minetest.register_on_punchnode(function(pos, node, puncher, pointed_thing)
    if
        node.name == "electricity:wire_on" or
        node.name == "electricity:wire_bend_on" or
        node.name == "electricity:wire_corner_on" or
        node.name == "electricity:wire_branch_on" or
        node.name == "electricity:wire_bend_up_on" or
        node.name == "electricity:wire_up_on" or
        node.name == "electricity:wire_branch_up_on" or
        node.name == "electricity:wire_half_on" or
        node.name == "electricity:lamp_on" or
        node.name == "electricity:transistor_on" or
        node.name == "electricity:torch_on"
    then
        if puncher and puncher:is_player() then
            puncher:punch(puncher, 1.0, {
                full_punch_interval=1.0,
                damage_groups = {fleshy=1}
            }, nil)
        end
    end

    if
        node.name == "electricity:transistor_nc_on"
    then
        if electricity.get(pos, pos) > 0 then
            if puncher and puncher:is_player() then
                puncher:punch(puncher, 1.0, {
                    full_punch_interval=1.0,
                    damage_groups = {fleshy=1}
                }, nil)
            end
        end
    end
end)

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
	output = "default:copper_ingot 5",
	recipe = {"electricity:wire_branch_up_off"},
})

minetest.register_craft({
	output = "electricity:wire_corner_off 2",
	recipe = {
		{"", "electricity:wire_off", ""},
		{"", "", "electricity:wire_off"},
		{"", "", ""}
	}
})

minetest.register_craft({
    type = "shapeless",
	output = "electricity:wire_off",
	recipe = {"electricity:wire_corner_off"},
})

minetest.register_craft({
    type = "shapeless",
	output = "electricity:stone_with_wire_off",
    recipe = {"electricity:wire_off", "default:stone"}
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
		{"default:goldblock", "default:coalblock", "default:goldblock"},
		{"default:obsidian", "default:obsidian", "default:obsidian"}
	}
})

minetest.register_craft({
	output = "electricity:lamp_off",
	recipe = {
		{"", "default:obsidian_glass", ""},
		{"electricity:wire_off", "default:steel_ingot", "electricity:wire_off"},
		{"", "default:obsidian_glass", ""}
	},
})

minetest.register_craft({
    type = "shapeless",
	output = "electricity:lamp_red_off",
    recipe = {"group:electricity_lamp", "dye:red"}
})

minetest.register_craft({
    type = "shapeless",
	output = "electricity:lamp_green_off",
    recipe = {"group:electricity_lamp", "dye:green"}
})

minetest.register_craft({
    type = "shapeless",
	output = "electricity:lamp_blue_off",
    recipe = {"group:electricity_lamp", "dye:blue"}
})

minetest.register_craft({
    type = "shapeless",
	output = "electricity:lamp_off",
    recipe = {"group:electricity_lamp", "dye:white"}
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
		{"electricity:wire_off", "default:diamond", "electricity:wire_off"},
		{"", "default:obsidian", ""}
	}
})

minetest.register_craft({
	output = "electricity:transistor_nc_off",
	recipe = {
		{"", "electricity:wire_off", ""},
		{"electricity:wire_off", "default:obsidian", "electricity:wire_off"},
		{"", "default:diamond", ""}
	}
})

minetest.register_craft({
	output = "electricity:piston_off",
	recipe = {
		{"group:wood",  "group:wood", "group:wood"},
		{"default:bronze_ingot", "default:steelblock", "default:bronze_ingot"},
		{"default:bronze_ingot", "electricity:wire_off", "default:bronze_ingot"},
	}
})

minetest.register_craft({
	output = "electricity:torch_off",
	recipe = {
    	{"electricity:wire_off"},
    	{"default:stick"},
    }
})

minetest.register_craft({
	output = "electricity:echest_closed",
	recipe = {
        {"default:tin_ingot", "default:tin_ingot", "default:tin_ingot"},
		{"default:tin_ingot", "electricity:wire_off", "default:tin_ingot"},
		{"default:tin_ingot", "default:tin_ingot", "default:tin_ingot"}
    }
})

minetest.register_craft({
	output = "electricity:biometrics_off",
	recipe = {
        {"default:stone", "electricity:wire_off", "default:stone"},
		{"default:stone", "default:obsidian_glass", "default:stone"},
		{"default:stone", "default:mese_crystal", "default:stone"}
    }
})

minetest.register_craft({
	output = "electricity:battery",
	recipe = {
        {"default:copper_ingot", "electricity:wire_off", "default:copper_ingot"},
		{"default:coal_lump", "default:coal_lump", "default:coal_lump"},
		{"default:tin_ingot", "default:tin_ingot", "default:tin_ingot"}
    }
})
