/*
    contains all functions responsible for processing the Packets the AP Server sends

    the function names are the same as the names of the packet commands the server sends 
    (https://github.com/ArchipelagoMW/Archipelago/blob/main/docs/network%20protocol.md#server---client),
    when a message is received the code looks for a function with a name matching the 
    command it received in the PacketProcessor table and calls it
*/

local PR = {}

local RoomBase = { -- this is also present in slotbase.lua which isn't great
    Members = {},
    DataPackage = {
        games = {}
    },
    DataStore = {},
    GiftBoxes = {},
}

function PR.RoomInfo( packet , slot )
    slot.Socket.VoluntaryDC = false
    print("Received RoomInfo, GMOD and AP time difference: ", os.time() - packet.time )
    packet.cmd = nil

    local pwstring = '"password":"'..slot.password..'",'
    if packet.password then

    end

    packet.password = nil

    if GMAP.Rooms[slot.address].seed_name != packet.seed_name then
        GMAP.Rooms[slot.address] = table.Copy(RoomBase)
    end
    table.Merge(GMAP.Rooms[slot.address],packet)

    local gamename = slot.game
    local tags = {}
    if slot.receiveAPchat == false then
        tags[#tags+1] = "NoText"
    end
    slot.cantSendLocations = nil
    if slot.textOnly == true or gamename == "" then
        tags[#tags+1] = "TextOnly"
        slot.cantSendLocations = true
    end
    if slot.deathlink == true then
        tags[#tags+1] = "DeathLink"
    end

    local requestedDPs = {}

    local datapack = slot.Room.DataPackage

    if table.IsEmpty(datapack.games) then
      for k,v in pairs(packet.datapackage_checksums) do
        if file.Exists("archipelago/datapackages/"..k.."/"..v..".json","DATA") then
          datapack.games[k] = util.JSONToTable(file.Read("archipelago/datapackages/"..k.."/"..v..".json","DATA"))
          local gamedp = datapack.games[k]
          gamedp.location_id_to_name = table.Flip(gamedp.location_name_to_id)
          gamedp.item_id_to_name = table.Flip(gamedp.item_name_to_id)

          GMAP.DataPackageRegister[k] = GMAP.DataPackageRegister[k] or {}
          GMAP.DataPackageRegister[k][v] = os.time()
        else
          requestedDPs[#requestedDPs+1] = k
        end
      end
    end

    local DPString = ""

    if !table.IsEmpty(requestedDPs) then
        print("requesting DataPackages for: "..util.TableToJSON(requestedDPs))
        DPString = '{"cmd":"GetDataPackage","games":'..util.TableToJSON(requestedDPs)..'},'
    end

    slot.Socket:write('['..DPString..'{"cmd":"Connect","name":"'..slot.slotName..'","game":"'..gamename..'",'..pwstring..'"slot_data":true,"items_handling":7,"uuid":"","tags":'..util.TableToJSON(tags)..',"version":{"major":0,"minor":6,"build":1,"class":"Version"}}]')
end



local function ProcessLocations(oldLctns, val)
    local newLctns = {}
    for k,v in ipairs(oldLctns) do
        newLctns[v] = val
    end
    return newLctns
end

function PR.Connected( packet , slot )
    print("Received Connection Info")
    packet.cmd = nil

    if slot.game == "" then
        if table.HasValue(slot.tags,"TextOnly") == false then
            slot.game = packet.slot_info[packet.slot].game
        end
    end

    slot.Locations = table.Merge(ProcessLocations(packet.missing_locations,false),ProcessLocations(packet.checked_locations,true))
    for k,v in pairs(slot.Locations) do
        GMAP.RunTrackers(slot.ID,"lctn",k)
    end

    slot.slotData = packet.slot_data
    slot.Nr = packet.slot
    slot.hintPoints = packet.hint_points
    slot.team = packet.team

    local playertbl = {} -- same code is also run in RoomUpdate, consider turning this into a function

    for k,v in ipairs(packet.players) do
        v.class = nil
        local teamid = v.team
        local slotid = v.slot
        v.team = nil
        v.slot = nil
        playertbl[teamid] = playertbl[teamid] or {}
        playertbl[teamid][slotid] = v
    end

    slot.Room.Players = playertbl

    for k,v in pairs(packet.slot_info) do
        v.class = nil
    end
    slot.Room.SlotInfo = packet.slot_info

    slot.Items = {} or slot.Items

    hook.Run("AP_Connect",slot.ID)
    print("running ".."AP_"..slot.ID.."_LocationListUpdate")
    hook.Run("AP_"..slot.ID.."_LocationListUpdate")
    print("running ".."AP_"..slot.ID.."_ItemListUpdate")
    hook.Run("AP_"..slot.ID.."_ItemListUpdate")
    slot.Socket:write('[{"cmd":"Sync"}]')

    local giftboxkeys = {}

    for k,v in pairs(playertbl) do
        giftboxkeys[#giftboxkeys+1] = "GiftBoxes;"..k
    end
    local giftboxproto = {
        [slot.Nr]={
        is_open=true,
        accepts_any_gift=true,
        desired_traits={},
        minimum_gift_data_version=3,
        maximum_gift_data_version=3,
    }}
    slot:DataStoreSet("GiftBoxes;"..slot.team,giftboxproto,true,{{operation="update",value=""}})
    -- gmods json converter automatically converts empty tables to arrays instead of dictonaries so we need to prewrite the command for this
    slot.Socket:write('[{"cmd":"Set","want_reply":true,"key":"GiftBox;'..slot.team..';'..slot.Nr..'","default":{},"operations":[{"operation":"default","value":{}}]}]')
    --slot:DataStoreSet("GiftBox;"..slot.team..";"..slot.Nr,{},true,{{operation="default",value=""}})
    slot:DataStoreGet(giftboxkeys)
    slot:DataStoreSetNotify(giftboxkeys)
end



function PR.ConnectionRefused( packet , slot )
    slot.Socket:close()
    print("Connection Refused: ", util.TableToJSON(packet.errors))
end



local ownslotcolor = GMAP.Colors.apmagenta
local otherslotcolor = GMAP.Colors.apyellow

function PR.PrintJSON( packet , slot )
    if not string.EndsWith( tostring(packet.data[1]["text"]) , slot.lastSentChat ) then -- does this still work?
        --AutoPrint(packet)
        if slot.forwardAPchat == true then
            if packet.type == "Chat" then
                local num = packet.slot
                local teamid = packet.team
                local color = otherslotcolor
                if num == slot.Nr then
                    color = ownslotcolor
                end
                    GMAP.SendChatMessage(slot.Room.Players[teamid][num].alias,color,false)
                    GMAP.SendChatMessage(": "..packet.message,color_white,true)
            elseif packet.type == "ServerChat" then
                GMAP.SendChatMessage("AP Server: ",color_white,false)
                GMAP.SendChatMessage(packet.message,color_white,true)
            else
                for k,v in ipairs(packet.data) do
                    if v.type == "item_id" then
                        GMAP.SendChatMessage(slot.Room.DataPackage.games[slot.Room.SlotInfo[v.player].game].item_id_to_name[tonumber(v.text)],GMAP.ItemTypeColors[v.flags],false)
                    elseif v.type == "location_id" then
                        GMAP.SendChatMessage(slot.Room.DataPackage.games[slot.Room.SlotInfo[v.player].game].location_id_to_name[tonumber(v.text)],Color(128, 255, 191),false)
                    elseif v.type == "player_id" then
                        local num = tonumber(v.text)
                        local color = otherslotcolor
                        if num == slot.Nr then
                            color = ownslotcolor
                        end
                        GMAP.SendChatMessage(slot.Room.Players[slot.team][num].alias,color,false)
                    elseif v.type == "Goal" then
                        GMAP.SendChatMessage(v.text,Color(255,255,0),false)
                    else
                        GMAP.SendChatMessage(v.text,color_white,false)
                    end
                end
                GMAP.SendChatMessage("",color_white,true)
            end
        end
        hook.Run("AP_"..slot.ID.."_ChatMessage",packet)
    end
end

----------------- ReceivedItems

-- rearranges the data from the ReceivedItems Packet into a format that allows for faster lookups
local function ProcessItems(oldItems) 
  local newItems = {}
  for k,v in ipairs(oldItems) do
    local ID = v.item
    newItems[ID] = newItems[ID] or {}
    local listpos = #newItems[ID]+1
    newItems[ID][listpos] = table.Copy(v)
    newItems[ID][listpos].item , newItems[ID][listpos].class = nil
  end
  return newItems
end

function PR.ReceivedItems( packet , slot )
    --print(packet.index, slot.lastItemIndex)
    if packet.index == 0 then
        slot.Items = ProcessItems(packet.items)
        for k,v in pairs(slot.Items) do
            GMAP.RunTrackers(slot.ID,"item",k)
        end
        hook.Run("AP_"..slot.ID.."_ItemListUpdate")
    elseif packet.index == slot.lastItemIndex then
        local newItems = ProcessItems(packet.items)
        local trackertbl = {}
        if GMAP.Trackers[slot.ID] != nil then
            trackertbl = GMAP.Trackers[slot.ID].item
        else
            trackertbl = nil
        end
        for k, v in pairs(newItems) do
            print(k,v)
            if slot.Items[k] != nil then
            --PrintTable(slot.Items[k])
            table.Add(slot.Items[k],newItems[k])
            else
            --print("itemsprocessed is nil")
            slot.Items[k] = newItems[k]
            end
            GMAP.RunTrackers(slot.ID,"item",k)
        end
        hook.Run("AP_"..slot.ID.."_ItemListUpdate")
    else
        slot.Items = {} -- if the slot hasn't received any items yet the server won't send anything back so we have to clear the item lists out just in case
        hook.Run("AP_"..slot.ID.."_ItemListUpdate") -- this also means we have to send out another itemlistupdate event, which might be followed up by another right after
        slot.Socket:write('[{"cmd":"Sync"}]')
    end
    slot.lastItemIndex = packet.index + #packet.items
end

-------------------- DataPackage

function PR.DataPackage( packet , slot )
    print("Received DataPackage")

    for k,v in pairs(packet.data.games) do
        if !file.IsDir("/archipelago/datapackages/"..k.."/","DATA") then
            file.CreateDir("archipelago/datapackages/"..k)
        end
        file.Write("archipelago/datapackages/"..k.."/"..packet.data.games[k].checksum..".json",util.TableToJSON(packet.data.games[k],true)) -- could set the prettyprint option in tabletojson to false later to save some space
        packet.data.games[k].location_id_to_name = table.Flip(v.location_name_to_id)
        packet.data.games[k].item_id_to_name = table.Flip(v.item_name_to_id)

        GMAP.DataPackageRegister[k] = GMAP.DataPackageRegister[k] or {}
        GMAP.DataPackageRegister[k][packet.data.games[k].checksum] = os.time()
    end

    table.Merge(slot.Room.DataPackage, packet.data)
end 

-------------------- Bounced

function PR.Bounced( packet , slot )
    print("Received Bounce Package for "..slot.ID)
    if istable(packet.tags) then
        local newtags = {}
        for k,v in ipairs(packet.tags) do 
            newtags[v] = true
        end
        packet.tags = newtags
    end
    if istable(packet.games) then
        local newgames = {}
        for k,v in ipairs(packet.games) do 
            newgames[v] = true
        end
        packet.games = newgames
    end
    if istable(packet.slots) then
        local newslots = {}
        for k,v in ipairs(packet.slots) do 
            newslots[v] = true
        end
        packet.slots = newslots
    end
    local hkrtrn = hook.Run("AP_Bounced",slot,packet)
    if hkrtrn != nil then
        hkrtrn = hook.Run("AP_Bounced_"..slot.ID,packet)
    end
    PrintTable(packet)
end 

--------------------- RoomUpdate

function PR.RoomUpdate( packet, slot )
    print("Received RoomUpdate")
    PrintTable(packet)
    if packet.checked_locations != nil then
        for k,v in ipairs(packet.checked_locations) do
            if slot.Locations[v] != true then
                slot.Locations[v] = true
                GMAP.RunTrackers(slot.ID,"lctn",v)
                hook.Run("AP_"..slot.ID.."_LocationListUpdate")
            end
        end
    end
    if packet.players then
        local playertbl = {} -- same code is also run in Connected, consider turning this into a function

        for k,v in ipairs(packet.players) do
            v.class = nil
            local teamid = v.team
            local slotid = v.slot
            v.team = nil
            v.slot = nil
            playertbl[teamid] = playertbl[teamid] or {}
            playertbl[teamid][slotid] = v
        end

        slot.Room.Players = playertbl
    end
end



local function DSHandler(slot, key, value)
    if string.StartsWith(key,"GiftBoxes;") then
        local teamnum = tonumber(string.sub(key,11,-1))
        for k,v in pairs(value) do
            local newtraits = {}
            print("desired_traits",v.desired_traits,v)
            if v.desired_traits then
                for ik,iv in ipairs(v.desired_traits) do
                    newtraits[iv] = true
                end
            end
            v.desired_traits = newtraits
            slot.Room.GiftBoxes[teamnum] = value
        end
    else
        slot.Room.DataStore[key] = value
    end
    GMAP.RunTrackers(slot.ID,"dstore",key)
end

function PR.Retrieved( packet, slot )
    print("Received Retrieved Package for "..slot.ID)
    PrintTable(packet.keys)
    for k,v in pairs(packet.keys) do
        DSHandler(slot,k,v)
    end
end 



function PR.SetReply( packet, slot )
    print("Received SetReply Package for "..slot.ID)
    PrintTable(packet)
    DSHandler(slot,packet.key,packet.value)
end



function PR.InvalidPacket( packet, slot )
    print("Received InvalidPacket Packet")
    ErrorNoHalt("Invalid Packet sent to server: "..packet.text.."\n")
end

setmetatable(PR, {
  __index = function( self , key )
    return function(packet, slot)
      ErrorNoHalt("Received Unhandled Package Type "..packet.cmd.." for "..slot.ID.."\n" )
      PrintTable(packet)
    end
  end
})

/*
    this doesn't really need to be in the global variable since it's only called once in the Socket Bases onmessage event 
    but doing it like this makes it easier to debug since gmod wouldn't reload it otherwise
*/
GMAP.PacketProcessor = PR