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