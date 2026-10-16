-- CardSleeves cross-mod
-- Each sleeve gives its deck's bonus. On its own deck it gives a smaller bonus instead (the "_alt" text).

SMODS.Atlas {
    key = "sleeves",
    path = "sleeves.png",
    px = 73,
    py = 95
}

CardSleeves.Sleeve {
    key = 'titan',
    atlas = 'pwr_sleeves',
    pos = { x = 0, y = 0 },
    loc_vars = function(self)
        if self.get_current_deck_key() == 'b_pwr_titan' then
            self.config = { joker_slot = 1 }
            return { key = self.key .. '_alt', vars = { self.config.joker_slot } }
        end
        self.config = { joker_slot = 1, hand_size = 2 }
        return { key = self.key, vars = { self.config.joker_slot, self.config.hand_size } }
    end,
}

CardSleeves.Sleeve {
    key = 'signet',
    atlas = 'pwr_sleeves',
    pos = { x = 1, y = 0 },
    loc_vars = function(self)
        if self.get_current_deck_key() == 'b_pwr_signet' then
            self.config = { consumable_slot = 2 }
            return { key = self.key .. '_alt', vars = { self.config.consumable_slot } }
        end
        self.config = { consumable_slot = 2, consumables = copy_table(PowerDecks.seal_spectrals) }
        local vars = { self.config.consumable_slot }
        for _, name in ipairs(PowerDecks.spectral_names(self.config.consumables)) do
            vars[#vars + 1] = name
        end
        return { key = self.key, vars = vars }
    end,
}

CardSleeves.Sleeve {
    key = 'tycoon',
    atlas = 'pwr_sleeves',
    pos = { x = 2, y = 0 },
    loc_vars = function(self)
        if self.get_current_deck_key() == 'b_pwr_tycoon' then
            self.config = { dollars = 14, extra_boosters = 1 }
            return { key = self.key .. '_alt', vars = { self.config.dollars, self.config.extra_boosters } }
        end
        self.config = { dollars = 14, shop_size = 2, extra_boosters = 1 }
        return { key = self.key, vars = { self.config.dollars, self.config.shop_size, self.config.extra_boosters } }
    end,
    apply = function(self, sleeve)
        CardSleeves.Sleeve.apply(sleeve)
        PowerDecks.apply_bonus(sleeve.config)
    end,
}

CardSleeves.Sleeve {
    key = 'jack',
    atlas = 'pwr_sleeves',
    pos = { x = 3, y = 0 },
    loc_vars = function(self)
        if self.get_current_deck_key() == 'b_pwr_jack' then
            -- The two bonuses the deck's rounding left out
            self.config = { joker_slot = 1, extra_boosters = 1 }
            return { key = self.key .. '_alt', vars = { self.config.joker_slot, self.config.extra_boosters } }
        end
        self.config = PowerDecks.jack_config()
        return { key = self.key, vars = {
            self.config.hand_size, self.config.consumable_slot, self.config.shop_size,
            self.config.dollars, self.config.random_seal_spectrals,
        } }
    end,
    apply = function(self, sleeve)
        CardSleeves.Sleeve.apply(sleeve)
        PowerDecks.apply_bonus(sleeve.config)
    end,
}

CardSleeves.Sleeve {
    key = 'master',
    atlas = 'pwr_sleeves',
    pos = { x = 4, y = 0 },
    loc_vars = function(self)
        if self.get_current_deck_key() == 'b_pwr_master' then
            -- Jack of All Trades on top of the full set
            self.config = PowerDecks.jack_config()
            return { key = self.key .. '_alt' }
        end
        self.config = PowerDecks.master_config()
        return { key = self.key }
    end,
    apply = function(self, sleeve)
        CardSleeves.Sleeve.apply(sleeve)
        PowerDecks.apply_bonus(sleeve.config)
    end,
}
