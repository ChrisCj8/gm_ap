if !util.IsBinaryModuleInstalled("gwsockets") then
    error("Couldn't find GWSockets")
end

--require("gwsockets") 

AddCSLuaFile("archipelago/cl/slot_config.lua")

util.AddNetworkString("APmessage")
util.AddNetworkString("APConfiguratorInfoSender")
util.AddNetworkString("APConfiguratorCommand")
util.AddNetworkString("APnotify")

GMAP.Registered = GMAP.Registered or {}
GMAP.Connected = GMAP.Connected or {}
GMAP.Rooms = GMAP.Rooms or {}

if !file.IsDir("/archipelago/","DATA") then
    file.CreateDir("archipelago")
end

include("archipelago/sv/dpmanagement.lua")

local cols = GMAP.Colors

GMAP.ItemTypeColors = {
    [0] = cols.apcyan, -- normal
    [1] = cols.applum, -- progression
    [2] = cols.apslateblue, -- useful
    [3] = cols.applum, -- proguseful
    [4] = cols.apsalmon, -- trap
    [5] = cols.applum, -- progtrap
    [6] = cols.apslateblue, -- usefultrap
    [7] = cols.applum, -- progusefultrap
}

setmetatable(GMAP.ItemTypeColors, {
    __index = function(self, key)
        local out = GMAP.Colors.apcyan
        if isnumber(key) then
            out = GMAP.ItemTypeColors[bit.band(key,7)]
        end
        return out
    end
})

include("archipelago/sv/slotbase.lua")

GMAP.ChatReaders = GMAP.ChatReaders or {}

hook.Add("PlayerSay","APChatReader", function( ply, text )
    for k,v in pairs(GMAP.ChatReaders) do
        local slot = GMAP.Registered[v.ID]
        if slot.Socket:isConnected() then
            slot:SendChatMessage("["..ply:Name().."] "..text)
        end
    end
end)

function GMAP.SendChatMessage(txt,clr,last)
    txt = txt or "empty"
    --clr = clr or color_white
    net.Start("APmessage")
        net.WriteColor(clr,false)
        net.WriteString(txt)
        net.WriteBool(last)
        --print((net.BytesWritten()).." bytes")
    net.Broadcast()
end

function GMAP.SendNotify(txt,type,time,ply)
    net.Start("APnotify")
        net.WriteString(txt)
        net.WriteUInt(type,3)
        net.WriteDouble(time)
    if ply != nil then
        net.Send(ply)
    else
        net.Broadcast()
    end
end

local function GenerateConfigData()
    local ConfigData = {}
    for k,v in pairs(GMAP.Registered) do
        if !v.dontStore then 
            ConfigData[k] = {}
            local CopyFields = {"ID","slotName","forwardAPchat","forwardGMODchat","receiveAPchat","game","password","textOnly","address","deathlink"}
            for ik,iv in ipairs(CopyFields) do
                ConfigData[k][iv] = v[iv]
            end
            if v.Socket != nil and v.Socket:isConnected() then
                ConfigData[k].connected = true
            end
        end
    end
    return ConfigData
end

local reconnectonloadCVAR = CreateConVar("sv_gmap_reconnect_on_persist_load",1,FCVAR_ARCHIVE,"Automatically reconnect all slots that were connected the last time the persistence data was saved.",0,1)

local function ApplyConfigData(data)
    for k,v in pairs(data) do
        GMAP.NewSlot(v)
        if v.connected and reconnectonloadCVAR:GetBool() then -- may be a good idea to move this somewhere else later
            GMAP.Registered[k]:Connect()
        end
    end
end

local function ConfigSender(ply)
    local ConfigString = util.TableToJSON(GenerateConfigData())
    repeat
        net.Start("APConfiguratorInfoSender")
            net.WriteString(string.sub(ConfigString,0,64000))
            ConfigString = (string.sub(ConfigString,64001))
            net.WriteBool(#ConfigString == 0)
            --print((net.BytesWritten()).." bytes")
        net.Send( ply )
    until #ConfigString == 0
end

local ConfigSenderTable = ConfigSenderTable or {}
local ConfigInfo = ConfigInfo or {}

net.Receive("APConfiguratorInfoSender", function(len,ply)
    table.Add(ConfigSenderTable,{net.ReadString()})
    if net.ReadBool() then
        ConfigInfo = util.JSONToTable(table.concat(ConfigSenderTable)) or {}
        if ConfigInfo.ID == "" then
            ConfigInfo.ID = ConfigInfo.slotName
        end

        local id = ConfigInfo.ID
        local slottbl = GMAP.Registered[id]

        if slottbl != nil then
            if GMAP.Connected[id] != nil then
                if ConfigInfo.receiveAPchat != slottbl.receiveAPchat or ConfigInfo.deathlink != slottbl.deathlink then
                    local tags = {}
                    if slottbl.cantSendLocations == true then
                        tags[#tags+1] = "TextOnly"
                    end
                    if ConfigInfo.receiveAPchat == false then
                        tags[#tags+1] = "NoText"
                    end
                    if ConfigInfo.deathlink == true then
                        tags[#tags+1] = "DeathLink"
                    end
                    GMAP.Connected[id].Socket:write('[{"cmd":"ConnectUpdate","tags":'..util.TableToJSON(tags)..'}]')
                end
                if ConfigInfo.forwardGMODchat == true and GMAP.ChatReaders[id] == nil then
                    GMAP.ChatReaders[id] = slottbl
                elseif ConfigInfo.forwardGMODchat == false and GMAP.ChatReaders[id] != nil then
                    GMAP.ChatReaders[id] = nil
                end
                if ConfigInfo.address != slottbl.address then
                    ConfigInfo.address = nil
                    GMAP.SendNotify("Can't change address while slot is connected, address change discarded ",1,3,ply)
                end
            end
            table.Merge(slottbl,ConfigInfo)
            print("updated slot "..id)
        else
            GMAP.NewSlot(ConfigInfo)
            print("created new slot "..id)
        end
        ConfigSenderTable = {}
        ConfigSender(ply)
    end
end)

net.Receive("APConfiguratorCommand", function(len, ply)
    local cmd = net.ReadString()
    if cmd == "Refresh" then
        ConfigSender(ply)
    elseif cmd == "Connect" then
        local slot = net.ReadString()
        GMAP.Registered[slot]:Connect()
    elseif cmd == "Disconnect" then
        local slot = net.ReadString()
        GMAP.Registered[slot]:Disconnect()
    elseif cmd == "Delete" then
        local slot = net.ReadString()
        if GMAP.Connected[slot] == nil then
            GMAP.Registered[slot] = nil
        else
            GMAP.SendNotify("Can't delete currently connected slot "..slot,1,3,ply)
            print(ply:Name().." tried to delete currently connected slot "..slot)
        end
        ConfigSender(ply)
    end
end)

function GMAP.DisconnectAll()
    for k,v in pairs(GMAP.Connected) do
        v:Disconnect()
    end
end

hook.Add("Initialize","apConfigLoad", function()
    if file.Exists("archipelago/slotconfig.json","DATA") then
        ApplyConfigData(util.JSONToTable(file.Read("archipelago/slotconfig.json")))
    end
end)

hook.Add("ShutDown","apConfigSave", function()
    file.Write("archipelago/slotconfig.json",util.TableToJSON(GenerateConfigData()))
end)

-- old attempt to detect when the game is paused, no longer necessary since it now automatically reconnects whenever the connection is interrupted

--[[
GMAP.LastThink = GMAP.LastThink or -1
GMAP.ThinkGap = 0
GMAP.LastPause = -1

hook.Add("Think","GMAP Pause Detector", function()
    local curthink = os.time()
    if GMAP.LastThink > 0 then
        GMAP.ThinkGap = curthink - GMAP.LastThink
        if GMAP.ThinkGap > 2 then
            print("game was paused for "..GMAP.ThinkGap.." seconds")
            GMAP.LastPause = CurTime()
        end
    end
    GMAP.LastThink = curthink
end)

util.AddNetworkString("GMAP_PauseInfo")

GMAP.PauseStart = 0
GMAP.PauseLength = 0

net.Receive("GMAP_PauseInfo", function(len,ply)
    if net.ReadBool() then
        print("game was paused")
        GMAP.PauseStart = os.time()
    else
        GMAP.LastPause = CurTime()
        GMAP.PauseLength = os.time() - GMAP.PauseStart
        print("game was unpaused after "..GMAP.PauseLength.." seconds")
    end
end)
]]

include("archipelago/sv/tracking.lua")
include("archipelago/sv/deathlink.lua")