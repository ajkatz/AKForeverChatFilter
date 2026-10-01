-- Review: the window ('/gtf review') with the lines that went, newest last, each with its reason;
-- '/gtf review all' shows the kept ones too. A click on a line prints it to chat with every word that
-- counted and its weight, so that the word to teach ('/gtf allow <word>', '/gtf block <word>') is in
-- plain sight.
--
-- The window is ours alone: a plain frame with Blizzard's tooltip backdrop, dragged by its title, its
-- place remembered. Nothing protected, nothing of Blizzard's touched.
local _, ns = ...

local Review = {}
ns.Review = Review

local WIDTH, HEIGHT, PAD = 480, 320, 12
local REVIEW_MAX = 300  -- lines the window shows
local DEFAULT_POSITION = { point = "CENTER", relativePoint = "CENTER", x = 0, y = 120 }

local BACKDROP = {
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
}

local window
local widgets = {}

-- a line as a chat window would show it, minus the links' innards (a link cannot sit inside another)
function Review.Plain(text)
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
    w.title:SetText("AKForeverTradeFilter")
    w.note = text(window, "GameFontDisableSmall", "RIGHT")
    w.note:SetPoint("TOPRIGHT", window, "TOPRIGHT", -30, -12)
    w.close = CreateFrame("Button", nil, window, "UIPanelCloseButton")
    w.close:SetPoint("TOPRIGHT", window, "TOPRIGHT", -2, -2)
    w.close:SetScript("OnClick", function()
        ns.SafeCall(Review.Close)
    end)

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
        ns.SafeCall(Review.Explain, Review, link)
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
    w.hint:SetText("Click a line for the words that counted; /gtf allow or /gtf block teaches one.")
    w.showAll = button(window, "All", 60, function()
        Review:Show("all")
    end)
    w.showAll:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -PAD, 10)
    w.showHidden = button(window, "Hidden", 70, function()
        Review:Show("hidden")
    end)
    w.showHidden:SetPoint("RIGHT", w.showAll, "LEFT", -6, 0)

    Review.window = window
    Review.widgets = widgets
end

------------------------------------------------------------------------
-- The lines
------------------------------------------------------------------------
local function line(entry)
    local who = "|cffffd100" .. tostring(entry.who) .. "|r"
    local why = "|cff5ac8e8" .. tostring(entry.why) .. "|r"
    local verdict = (entry.keep and "|cff60ff60kept|r" or "|cffff8080hidden|r") .. (entry.kind and (" " .. entry.kind) or "")
    return string.format("|Hgtf:%d|h|cff808080[%s]|r %s: %s - %s, %s|h",
        entry.id or 0, stamp(entry.t), who, Review.Plain(entry.text), verdict, why)
end

function Review:Fill(what)
    local list = widgets.list
    if type(list.Clear) == "function" then
        list:Clear()
    end
    local log = ns.db and ns.db.log or {}
    local shown, first = 0, math.max(1, #log - REVIEW_MAX + 1)
    for index = first, #log do
        local entry = log[index]
        if what == "all" or not entry.keep then
            list:AddMessage(line(entry))
            shown = shown + 1
        end
    end
    if shown == 0 then
        list:AddMessage("|cff808080nothing " .. (what == "all" and "seen" or "hidden") .. " yet|r")
    end
    if type(list.ScrollToBottom) == "function" then
        list:ScrollToBottom()
    end
    Review.showing = what
    widgets.note:SetText((what == "all" and "every line" or "hidden lines") .. ", " .. shown .. " shown")
end

-- a line clicked: its verdict, its reason and every word that counted, printed to chat
function Review:Explain(link)
    local id = tonumber(string.match(tostring(link), "^gtf:(%d+)"))
    local entry = id and ns.Filter.EntryById(id)
    if not entry then
        return
    end
    ns:Print((entry.keep and "kept" or "hidden") .. " - " .. tostring(entry.why) .. "; " .. tostring(entry.work)
        .. ". |cffffd100/gtf allow <word>|r or |cffffd100/gtf block <word>|r teaches one.")
end

function Review:Show(what)
    build()
    window:Show()
    self:Fill(what or Review.showing or "hidden")
end

function Review:Close()
    if window then
        window:Hide()
    end
end

function Review:Describe()
    return {
        built = window ~= nil,
        shown = window and window:IsShown() or false,
        showing = Review.showing,
    }
end

------------------------------------------------------------------------
-- Commands
------------------------------------------------------------------------
ns:RegisterCommand("review", "the lines that went, with the reason; '/gtf review all' shows the kept ones too", function(rest)
    Review:Show(string.lower(rest or "") == "all" and "all" or "hidden")
end)

ns:RegisterCommand("clear", "forget the logged lines", function()
    if ns.db then
        ns.db.log = {}
    end
    if window and window:IsShown() then
        Review:Show(Review.showing)
    end
    ns:Print("cleared.")
end)
