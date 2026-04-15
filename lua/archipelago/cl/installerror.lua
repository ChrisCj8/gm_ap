local uimake = vgui.Create

local errortype = net.ReadString() or "notfound"
local window = vgui.Create("DFrame")
window:SetSize(400,200)
window:SetTitle("#gmap.installerrorui.title")
window:SetPos(ScrW()/2-200,ScrH()/2-100)
window:SetBackgroundBlur(true)
window:MakePopup()

local background = vgui.Create("DPanel",window)
background:SetPos(5,25)

local errortext = vgui.Create("DLabel",background)
errortext:SetPos(5,5)
errortext:SetDark(true)
errortext:SetWrap(true)
errortext:SetText("#gmap.installerrorui.error."..errortype)

function background:PerformLayout(w,h)
    errortext:SetSize(w-10,h-10)
end

local oldlayout = window.PerformLayout
function window:PerformLayout(w,h)
    oldlayout(self,w,h)
    background:SetSize(w-10,h-30)
end
