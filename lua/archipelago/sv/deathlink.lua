hook.Add("AP_Bounced","GMAP_DeathLink", function(slot,packet) 
    -- currently checks if the packet has a deathlink tag on it to figure out if it's supposed to be a deathlink package
    -- this might cause issues if someone were to send a non-deathlink bounce package to all slots using it for some reason
    if !packet.tags or !packet.tags.DeathLink then return end
    local dat = packet.data
    print("Slot "..slot.ID.." received a DeathLink from "..dat.source.." ("..dat.cause..")")
    hook.Run("AP_DeathLink",slot,packet)
    return true
end)