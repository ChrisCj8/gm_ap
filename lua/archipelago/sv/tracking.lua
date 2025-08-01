/*
    Custom Hooking System that allows hooks to be registered that only run when a specific item is received, location is checked, etc.
*/

GMAP.Trackers = GMAP.Trackers or {}
GMAP.TrackerMethods = GMAP.TrackerMethods or {}

function GMAP.AddTracker(slot,type,trackedID,hookID,method)
    --print("tried to register a tracker for slot"..slot)
    if trackedID != nil then
        GMAP.Trackers[slot] = GMAP.Trackers[slot] or {}
        GMAP.Trackers[slot][type] = GMAP.Trackers[slot][type] or {}
        GMAP.Trackers[slot][type][trackedID] = GMAP.Trackers[slot][type][trackedID] or {}
        GMAP.Trackers[slot][type][trackedID][hookID] = {
            method = method
        }
    end
end

function GMAP.RemoveTracker(slot,type,trackedID,hookID)
    if GMAP.Trackers[slot] != nil then
        if GMAP.Trackers[slot][type] != nil then
            if GMAP.Trackers[slot][type][trackedID] != nil then
                GMAP.Trackers[slot][type][trackedID][hookID] = nil
                if table.IsEmpty(GMAP.Trackers[slot][type][trackedID]) then
                    GMAP.Trackers[slot][type][trackedID] = nil
                end
            end
            if table.IsEmpty(GMAP.Trackers[slot][type]) then
                GMAP.Trackers[slot][type] = nil
            end
        end
        if table.IsEmpty(GMAP.Trackers[slot]) then
            GMAP.Trackers[slot] = nil
        end
    end
end

function GMAP.RunTrackers(slot, type, trackedID)
    --print("runtrackers",slot,type,trackedID)
    if GMAP.Trackers[slot] != nil and GMAP.Trackers[slot][type] != nil and GMAP.Trackers[slot][type][trackedID] != nil then
        for k,v in pairs(GMAP.Trackers[slot][type][trackedID]) do
            if isstring(k) or IsValid(k) then
                v.method(slot,trackedID)
            else
                --print(k.." is not valid, removing")
                GMAP.RemoveTracker(slot,type,trackedID,k)
            end
        end
    end
end
