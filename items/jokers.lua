-- Jokers

SMODS.Joker {
    key = 'coupon_clipper',
    atlas = 'jokers',
    pos = { x = 0, y = 0 },
    rarity = 2,
    cost = 7,
    unlocked = true,
    blueprint_compat = true,
    config = { extra = { xmult_per = 0.75 } },
    loc_vars = function(self, info_queue, card)
        local xmult_per = card.ability.extra.xmult_per
        return { vars = { xmult_per, 1 + xmult_per * PowerDecks.voucher_count() } }
    end,
    calculate = function(self, card, context)
        if context.joker_main then
            local xmult = 1 + card.ability.extra.xmult_per * PowerDecks.voucher_count()
            if xmult > 1 then
                return { xmult = xmult }
            end
        end
    end,
}

SMODS.Joker {
    key = 'piggy_bank',
    atlas = 'jokers',
    pos = { x = 1, y = 0 },
    rarity = 2,
    cost = 6,
    unlocked = true,
    blueprint_compat = false,
    config = { extra = { dollars = 3, dollars_per = 2 } },
    loc_vars = function(self, info_queue, card)
        local extra = card.ability.extra
        return { vars = { extra.dollars, extra.dollars_per, extra.dollars + extra.dollars_per * PowerDecks.voucher_count() } }
    end,
    calc_dollar_bonus = function(self, card)
        return card.ability.extra.dollars + card.ability.extra.dollars_per * PowerDecks.voucher_count()
    end,
}

SMODS.Joker {
    key = 'toil_and_trouble',
    atlas = 'jokers',
    pos = { x = 2, y = 0 },
    rarity = 2,
    cost = 6,
    unlocked = true,
    blueprint_compat = true,
    calculate = function(self, card, context)
        if context.end_of_round and context.main_eval and context.beat_boss and not context.game_over then
            if PowerDecks.create_consumable('Spectral', 'pwr_toil_and_trouble') then
                return { message = localize('k_plus_spectral'), colour = G.C.SECONDARY_SET.Spectral }
            end
        end
    end,
}

SMODS.Joker {
    key = 'purple_card',
    atlas = 'jokers',
    pos = { x = 3, y = 0 },
    rarity = 1,
    cost = 5,
    unlocked = true,
    blueprint_compat = true,
    calculate = function(self, card, context)
        if context.skipping_booster then
            if PowerDecks.create_consumable('Tarot', 'pwr_purple_card') then
                return { message = localize('k_plus_tarot'), colour = G.C.PURPLE }
            end
        end
    end,
}

-- Legendary: the only hyperoperations in the mod. Both grow off other Jokers' triggers and pay out on their own.
SMODS.Joker {
    key = 'stanczyk',
    atlas = 'jokers',
    pos = { x = 4, y = 0 },
    soul_pos = { x = 6, y = 0 },
    rarity = 4,
    cost = 20,
    unlocked = true,
    blueprint_compat = true,
    config = { extra = { power = 1, gain = 0.01 } },
    loc_vars = function(self, info_queue, card)
        return { vars = { card.ability.extra.gain, card.ability.extra.power } }
    end,
    calculate = function(self, card, context)
        return PowerDecks.calculate_power(card, context, PowerDecks.xmult_keys, 'e_mult')
    end,
}

SMODS.Joker {
    key = 'dagonet',
    atlas = 'jokers',
    pos = { x = 5, y = 0 },
    soul_pos = { x = 7, y = 0 },
    rarity = 4,
    cost = 20,
    unlocked = true,
    blueprint_compat = true,
    config = { extra = { power = 1, gain = 0.01 } },
    loc_vars = function(self, info_queue, card)
        return { vars = { card.ability.extra.gain, card.ability.extra.power } }
    end,
    calculate = function(self, card, context)
        return PowerDecks.calculate_power(card, context, PowerDecks.chip_keys, 'e_chips')
    end,
}
