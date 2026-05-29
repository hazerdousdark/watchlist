util.AddNetworkString("WatchlistUpdate")

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
    testmoderator   = true,
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

local COOLDOWNS = {
    [MSG_REQUEST] = 0.5,
    [MSG_ADD]     = 2,
}

local SID64_PATTERN    = "^%d%d%d%d%d%d%d%d%d%d%d%d%d%d%d%d%d$"
local ENTRY_MAX_AGE_DAYS = 180

local function HasRank(ply)
    return IsValid(ply) and ALLOWED_RANKS[ply:GetUserGroup()] == true
end

local function IsValidSID64(sid)
    return sid and sid:match(SID64_PATTERN) ~= nil
end

local lastAction = {}

local function IsRateLimited(ply, msgtype)
    local sid = ply:SteamID64()
    local now = CurTime()
    lastAction[sid] = lastAction[sid] or {}
    local cd = COOLDOWNS[msgtype] or 1
    if (lastAction[sid][msgtype] or 0) + cd > now then return true end
    lastAction[sid][msgtype] = now
    return false
end

local function SqlErr(context)
    ErrorNoHalt("[Watchlist] " .. context .. ": " .. sql.LastError() .. "\n")
end

local function InitDB()
    if sql.Query([[
        CREATE TABLE IF NOT EXISTS watchlist (
            id            INTEGER PRIMARY KEY AUTOINCREMENT,
            steamid       TEXT    NOT NULL,
            name          TEXT    NOT NULL,
            reason        TEXT    NOT NULL,
            category      TEXT    NOT NULL DEFAULT 'other',
            admin_steamid TEXT    NOT NULL,
            admin_name    TEXT    NOT NULL,
            timestamp     INTEGER NOT NULL
        )
    ]]) == false then
        SqlErr("Table creation")
        return
    end

    sql.Query("CREATE INDEX IF NOT EXISTS idx_steamid  ON watchlist(steamid)")
    sql.Query("CREATE INDEX IF NOT EXISTS idx_category ON watchlist(category)")

    local cutoff = os.time() - (ENTRY_MAX_AGE_DAYS * 24 * 60 * 60)
    if sql.Query(string.format("DELETE FROM watchlist WHERE timestamp < %d", cutoff)) == false then
        SqlErr("Cleanup")
    end
end

InitDB()

local function SendConfirm(client, ok, reason)
    net.Start("WatchlistUpdate")
        net.WriteUInt(MSG_CONFIRM, 4)
        net.WriteBool(ok)
        net.WriteString(reason or "")
    net.Send(client)
end

local function SendEntries(client, steamid)
    local rows = sql.Query(string.format([[
        SELECT id, name, reason, category, admin_name, timestamp
        FROM watchlist
        WHERE steamid = %s
        ORDER BY timestamp DESC
    ]], sql.SQLStr(steamid)))

    if rows == false then SqlErr("Fetch") end
    rows = rows or {}

    net.Start("WatchlistUpdate")
        net.WriteUInt(MSG_DATA, 4)
        net.WriteString(steamid)
        net.WriteUInt(#rows, 16)
        for _, row in ipairs(rows) do
            net.WriteUInt(tonumber(row.id), 32)
            net.WriteString(row.name)
            net.WriteString(row.reason)
            net.WriteString(row.category)
            net.WriteString(row.admin_name)
            net.WriteDouble(tonumber(row.timestamp))
        end
    net.Send(client)
end

local function AddEntry(steamid, name, admin, reason, category)
    if not CATEGORY_LABEL[category] then category = "other" end
    if name == "" then name = steamid end

    if sql.Query(string.format([[
        INSERT INTO watchlist (steamid, name, reason, category, admin_steamid, admin_name, timestamp)
        VALUES (%s, %s, %s, %s, %s, %s, %d)
    ]],
        sql.SQLStr(steamid),
        sql.SQLStr(name),
        sql.SQLStr(reason),
        sql.SQLStr(category),
        sql.SQLStr(admin:SteamID64()),
        sql.SQLStr(admin:Nick()),
        os.time()
    )) == false then
        SqlErr("Insert")
        return false, "sql_error:" .. sql.LastError()
    end

    return true
end

net.Receive("WatchlistUpdate", function(_, client)
    if not HasRank(client) then return end

    local msgtype = net.ReadUInt(4)

    if IsRateLimited(client, msgtype) then
        if msgtype == MSG_ADD then SendConfirm(client, false, "rate_limited") end
        return
    end

    if msgtype == MSG_REQUEST then
        local steamid = net.ReadString()
        if not IsValidSID64(steamid) then
            SendEntries(client, steamid) -- returns empty, safe
            return
        end
        SendEntries(client, steamid)

    elseif msgtype == MSG_ADD then
        local steamid  = net.ReadString()
        local name     = net.ReadString()
        local reason   = net.ReadString()
        local category = net.ReadString()

        if not IsValidSID64(steamid) then
            SendConfirm(client, false, "invalid_steamid")
            return
        end

        if reason == "" then
            SendConfirm(client, false, "empty_reason")
            return
        end

        local ok, err = AddEntry(steamid, name, client, reason, category)
        SendConfirm(client, ok, ok and nil or (err or "unknown"))
    end
end)

function WatchlistSendToAdmin(admin, steamid)
    if not IsValid(admin) or not HasRank(admin) then return end
    if not IsValidSID64(steamid) then return end
    SendEntries(admin, steamid)
end
