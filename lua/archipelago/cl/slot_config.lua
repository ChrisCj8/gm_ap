hook.Add( "AddToolMenuCategories", "ArchipelagoCategories", function()
    spawnmenu.AddToolCategory( "Utilities", "Archipelago", "Archipelago" )
    spawnmenu.AddToolMenuOption( "Utilities", "Archipelago", "APSlotConfig", "#menu.ap_slot_config.title", "", "", BuildSlotConfigMenu )
end)

local SlotConfigPanel = SlotConfigPanel or {}

local ConfigInfo = ConfigInfo or {}
local ConfigSenderTable = {}
local ConfigRefreshTarget  = ConfigRefreshTarget or {}

net.Receive("APConfiguratorInfoSender", function(len)
    table.Add(ConfigSenderTable,{net.ReadString()})
    --PrintTable(ConfigSenderTable)
    if net.ReadBool() then
        ConfigInfo = util.JSONToTable(table.concat(ConfigSenderTable)) or {}
        PrintTable(ConfigInfo)
        ConfigRefreshTarget:Refresh()
        ConfigSenderTable = {}
    end
end)

local function RequestConfig(refreshTarget)
    net.Start("APConfiguratorCommand")
        net.WriteString("Refresh")
    net.SendToServer()
end

function BuildSlotConfigMenu(panel)

    SlotConfigPanel = panel
    panel:Clear()

    local ActiveSlotsLabel = vgui.Create("DLabel",panel)
    ActiveSlotsLabel:SetText("#menu.ap_slot_config.registeredslots")
    ActiveSlotsLabel:SetDark(true)

    local SlotsPanel = vgui.Create("DListView",panel)
    SlotsPanel:AddColumn("#menu.ap_slot_config.identifier",1)
    SlotsPanel:AddColumn("#menu.ap_slot_config.slot_name",2)
    SlotsPanel:AddColumn("#menu.ap_slot_config.game",3)
    SlotsPanel:AddColumn("#menu.ap_slot_config.connected",4)
    SlotsPanel:SetHeight(100)

    ConfigRefreshTarget = SlotsPanel

    local RefreshSlotsButton = vgui.Create("DButton",panel)
    function RefreshSlotsButton:DoClick()
        RequestConfig(SlotsPanel)
    end
    RefreshSlotsButton:SetText("#menu.ap_slot_config.refreshslots")

    local ConnectButton = vgui.Create("DButton",panel)
    function ConnectButton:DoClick()
        PrintTable(SlotsPanel:GetSelected())
        for k,v in ipairs(SlotsPanel:GetSelected()) do
            net.Start("APConfiguratorCommand")
                net.WriteString("Connect")
                net.WriteString(v:GetValue(1))
            net.SendToServer()
        end
    end
    ConnectButton:SetText("#menu.ap_slot_config.connectslot")

    local DisconnectButton = vgui.Create("DButton",panel)
    function DisconnectButton:DoClick()
        PrintTable(SlotsPanel:GetSelected())
        for k,v in ipairs(SlotsPanel:GetSelected()) do
            net.Start("APConfiguratorCommand")
                net.WriteString("Disconnect")
                net.WriteString(v:GetValue(1))
            net.SendToServer()
        end
    end
    DisconnectButton:SetText("#menu.ap_slot_config.disconnectslot")

    local DeleteButton = vgui.Create("DButton",panel)
    function DeleteButton:DoClick()
        PrintTable(SlotsPanel:GetSelected())
        for k,v in ipairs(SlotsPanel:GetSelected()) do
            net.Start("APConfiguratorCommand")
                net.WriteString("Delete")
                net.WriteString(v:GetValue(1))
            net.SendToServer()
        end
    end
    DeleteButton:SetText("#menu.ap_slot_config.deleteslot")

    --local Divider1 = vgui.Create("DVerticalDivider",panel)

    local labelwidth = 70
    local scalinginputs = {}

    local function GenerateTextInput(labelText)
        local TextInput = vgui.Create("DPanel", panel)
        TextInput:SetPaintBackground(false)
        TextInput:StretchToParent(0,0,0)
        TextInput:SetTall(20)

            TextInput.Label = vgui.Create("DLabel", TextInput)
            TextInput.Label:SetText(labelText)
            TextInput.Label:AlignLeft(0)
            TextInput.Label:SetDark(true)
            TextInput.Label:SetWidth(labelwidth)

            TextInput.Input = vgui.Create("DTextEntry", TextInput)
            TextInput.Input:AlignLeft(labelwidth + 20)

            scalinginputs[#scalinginputs+1] = TextInput.Input

        return TextInput
    end

    local IdentifierInput = GenerateTextInput("#menu.ap_slot_config.slot_identifier")
    local SlotNameInput = GenerateTextInput("Slot Name")


    function SlotNameInput.Input:OnChange()
        IdentifierInput.Input:SetPlaceholderText(self:GetValue())
    end

    local AddressInput = GenerateTextInput("#menu.ap_slot_config.slot_address")
    AddressInput.Input:SetPlaceholderText("ws://localhost:38281")

    local SlotPasswordInput = GenerateTextInput("#menu.ap_slot_config.slot_pass")
    local GameInput = GenerateTextInput("#menu.ap_slot_config.game_name")

    local TextOnlyCheck = vgui.Create("DCheckBoxLabel", panel)
    TextOnlyCheck:SetText("#menu.ap_slot_config.text_only_check")
    TextOnlyCheck:SetTextColor(color_black)
    TextOnlyCheck:SetIndent(30)

    local ReceiveAPchatCheck = vgui.Create("DCheckBoxLabel", panel)
    ReceiveAPchatCheck:SetText("#menu.ap_slot_config.receive_chat_check")
    ReceiveAPchatCheck:SetTextColor(color_black)
    ReceiveAPchatCheck:SetIndent(30)

    local ForwardAPchatCheck = vgui.Create("DCheckBoxLabel", panel)
    ForwardAPchatCheck:SetText("#menu.ap_slot_config.forward_to_gmod_chat")
    ForwardAPchatCheck:SetTextColor(color_black)
    ForwardAPchatCheck:SetIndent(40)

    local ForwardGMODchatCheck = vgui.Create("DCheckBoxLabel", panel)
    ForwardGMODchatCheck:SetText("#menu.ap_slot_config.forward_to_ap_chat")
    ForwardGMODchatCheck:SetDark(true)
    ForwardGMODchatCheck:SetIndent(40)

    local DeathlinkCheck = vgui.Create("DCheckBoxLabel", panel)
    DeathlinkCheck:SetText("#menu.ap_slot_config.deathlink_check")
    DeathlinkCheck:SetTextColor(color_black)
    DeathlinkCheck:SetIndent(30)

    local UpdateButton = vgui.Create("DButton",panel)
    function UpdateButton:DoClick()
        if SlotNameInput.Input:GetText() != "" and SlotNameInput.Input:GetText() != "" then
            local ConfigData = util.TableToJSON({
                ID = IdentifierInput.Input:GetText(),
                slotName = SlotNameInput.Input:GetText(),
                password = SlotPasswordInput.Input:GetText(),
                game = GameInput.Input:GetText(),
                address = AddressInput.Input:GetText(),
                forwardAPchat = ForwardAPchatCheck:GetChecked(),
                forwardGMODchat = ForwardGMODchatCheck:GetChecked(),
                receiveAPchat = ReceiveAPchatCheck:GetChecked(),
                textOnly = TextOnlyCheck:GetChecked(),
                deathlink = DeathlinkCheck:GetChecked(),
            })
            repeat
                net.Start("APConfiguratorInfoSender")
                    net.WriteString(string.sub(ConfigData,0,64000))
                    ConfigData = (string.sub(ConfigData,64001))
                    net.WriteBool(#ConfigData == 0)
                    --print((net.BytesWritten()).." bytes")
                net.SendToServer()
            until #ConfigData == 0
        end
    end
    UpdateButton:SetText("#menu.ap_slot_config.updateslot")

    panel:AddItem(ActiveSlotsLabel)
    panel:AddItem(SlotsPanel)
    panel:AddItem(RefreshSlotsButton)
    panel:AddItem(ConnectButton)
    panel:AddItem(DisconnectButton)
    panel:AddItem(DeleteButton)
    --panel:AddItem(Divider1)
    panel:AddItem(IdentifierInput)
    panel:AddItem(SlotNameInput)
    panel:AddItem(SlotPasswordInput)
    panel:AddItem(AddressInput)
    panel:AddItem(GameInput)
    panel:AddItem(TextOnlyCheck)
    panel:AddItem(ReceiveAPchatCheck)
    panel:AddItem(ForwardAPchatCheck)
    panel:AddItem(ForwardGMODchatCheck)
    panel:AddItem(DeathlinkCheck)
    panel:AddItem(UpdateButton)

    function SlotsPanel:OnRowSelected( rowIndex, rowPanel )
        IdentifierInput.Input:SetText(ConfigInfo[rowPanel:GetValue(1)].ID)
        SlotNameInput.Input:SetText(ConfigInfo[rowPanel:GetValue(1)].slotName)
        SlotPasswordInput.Input:SetText(ConfigInfo[rowPanel:GetValue(1)].password)
        AddressInput.Input:SetText(ConfigInfo[rowPanel:GetValue(1)].address)
        GameInput.Input:SetText(ConfigInfo[rowPanel:GetValue(1)].game)
        ForwardAPchatCheck:SetValue(ConfigInfo[rowPanel:GetValue(1)].forwardAPchat)
        ReceiveAPchatCheck:SetValue(ConfigInfo[rowPanel:GetValue(1)].receiveAPchat)
        ForwardGMODchatCheck:SetValue(ConfigInfo[rowPanel:GetValue(1)].forwardGMODchat)
        TextOnlyCheck:SetValue(ConfigInfo[rowPanel:GetValue(1)].textOnly)
        DeathlinkCheck:SetValue(ConfigInfo[rowPanel:GetValue(1)].deathlink)
    end

    function SlotsPanel:Refresh()
        local oldSelection = self:GetSelected()
        local oldSelectionVal
        if #oldSelection > 0 then
            oldSelectionVal = oldSelection[1]:GetValue(1)
        end
        for k,v in ipairs(SlotsPanel:GetLines()) do
            SlotsPanel:RemoveLine(k)
        end
        for k,v in pairs(ConfigInfo) do
            local newLine = self:AddLine(v.ID,v.slotName,v.game,v.connected)
            if v.ID == oldSelectionVal then
                self:SelectItem(newLine)
            end
        end
    end

    local oldlayout = panel.PerformLayout

    function panel:PerformLayout(w,h)
        oldlayout(self,w,h)
        for k,v in ipairs(scalinginputs) do
            v:StretchToParent(nil,0,0)
        end
    end

    RequestConfig(SlotsPanel)

end

function APRebuildSlotConfig()
    BuildSlotConfigMenu(SlotConfigPanel)
end