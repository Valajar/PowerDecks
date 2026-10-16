-- POWERDECKS CORE

PowerDecks = PowerDecks or {}
PowerDecks.version = SMODS.current_mod.version

-- The Legendary Jokers react to other Jokers triggering
SMODS.current_mod.optional_features = {
    post_trigger = true,
}

SMODS.Atlas {
    key = "modicon",
    path = "icon.png",
    px = 34,
    py = 34
}

SMODS.Atlas {
    key = "decks",
    path = "decks.png",
    px = 71,
    py = 95
}

SMODS.Atlas {
    key = "vouchers",
    path = "vouchers.png",
    px = 71,
    py = 95
}

SMODS.Atlas {
    key = "jokers",
    path = "jokers.png",
    px = 71,
    py = 95
}

PowerDecks.files = {
    'lib/bonus.lua',
    'items/decks.lua',
    'items/vouchers.lua',
    'items/jokers.lua',
}
-- Cross-mod
if CardSleeves then table.insert(PowerDecks.files, 'items/sleeves.lua') end

for _, file in ipairs(PowerDecks.files) do
    assert(SMODS.load_file(file))()
end

-- Dev only: the self-test runs when its marker file exists (see dev/selftest.lua)
if NFS.getInfo(SMODS.current_mod.path .. 'dev/RUN_SELFTEST') then
    assert(SMODS.load_file('dev/selftest.lua'))()
end
