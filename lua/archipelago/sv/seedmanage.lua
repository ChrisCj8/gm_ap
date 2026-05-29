
GMAP.SeedRegister = GMAP.SeedRegister or {}

if file.Exists("archipelago/seedcache/register.json","DATA") then
    GMAP.SeedRegister = util.JSONToTable(file.Read("archipelago/seedcache/register.json","DATA"),false,true)
elseif !file.IsDir("/archipelago/seedcache","DATA") then
    file.CreateDir("archipelago/seedcache")
end

local CleanUpCVAR = CreateConVar("sv_gmap_seeddata_cleanup",72,FCVAR_ARCHIVE,
    "Time in hours that has to pass since the last usage for cached Seed Data to be deleted. Doesn't have to be a whole number.",-1)

function GMAP.SeedManage()
    local finalreg = GMAP.SeedRegister
    local curtime = os.time()
    local cvar = CleanUpCVAR:GetFloat()

    if cvar > 0 then
        for k,v in pairs(GMAP.Rooms) do
            local seed = v.seed_name
            finalreg[seed] = curtime
            file.Write("archipelago/seedcache/"..seed..".json",util.TableToJSON({
                SlotData = v.SlotData,
                Locs = v.LocationInfo,
                SlotNameToID = v.SlotNameToID
            }))
        end
    end
    if cvar != -1 then
        local deltime = curtime - cvar*3600
        for k,v in pairs(finalreg) do
            if v < deltime then
                local path = "archipelago/seedcache/"..k..".json"
                if file.Exists(path,"DATA") then
                    file.Delete(path,"DATA")
                end
                finalreg[k] = nil
            end
        end
    end
    file.Write("archipelago/seedcache/register.json",util.TableToJSON(finalreg))
end

hook.Add("ShutDown","GMAP_ManageSeedData",GMAP.SeedManage)