require("gwsockets") 

local reconnectCVAR = CreateConVar("sv_gmap_max_reconnects",3,FCVAR_ARCHIVE,"How many times a slot should attempt to reestablish a connection after losing it.",0)

local RoomBase = {
    Members = {},
    DataPackage = {
        games = {}
    },
    DataStore = {},
    GiftBoxes = {},
}

include("archipelago/sv/packetprocessor.lua")

local SocketBase = {
    __index = {
        onMessage = function(self,txt)
            local slot = GMAP.Registered[self.Owner]
            local packet = util.JSONToTable(txt)
            for k,v in ipairs(packet) do
                --print("received package type",v.cmd,k)
                GMAP.PacketProcessor[v.cmd](v,slot)
            end
        end,
        onError =  function(self,err)
            print(self.Owner.." socket Error: ", err)
        end,
        onConnected = function(self)
            local ownerID = self.Owner
            print(ownerID.." socket connected")
            GMAP.SendChatMessage("Slot "..ownerID.." was connected",color_white,true)
            self.ReconnectAttempts = 0
        end,
        onDisconnected = function(self)
            local ownerID = self.Owner
            local owner = GMAP.Registered[ownerID]

            GMAP.Connected[ownerID] = nil
            owner.Connected = false
            GMAP.ChatReaders[ownerID] = nil

            local reconnect = false
            local wasconnected = true

            if self.VoluntaryDC == nil then
                print(ownerID.." socket couldn't connect")
                GMAP.SendChatMessage("Slot "..ownerID.." couldn't connect",color_white,true)
                wasconnected = false
            elseif self.VoluntaryDC == false then
                owner.Reconnecting = true
                local maxreconnects = reconnectCVAR:GetInt()
                if self.ReconnectAttempts < maxreconnects then
                    self.ReconnectAttempts = self.ReconnectAttempts + 1
                    reconnect = true
                    print(ownerID.." socket lost connection")
                    GMAP.SendChatMessage("Slot "..ownerID.." lost connection, attempting reconnect "..self.ReconnectAttempts,color_white,true)
                else
                    if maxreconnects == 0 then
                        GMAP.SendChatMessage("Slot "..ownerID.." lost connection" ,color_white,true)
                    else
                        GMAP.SendChatMessage("Slot "..ownerID.." lost connection, reconnect failed" ,color_white,true)
                        owner.Reconnecting = false
                    end
                end
            else
                print(ownerID.." socket disconnected")
                GMAP.SendChatMessage("Slot "..ownerID.." was disconnected",color_white,true)
            end

            if wasconnected and self.ReconnectAttempts <= 1 then
                hook.Run("AP_Disconnect",ownerID)
            end

            if reconnect then
                owner:Connect()
            elseif wasconnected then
                GMAP.Rooms[owner.address].Members[ownerID] = nil
                if table.IsEmpty(GMAP.Rooms[owner.address].Members) then
                    GMAP.Rooms[owner.address] = nil
                end
                owner.DataPackage, owner.Room = nil
                self.VoluntaryDC = nil
            end
        end,
    }
}

table.Merge(SocketBase, FindMetaTable("WebSocket")) -- i feel like there's probably a better way do this but i've spent too much time on this
--setmetatable(SocketBase, FindMetaTable("WebSocket"))

local APslotBase = {
    Locations = {},
    Items = {},
    tags = {}
}

function APslotBase:Connect()
    if self.Socket != nil and self.Socket:isConnected() then
        print("already connected")
    else
        local address = self.address
        if self.Socket == nil or self.Socket.Address != address then
            self.Socket = GWSockets.createWebSocket(self.address,false)
            local sock = self.Socket

            setmetatable(sock, SocketBase)

            sock:setMessageCompression(true)
            sock.Owner = self.ID
            sock.Address = address
            sock.ReconnectAttempts = 0
        end
        GMAP.Rooms[address] = GMAP.Rooms[address] or table.Copy(RoomBase)
        self.Room = GMAP.Rooms[address]
        self.Room.Members[self.ID] = true
        local sock = self.Socket
        self.Socket:open()
        GMAP.Connected[self.ID] = self
        self.Connected = true
        if self.forwardGMODchat then
            GMAP.ChatReaders[self.ID] = self
        end
    end
end

function APslotBase:Disconnect()
    if self.Socket:isConnected() then
        self.Socket.VoluntaryDC = true
        self.Socket:close()
    else
        print("already disconnected")
    end
end

function APslotBase:sendChatMessage(txt)
    self.Socket:write('[{"cmd":"Say","text":"'..tostring(txt)..'"}]')
    self.lastSentChat = txt
end

function APslotBase:sendLocation(lctn,nodebug)
    if self.Locations == nil then
        if !nodebug then print("Location list not received yet") end
        return
    end
    if self.cantSendLocations then
        if !nodebug then print("can't send location as text only slot") end
        return
    end
    if isstring(lctn) then
        lctn = self.Room.DataPackage.games[self.game].location_name_to_id[lctn]
        print("lctnprint",lctn)
    end
    if isnumber(lctn) then
        if self.Locations[lctn] == false then
            self.Socket:write('[{"cmd":"LocationChecks","locations":['..tostring(lctn)..']}]')
            self.Locations[lctn] = true
            GMAP.RunTrackers(self.ID,"lctn",lctn)
        elseif self.Locations[lctn] == true then
            print("Location already sent")
        else
            print("Location does not exist")
        end
    elseif nodebug != true then
        print("Invalid Type passed to sendLocation"..tostring(lctn))
    end
end

function APslotBase:sendGoal()
    self.Socket:write('[{"cmd":"StatusUpdate","status":30}]')
end

function APslotBase:DataStoreGet(keys,callback)
    if !istable(keys) then
        keys = {keys}
    end

    local cbstring = ""

    if isfunction(callback) then
        self.GetCBs[self.GetRequests] = callback
        cbstring = ',"reqid":'..self.GetRequests
        self.GetRequests = self.GetRequests + 1
    end

    self.Socket:write('[{"cmd":"Get","keys":'..util.TableToJSON(keys)..''..cbstring..'}]')
end

function APslotBase:DataStoreSet(key,default,want_reply,ops)
    self.Socket:write(util.TableToJSON({{
        cmd = "Set",
        key = key,
        default = default,
        want_reply = want_reply,
        operations = ops
    }}))
end

function APslotBase:DataStoreSetNotify(keys)
    if !istable(keys) then
        keys = {keys}
    end
    self.Socket:write('[{"cmd":"SetNotify","keys":'..util.TableToJSON(keys)..'}]')
end

function APslotBase:SendGift(targetTeam,targetID,giftTbl)
    local teambox = self.Room.GiftBoxes[targetTeam]
    if !teambox then
        print("target team does not have a motherbox")
        return
    end
    local targetbox = teambox[targetID]
    if !targetbox or !targetbox.is_open then
        print("cannot send gift to target that doesn't accept gifts")
        return
    end
    if targetbox.minimum_gift_data_version > 3 or targetbox.maximum_gift_data_version < 3 then
        print("target doesn't support gift data version 3")
        return
    end

    local traitcheck = false

    if false then --currently always false until i add refund handling, should be targetbox.accepts_any_gift
        traitcheck = true
    else
        local acceptedtraits = targetbox.desired_traits
        for k,v in ipairs(giftTbl.traits) do
            if acceptedtraits[v.trait] then
                traitcheck = true
                break
            end
        end
    end

    if !traitcheck then
        print("target giftbox doesn't accept any of the gifts traits")
        return
    end

    local giftID = "gmod-"..os.time().."-"..CurTime().."-"..math.random(-9999,9999)
    giftTbl.id = giftID
    giftTbl.sender_slot = self.Nr
    giftTbl.sender_team = self.team
    giftTbl.receiver_slot = targetID
    giftTbl.receiver_team = targetTeam
    if !giftTbl.amount or giftTbl.amount <= 0 then -- the gifting specification just says that it shouldn't be a negative value but let's include zero just in case
        giftTbl.amount = 1
    end
    giftTbl.amount = math.floor(giftTbl.amount)
    self.Socket:write(util.TableToJSON({{
        cmd = "Set",
        key = "GiftBox;"..targetTeam..";"..targetID,
        default = {},
        want_reply = true,
        operations = {{
            operation = 'update',
            value = {[giftID] = giftTbl}
        }}
    }}))
end

function APslotBase:writeDataPackage()
    file.Write("archipelago/"..self.ID.."_datapackage.json",util.TableToJSON(self.Room.DataPackage,true))
end

function APslotBase:sendDeathLink(cause,nameoverride)
    self.Socket:write('[{"cmd":"Bounce","tags":["DeathLink"],"data":{"time":'..os.time()..',"source":"'..(nameoverride or self.ID)..'","cause":"'..cause..'"}}]')
end

function GMAP.NewSlot( inputTable )
    if GMAP.Connected[ID] != nil or GMAP.Connected[slotName] != nil then
        print("Slot with same ID or Name already connected")
    else
        local newSlot = {}

        setmetatable(newSlot, {__index = APslotBase})

        if inputTable.address == "" or inputTable.address == nil then
            newSlot.address = "ws://localhost:38281"
        else
            if #inputTable.address < 6 then
                local portnum = tonumber(inputTable.address)
                if portnum != nil and 1023 < portnum < 65536 then
                    portnum = math.Round(portnum,0) --rounding just in case
                    newSlot.address = "wss://archipelago.gg:"..inputTable.address
                end
            else
                if not((string.Left(inputTable.address,5) == "ws://") or (string.Left(inputTable.address,6) == "wss://")) then
                    inputTable.address = "wss://"..inputTable.address
                end
                local portpos = string.find(inputTable.address,":",-6)
                if portpos == nil then
                    inputTable.address = inputTable.address..":38281"
                end
                newSlot.address = inputTable.address
            end
        end

        newSlot.ID = inputTable.ID or inputTable.slotName
        newSlot.slotName = string.Left(inputTable.slotName,16)
        newSlot.password = inputTable.password or ""
        newSlot.game = inputTable.game or ""

        newSlot.textOnly = inputTable.textOnly or false
        newSlot.receiveAPchat = inputTable.receiveAPchat or false
        newSlot.forwardAPchat = inputTable.forwardAPchat or false
        newSlot.forwardGMODchat = inputTable.forwardGMODchat or false
        newSlot.deathlink = inputTable.deathlink or false

        GMAP.Registered[newSlot.ID] = newSlot

        return newSlot
    end
end