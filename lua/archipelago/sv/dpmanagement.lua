/*
    This code handles the automatic deletion of DataPackages that haven't been used in a while
    The code that actually stores them is in packetprocessor.lua
*/

GMAP.DataPackageRegister = GMAP.DataPackageRegister or {}

if file.Exists("archipelago/datapackages/register.json","DATA") then
    GMAP.DataPackageRegister = util.JSONToTable(file.Read("archipelago/datapackages/register.json","DATA"))
elseif !file.IsDir("/archipelago/datapackages/","DATA") then
    file.CreateDir("archipelago/datapackages")
end

local DPCleanupCVAR = CreateConVar("sv_gmap_datapackage_cleanup",72,FCVAR_ARCHIVE,
    "Time in hours that has to pass since the last usage for saved DataPackages to be deleted. Doesn't have to be a whole number.",-1)

function GMAP.DPCleanup()
    if DPCleanupCVAR:GetInt() != -1 then
      for k,v in pairs(GMAP.DataPackageRegister) do
        for ik, iv in pairs(v) do
          local lastuse = os.time()-iv
          --print(k.."/"..ik..".json was last used "..tostring(math.Round(lastuse/3600,3)).." hours ago")
          if lastuse > DPCleanupCVAR:GetFloat()*3600 then
            file.Delete("archipelago/datapackages/"..k.."/"..ik..".json")
            v[ik] = nil
          end
          if #file.Find("archipelago/datapackages/"..k.."/*","DATA") == 0 then
            file.Delete("archipelago/datapackages/"..k.."/")
          end
        end
        if table.IsEmpty(v) then
          GMAP.DataPackageRegister[k] = nil
        end
      end
    end
    file.Write("archipelago/datapackages/register.json",util.TableToJSON(GMAP.DataPackageRegister))
end

hook.Add("ShutDown","apCleanUpDatapackages",GMAP.DPCleanup)