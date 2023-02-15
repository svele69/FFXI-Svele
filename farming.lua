--[[
Copyright (c) 2023, Svele
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

* Redistributions of source code must retain the above copyright
notice, this list of conditions and the following disclaimer.
* Redistributions in binary form must reproduce the above copyright
notice, this list of conditions and the following disclaimer in the
documentation and/or other materials provided with the distribution.
* Neither the name of azureSets nor the
names of its contributors may be used to endorse or promote products
derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL The Addon's Contributors BE LIABLE FOR ANY
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
]]

_addon.name = 'FarmCP'
_addon.author = 'SveLe'
_addon.version = '15.02.2023.02 (Beta)'
_addon.command = 'farmcp'

config = require('config')
packets = require('packets')
res = require('resources')

Start_Engine = true
isCasting = false
isBusy = 0
buffactive = {}
Action_Delay = 3

buffactive = {}

defaults = {}
defaults.autotarget = false
defaults.targets = S{}
defaults.debuff = ""
defaults.pull = false

tickdelay = os.clock() + 5

settings = config.load({
    targets = L{},
    add_to_chat_mode = 8,
    sets = {},
    pull = false,
    debuff = "",
})

windower.register_event('incoming chunk', function(id, data)
    if id == 0x028 then
        local action_message = packets.parse('incoming', data)
		if action_message["Category"] == 4 then
			isCasting = false
		elseif action_message["Category"] == 8 then
			isCasting = true
			if action_message["Target 1 Action 1 Message"] == 0 then
				isCasting = false
				isBusy = Action_Delay
			end
		end
	end
end)

windower.register_event('outgoing chunk', function(id, data)
    if id == 0x015 then
        local action_message = packets.parse('outgoing', data)
		PlayerH = action_message["Rotation"]
	end
end)


function Engine()
    local player = windower.ffxi.get_player()
    Buffs = windower.ffxi.get_player()["buffs"]
    table.reassign(buffactive,convert_buff_list(Buffs))
    local t = windower.ffxi.get_mob_by_target('t')
    local current_time = os.clock()
    
   -- tickdelay = os.clock() + 10

    if player.status == 0 and current_time > tickdelay then
        target_nearest(settings.targets)
        
    end
    --windower.add_to_chat(settings.add_to_chat_mode, tickdelay .. ' tickdelay')
    --windower.add_to_chat(settings.add_to_chat_mode, current_time .. ' current_time')

    if player.status == 0 and not (windower.ffxi.get_mob_by_target('t') == '' or windower.ffxi.get_mob_by_target('t') == nil) then
        if t.distance:sqrt() > 4 and settings.pull == true and settings.debuff == "range" then
            windower.send_command("ra")
        elseif t.distance:sqrt() > 4 and settings.pull == true and not settings.debuff == "range" then
            windower.send_command("input /ma " .. settings.debuff)
        end
        windower.send_command("input /attack")
        
    elseif not (t == '' or t == nil) and current_time > tickdelay then
        if player.status == 1 and  t.distance:sqrt() > 3.85 then
            windower.send_command("input /attack")
        end
    end
    
    if player.status == 1 and not (windower.ffxi.get_mob_by_target('t') == '' or windower.ffxi.get_mob_by_target('t') == nil) then
            TurnToTarget()
    end

	if Start_Engine then
		coroutine.schedule(Engine,1)
	end
end


function convert_buff_list(bufflist)
    local buffarr = {}
    for i,v in pairs(bufflist) do
        if res.buffs[v] then -- For some reason we always have buff 255 active, which doesn't have an entry.
            local buff = res.buffs[v].english
            if buffarr[buff] then
                buffarr[buff] = buffarr[buff] +1
            else
                buffarr[buff] = 1
            end
            
            if buffarr[v] then
                buffarr[v] = buffarr[v] +1
            else
                buffarr[v] = 1
            end
        end
    end
    return buffarr
end

function target_nearest(target_names)
    local mobs = windower.ffxi.get_mob_array()
    local closest
    local player = windower.ffxi.get_player()

    for _, mob in pairs(mobs) do
        if mob.valid_target and mob.hpp > 0 and target_names:contains(mob.name:lower()) then
            if not closest or mob.distance < closest.distance then
                closest = mob
            end
        end
    end

    if not closest then
        windower.add_to_chat(settings.add_to_chat_mode, 'Cannot find valid target')
        return
    end

    packets.inject(packets.new('incoming', 0x058, {
        ['Player'] = player.id,
        ['Target'] = closest.id,
        ['Player Index'] = player.index,
    }))

    tickdelay = os.clock() + 20
end

function HeadingTo(X,Y)
	local X = X - windower.ffxi.get_mob_by_id(windower.ffxi.get_player().id).x
	local Y = Y - windower.ffxi.get_mob_by_id(windower.ffxi.get_player().id).y
	local H = math.atan2(X,Y)
	return H - 1.5708
end

function TurnToTarget()
    local destX = windower.ffxi.get_mob_by_target('t').x
    local destY = windower.ffxi.get_mob_by_target('t').y
    local direction = math.abs(PlayerH - math.deg(HeadingTo(destX,destY)))
    if direction > 10 then
        windower.ffxi.turn(HeadingTo(destX,destY))
    end
end

commands = {}

commands.save = function(set_name)
    if not set_name then
        windower.add_to_chat(11, 'A saved target set needs a name: //farmcp save <set>')
        return
    end

    settings.sets[set_name] = L{settings.targets:unpack()}
    settings:save()
    windower.add_to_chat(11, set_name .. ' saved')
end

commands.load = function(set_name)
    if not set_name or not settings.sets[set_name] then
        windower.add_to_chat(11, 'Unknown target set: //farmcp load <set>')
        return
    end

    settings.targets = L{settings.sets[set_name]:unpack()}
    settings:save()
    windower.add_to_chat(11, set_name .. ' target set loaded')
end



commands.add= function(...)
    local targets = T{...}:sconcat()
    if targets == 'nil' then return end

    if targets == '' then
        local selected_target = windower.ffxi.get_mob_by_target('t')
        if not selected_target then return end
        targets = selected_target.name
    end

    targets = targets:lower()
    if not settings.targets:contains(targets) then
        settings.targets:append(targets)
        settings.targets:sort()
        settings:save()
    end

    windower.add_to_chat(settings.add_to_chat_mode, targets .. ' added')
end
commands.a = commands.add

commands.list = function()
    if settings.targetd == 0 then
        windower.add_to_chat(11, 'There are no targets set')
        return
    end

    windower.add_to_chat(11, 'Targets:')
    for _, target in ipairs(settings.targets) do
        windower.add_to_chat(11, '  ' .. target)
    end
end
commands.l = commands.list

commands.start = function()
    windower.add_to_chat(2,"....Starting CP-Farm Helper....")
    Start_Engine = true
    Engine()
end
commands.s = commands.start

commands.halt = function()
    windower.add_to_chat(2,"....Stopping CP-Farm Helper....")
		Start_Engine = false
    end
commands.h = commands.halt

commands.remove = function(...)
    local target = T{...}:sconcat()

    if target == '' then
        local selected_target = windower.ffxi.get_mob_by_target('t')
        if not selected_target then return end
        target = selected_target.name
    end

    target = target:lower()
    local new_targets = L{}
    for k, v in ipairs(settings.targets) do
        if v ~= target then
            new_targets:append(v)
        end
    end
    settings.targets = new_targets
    settings:save()
    windower.add_to_chat(settings.add_to_chat_mode, target .. ' removed')
end
commands.r = commands.remove

commands.spell = function(str)
    if L{"dia","bio","provoke","flash","hj","fq","range"}:contains(str) then
        settings.debuff = str
        windower.add_to_chat(settings.add_to_chat_mode, ("Using pull : %s"):format(str))
    else
        windower.add_to_chat(settings.add_to_chat_mode,"Please specify one of the valid augmenting styles: [Range,Dia,Bio,Flash,Provoke,hj(Hojo:Ni)],fq(Foe requiem VII)")
    end

end


commands.pull = function(bool)
    if bool then
        if L{"true","t","yes","y"}:contains(bool) then
            settings.pull = true
            windower.add_to_chat(11, 'Pull Mode enabled')
        elseif L{"false","f","no","n"}:contains(bool) then
            settings.pull = false
            windower.add_to_chat(11, 'Pull Mode disabled')
        end
    else
        settings.pellucid = not settings.pellucid
    end
end
commands.p = commands.pull


commands.show = function()
    windower.add_to_chat(11,"Autotarget: "..tostring(settings.autotarget))
	windower.add_to_chat(11,"Debuff: "..settings.debuff)
	windower.add_to_chat(11,"Pull Mode "..tostring(settings.pull))
	windower.add_to_chat(11,"Target(s): "..settings.targets:tostring())
end



commands.help = function()
    windower.add_to_chat(11, 'Farm CP:')
    windower.add_to_chat(11, '  //farmcp add <target name> - add a target to the list')
    windower.add_to_chat(11, '  //farmcp remove <target name> - remove a target from the list')
    windower.add_to_chat(11, '  //farmcp pull true/false - Pullmode on or off')
    windower.add_to_chat(11, '  //farmcp spell - Dia / Provoke / ...')
    windower.add_to_chat(11, '  //farmcp start - target the nearest target from the list')
    windower.add_to_chat(11, '  //farmcp save <set> - save current targets as a target set')
    windower.add_to_chat(11, '  //farmcp load <set> - load a previously saved target set')
    windower.add_to_chat(11, '  //farmcp list - list current targets')
    windower.add_to_chat(11, '  //farmcp help - display this help')
    windower.add_to_chat(11, '(For more detailed information, see the readme)')
end



windower.register_event('addon command', function(command, ...)
    command = command and command:lower() or 'help'

    if commands[command] then
        commands[command](...)
    else
        commands.help()
    end
end)

buff_spell_lists = {

	Default = {
		{Name='Jubuku: Ichi',Buff='Subtle Blow Plus',SpellID=341,Reapply=false},
		{Name='Hojo: Ni',Buff='Store TP',SpellID=345,Reapply=false},

	},
}