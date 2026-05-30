--[[
* Addons - Copyright (c) 2021 Ashita Development Team
* Contact: https://www.ashitaxi.com/
* Contact: https://discord.gg/Ashita
*
* This file is part of Ashita.
*
* Ashita is free software: you can redistribute it and/or modify
* it under the terms of the GNU General Public License as published by
* the Free Software Foundation, either version 3 of the License, or
* (at your option) any later version.
*
* Ashita is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
* GNU General Public License for more details.
*
* You should have received a copy of the GNU General Public License
* along with Ashita.  If not, see <https://www.gnu.org/licenses/>.
--]]

addon.name      = 'craftmonq';
addon.author    = 'atom0s (modified by Thotnessmonster)';
addon.version   = '1.0';
addon.desc      = 'Displays crafting results immediately upon starting a synth. (Result totals and toggles added by Thotnessmonster)';
addon.link      = 'https://ashitaxi.com/';

require('common');
local chat = require('chat');

-- craftmonq Variables
local nrm, brk, hq1, hq2, hq3, tot = 0, 0, 0, 0, 0, 0;
local showQual, showTot, showItem, trackTotal = true, false, true, true;
local craftResult = '';

--[[
* Prints the addon help information.
*
* @param {boolean} isError - Flag if this function was invoked due to an error.
--]]
local function print_help(isError)
    -- Print the help header..
    if (isError) then
        print(chat.header(addon.name):append(chat.error('Invalid command syntax for command: ')):append(chat.success('/' .. addon.name)));
    else
        print(chat.header(addon.name):append(chat.message('Available commands:')));
    end

    local cmds = T{
        { '/craftmonq or /cmq', 'Can use /craftmonq or /cmq for commands.' },
        { '/craftmonq help', 'Displays the addons help information.' },
        { '/craftmonq show (result | item | total | all)', 'Adds the information in the chatlog.' },
		{ '/craftmonq hide (result | item | total | all)', 'Stops adding the information in the chatlog.' },
        { '/craftmonq start', 'Starts tracking crafts.' },
        { '/craftmonq stop', 'Stops tracking crafts.' },
        { '/craftmonq total', 'Prints the current total and count.' },
        { '/craftmonq reset', 'Resets the total and count.' },
    };

    -- Print the command list..
    cmds:ieach(function (v)
        print(chat.header(addon.name):append(chat.error('Usage: ')):append(chat.message(v[1]):append(' - ')):append(chat.color1(6, v[2])));
    end);
end

--[[
* Returns the crafting result based on the animation id.
*
* @param {number} id - The craft animation id.
* @return {table} A table containing a color code and string representing the craft result type.
--]]
local function get_craft_result(res)
    return switch(res, {
        [0] = function () return { 1, 'Normal Quality', }; end,
        [1] = function () return { 39, 'Break', }; end,
        [2] = function () return { 5, 'High-Quality 1', }; end,
        [3] = function () return { 5, 'High-Quality 2', }; end,
        [4] = function () return { 5, 'High-Quality 3', }; end,
        [switch.default] = function ()
            return { 4, ('Unknown Quality (%d)'):fmt(res), };
        end
    });
end

--[[
* event: packet_in
* desc : Event called when the addon is processing incoming packets.
--]]
ashita.events.register('packet_in', 'packet_in_cb', function (e)
    -- Packet: Synthesis Animation
	if (e.id == 0x0030) then
        -- Obtain the local player..
        local player = GetPlayerEntity();
        -- Ensure the packet was for the local player..
        if (player ~= nil and player.TargetIndex == struct.unpack('H', e.data_modified, 0x08 + 0x01)) then
            local res = get_craft_result(struct.unpack('b', e.data_modified, 0x0C + 0x01));
			if (trackTotal == true) then
				craftResult = res[2]; end
			if (showQual == true) then
				print(chat.header(addon.name) + chat.color1(81, '>') + chat.message('Result: ') + chat.color1(res[1], res[2])); end			
        end
    end

    -- Packet: Synthesis Results
    if (e.id == 0x006F) then
		-- Checks if tracking is on and adds to the result counts..
		if (trackTotal == true) then
			if (craftResult == 'Normal Quality') then
				nrm = nrm + 1; tot = tot + 1; end
			if (craftResult == 'Break') then
				brk = brk + 1; tot = tot + 1; end
			if (craftResult == 'High-Quality 1') then
				hq1 = hq1 + 1; tot = tot + 1; end
			if (craftResult == 'High-Quality 2') then
				hq2 = hq2 + 1; tot = tot + 1; end
			if (craftResult == 'High-Quality 3') then
				hq3 = hq3 + 1; tot = tot + 1; end
		end
        -- Ensure the craft result was successful..
        local result = struct.unpack('b', e.data_modified, 0x04 + 0x01);
        if (result == 0) then
            -- Obtain the items resource information..
            local item = AshitaCore:GetResourceManager():GetItemById(struct.unpack('H', e.data_modified, 0x08 + 0x01));
            if (item ~= nil) then
                local c = struct.unpack('b', e.data_modified, 0x06 + 0x01);
                if (showItem == true) then
					print(chat.header(addon.name) + chat.color1(81, '>') + chat.message('Item: ') + chat.color1(72, item.Name[1]) + chat.message(' - Qty: ') + chat.success(c)); 
				end
            end
        end
        if (showTot == true) then
	        print(chat.header(addon.name) + chat.color1(81, '>') + chat.message('Total: ' + tot +', ') + chat.color1(1, 'NQ: ') + chat.message(nrm + ', ') + chat.color1(39, 'Brk: ') + chat.message(brk + ', ') + chat.color1(5, 'HQ1/2/3: ') + chat.message(hq1 + '/' + hq2 + '/' + hq3));
		end
    end
end)

--[[
* event: command
* desc : Event called when the addon is processing a command.
--]]
ashita.events.register('command', 'command_cb', function (e)
    -- Parse the command arguments..
    local args = e.command:args();
    if (#args == 0 or ( args[1] ~= '/craftmonq' and args[1] ~= '/cmq' )) then
        return;
    end

    -- Block all related commands..
    e.blocked = true;

    -- Handle: /craftmonq help - Shows the addon help.
    if (#args == 2 and args[2]:any('help')) then
        print_help(false);
        return;
    end

    -- Handle: /craftmonq show (result | item | total | all) - Adds the information in the log.
    if (#args == 3 and args[2]:any('show', 'Show')) then
		if (args[3]:any('result', 'res', 'Result')) then
			showQual = true; 
			print(chat.header(addon.name) + chat.color1(81, '>') + chat.message('Showing result.')); end
        if (args[3]:any('item', 'itm', 'Item')) then
			showItem = true;
			print(chat.header(addon.name) + chat.color1(81, '>') + chat.message('Showing item.')); end
		if (args[3]:any('total', 'tot', 'Total')) then
			showTot = true; 
			print(chat.header(addon.name) + chat.color1(81, '>') + chat.message('Showing total.')); end
		if (args[3]:any('all', 'All')) then
			showQual, showTot, showItem = true, true, true;
			print(chat.header(addon.name) + chat.color1(81, '>') + chat.message('Showing all.')); end			
		return;
    end
	
    -- Handle: /craftmonq hide (result | item | total | all) - Stops adding the information in the log.
    if (#args == 3 and args[2]:any('hide', 'Hide')) then
		if (args[3]:any('result', 'res', 'Result')) then
			showQual = false;
			print(chat.header(addon.name) + chat.color1(81, '>') + chat.message('Hiding result.')); end
		if (args[3]:any('item', 'itm', 'Item')) then
			showItem = false; 
			print(chat.header(addon.name) + chat.color1(81, '>') + chat.message('Hiding item.')); end
		if (args[3]:any('total', 'tot', 'Total')) then
			showTot = false;
			print(chat.header(addon.name) + chat.color1(81, '>') + chat.message('Hiding total.')); end
		if (args[3]:any('all', 'All')) then
			showQual, showTot, showItem = false, false, false; 
			print(chat.header(addon.name) + chat.color1(81, '>') + chat.message('Hiding all.')); end			
		return;
    end

    -- Handle: /craftmonq start - Starts tracking crafts.
    if (#args == 2 and args[2]:any('start', 'Start', 'on', 'On')) then
		print(chat.header(addon.name) + chat.color1(81, '>') + chat.message('Tracking started. Showing total.'));
        trackTotal = true;
        return;
    end

    -- Handle: /craftmonq stop - Stops tracking crafts.
    if (#args == 2 and args[2]:any('stop', 'Stop', 'off', 'Off')) then
		print(chat.header(addon.name) + chat.color1(81, '>') + chat.message('Tracking stopped. Hiding total.'));
        trackTotal = false;
        return;
    end

    -- Handle: /craftmonq total - Prints the current total and count.
    if (#args == 2 and args[2]:any('total', 'count', 'print')) then
        print(chat.header(addon.name) + chat.color1(81, '>') + chat.message('Total: ' + tot +', ') + chat.color1(1, 'NQ: ') + chat.message(nrm + ', ') + chat.color1(39, 'Brk: ') + chat.message(brk + ', ') + chat.color1(5, 'HQ1/2/3: ') + chat.message(hq1 + '/' + hq2 + '/' + hq3));
        return;
    end

    -- Handle: /craftmonq reset - Resets the total and count.
    if (#args == 2 and args[2]:any('reset')) then
		print(chat.header(addon.name) + chat.color1(81, '>') + chat.message('Total reset.'));
        nrm, brk, hq1, hq2, hq3, tot = 0, 0, 0, 0, 0, 0;
        return;
    end
	
    -- Unhandled: Print help information..
    print_help(true);
end);