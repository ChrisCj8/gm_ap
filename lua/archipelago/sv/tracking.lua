/*
  Custom Hooking System that allows hooks to be registered that only run when a specific item is received, location is checked, etc.
*/



GMAP.Trackers = GMAP.Trackers or {}
GMAP.TrackerMethods = GMAP.TrackerMethods or {}

function GMAP.RegisterTracker( slot, type, trackedID, hookID, method, tracker )
  --print("tried to register a tracker for slot"..slot)
  if trackedID != nil then
    GMAP.Trackers[slot] = GMAP.Trackers[slot] or {}
    GMAP.Trackers[slot][type] = GMAP.Trackers[slot][type] or {}
    GMAP.Trackers[slot][type][trackedID] = GMAP.Trackers[slot][type][trackedID] or {}
    local chosenmethod = method
    local methodargs = ""
    --print(chosenmethod)
    if !isfunction(chosenmethod) then
      if chosenmethod == nil then
        ErrorNoHalt("invalid method /n")
      elseif isstring(chosenmethod) then
        local seppos = string.find(chosenmethod,":")
        if seppos != nil then
          methodargs = string.sub(chosenmethod,seppos+1)
          chosenmethod = string.sub(chosenmethod,1,seppos-1)
          print(chosenmethod)
        end
      end
      chosenmethod = GMAP.TrackerMethods[chosenmethod]
    end
    --print(chosenmethod,methodargs)
    if methodargs == "" then methodargs = nil end
    GMAP.Trackers[slot][type][trackedID][hookID] = {
      track = tracker,
      method = chosenmethod,
      args = methodargs
    }
  end
end

function GMAP.UnregisterTracker( slot, type, trackedID, hookID )
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
            --print("running "..k)
            if !(v.track and !IsValid(v.track)) then
                v.method(slot,trackedID,v.args,v.track)
            else
                GMAP.UnregisterTracker(slot,type,trackedID,k)
            end
        end
    end
end
