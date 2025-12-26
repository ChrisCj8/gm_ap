/*
    Custom Hooking System that allows hooks to be registered that only run when a specific item is received, location is checked, etc.
*/

GMAP.Trackers = GMAP.Trackers or {}
GMAP.TrackerMethods = GMAP.TrackerMethods or {}

function GMAP.AddTracker(slot,type,trackedID,hookID,method)
    --print("tried to register a tracker for slot"..slot)
    if trackedID != nil then
        local tracker = GMAP.Trackers
        trackers[slot] = trackers[slot] or {}
        trackers[slot][type] = trackers[slot][type] or {}
        trackers[slot][type][trackedID] = trackers[slot][type][trackedID] or {}
        trackers[slot][type][trackedID][hookID] = {
            method = method
        }
    end
end

function GMAP.RemoveTracker(slot,type,trackedID,hookID)
    local slottrackers = GMAP.Trackers[slot]
    if slottrackers != nil then
        if slottrackers[type] != nil then
            if slottrackers[type][trackedID] != nil then
                slottrackers[type][trackedID][hookID] = nil
                if !next(slottrackers[type][trackedID]) then
                    slottrackers[type][trackedID] = nil
                end
            end
            if !next(slottrackers[type]) then
                slottrackers[type] = nil
            end
        end
        if !next(slottrackers) then
            GMAP.Trackers[slot] = nil
        end
    end
end

function GMAP.RunTrackers(slot, type, trackedID)
    --print("runtrackers",slot,type,trackedID)
    local slottrackers = GMAP.Trackers[slot]
    if slottrackers != nil and slottrackers[type] != nil and slottrackers[type][trackedID] != nil then
        for k,v in pairs(slottrackers[type][trackedID]) do
            if isstring(k) or IsValid(k) then
                v.method(slot,trackedID)
            else
                --print(k.." is not valid, removing")
                GMAP.RemoveTracker(slot,type,trackedID,k)
            end
        end
    end
end
