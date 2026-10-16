-- Decks

SMODS.Back {
    key = 'titan',
    atlas = 'decks',
    pos = { x = 0, y = 0 },
    config = { joker_slot = 1, hand_size = 2 },
    unlocked = true,
    loc_vars = function(self)
        return { vars = { self.config.joker_slot, self.config.hand_size } }
    end,
}

SMODS.Back {
    key = 'signet',
    atlas = 'decks',
    pos = { x = 1, y = 0 },
    config = { consumable_slot = 2, consumables = { 'c_deja_vu', 'c_trance', 'c_medium', 'c_talisman' } },
    unlocked = true,
    loc_vars = function(self)
        local vars = { self.config.consumable_slot }
        for _, name in ipairs(PowerDecks.spectral_names(self.config.consumables)) do
            vars[#vars + 1] = name
        end
        return { vars = vars }
    end,
}

SMODS.Back {
    key = 'tycoon',
    atlas = 'decks',
    pos = { x = 2, y = 0 },
    config = { dollars = 14, shop_size = 2, extra_boosters = 1 },
    unlocked = true,
    loc_vars = function(self)
        return { vars = { self.config.dollars, self.config.shop_size, self.config.extra_boosters } }
    end,
    apply = function(self, back)
        PowerDecks.apply_bonus(self.config)
    end,
}

-- Half of every bonus above, rounded down
SMODS.Back {
    key = 'jack',
    atlas = 'decks',
    pos = { x = 3, y = 0 },
    config = PowerDecks.jack_config(),
    unlocked = true,
    loc_vars = function(self)
        return { vars = {
            self.config.hand_size, self.config.consumable_slot, self.config.shop_size,
            self.config.dollars, self.config.random_seal_spectrals,
        } }
    end,
    apply = function(self, back)
        PowerDecks.apply_bonus(self.config)
    end,
}

-- Titan, Signet and Tycoon at once
SMODS.Back {
    key = 'master',
    atlas = 'decks',
    pos = { x = 4, y = 0 },
    config = PowerDecks.master_config(),
    unlocked = true,
    apply = function(self, back)
        PowerDecks.apply_bonus(self.config)
    end,
}
