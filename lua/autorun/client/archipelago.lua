list.Set( "ContentCategoryIcons", "Archipelago", "archipelago/ap16.png" )

local APMessageTable = {}

net.Receive("APmessage", function(len)
    table.Add(APMessageTable,{net.ReadColor(false),net.ReadString()})
    if net.ReadBool() then
        chat.AddText(unpack(APMessageTable))
        APMessageTable = {}
    end
end)

net.Receive("APnotify", function(len)
    local txt = net.ReadString()
    local type = net.ReadUInt(3)
    notification.AddLegacy(txt,type,net.ReadDouble())
    local sounds = {
        [1] = "buttons/button10.wav",
        [2] = "buttons/button15.wav",
        [3] = "buttons/button15.wav",
        [4] = "buttons/button15.wav"
    }
    surface.PlaySound(sounds[type])
end)

net.Receive("GMAPInstallErrorInfo",function()
    include("archipelago/cl/installerror.lua")
end)

include("archipelago/cl/slot_config.lua")

-- old attempt to detect when the game is paused, no longer necessary since it now automatically reconnects whenever the connection is interrupted

--[[
if game.SinglePlayer() then
    hook.Add("OnPauseMenuShow","GMAP Pause Detector",function()
        net.Start("GMAP_PauseInfo")
            net.WriteBool(true)
        net.SendToServer()
        timer.Simple(0, function()
            net.Start("GMAP_PauseInfo")
                net.WriteBool(false)
            net.SendToServer()
        end)
    end)
end
]]
