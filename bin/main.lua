package.cpath = "?.dll;".. package.cpath
package.path = "?.lua;./?/init.lua;" .. package.path
-- local multi, thread = require("multi"):init()
-- GLOBAL, THREAD = require("multi.integration.threading"):init()
bin = require("bin")
json = require("json")
lfs = require("lfs")
gd = require("gd")
md5 = require("bin/hashes/md5")
random = require("bin/numbers/random")
song_list = {}
name_list = {}
track_list = {}
local pack_version = 8
local version = "1.0"

function isDir(name)
    if type(name)~="string" then return false end
    local cd = lfs.currentdir()
    local is = lfs.chdir(name) and true or false
    lfs.chdir(cd)
    return is
end

function isFile(name)
    if type(name)~="string" then return false end
    if not isDir(name) then
        return os.rename(name,name) and true or false
    end
    return false
end

function tprint (tbl, indent)
    if not indent then indent = 0 end
    for k, v in pairs(tbl) do
        formatting = string.rep("  ", indent) .. k .. ": "
        if type(v) == "table" then
            print(formatting)
            tprint(v, indent+1)
        elseif type(v) == 'boolean' then
            print(formatting .. tostring(v))      
        else
            print(formatting .. v)
        end
    end
end

for song in lfs.dir("../music") do
    if isFile("../music/"..song) then
        table.insert(track_list, song:match("(.+)%.ogg"))
        table.insert(name_list, song:lower():gsub("%s",""):match(".+%-(%S+)%."))
        table.insert(song_list, song)
    end
end

if isFile("index.json") then
    -- We need to keep indexes for the old records
    local data = json:decode(bin.load("index.json").data)
    local old = {}
    local new = {}
    for i,v in pairs(track_list) do
        if data[v] then
            table.insert(old,"../music/"..v..".ogg")
        else
            table.insert(new,"../music/"..v..".ogg")
        end
    end
    for i,v in pairs(new) do
        table.insert(old,v)
    end
    track_list = {}
    name_list = {}
    song_list = {}
    for _,song in pairs(old) do
        if isFile(song) then
            song = song:match("../music/(.+)")
            table.insert(track_list, song:match("(.+)%.ogg"))
            table.insert(name_list, song:lower():gsub("%s",""):match(".+%-(%S+)%."))
            table.insert(song_list, song)
        end
    end
    local data = {}
    for i = 1,#track_list do
        data[track_list[i]] = i
    end
    bin.new(json:encode_pretty(data)):tofile("index.json")
else
    local data = {}
    for i = 1,#track_list do
        data[track_list[i]] = i
    end
    bin.new(json:encode_pretty(data)):tofile("index.json")
end

function string.split(inputstr, sep)
    if sep == nil then
        sep = "%s"
    end
    local t={}
    for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
            table.insert(t, str)
    end
    return t
end

function CreateDisk(path)
    local hash = md5.sumhexa(path)
    hash = hash:sub(1,math.floor(#hash/4))
    seed = tonumber(hash,16)
    rand = random:new(seed)
    for i = 1,300 do
        rand:randomInt(0,0)
    end
    function RandomColor()
        return {rand:randomInt(0,255),rand:randomInt(0,255),rand:randomInt(0,255)}
    end
    function LightenColor(color,v)
        return {color[1] + (255 - color[1]) * v,color[2] + (255 - color[2]) * v,color[3] + (255 - color[3]) * v}
    end
    disc = gd.createFromPng("source.png")
    color = RandomColor()
    lcolor = LightenColor(color,.35)
    bg = disc:colorAllocate(0,0,0)
    dark = disc:colorAllocate(unpack(color))
    light = disc:colorAllocate(unpack(lcolor))

    disc:colorTransparent(bg)

    color_dark = {
        {6,6},{7,6},{8,6},{5,7},{6,7}
    }
    color_light = {
        {8,7},{9,7},{6,8},{7,8},{8,8}
    }

    for _,p in pairs(color_dark) do
        disc:setPixel(p[1],p[2],dark)
    end

    for _,p in pairs(color_light) do
        disc:setPixel(p[1],p[2],light)
    end

    disc:png(path)
end

function buildPath(path)
    local paths = path:split("/")
    local p = {}
    for i = 1,#paths do
        table.insert(p,paths[i])
        lfs.mkdir(table.concat(p,"/"))
    end
end

function writeMCFunction(name,fname,file)
    file:tofile("../"..name.."/data/"..name.."/functions/"..fname..".mcfunction")
end

function BuildDatapack(name)
    os.execute("rmdir /s /q ../"..name)
    buildPath("../"..name .. "/data/minecraft/tags/functions")
    buildPath("../"..name .. "/data/minecraft/loot_tables/entities")
    buildPath("../"..name .. "/data/"..name.."/functions")

    -- Write 'pack.mcmeta'
    bin.new(json:encode_pretty({pack={
        pack_format = 7;
        description = "Adds " .. #name_list .. " custom music discs to minecraft"
    }})):tofile("../"..name.."/pack.mcmeta")

    -- Write 'load.json'
    bin.new(json:encode_pretty({values={
        name..":setup_load"
    }})):tofile("../"..name.."/data/minecraft/tags/functions/load.json")

    -- Write 'tick.json'
    bin.new(json:encode_pretty({values={
        name..":detect_play_tick",
        name..":detect_stop_tick"
    }})):tofile("../"..name.."/data/minecraft/tags/functions/tick.json")

    -- Write 'setup_load.mcfunction'
    writeMCFunction(name,'setup_load',bin.new([[
scoreboard objectives add usedDisc minecraft.used:minecraft.music_disc_11
scoreboard objectives add heldDisc dummy

tellraw @a {"text":"Custom Music Discs V]]..version..[[!","color":"yellow"}
    ]]))

    -- Write 'detect_play_tick.mcfunction'
    writeMCFunction(name,'detect_play_tick',bin.new([[
execute as @a[scores={usedDisc=0}] run scoreboard players set @s heldDisc -1
execute as @a[scores={usedDisc=0},nbt={Inventory:[{Slot:-106b,id:"minecraft:music_disc_11"}]}] store result score @s heldDisc run data get entity @s Inventory[{Slot:-106b}].tag.CustomModelData
execute as @a[scores={usedDisc=0},nbt={SelectedItem:{id:"minecraft:music_disc_11"}}] store result score @s heldDisc run data get entity @s SelectedItem.tag.CustomModelData
execute as @a[scores={usedDisc=2}] run function ]]..name..[[:disc_play

execute as @a run scoreboard players add @s usedDisc 0
execute as @a[scores={usedDisc=2..}] run scoreboard players set @s usedDisc 0
scoreboard players add @a[scores={usedDisc=1}] usedDisc 1
    ]]))

    -- Write 'disc_play.mcfunction'
    disc_play = bin.new()
    for i,v in pairs(name_list) do
        disc_play:tackE("execute as @s[scores={heldDisc="..i.."}] run function "..name..":play_"..v.."\n")
    end
    writeMCFunction(name,'disc_play',disc_play)

    -- Write 'detect_stop_tick.mcfunction'
    writeMCFunction(name,'detect_stop_tick',bin.new([[
execute as @e[type=item, nbt={Item:{id:"minecraft:music_disc_11"}}] at @s unless entity @s[tag=old] if block ~ ~-1 ~ minecraft:jukebox run function ]]..name..[[:disc_stop
execute as @e[type=item, nbt={Item:{id:"minecraft:music_disc_11"}}] at @s unless entity @s[tag=old] if block ~ ~ ~ minecraft:jukebox run function ]]..name..[[:disc_stop
execute as @e[type=item, nbt={Item:{id:"minecraft:music_disc_11"}}] at @s unless entity @s[tag=old] run tag @s add old
    ]]))

    -- Write 'disc_stop.mcfunction'
    disc_stop = bin.new()
    for i,v in pairs(name_list) do
        disc_stop:tackE("execute as @s[nbt={Item:{tag:{CustomModelData:"..i.."}}}] at @s run stopsound @a[distance=..64] record minecraft:music_disc."..v.."\n")
    end
    writeMCFunction(name,'disc_stop',disc_stop)

    -- Write 'set_disc_track.mcfunction'
    set_disc_track = bin.new()
    for i,v in pairs(track_list) do
        set_disc_track:tackE('execute as @s[nbt={SelectedItem:{id:"minecraft:music_disc_11", tag:{CustomModelData:'..i..'}}}] run item replace entity @s weapon.mainhand with minecraft:music_disc_11{CustomModelData:'..i..', HideFlags:32, display:{Lore:[\"\\\"\\\\u00a77'..(v:gsub('"',""))..'\\\"\"]}}\n')
    end
    writeMCFunction(name,"set_disc_track",set_disc_track)

    -- Write 'play_*.mcfunction' files
    for i,v in pairs(name_list) do
        writeMCFunction(name,"play_"..v,bin.new([[
execute as @s at @s run title @a[distance=..64] actionbar {"text":"Now Playing: ]]..(track_list[i]:gsub('"',""))..[[","color":"green"}
execute as @s at @s run stopsound @a[distance=..64] record minecraft:music_disc.11
execute as @s at @s run playsound minecraft:music_disc.]]..v..[[ record @a[distance=..64] ~ ~ ~ 4 1
        ]]))
    end

    -- Write 'give_*_disc.mcfunction' files
    for i,v in pairs(track_list) do
        writeMCFunction(name,"give_"..name_list[i],bin.new([[execute as @s at @s run summon item ~ ~ ~ {Item:{id:"minecraft:music_disc_11", Count:1b, tag:{CustomModelData:]]..i..[[, HideFlags:32, display:{Lore:["\"\\u00a77]]..v..[[\""]}}}}]]))
    end

    -- Write 'give_all_discs.mcfunction'
    give_all = bin.new()
    for i,v in pairs(track_list) do
        give_all:tackE([[execute as @s at @s run summon item ~ ~ ~ {Item:{id:"minecraft:music_disc_11", Count:1b, tag:{CustomModelData:]]..i..[[, HideFlags:32, display:{Lore:["\"\\u00a77]]..v..[[\""]}}}}]].."\n")
    end
    writeMCFunction(name,"give_all_discs",give_all)

    -- Write 'creeper.json'
    creeper_mdentries = {}
    table.insert(creeper_mdentries,{
        type="minecraft:tag",
        weight = 1,
        name = "minecraft:creeper_drop_music_discs",
        expand = true
    })
    for i,track in pairs(track_list) do
        table.insert( creeper_mdentries, {
            type = 'minecraft:item', 
            weight = 1, 
            name = 'minecraft:music_disc_11', 
            functions = {
                {
                    ['function']='minecraft:set_nbt', 
                    tag='{CustomModelData:'..i..', HideFlags:32, display:{Lore:[\"\\\"\\\\u00a77'..(track:gsub('"',''))..'\\\"\"]}}'
                }
            }
        })
    end
    creeper_normentries = {
        {
            type = 'minecraft:item',
            functions = {
                {
                    ['function']='minecraft:set_count',
                    count={
                        min=0,
                        max=2,
                        type='minecraft:uniform'
                    }
                },
                {
                    ['function']='minecraft:looting_enchant',
                    count={
                        min = 0,
                        max = 1
                    }
                }
            },
            name = 'minecraft:gunpowder'
        }
    }
    creeper = bin.new(json:encode_pretty({
        type = 'minecraft:entity',
        pools={
            {
                rolls=1,
                entries = creeper_normentries
            },
            {
                rolls=1,
                entries = creeper_mdentries,
                conditions = {
                    {
                        condition='minecraft:entity_properties',
                        predicate={
                            type='#minecraft:skeletons'
                        },
                        entity='killer'
                    }
                }
            }
        }
    }))
    creeper:tofile("../"..name.."/data/minecraft/loot_tables/entities/creeper.json")
    bin.load("pack.png"):tofile("../"..name.."/pack.png")
end
function BuildResourcepack(name)
    os.execute("rmdir /s /q ../"..name)
    buildPath("../"..name .. "/assets/minecraft/models/item")
    buildPath("../"..name .. "/assets/minecraft/sounds/records")
    buildPath("../"..name .. "/assets/minecraft/textures/item")

    -- Write 'pack.mcmets'
    bin.new(json:encode_pretty({
        pack = {
            pack_format = pack_version,
            description = "Adds " .. #name_list .. " custom music discs to minecraft"
        }
    })):tofile("../"..name .. "/pack.mcmeta")

    -- Write 'sounds.json'
    pack = bin.new('{')
    for i,v in pairs(name_list) do
        pack:tackE('\n"music_disc.'..v..'":')
        pack:tackE(json:encode_pretty({
            sounds = {
                {
                    name='records/'..v,
                    stream = true
                }
            }
        }))
        if i < #name_list then
            pack:tackE(",\n")
        end
    end
    pack:tackE('\n}')
    pack:tofile("../"..name.."/assets/minecraft/sounds.json")

    -- Write 'music_disc_11.json'
    music_disc_11 = bin.new()
    json_list = {}
    for i,v in pairs(name_list) do
        table.insert(json_list,{
            predicate={
                custom_model_data = i
            },
            model = 'item/music_disc_'..v
        })
    end

    music_disc_11:tackE(json:encode_pretty({
        parent='item/generated',
        textures={
            layer0 = 'item/music_disc_11'
        },
        overrides=json_list
    }))

    music_disc_11:tofile("../"..name.."/assets/minecraft/models/item/music_disc_11.json")

    -- Write 'music_disc_*.json' files
    for i,v in pairs(name_list) do
        bin.new(json:encode_pretty({
            parent='item/generated',
            textures={
                layer0='item/music_disc_'..v
            }
        })):tofile("../"..name.."/assets/minecraft/models/item/music_disc_"..v..".json")
    end

    -- Copy sound and texture files
    for i,v in pairs(name_list) do
        bin.load("../music/"..song_list[i]):tofile("../"..name.."/assets/minecraft/sounds/records/"..v..".ogg")
        CreateDisk("../"..name.."/assets/minecraft/textures/item/music_disc_"..v..".png")
    end

    -- Copy pack.png
    bin.load("pack.png"):tofile("../"..name.."/pack.png")
end
BuildDatapack("cmd_dp")
BuildResourcepack("cmd_rp")