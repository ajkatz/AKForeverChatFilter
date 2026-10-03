-- The words. Every line of chat is scored by the words in it: what says "game business" counts up, what
-- says "the world outside" counts down, and the sum decides (Rules.lua). Every list belongs to a KIND -
-- trade, groups, guilds, talk (the rest of the game), world - and the kind the words favour is the kind
-- of the line. The lists are plain data so that a wrong call is a one-line fix - and '/gtf allow <word>'
-- / '/gtf block <word>' teach more without touching this file.
--
-- Rules of thumb for the lists:
--   * a word that is BOTH stays out: "war" is a warrior, "gates" are AQ's, "if" is Ironforge and a
--     conjunction, "ah" is the auction house and a sigh, "nuke" is what a mage does, "camp" is where a
--     rare spawns and where history was made. A missing word costs a line nothing, a wrong word costs
--     the wrong verdict;
--   * nationalities and countries are the world outside, but only in passing (-1): "french guild
--     recruiting" is guild business, "any russians here" is not;
--   * everything is lower case; a phrase (with spaces) is matched as a phrase on the whole line.
local _, ns = ...

local Terms = {}
ns.Terms = Terms

Terms.LISTS = {
    -- TRADE: selling, buying, a price, a service for a tip
    { weight = 2, kind = "trade", words = {
        "wts", "wtb", "wtt", "wttf", "sell", "selling", "sells", "sold", "buy", "buying", "trade", "trading",
        "trader", "lfw", "lfe", "pst", "cod", "obo", "ono", "offer", "offers", "offering", "bid", "bids",
        "bidding", "gold", "silver", "copper", "tip", "tips", "tipping", "mats", "own mats", "your mats",
        "my mats", "boost", "boosting", "boosts", "carry", "carries", "carried", "port", "ports", "portal",
        "portals", "summon", "summons", "summ",
        "ench", "enchant", "enchants", "enchanter", "enchanting", "craft", "crafts", "crafting", "crafter",
        "craftable", "price", "prices", "priced", "cheap", "cheapest", "cheaper", "auction", "auctions",
        "auction house", "on ah", "in ah", "on the ah", "in the ah", "ah price", "ah prices", "than ah",
        "buyout", "bo", "lowest", "highest", "paying", "pay", "pays", "sale", "sales", "in stock", "wanted",
        "seeking", "hiring", "service", "services", "delivery", "deliver", "vendor", "vendors", "vendored",
        "going for", "how much", "worth", "asking price", "any offers", "make an offer", "best offer",
    } },
    -- GROUPS: a group forming for a dungeon, a raid, a quest
    { weight = 2, kind = "groups", words = {
        "lf", "lfm", "lfg", "lft", "lfh", "lfdps", "lf1m", "lf2m", "lf3m", "lf4m", "lf5m", "lfr", "looking for",
        "send tell", "send a tell", "send me a tell", "please send tell", "need tank",
        "need a tank", "need healer", "need a healer", "need heals", "need dps", "need 1", "need 2", "need 3",
        "need one", "need two", "1 more", "2 more", "3 more", "one more", "two more", "forming", "spots open",
        "spot left", "spots left", "spot open", "full clear", "anyone want to do", "anyone wanna do",
        "anyone up for", "who wants to do",
    } },
    { weight = 1, kind = "groups", words = {
        "tank", "tanks", "tanking", "healer", "healers", "heals", "heal", "healing", "dps", "dpser", "dpsers",
        "group", "grp", "party", "raid", "raids", "raiding", "run", "runs", "spot", "spots", "invite", "inv",
        "invites", "summons available",
    } },
    -- GUILDS: a guild recruiting, or somebody looking for one
    { weight = 2, kind = "guilds", words = {
        "recruit", "recruits", "recruiting", "recruitment", "guild", "guilds", "lf guild", "looking for a guild",
        "looking for guild", "guildless", "social guild", "raiding guild", "leveling guild", "pvp guild",
        "casual guild", "new guild", "our guild", "join us", "guildies", "gbank", "guild bank",
    } },
    { weight = 1, kind = "guilds", words = {
        "gm", "officer", "officers", "discord", "members", "member", "community", "friendly", "active",
        "semi-hardcore", "all classes", "all levels", "charter", "charters", "sigs", "sig", "signature",
        "signatures", "sign my", "guild cigs",
    } },
    -- TALK: the vocabulary of the game itself
    { weight = 1, kind = "talk", words = {
        -- professions
        "alchemy", "alchemist", "alch", "blacksmith", "blacksmithing", "smith", "smithing", "armorsmith",
        "weaponsmith", "engineer", "engineering", "engi", "eng", "leatherworker", "leatherworking", "lw",
        "tailor", "tailoring", "skinner", "skinning", "miner", "mining", "herbalist", "herbalism", "herb",
        "herbs", "fishing", "fisherman", "cooking", "cook", "first aid", "recipe", "recipes", "pattern",
        "patterns", "plans", "schematic", "schematics", "formula", "formulas", "profession", "professions",
        "prof", "profs",
        -- dungeons and raids
        "rfc", "ragefire", "wc", "wailing caverns", "deadmines", "dead mines", "vc", "vancleef", "sfk",
        "shadowfang", "bfd", "blackfathom", "stockade", "stockades", "gnomer", "gnomeregan", "rfk", "rfd",
        "razorfen", "sm", "scarlet monastery", "monastery", "cath", "cathedral", "armory", "library",
        "graveyard", "ulda", "uldaman", "zf", "zul'farrak", "zulfarrak", "mara", "maraudon", "sunken temple",
        "brd", "blackrock", "lbrs", "ubrs", "brs", "scholo", "scholomance", "strat", "stratholme", "dire maul",
        "dm east", "dm west", "dm north", "dm tribute", "tribute run", "mc", "molten core", "ony", "onyxia",
        "bwl", "blackwing", "zg", "zul'gurub", "zulgurub", "aq", "aq20", "aq40", "naxx", "naxxramas",
        "ruins of lordaeron", "rol", "lordaeron",
        "dungeon", "dungeons", "instance", "instances", "raider", "raiders", "clears", "attune", "attuned",
        "attunement", "key", "keys", "keyed",
        -- zones and cities
        "barrens", "durotar", "mulgore", "tirisfal", "silverpine", "hillsbrad", "ashenvale", "stonetalon",
        "westfall", "elwynn", "dun morogh", "loch modan", "redridge", "duskwood", "wetlands", "darkshore",
        "teldrassil", "stranglethorn", "stv", "desolace", "tanaris", "feralas", "hinterlands", "badlands",
        "searing gorge", "burning steppes", "un'goro", "ungoro", "silithus", "winterspring", "plaguelands",
        "epl", "wpl", "felwood", "azshara", "swamp of sorrows", "blasted lands", "arathi", "alterac",
        "thousand needles", "dustwallow", "moonglade", "deadwind", "orgrimmar", "org", "thunder bluff", "tb",
        "undercity", "uc", "stormwind", "sw", "ironforge", "darnassus", "darn", "gadgetzan", "gadget", "gadetzan",
        "booty bay", "bb", "ratchet", "everlook", "crossroads", "xr", "tarren mill", "tm", "southshore",
        "astranaar", "taurajo", "brill", "goldshire", "kargath", "menethil", "theramore", "nethergarde",
        "cenarion hold", "light's hope", "andorhal", "feathermoon", "nijel's point", "thelsamar", "auberdine",
        "sepulcher", "hammerfall", "refuge pointe", "splintertree", "sun rock", "camp mojache", "freewind",
        "shadowprey", "zoram", "kalimdor", "eastern kingdoms", "azeroth",
        -- classes, specs and roles
        "warrior", "warr", "mage", "mages", "priest", "priests", "rogue", "rogues", "druid", "druids",
        "shaman", "shamans", "sham", "warlock", "warlocks", "lock", "locks", "paladin", "paladins", "pally",
        "pala", "hunter", "hunters", "hunt", "ranged", "melee", "caster", "casters", "hybrid", "spec",
        "specs", "respec", "resto", "feral", "prot", "fury", "arms", "shadow", "disc", "frost", "fire",
        "arcane", "affliction", "demo", "destro", "enh", "enhance", "enhancement", "ele", "elemental",
        "boomkin", "survival", "bm", "mm", "combat", "assassination", "ret", "retri", "hpally", "holy pally",
        "holy priest", "holy spec",
        -- loot and play
        "rep", "boss", "bosses", "wipe", "wiped", "faction", "factions", "cross-faction", "mailbox", "mail",
        "loot", "loots", "roll", "rolls", "rolled", "ninja", "ninjad", "reserved", "hr", "ms", "os", "greed",
        "bind", "boe", "bop", "epic", "epics", "purple", "purples", "blues", "greens", "greys", "quest",
        "quests", "questing", "escort", "turn in", "turnin", "level", "levels", "lvl", "lvls", "leveling",
        "lvling", "lv", "xp", "exp", "alt", "alts", "main", "twink", "twinks", "pvp", "pve", "bg", "bgs",
        "wsg", "ab", "av", "warsong", "arathi basin", "alterac valley", "honor", "rank", "ranks", "ranked",
        "hk", "hks", "gank", "ganked", "ganking", "gankers", "ganker", "camped", "camping", "flight", "fp",
        "flightpath", "flight path", "hearth", "hs", "hearthstone", "mount", "mounts", "rez", "res", "ress",
        "resurrect", "buff", "buffs", "buffed", "fort", "fortitude", "motw", "mark of the wild", "intellect",
        "int", "spirit", "water", "food", "conjure", "conjured", "stack", "stacks", "bag", "bags", "slot",
        "slots", "bank", "whisper", "wisp", "wsp", "pm", "dm me", "whisper me", "w me", "afk", "brb", "lag",
        "lagging", "laggy", "latency", "stutter", "stuttering", "fps", "frames", "frame rate", "server", "servers",
        "realm", "realms", "layer", "layers", "queue", "queues", "login", "log in", "loggin", "logging", "logged",
        "fresh", "fresh start", "fresh server", "fresh realm", "turn it in", "hand it in", "hand in",
        "logout", "relog", "reload", "addon", "addons", "macro", "macros", "keybind", "ui", "dc",
        "disconnect", "disconnected", "patch", "hotfix", "nerf", "nerfed", "bug", "bugs", "bugged", "report a bug",
        "bug report", "beta", "stealth", "sap", "sheep",
        "polymorph", "fear", "cc", "kite", "kiting", "pull", "pulls", "pulled", "aggro", "threat", "taunt",
        "dot", "dots", "hots", "crit", "crits", "proc", "procs", "mana", "rage", "combo", "cooldown",
        "cooldowns", "cd", "cds", "gear", "geared", "gearing", "ilvl", "tier", "t1", "t2", "t3", "pre-bis",
        "prebis", "bis", "spell", "spells", "ability", "talent", "talents", "trainer", "skill", "skills",
        "skilled", "skill up", "skillup", "horde", "alliance", "ally", "orc", "orcs", "troll", "trolls",
        "tauren", "undead", "forsaken", "human", "humans", "dwarf", "dwarves", "gnome", "gnomes", "night elf",
        "nelf", "nelfs", "elf", "elves", "goblin", "goblins", "murloc", "murlocs", "kobold", "kobolds",
        "gnoll", "gnolls", "harpy", "harpies", "centaur", "quilboar", "naga", "furbolg", "ogre", "ogres",
        "dragon", "dragons", "whelp", "whelps", "elite", "elites", "rare", "rares", "spawn", "spawns",
        "spawned", "respawn", "mob", "mobs", "npc", "npcs", "flightmaster", "innkeeper", "auctioneer",
        "banker",
        -- items and materials
        "weapon", "weapons", "armor", "sword", "swords", "axe", "axes", "mace", "maces", "dagger", "daggers",
        "staff", "staves", "bow", "bows", "wand", "wands", "shield", "shields", "cloak", "cloaks", "robe",
        "robes", "chest", "chestpiece", "leggings", "legs", "pants", "boots", "gloves", "gauntlets", "belt",
        "bracers", "bracer", "helm", "helmet", "hat", "shoulders", "shoulder", "ring", "rings", "trinket",
        "trinkets", "neck", "necklace", "amulet", "off-hand", "offhand", "2h", "1h", "two-hand", "vest", "tunic", "jerkin",
        "one-hand", "2hander", "1hander", "potion", "potions", "pot", "pots", "elixir", "elixirs", "flask",
        "flasks", "scroll", "scrolls", "bandage", "bandages", "cloth", "linen", "wool", "silk", "mageweave",
        "runecloth", "felcloth", "leather", "hide", "hides", "rugged", "ore", "ores", "bars", "tin", "bronze",
        "iron", "steel", "mithril", "thorium", "truesilver", "arcanite", "dark iron", "ingot", "peacebloom",
        "silverleaf", "earthroot", "mageroyal", "briarthorn", "stranglekelp", "bruiseweed", "kingsblood",
        "liferoot", "fadeleaf", "goldthorn", "wintersbite", "firebloom", "purple lotus", "sungrass",
        "blindweed", "ghost mushroom", "gromsblood", "golden sansam", "dreamfoil", "silversage",
        "plaguebloom", "icecap", "black lotus", "lotus", "gem", "gems", "pearl", "pearls", "essence",
        "essences", "dust", "shard", "shards", "crystal", "crystals", "cores", "orb", "orbs", "rune", "runes",
        "oil", "oils", "poison", "poisons", "sharpening", "weightstone", "stone", "stones", "grinding",
        "arrows", "bullets", "ammo", "quiver", "dye", "salt", "vial", "vials", "kit", "kits", "spices", "meat",
        "fish", "egg", "eggs", "noggenfogger", "devilsaur", "wildvine", "elemental fire", "elemental water",
        "elemental earth", "elemental air", "heart of fire", "globe of water", "core of earth",
        "breath of wind", "blood of the mountain", "fire core", "sulfuras", "thunderfury", "ashkandi",
        "quel'serrar", "windfury", "rockbiter", "flametongue", "frostbrand", "raptor", "wolf", "tiger", "kodo",
        "ram", "horse", "mechanostrider", "nightsaber", "epic mount", "riding", "mounted",
    } },
    -- GOLD SELLERS: real money, a website, a delivery - a line gone whatever else it says (the user, 2026-09-30)
    { weight = -3, kind = "seller", words = {
        "paypal", "venmo", "cashapp", "cash app", "usd", "real money", "rmt", "discount", "coupon", "promo",
        "promo code", "24/7", "fast delivery", "safe delivery", "instant delivery", "quick delivery",
        "delivery time", "cheap gold", "cheapest gold", "buy gold", "buying gold", "sell gold", "selling gold",
        "gold for sale", "wow gold", "gold shop", "gold store", "gold seller", "website", "livechat", "live chat",
        "whatsapp", "telegram", "skype", "wechat", "per 100g", "per 1000g", "per 1k", "lowest price", "best price",
        "trusted", "legit gold", "gold cheap", "power leveling", "powerleveling", "boosting service",
        -- a shop's advert (heard 2026-10-02: "we cover your Leveling & Dungeons ... Order for Beta or
        -- Pre-Order for release >>> MythicStore.com <<<"): nobody in the game takes orders
        "pre order", "preorder", "pre orders", "preorders", "order now", "order today", "order here", "order for beta",
        "place your order", "we cover", "we cover your", "our store", "our shop", "our site", "our website",
        "visit our", "boosting services", "leveling service", "leveling services", "carry service", "carry services",
        "professional team", "pro team", "account sharing", "selfplay", "self play", "piloted", "money back",
        "best prices", "cheapest prices", "dot com",
    } },
    -- THE WORLD OUTSIDE, loud: politics, war, faith, the words no trade line needs
    { weight = -3, kind = "world", words = {
        -- people
        "trump", "donald trump", "biden", "joe biden", "obama", "clinton", "hillary", "kamala", "jd vance",
        "pence", "desantis", "newsom", "aoc", "ocasio", "bernie", "sanders", "pelosi", "mcconnell",
        "schumer", "musk", "elon", "bezos", "zuckerberg", "soros", "putin", "zelensky", "zelenskyy",
        "netanyahu", "erdogan", "xi jinping", "jinping", "kim jong", "modi", "macron", "trudeau", "carney",
        "starmer", "sunak", "boris johnson", "merkel", "scholz", "milei", "orban", "lula", "bolsonaro",
        "maduro", "hitler", "stalin", "mao", "mussolini", "castro", "guevara", "bin laden", "saddam",
        "gaddafi", "assad", "khamenei", "ayatollah", "epstein", "rfk jr", "tulsi", "hegseth", "rubio",
        "rogan", "tucker carlson", "hannity", "maddow", "shapiro", "ben shapiro", "candace", "charlie kirk",
        "george bush", "cheney", "reagan", "nixon", "jimmy carter", "kennedy", "jfk", "roosevelt",
        "thatcher", "churchill", "truss", "corbyn", "farage", "le pen", "sarkozy", "hollande", "berlusconi",
        "meloni", "gorbachev", "yeltsin", "lenin", "trotsky", "pol pot", "pinochet", "mandela", "gandhi",
        "kissinger", "al gore", "romney", "mccain", "palin", "ted cruz", "hawley", "gaetz", "boebert",
        "marjorie taylor greene", "fetterman", "buttigieg", "elizabeth warren", "bloomberg", "giuliani",
        "bannon", "stephen miller", "kushner", "ivanka", "melania", "hunter biden", "michelle obama", "walz",
        "tim walz", "whitmer", "pritzker", "hochul", "greg abbott", "youngkin", "noem", "ramaswamy", "vivek",
        "nikki haley", "huckabee", "king charles", "prince harry", "meghan markle", "royal family",
        -- streamers and their screens: any direct talk of them (the user, 2026-09-30)
        "asmon", "asmongold", "zackrawrr", "streamer", "streamers", "streaming", "stream", "streams", "twitch",
        "twitch chat", "youtuber", "youtubers", "content creator", "influencer", "influencers", "xqc",
        "sodapoppin", "esfand", "mizkif", "tyler1", "pirate software", "quin69", "guzu", "nmplol", "cdew",
        "venruki", "swifty", "towelliee", "cohh", "cohhcarnage", "onlyfangs", "savix", "ziqo", "payo", "ahmpy",
        "grubby", "kaif", "emiru", "pokelawls", "forsen", "kai cenat", "ishowspeed", "mrbeast", "mr beast",
        "alex jones", "jordan peterson", "andrew tate", "steven crowder", "crowder", "tim pool", "nick fuentes",
        "fuentes", "greta thunberg", "bill gates", "george floyd", "rittenhouse", "mangione", "diddy",
        "weinstein", "oprah", "kim jong un",
        -- parties, sides and labels
        "republican", "republicans", "democrat", "democrats", "democratic party", "democracy", "gop", "dnc",
        "rnc", "maga", "liberal", "liberals", "libs", "libtard", "libtards", "conservative", "conservatives",
        "conservatard", "leftist", "leftists", "lefty", "leftie", "lefties", "rightwing", "right-wing",
        "right wing", "leftwing", "left-wing", "left wing", "socialist", "socialists", "socialism",
        "communist", "communists", "communism", "commie", "commies", "fascist", "fascists", "fascism", "nazi",
        "nazis", "neo-nazi", "neonazi", "woke", "wokeness", "wokeism", "antifa", "blm", "marxist", "marxists",
        "marxism", "capitalist", "capitalists", "capitalism", "anarchist", "anarchists", "libertarian",
        "libertarians", "progressives", "zionist", "zionists", "zionism", "globalist", "globalists",
        "deep state", "illuminati", "qanon", "alt-right", "alt right", "far-right", "far right", "far-left",
        "far left", "radical left", "radical right", "feminist", "feminists", "feminism", "sjw", "sjws",
        "incel", "incels", "redpill", "red pill", "redpilled", "blackpill", "boomers", "snowflake",
        "snowflakes", "cancel culture", "virtue signal", "virtue signaling", "lgbt", "lgbtq",
        -- the machinery
        "election", "elections", "electoral", "ballot", "ballots", "voter", "voters", "president",
        "presidential", "presidency", "senate", "senator", "senators", "congress", "congressman",
        "congresswoman", "parliament", "governor", "prime minister", "supreme court", "scotus", "impeach",
        "impeached", "impeachment", "tariff", "tariffs", "trade war", "immigrant", "immigrants",
        "immigration", "migrant", "migrants", "deport", "deported", "deportation", "deportations",
        "ice raids", "border wall", "abortion", "abortions", "pro-life", "pro-choice", "gun control",
        "2nd amendment", "second amendment", "nra", "jan 6", "jan 6th", "january 6", "january 6th",
        "insurrection", "riot", "riots", "rioters", "protest", "protests", "protesters", "protestors",
        "lockdowns", "mandate", "mandates", "executive order", "white house", "the white house", "pentagon",
        "cia", "fbi", "nsa", "kremlin", "politics", "political", "politician", "politicians", "government",
        "governments", "regime", "dictator", "dictatorship", "propaganda", "conspiracy", "conspiracies",
        "police", "cops", "military",
        -- countries: a country named is a line gone, whatever else it says
        "usa", "united states", "america", "canada", "mexico", "uk", "britain", "england",
        "scotland", "ireland", "wales", "france", "germany", "spain", "italy", "portugal", "netherlands",
        "belgium", "sweden", "norway", "denmark", "finland", "iceland", "greenland", "poland", "greece",
        "turkey", "austria", "switzerland", "hungary", "czech", "czechia", "slovakia", "slovenia", "croatia",
        "serbia", "bosnia", "romania", "bulgaria", "moldova", "belarus", "estonia", "latvia", "lithuania",
        "luxembourg", "malta", "cyprus", "georgia", "armenia", "azerbaijan", "kazakhstan", "mongolia",
        "brazil", "argentina", "chile", "peru", "bolivia", "ecuador", "colombia", "venezuela", "uruguay",
        "paraguay", "cuba", "haiti", "jamaica", "panama", "costa rica", "guatemala", "honduras", "nicaragua",
        "el salvador", "puerto rico", "dominican republic", "australia", "new zealand", "japan", "korea",
        "south korea", "north korea", "india", "pakistan", "bangladesh", "sri lanka", "nepal", "vietnam",
        "thailand", "philippines", "indonesia", "malaysia", "singapore", "myanmar", "cambodia", "africa",
        "south africa", "nigeria", "kenya", "ethiopia", "egypt", "morocco", "algeria", "libya", "sudan",
        "somalia", "saudi", "saudi arabia", "qatar", "dubai", "uae", "yemen", "jordan", "lebanon", "kuwait",
        "bahrain", "oman", "europe", "asia",
        -- wars and places in the news
        "ukraine", "ukrainian", "ukrainians", "russia", "moscow", "israel", "israeli", "israelis", "gaza",
        "palestine", "palestinian", "palestinians", "hamas", "hezbollah", "iran", "iranian", "iranians",
        "tehran", "iraq", "syria", "afghanistan", "taliban", "isis", "al qaeda", "alqaeda", "china", "beijing",
        "middle east", "the middle east", "west bank", "gaza strip", "golan", "kashmir", "crimea", "donbas", "balkans",
        "far east", "third world", "global south", "the west", "western world", "eastern europe", "latin america",
        "ccp", "taiwan", "hong kong", "pyongyang", "genocide", "apartheid", "terrorist", "terrorists",
        "terrorism", "jihad", "jihadi", "war crimes", "holocaust", "ethnic cleansing", "shooting",
        "mass shooting",
        -- faith and race, the way they turn up in chat
        "islam", "islamic", "muslim", "muslims", "christian", "christians", "christianity", "catholic",
        "catholics", "jew", "jews", "jewish", "judaism", "atheist", "atheists", "religion", "religious",
        "bible", "quran", "koran", "pope", "vatican", "mormon", "mormons", "evangelical", "evangelicals",
        "racist", "racists", "racism", "sexist", "sexism", "misogynist", "misogyny", "transgender",
        "transphobic", "homophobic", "homophobe", "white people", "black people", "white supremacy",
        "supremacist", "supremacists", "slavery", "colonialism", "youtube", "tiktok", "instagram",
        -- a crime story is the world's too
        "murder", "murdered", "murderer", "strangled", "strangle", "pedophile", "pedophiles", "pedo", "pedos",
        "paedophile", "paedophiles", "paedo", "paedos", "pedophilia", "pedofile", "pedofiles", "nonce", "nonces",
        "rapist", "rapists", "molested", "molester",
        -- the sexual and the political slang of this chat (heard in Trade, 2026-09-30)
        "trans", "dick", "cock", "pussy", "porn", "nudes", "onlyfans", "horny", "chud", "chuds", "milady",
        "miladies", "petro dollar", "petrodollar", "libtards", "trannies", "tranny", "groomer", "groomers",
        "culture war", "culture wars", "billionaire", "billionaires", "billionares", "gock", "psyop", "psyops",
        "beta male", "beta males", "thot", "thots", "white knight", "midterms", "hormuz", "sex", "sexual",
        "furry", "furries", "bestiality", "ragebait", "rage bait", "troll bait", "indoctrination", "indoctrinated",
        -- health, money and the rest of the outside
        "covid", "corona", "coronavirus", "vaccine", "vaccines", "vaccinated", "vax", "vaxx", "vaxxed",
        "antivax", "anti-vax", "antivaxx", "pandemic", "fauci", "cdc", "climate change", "global warming",
        "inflation", "recession", "stock market", "wall street", "federal reserve", "irs", "taxes",
        "taxpayer", "taxpayers", "welfare", "medicare", "medicaid", "obamacare", "healthcare", "bitcoin",
        "btc", "crypto", "ethereum", "nft", "nfts", "dogecoin", "oil prices", "oil price", "gas prices",
        "gas price", "price of oil", "price of gas",
        -- the game's words in the world's phrases: a tank that holds gas, an oil that gets changed
        "gas tank", "fish tank", "think tank", "tank top", "septic tank", "gas station", "oil change",
        "car wash", "water heater", "hot water tank",
    } },
    -- THE WORLD OUTSIDE, in passing: a nationality, a language, a screen - a line about the game may mention them
    { weight = -1, kind = "world", words = {
        "american", "americans", "british", "english", "scottish", "irish", "welsh", "french", "german",
        "germans", "spanish", "italian", "italians", "portuguese", "dutch", "belgian", "swedish", "swede",
        "swedes", "norwegian", "danish", "finnish", "polish", "russian", "russians", "greek", "turkish",
        "brazilian", "brazilians", "mexican", "mexicans", "canadian", "canadians", "australian", "aussie",
        "aussies", "kiwi", "kiwis", "japanese", "korean", "koreans", "chinese", "indian", "indians",
        "pakistani", "african", "africans", "european", "europeans", "asian", "asians", "arab", "arabs",
        "arabic", "latino", "latinos", "hispanic", "hispanics", "texas", "texan", "california", "florida",
        "new york", "chicago", "london", "paris", "berlin", "toronto", "sydney",
        "cnn", "fox news", "foxnews", "msnbc", "nbc", "cbs", "bbc", "nytimes", "new york times",
        "washington post", "breitbart", "infowars", "twitter", "tweet", "tweets",
        "facebook", "reddit", "netflix", "spotify", "podcast", "podcasts", "nfl", "nba", "mlb",
        "nhl", "super bowl", "superbowl", "world cup", "olympics", "ufc", "wwe", "patriots", "taylor swift",
        "kardashian", "beyonce", "kanye", "eminem", "hollywood", "oscars", "grammys", "movie", "movies",
        "voted", "weather", "snowstorm", "hurricane", "earthquake", "wildfire", "wildfires", "flood",
        "floods", "economy", "my boss", "boss at work", "landlord", "rent", "mortgage", "tuition", "college",
        "university", "school", "homework", "exam", "exams", "wife", "husband", "girlfriend", "boyfriend",
        "kid", "kids", "baby", "pregnant", "wedding", "divorce", "church", "prayer", "pray", "god bless", "amen",
        "drugs", "cocaine", "marijuana", "meth", "gay",
        -- the life outside, in passing: the car, the kitchen, the body
        "gas", "gasoline", "petrol", "fuel", "car", "cars", "truck", "trucks", "traffic", "commute",
        "commuting", "highway", "freeway", "driving", "drove", "parking", "tires", "tyres", "mechanic",
        "garage", "dealership", "insurance", "grocery", "groceries", "walmart", "costco", "amazon", "uber",
        "doordash", "pizza", "burger", "burgers", "mcdonalds", "taco bell", "starbucks", "coffee", "lunch",
        "dinner", "breakfast", "bed", "bedtime", "shower", "laundry", "dishes", "vacuum", "lawn", "mowing",
        "hospital", "nurse", "surgery", "dentist", "flu", "fever", "headache", "diet", "gym", "workout",
        -- the economy and the wires, in passing
        "debt", "trillion", "billion", "dollar", "dollars", "internet", "spectrum", "isp", "wifi", "router",
        "queer", "baddie", "straight guys", "boomer", "zoomer", "zoomers", "gen x", "gen z", "millennial",
        "millennials", "hamburgers", "hotdogs", "cigarettes", "cigs",
        -- people, as the world outside talks about them (the user's call, 2026-09-30: "man", "woman", "boy",
        -- "girl", "children" count against a line; "guys" and "bro" do not - too much of the game's own chat)
        "man", "men", "woman", "women", "boy", "boys", "girl", "girls", "child", "children", "male", "female",
        "males", "females", "mom", "dad", "mommy", "daddy", "parents", "family", "father", "mother",
        "daughter", "sister", "gf", "bf", "femboy", "femboys", "fembois", "femboi", "betas", "tv", "costume",
        "costumes", "trolling", "trolled", "hyperpop",
        -- the mind and its care, a real-life thing (the user, 2026-09-30: "therapy")
        "therapy", "therapist", "meds", "medication", "depression", "depressed", "anxiety", "adhd", "autism",
        "autistic", "mental health", "mental illness", "asylum", "psychiatrist", "psych ward", "trauma",
        "gender", "genders", "pronouns",
    } },
}

-- Said of the channel itself, not of trade: taken out of the line before its words are counted, so that
-- "somebody spergin in trade chat" is not trade.
Terms.NEUTRAL = { "trade chat", "trade channel", "general chat", "in trade", "on trade" }

-- Things that are not words: a hyperlink is the strongest sign of all, a sum of gold nearly as strong,
-- a web address the opposite. Patterns in Lua's own dialect, run on the lower-cased line.
Terms.PATTERNS = {
    -- a line that opens with "imagine ..." is bait, whatever follows (the user's call, 2026-09-30)
    { weight = -3, kind = "world", name = "an 'imagine ...' opener", pattern = "^%s*imagine%f[%W]" },
    { weight = -3, kind = "world", name = "an 'imagine ...' opener", pattern = "^%s*l[om][la]o?%s+imagine%f[%W]" },
    { weight = 3, kind = "talk", name = "a link", pattern = "|h%[[^%]]+%]|h" },   -- an item, spell, quest, ... link
    { weight = 2, kind = "guilds", name = "a <guild>", pattern = "<[^<>]+>" },    -- a guild's name
    { weight = 2, kind = "trade", pattern = "%f[%w]%d+%s*g%f[%W]" },              -- 50g, 5 g
    { weight = 2, kind = "trade", pattern = "%f[%w]%d+%s*k%f[%W]" },              -- 5k
    { weight = 2, kind = "trade", pattern = "%f[%w]%d+%s*gold%f[%W]" },           -- 50 gold
    { weight = 2, kind = "trade", pattern = "%f[%w]%d+%s*silver%f[%W]" },
    { weight = 2, kind = "trade", pattern = "%f[%w]%d+%s*s%f[%W]" },              -- 50s
    { weight = 2, kind = "trade", pattern = "%f[%w]%d+%s*c%f[%W]" },              -- 50c
    { weight = 1, kind = "trade", pattern = "%f[%w]x%d+%f[%W]" },                 -- x20
    { weight = 1, kind = "trade", pattern = "%f[%w]%d+x%f[%W]" },                 -- 20x
    { weight = 1, kind = "groups", pattern = "%f[%w]%d+/%d+%f[%W]" },             -- 3/5 (a group forming)
    { weight = 1, kind = "talk", pattern = "%f[%w]lvl?%s*%d+%f[%W]" },            -- lvl 40, lv40
    { weight = 1, kind = "talk", pattern = "%f[%w]%d+%s*%-%s*%d+%f[%W]" },        -- 40-50
    { weight = -3, kind = "seller", name = "a $ price", pattern = "%$%s*%d" },              -- $5
    { weight = -3, kind = "seller", name = "a $ price", pattern = "%d%s*%$" },              -- 5$
    { weight = -3, kind = "seller", name = "a price in euros", pattern = "%d%s*€" },
    { weight = -3, kind = "seller", name = "a price in euros", pattern = "€%s*%d" },
    -- a web address: a line gone, no other consideration (the user, 2026-09-30) - a Discord invite included
    { weight = -3, kind = "web", name = "a web address", pattern = "https?://" },
    { weight = -3, kind = "web", name = "a web address", pattern = "%f[%w]www%." },
    { weight = -3, kind = "web", name = "a web address", pattern = "%.com%f[%W]" },
    { weight = -3, kind = "web", name = "a web address", pattern = "%.gg%f[%W]" },
    { weight = -3, kind = "web", name = "a web address", pattern = "%.tv%f[%W]" },
    { weight = -3, kind = "web", name = "a web address", pattern = "%.net%f[%W]" },
    { weight = -3, kind = "web", name = "a web address", pattern = "%.org%f[%W]" },
    { weight = -3, kind = "web", name = "a web address", pattern = "%.io%f[%W]" },
    { weight = -3, kind = "web", name = "a web address", pattern = "%.xyz%f[%W]" },
    { weight = -3, kind = "web", name = "a web address", pattern = "%.info%f[%W]" },
    { weight = -3, kind = "web", name = "a web address", pattern = "%.shop%f[%W]" },
    { weight = -3, kind = "web", name = "a web address", pattern = "%.store%f[%W]" },
    { weight = -3, kind = "web", name = "a web address", pattern = "%.co%.uk%f[%W]" },
    { weight = -3, kind = "web", name = "a web address", pattern = "%.de%f[%W]" },
    { weight = -3, kind = "web", name = "a web address", pattern = "%f[%w]discord%.gg" },
    -- ... written with a trick: "store,com", "store . com", "store(dot)com", "store dot com". Only "com"
    -- gets this latitude: "org" is Orgrimmar and "net" is what a fisherman holds.
    { weight = -3, kind = "web", name = "a web address", pattern = "%w%s*[%.,]%s*com%f[%W]" },
    { weight = -3, kind = "web", name = "a web address", pattern = "[%(%[{<]%s*dot%s*[%)%]}>]" },
    { weight = -3, kind = "web", name = "a web address", pattern = "%f[%w]dot%s*com%f[%W]" },
}

