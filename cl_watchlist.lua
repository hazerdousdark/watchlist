CATEGORIES = {
    { id = "rdm",         label = "RDM" },
    { id = "failrp",      label = "FailRP" },
    { id = "nlr",         label = "NLR" },
    { id = "störung",     label = "Störung" },
    { id = "beleidigung", label = "Beleidigung" },
    { id = "jobregel",    label = "Jobregel" },
    { id = "rpflucht",    label = "RP-Flucht" },
    { id = "bugabuse",    label = "Bug Abuse" },
    { id = "backseat",    label = "Backseat" },
    { id = "other",       label = "Sonstiges" },
}

CATEGORY_LABEL = {}
for _, c in ipairs(CATEGORIES) do
    CATEGORY_LABEL[c.id] = c.label
end

ALLOWED_RANKS = {
    testmoderator   = true,git config --global user.name "Your Name"
git config --global user.email "you@example.com"
    juniormoderator = true,
    moderator       = true,
    seniormoderator = true,
    admin           = true,
    superadmin      = true,
    headadmin       = true,
    serverleiter    = true,
    owner           = true,
}

MSG_REQUEST = 0
MSG_ADD     = 1
MSG_CONFIRM = 2
MSG_DATA    = 3

local COLOR_BG      = Color(40, 40, 40, 220)
local COLOR_SUBTEXT = Color(200, 200, 200)
local ALERT_W       = 320

local function HasRank()
    local ply = LocalPlayer()
    if not IsValid(ply) then return false end
    return true 
end

local function TimeAgo(ts)
    local diff = os.time() - ts
    if diff < 60        then return diff                    .. "s ago"
    elseif diff < 3600  then return math.floor(diff / 60)  .. "m alt"
    elseif diff < 86400 then return math.floor(diff / 3600) .. "h alt"
    else                     return math.floor(diff / 86400) .. "d alt"
    end
end

local function CategoryLabel(id)
    return CATEGORY_LABEL[id] or id
end

local function MakeLabel(parent, x, y, w, text, font)
    local lbl = vgui.Create("DLabel", parent)
    lbl:SetPos(x, y)
    if w then lbl:SetSize(w, 20) else lbl:SizeToContents() end
    lbl:SetText(text)
    if font then lbl:SetFont(font) end
    return lbl
end

local function MakeCombo(parent, x, y, w, placeholder)
    local combo = vgui.Create("DComboBox", parent)
    combo:SetPos(x, y)
    combo:SetSize(w, 22)
    combo:SetValue(placeholder)
    return combo
end

local function FillPlayerCombo(combo)
    for _, ply in player.Iterator() do
        if ply ~= LocalPlayer() then
            combo:AddChoice(ply:Nick() .. "  [" .. ply:SteamID() .. "]", ply:SteamID64())
        end
    end
end

local WL = {
    open         = false,
    frame        = nil,
    entries      = {},
    lookupSID    = "",
    alertEntries = {},
    alertName    = "",
}

local function BuildAddSection(left, leftW)
    MakeLabel(left, 4, 4,  leftW - 8, "Spieler hinzufügen")
    MakeLabel(left, 4, 28, nil,       "Spieler:")

    local playerCombo = MakeCombo(left, 4, 46, leftW - 8, "Spieler wählen...")
    playerCombo._selectedSID  = nil
    playerCombo._selectedName = nil
    FillPlayerCombo(playerCombo)

    playerCombo.OnSelect = function(s, _, value, data)
        s._selectedSID  = data
        s._selectedName = value:match("^(.-)%s+%[") or value
    end

    MakeLabel(left, 4, 74, nil, "Kategorie:")

    local catCombo = MakeCombo(left, 4, 92, leftW - 8, "Kategorie wählen...")
    for _, c in ipairs(CATEGORIES) do
        catCombo:AddChoice(c.label, c.id)
    end

    MakeLabel(left, 4, 120, nil, "Begründung:")

    local reasonEntry = vgui.Create("DTextEntry", left)
    reasonEntry:SetPos(4, 138)
    reasonEntry:SetSize(leftW - 8, 72)
    reasonEntry:SetMultiline(true)
    reasonEntry:SetPlaceholderText("Grund eingeben...")

    local statusLbl = vgui.Create("DLabel", left)
    statusLbl:SetPos(4, 216)
    statusLbl:SetSize(leftW - 8, 18)
    statusLbl:SetText("")

    local addBtn = vgui.Create("DButton", left)
    addBtn:SetPos(4, 238)
    addBtn:SetSize(leftW - 8, 28)
    addBtn:SetText("Auf Watchlist setzen")

    addBtn.DoClick = function()
        local sid64    = playerCombo._selectedSID
        local name     = playerCombo._selectedName or ""
        local _, catID = catCombo:GetSelected()
        local reason   = reasonEntry:GetValue()

        if not sid64    then statusLbl:SetText("Bitte Spieler wählen!")      return end
        if not catID    then statusLbl:SetText("Bitte Kategorie wählen!")    return end
        if reason == "" then reason = CategoryLabel(catID) end2 / 2

        net.Start("WatchlistUpdate")
            net.WriteUInt(MSG_ADD, 4)
            net.WriteString(sid64)
            net.WriteString(name)
            net.WriteString(reason)
            net.WriteString(catID)
        net.SendToServer()

        statusLbl:SetText("Sende...")
        addBtn:SetEnabled(false)

        timer.Simple(8, function()
            if IsValid(addBtn)    then addBtn:SetEnabled(true) end
            if IsValid(statusLbl) then statusLbl:SetText("Timeout - keine Server-Antwort.") end
        end)
    end

    WL._statusLbl = statusLbl
    WL._addBtn    = addBtn

    return playerCombo
end

local function BuildLookupSection(left, leftW)
    local div = vgui.Create("DPanel", left)
    div:SetPos(4, 274)
    div:SetSize(leftW - 8, 1)
    div.Paint = function(_, w, h)
        surface.SetDrawColor(100, 100, 100, 200)
        surface.DrawRect(0, 0, w, h)
    end

    MakeLabel(left, 4, 282, leftW - 8, "Spieler nachschlagen", "DermaDefaultBold")
    MakeLabel(left, 4, 306, nil,       "Spieler:")

    local lookupCombo = MakeCombo(left, 4, 324, leftW - 8, "Spieler wählen...")
    FillPlayerCombo(lookupCombo)

    local lookupBtn = vgui.Create("DButton", left)
    lookupBtn:SetPos(4, 352)
    lookupBtn:SetSize(leftW - 8, 28)
    lookupBtn:SetText("Einträge laden")

    lookupBtn.DoClick = function()
        local _, sid64 = lookupCombo:GetSelected()
        if not sid64 then return end
        WL.lookupSID = sid64
        net.Start("WatchlistUpdate")
            net.WriteUInt(MSG_REQUEST, 4)
            net.WriteString(sid64)
        net.SendToServer()
    end
end

local function BuildEntryPanel(frame, rightX, rightW, H)
    local right = vgui.Create("DPanel", frame)
    right:SetPos(rightX, 30)
    right:SetSize(rightW, H - 38)

    local header = MakeLabel(right, 4, 4, rightW - 8, "Einträge", "DermaDefaultBold")

    local scroll = vgui.Create("DScrollPanel", right)
    scroll:SetPos(4, 26)
    scroll:SetSize(rightW - 8, H - 38 - 30)

    local entryList = vgui.Create("DListLayout", scroll)
    entryList:SetWide(rightW - 8)

    return function()
        entryList:Clear()

        if #WL.entries == 0 then
            local lbl = vgui.Create("DLabel", entryList)
            lbl:SetSize(rightW - 8, 40)
            lbl:SetText("Keine Einträge gefunden.")
            lbl:SetContentAlignment(5)
            return
        end

        header:SetText("Einträge (" .. #WL.entries .. ")")

        for _, e in ipairs(WL.entries) do
            local row = vgui.Create("DPanel", entryList)
            row:SetSize(rightW - 8, 60)

            local titleLbl = vgui.Create("DLabel", row)
            titleLbl:SetPos(4, 4)
            titleLbl:SetSize(rightW - 16, 18)
            titleLbl:SetText("#" .. e.id .. "  -  " .. CategoryLabel(e.category))

            local reasonLbl = vgui.Create("DLabel", row)
            reasonLbl:SetPos(4, 22)
            reasonLbl:SetSize(rightW - 16, 18)
            reasonLbl:SetText(e.reason)

            local metaLbl = vgui.Create("DLabel", row)
            metaLbl:SetPos(4, 40)
            metaLbl:SetSize(rightW - 16, 16)
            metaLbl:SetFont("DermaDefault")
            metaLbl:SetText("von " .. e.admin_name .. "  -  " .. TimeAgo(e.timestamp))
        end
    end
end

function WL:Close()
    if IsValid(self.frame) then self.frame:Remove() end
    self.open  = false
    self.frame = nil
end

function WL:Open(preselectedPlayer)
    if self.open then self:Close() end

    if not HasRank() then
        chat.AddText("[Watchlist] Keine Berechtigung.")
        return
    end

    self.open = true

    local W, H   = 780, 540
    local leftW  = 300
    local rightX = leftW + 16
    local rightW = W - rightX - 8

    local frame = vgui.Create("DFrame")
    self.frame  = frame
    frame:SetSize(W, H)
    frame:Center()
    frame:SetTitle("Watchlist")
    frame:SetDraggable(true)
    frame:MakePopup()
    frame:SetDeleteOnClose(true)

    local left = vgui.Create("DPanel", frame)
    left:SetPos(8, 30)
    left:SetSize(leftW, H - 38)

    local playerCombo    = BuildAddSection(left, leftW)
    BuildLookupSection(left, leftW)
    self._rebuildEntries = BuildEntryPanel(frame, rightX, rightW, H)
    self._rebuildEntries()

    if IsValid(preselectedPlayer) then
        playerCombo:SetValue(preselectedPlayer:Nick() .. "  [" .. preselectedPlayer:SteamID() .. "]")
        playerCombo._selectedSID  = preselectedPlayer:SteamID64()
        playerCombo._selectedName = preselectedPlayer:Nick()
    end
end

function WL:ShowSitAlert(entries, sid)
    self.alertEntries = entries
    self.alertName    = entries[1] and entries[1].name or sid

    timer.Simple(12, function() WL.alertEntries = {} end)
end

net.Receive("WatchlistUpdate", function()
    local msgtype = net.ReadUInt(4)

    if msgtype == MSG_CONFIRM then
        local ok      = net.ReadBool()
        local errcode = net.ReadString()

        if IsValid(WL._statusLbl) then
            WL._statusLbl:SetText(ok and "Erfolgreich hinzugefügt!" or ("Fehler: " .. (errcode ~= "" and errcode or "unbekannt")))
        end
        if IsValid(WL._addBtn) then WL._addBtn:SetEnabled(true) end

    elseif msgtype == MSG_DATA then
        local sid     = net.ReadString()
        local count   = net.ReadUInt(16)
        local entries = {}

        for i = 1, count do
            entries[i] = {
                id         = net.ReadUInt(32),
                name       = net.ReadString(),
                reason     = net.ReadString(),
                category   = net.ReadString(),
                admin_name = net.ReadString(),
                timestamp  = net.ReadDouble(),
            }
        end

        WL.entries   = entries
        WL.lookupSID = sid

        if count > 0 then WL:ShowSitAlert(entries, sid) end

        if IsValid(WL.frame) and WL._rebuildEntries then
            WL._rebuildEntries()
        end
    end
end)

hook.Add("HUDPaint", "WL_AlertHUD", function()
    if not HasRank() then return end

    local entries = WL.alertEntries
    local count   = #entries
    if count == 0 then return end

    local rows   = math.min(count, 3)
    local height = 54 + rows * 22 + 8
    local ax     = ScrW() - ALERT_W - 12
    local ay     = ScrH() - height  - 52

    draw.RoundedBox(4, ax, ay, ALERT_W, height, COLOR_BG)
    draw.SimpleText("WATCHLIST",                                    "DermaDefaultBold", ax + 8, ay + 8,  color_white,   TEXT_ALIGN_LEFT)
    draw.SimpleText(WL.alertName .. " – " .. count .. " Einträge", "DermaDefault",     ax + 8, ay + 26, COLOR_SUBTEXT, TEXT_ALIGN_LEFT)

    for i = 1, rows do
        local e      = entries[i]
        local y      = ay + 46 + (i - 1) * 22
        local reason = #e.reason > 28 and e.reason:sub(1, 26) .. "…" or e.reason
        draw.SimpleText(CategoryLabel(e.category) .. "  –  " .. reason, "DermaDefault", ax + 8, y, color_white, TEXT_ALIGN_LEFT)
    end

    if count > 3 then
        draw.SimpleText("+ " .. (count - 3) .. " weitere", "DermaDefault",
            ax + ALERT_W / 2, ay + height - 14, COLOR_SUBTEXT, TEXT_ALIGN_CENTER)
    end

    if input.IsMouseDown(MOUSE_LEFT) then
        local mx, my = gui.MousePos()
        if mx >= ax and mx <= ax + ALERT_W and my >= ay and my <= ay + height then
            WL.alertEntries = {}
            timer.Remove("WL_AlertDismiss")
        end
    end
end)

hook.Add("OnPlayerChat", "WL_ChatCmd", function(ply, text)
    if ply ~= LocalPlayer() then return end

    local arg = text:lower():match("^!watchlist%s*(.*)")
    if not arg then return end

    if not HasRank() then
        chat.AddText("[Watchlist] Keine Berechtigung.")
        return true
    end

    local presel
    if arg ~= "" then
        for _, p in ipairs(player.GetAll()) do
            if p:Nick():lower():find(arg, 1, true) then
                presel = p
                break
            end
        end
    end

    WL:Open(presel)
    return true
end)