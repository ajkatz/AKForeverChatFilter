-- Trainer: the window. Two pages.
--
-- TRAINING ('/gtf train on'): every line the filter decides on is put to you, one at a time, before you
-- are told what the filter did - "Trade" or "Not trade"? Then the filter's own call and its reason come
-- up beside yours, and the score keeps count of how often the two agree. Your answers are saved with the
-- line (db.labels), which is what the next round of tuning is made from. '/gtf train unsure' asks only
-- about the lines the filter had nothing to go by.
--
-- REVIEW ('/gtf review'): the lines that went, newest last, each with the reason; '/gtf review all' shows
-- the kept ones too. A click on a line flags its verdict as wrong (a second click takes the flag back) -
-- the flag is saved with the line.
--
-- The window is ours alone: a plain frame with Blizzard's tooltip backdrop, dragged by its title, its
-- place remembered. Nothing protected, nothing of Blizzard's touched.
local _, ns = ...

local Trainer = {}
ns.Trainer = Trainer

local WIDTH, HEIGHT, PAD = 480, 330, 12
local QUEUE_MAX = 30    -- lines waiting to be asked about; older ones are let go
local LABELS_MAX = 600  -- answers kept in the saved file
local REVIEW_MAX = 300  -- lines the review page shows
local DEFAULT_POSITION = { point = "CENTER", relativePoint = "CENTER", x = 0, y = 120 }

local BACKDROP = {
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
}

local window, page = nil, "train"
local widgets = {}
local queue, current, dropped = {}, nil, 0

-- a line as a chat window would show it, minus the links' innards (a link cannot sit inside another)
function Trainer.Plain(text)
    if type(text) ~= "string" then
        return ""
    end
    local plain = string.gsub(text, "|H[^|]*|h(%[[^%]]*%])|h", "%1")
    plain = string.gsub(plain, "|H[^|]*|h", "")
    plain = string.gsub(plain, "|T[^|]*|t", "")
    return plain
end

local function stamp(t)
    if type(date) == "function" and type(t) == "number" then
        return date("%H:%M", t)
    end
    return "--:--"
end

------------------------------------------------------------------------
-- The window
------------------------------------------------------------------------
local function savePosition()
    local point, _, relativePoint, x, y = window:GetPoint(1)
    if type(point) == "string" and type(x) == "number" and type(y) == "number" and ns.cdb then
        ns.cdb.options.window = { point = point, relativePoint = relativePoint or point, x = x, y = y }
    end
end

local function place()
    local saved = ns.cdb and ns.cdb.options and ns.cdb.options.window
    local position = (type(saved) == "table" and type(saved.x) == "number" and type(saved.y) == "number") and saved or DEFAULT_POSITION
    window:ClearAllPoints()
    window:SetPoint(position.point or "CENTER", UIParent, position.relativePoint or position.point or "CENTER", position.x, position.y)
end

local function button(parent, text, width, onClick)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(width, 22)
    b:SetText(text)
    b:SetScript("OnClick", function()
        ns.SafeCall(onClick)
    end)
    return b
end

local function text(parent, font, justify)
    local fs = parent:CreateFontString(nil, "OVERLAY", font)
    fs:SetJustifyH(justify or "LEFT")
    return fs
end

local function build()
    if window then
        return
    end
    local template = (type(BackdropTemplateMixin) == "table") and "BackdropTemplate" or nil
    window = CreateFrame("Frame", "AKForeverTradeFilterWindow", UIParent, template)
    window:SetSize(WIDTH, HEIGHT)
    window:SetFrameStrata("MEDIUM")
    window:SetClampedToScreen(true)
    window:SetMovable(true)
    window:EnableMouse(true)
    window:RegisterForDrag("LeftButton")
    window:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)
    window:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        ns.SafeCall(savePosition)
    end)
    if type(window.SetBackdrop) == "function" then
        window:SetBackdrop(BACKDROP)
        local c = TOOLTIP_DEFAULT_BACKGROUND_COLOR
        if c and type(c.r) == "number" then
            window:SetBackdropColor(c.r, c.g, c.b, 0.95)
        else
            window:SetBackdropColor(0.09, 0.09, 0.19, 0.95)
        end
    end
    place()

    local w = widgets
    w.title = text(window, "GameFontNormal")
    w.title:SetPoint("TOPLEFT", window, "TOPLEFT", PAD, -10)
    w.title:SetText("The Great Trade Filter")
    w.note = text(window, "GameFontDisableSmall", "RIGHT")
    w.note:SetPoint("TOPRIGHT", window, "TOPRIGHT", -30, -12)
    w.close = CreateFrame("Button", nil, window, "UIPanelCloseButton")
    w.close:SetPoint("TOPRIGHT", window, "TOPRIGHT", -2, -2)
    w.close:SetScript("OnClick", function()
        ns.SafeCall(Trainer.Close)
    end)

    -- the training page
    w.meta = text(window, "GameFontHighlightSmall")
    w.meta:SetPoint("TOPLEFT", window, "TOPLEFT", PAD, -36)
    w.message = text(window, "GameFontHighlight")
    w.message:SetPoint("TOPLEFT", window, "TOPLEFT", PAD, -54)
    w.message:SetWidth(WIDTH - 2 * PAD)
    w.message:SetHeight(96)
    w.message:SetJustifyV("TOP")
    if type(w.message.SetWordWrap) == "function" then
        w.message:SetWordWrap(true)
    end
    w.question = text(window, "GameFontNormal")
    w.question:SetPoint("TOPLEFT", window, "TOPLEFT", PAD, -158)
    w.question:SetText("Should Trade chat show this line?")
    w.trade = button(window, "Trade", 100, function()
        Trainer:Answer("trade")
    end)
    w.trade:SetPoint("TOPLEFT", window, "TOPLEFT", PAD, -182)
    w.notTrade = button(window, "Not trade", 100, function()
        Trainer:Answer("not")
    end)
    w.notTrade:SetPoint("LEFT", w.trade, "RIGHT", 8, 0)
    w.skip = button(window, "Skip", 70, function()
        Trainer:Skip()
    end)
    w.skip:SetPoint("LEFT", w.notTrade, "RIGHT", 8, 0)
    w.feedback = text(window, "GameFontHighlightSmall")
    w.feedback:SetPoint("TOPLEFT", window, "TOPLEFT", PAD, -214)
    w.feedback:SetWidth(WIDTH - 2 * PAD)
    w.feedback:SetHeight(44)
    w.feedback:SetJustifyV("TOP")
    if type(w.feedback.SetWordWrap) == "function" then
        w.feedback:SetWordWrap(true)
    end
    w.tally = text(window, "GameFontDisableSmall")
    w.tally:SetPoint("BOTTOMLEFT", window, "BOTTOMLEFT", PAD, 12)
    w.toReview = button(window, "Review", 80, function()
        Trainer:Show("review")
    end)
    w.toReview:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -PAD, 10)

    -- the review page
    w.list = CreateFrame("ScrollingMessageFrame", "AKForeverTradeFilterReview", window)
    w.list:SetPoint("TOPLEFT", window, "TOPLEFT", PAD, -36)
    w.list:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -PAD, 40)
    if type(w.list.SetFontObject) == "function" then
        w.list:SetFontObject(ChatFontSmall or ChatFontNormal or GameFontHighlightSmall)
    end
    w.list:SetJustifyH("LEFT")
    if type(w.list.SetFading) == "function" then
        w.list:SetFading(false)
    end
    if type(w.list.SetMaxLines) == "function" then
        w.list:SetMaxLines(REVIEW_MAX + 10)
    end
    if type(w.list.SetIndentedWordWrap) == "function" then
        w.list:SetIndentedWordWrap(true)
    end
    if type(w.list.SetHyperlinksEnabled) == "function" then
        w.list:SetHyperlinksEnabled(true)
    end
    w.list:SetScript("OnHyperlinkClick", function(_, link)
        ns.SafeCall(Trainer.Flag, Trainer, link)
    end)
    w.list:EnableMouseWheel(true)
    w.list:SetScript("OnMouseWheel", function(self, delta)
        if delta > 0 then
            if self.ScrollUp then self:ScrollUp() end
        elseif self.ScrollDown then
            self:ScrollDown()
        end
    end)
    w.hint = text(window, "GameFontDisableSmall")
    w.hint:SetPoint("BOTTOMLEFT", window, "BOTTOMLEFT", PAD, 12)
    w.hint:SetText("Click a line to flag its verdict as wrong; click again to take it back.")
    w.showAll = button(window, "All", 60, function()
        Trainer:Show("review", "all")
    end)
    w.showAll:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -PAD, 10)
    w.showHidden = button(window, "Hidden", 70, function()
        Trainer:Show("review", "hidden")
    end)
    w.showHidden:SetPoint("RIGHT", w.showAll, "LEFT", -6, 0)
    w.toTrain = button(window, "Train", 70, function()
        Trainer:Train("all")
    end)
    w.toTrain:SetPoint("RIGHT", w.showHidden, "LEFT", -6, 0)

    Trainer.window = window
    Trainer.widgets = widgets
end

local TRAIN_WIDGETS = { "meta", "message", "question", "trade", "notTrade", "skip", "feedback", "tally", "toReview" }
local REVIEW_WIDGETS = { "list", "hint", "showAll", "showHidden", "toTrain" }

local function showPage(name)
    page = name
    for _, key in ipairs(TRAIN_WIDGETS) do
        widgets[key]:SetShown(name == "train")
    end
    for _, key in ipairs(REVIEW_WIDGETS) do
        widgets[key]:SetShown(name == "review")
    end
end

------------------------------------------------------------------------
-- Training
------------------------------------------------------------------------
local function tally()
    local stats = ns.db and ns.db.trainStats or { asked = 0, agreed = 0 }
    if stats.asked == 0 then
        return "no answers yet"
    end
    return string.format("we agreed on %d of %d (%d%%)", stats.agreed, stats.asked, math.floor(100 * stats.agreed / stats.asked + 0.5))
end

local function refreshTraining()
    if not window or page ~= "train" then
        return
    end
    local w = widgets
    local waiting = #queue
    w.note:SetText("training - " .. (waiting > 0 and (waiting .. " waiting") or "up to date") .. (dropped > 0 and (", " .. dropped .. " let go") or ""))
    if current then
        w.meta:SetText(string.format("[%s] %s - %s:", stamp(current.t), current.ch == "general" and "General" or "Trade", tostring(current.who)))
        w.message:SetText(Trainer.Plain(current.text))
        w.question:SetText("Should " .. (current.ch == "general" and "General" or "Trade") .. " chat show this line?")
    else
        w.meta:SetText("")
        w.message:SetText("|cff808080waiting for the next line...|r")
        w.question:SetText("")
    end
    for _, key in ipairs({ "trade", "notTrade", "skip" }) do
        if current then
            w[key]:Enable()
        else
            w[key]:Disable()
        end
    end
    w.tally:SetText(tally())
end

local function showNext()
    current = table.remove(queue, 1)
    refreshTraining()
end

function Trainer:Offer(entry, verdict)
    local mode = ns:GetOption("training")
    if mode ~= "all" and mode ~= "unsure" then
        return
    end
    if mode == "unsure" and verdict.sure then
        return
    end
    if not window or not window:IsShown() or page ~= "train" then
        return
    end
    queue[#queue + 1] = entry
    while #queue > QUEUE_MAX do
        table.remove(queue, 1)
        dropped = dropped + 1
    end
    if not current then
        showNext()
    else
        refreshTraining()
    end
end

local function recordLabel(entry, label)
    local db = ns.db
    if not db then
        return
    end
    db.labels = db.labels or {}
    db.trainStats = db.trainStats or { asked = 0, agreed = 0 }
    local agree = (label == "trade") == (entry.keep == true)
    db.labels[#db.labels + 1] = {
        t = entry.t, ch = entry.ch, who = entry.who, text = entry.text,
        keep = entry.keep, why = entry.why, score = entry.score, mode = entry.mode,
        label = label, agree = agree,
    }
    while #db.labels > LABELS_MAX do
        table.remove(db.labels, 1)
    end
    db.trainStats.asked = db.trainStats.asked + 1
    if agree then
        db.trainStats.agreed = db.trainStats.agreed + 1
    end
    -- the log entry carries your call too, for the review page
    entry.label = label
    return agree
end

function Trainer:Answer(label)
    if not current then
        return
    end
    local entry = current
    local agree = recordLabel(entry, label)
    local w = widgets
    if agree then
        w.feedback:SetText("|cff60ff60Agreed.|r The filter " .. (entry.keep and "kept it" or "hid it") .. " - " .. tostring(entry.why))
    else
        w.feedback:SetText("|cffff6060Not what the filter did:|r it " .. (entry.keep and "kept it" or "hid it") .. " - " .. tostring(entry.why))
    end
    ns:Log("label", { text = entry.text, keep = entry.keep, label = label, agree = agree })
    showNext()
end

function Trainer:Skip()
    if not current then
        return
    end
    widgets.feedback:SetText("|cff808080Skipped.|r")
    showNext()
end

function Trainer:Train(mode)
    build()
    ns:SetOption("training", mode)
    showPage("train")
    window:Show()
    refreshTraining()
end

------------------------------------------------------------------------
-- Review
------------------------------------------------------------------------
local function reviewLine(entry)
    local who = "|cffffd100" .. tostring(entry.who) .. "|r"
    local why = "|cff5ac8e8" .. tostring(entry.why) .. "|r"
    local mark = ""
    if entry.flag then
        mark = " |cffff6060[flagged wrong]|r"
    elseif entry.label then
        mark = " |cff808080[you: " .. (entry.label == "trade" and "trade" or "not trade") .. "]|r"
    end
    local verdict = entry.keep and "|cff60ff60kept|r" or "|cffff8080hidden|r"
    return string.format("|Hgtf:%d|h|cff808080[%s]|r %s: %s - %s, %s%s|h",
        entry.id or 0, stamp(entry.t), who, Trainer.Plain(entry.text), verdict, why, mark)
end

function Trainer:Fill(what)
    local list = widgets.list
    if type(list.Clear) == "function" then
        list:Clear()
    end
    local log = ns.db and ns.db.log or {}
    local shown, first = 0, math.max(1, #log - REVIEW_MAX + 1)
    for index = first, #log do
        local entry = log[index]
        if what == "all" or not entry.keep then
            list:AddMessage(reviewLine(entry))
            shown = shown + 1
        end
    end
    if shown == 0 then
        list:AddMessage("|cff808080nothing " .. (what == "all" and "seen" or "hidden") .. " yet|r")
    end
    if type(list.ScrollToBottom) == "function" then
        list:ScrollToBottom()
    end
    Trainer.reviewing = what
    widgets.note:SetText("review - " .. (what == "all" and "every line" or "hidden lines") .. ", " .. shown .. " shown")
end

function Trainer:Flag(link)
    local id = tonumber(string.match(tostring(link), "^gtf:(%d+)"))
    if not id then
        return
    end
    local entry = ns.Filter.EntryById(id)
    if not entry then
        return
    end
    entry.flag = (not entry.flag) and "wrong" or nil
    ns:Log("flag", { text = entry.text, keep = entry.keep, flag = entry.flag })
    self:Fill(Trainer.reviewing or "hidden")
end

function Trainer:Show(pageName, what)
    build()
    showPage(pageName)
    window:Show()
    if pageName == "review" then
        self:Fill(what or Trainer.reviewing or "hidden")
    else
        refreshTraining()
    end
end

function Trainer:Close()
    if not window then
        return
    end
    window:Hide()
    if ns:GetOption("training") ~= "off" then
        ns:SetOption("training", "off")
        ns:Print("training off - |cffffd100/gtf train on|r to go on.")
    end
end

function Trainer:Describe()
    return {
        built = window ~= nil,
        shown = window and window:IsShown() or false,
        page = page,
        waiting = #queue,
        dropped = dropped,
        current = current and current.text or nil,
        training = ns:GetOption("training"),
        tally = tally(),
    }
end

ns:Listen("LINE", function(entry, verdict)
    Trainer:Offer(entry, verdict)
end)

ns:Listen("LOGIN", function()
    if ns:GetOption("training") ~= "off" then
        Trainer:Train(ns:GetOption("training"))
    end
end)

------------------------------------------------------------------------
-- Commands
------------------------------------------------------------------------
ns:RegisterCommand("train", "'on': every Trade line is put to you first - Trade or not? - then the filter's call is shown beside yours; 'unsure': only the lines it had nothing to go by; 'off'", function(rest)
    local mode = string.lower(rest or "")
    if mode == "on" then
        mode = "all"
    end
    if mode ~= "all" and mode ~= "unsure" and mode ~= "off" then
        ns:Print("usage: /gtf train on | unsure | off   (now: " .. tostring(ns:GetOption("training")) .. ")")
        return
    end
    if mode == "off" then
        ns:SetOption("training", "off")
        if window then
            window:Hide()
        end
        ns:Print("training off. " .. tally() .. ".")
        return
    end
    Trainer:Train(mode)
    ns:Print("training " .. (mode == "all" and "on: every line is put to you first." or "on for the unsure lines only.") .. " " .. tally() .. ".")
end)

ns:RegisterCommand("review", "the lines that went, with the reason; '/gtf review all' shows the kept ones too", function(rest)
    local what = string.lower(rest or "")
    Trainer:Show("review", what == "all" and "all" or "hidden")
end)

ns:RegisterCommand("clear", "forget the logged lines and your answers", function()
    if ns.db then
        ns.db.log, ns.db.labels, ns.db.trainStats = {}, {}, { asked = 0, agreed = 0 }
    end
    queue, current, dropped = {}, nil, 0
    if window and window:IsShown() then
        Trainer:Show(page, Trainer.reviewing)
    end
    ns:Print("cleared.")
end)

ns:RegisterCommand("reset", "put the window back in the middle of the screen", function()
    if ns.cdb then
        ns.cdb.options.window = nil
    end
    if window then
        place()
    end
    ns:Print("window reset.")
end)
