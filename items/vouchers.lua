-- Vouchers

-- Glass line: the break roll uses the 'glass' probability identifier
SMODS.Voucher {
    key = 'tempered_glass',
    atlas = 'vouchers',
    pos = { x = 0, y = 0 },
    cost = 10,
    unlocked = true,
    config = { extra = { odds_mult = 2 } },
    loc_vars = function(self, info_queue, card)
        info_queue[#info_queue + 1] = G.P_CENTERS.m_glass
        return { vars = { (card and card.ability or self.config).extra.odds_mult } }
    end,
    calculate = function(self, card, context)
        if context.mod_probability and context.identifier == 'glass' then
            return { denominator = context.denominator * card.ability.extra.odds_mult }
        end
    end,
}

SMODS.Voucher {
    key = 'laminated_glass',
    atlas = 'vouchers',
    pos = { x = 1, y = 0 },
    cost = 10,
    unlocked = true,
    requires = { 'v_pwr_tempered_glass' },
    config = { extra = { odds_mult = 4 } },
    loc_vars = function(self, info_queue, card)
        info_queue[#info_queue + 1] = G.P_CENTERS.m_glass
        return { vars = { (card and card.ability or self.config).extra.odds_mult } }
    end,
    calculate = function(self, card, context)
        if context.mod_probability and context.identifier == 'glass' then
            -- Tempered Glass already provides half of this
            local tempered = G.GAME.used_vouchers.v_pwr_tempered_glass and G.P_CENTERS.v_pwr_tempered_glass.config.extra.odds_mult or 1
            return { denominator = context.denominator * card.ability.extra.odds_mult / tempered }
        end
    end,
}

SMODS.Voucher {
    key = 'bulletproof_glass',
    atlas = 'vouchers',
    pos = { x = 2, y = 0 },
    cost = 15,
    unlocked = true,
    requires = { 'v_pwr_laminated_glass' },
    loc_vars = function(self, info_queue, card)
        info_queue[#info_queue + 1] = G.P_CENTERS.m_glass
    end,
    calculate = function(self, card, context)
        -- Fixed after every other modifier, so nothing can raise it again
        if context.fix_probability and context.identifier == 'glass' then
            return { numerator = 0 }
        end
    end,
}

-- Restock line: the base game only rolls new Vouchers after a Boss Blind
SMODS.Voucher {
    key = 'supplier',
    atlas = 'vouchers',
    pos = { x = 3, y = 0 },
    cost = 10,
    unlocked = true,
    calculate = function(self, card, context)
        if context.end_of_round and context.main_eval and not context.game_over then
            -- Wholesaler covers the Big Blind too
            if G.GAME.used_vouchers.v_pwr_wholesaler then return end
            if G.GAME.blind:get_type() == 'Big' then
                PowerDecks.restock_vouchers()
            end
        end
    end,
}

SMODS.Voucher {
    key = 'wholesaler',
    atlas = 'vouchers',
    pos = { x = 4, y = 0 },
    cost = 10,
    unlocked = true,
    requires = { 'v_pwr_supplier' },
    calculate = function(self, card, context)
        if context.end_of_round and context.main_eval and not context.game_over then
            local blind_type = G.GAME.blind:get_type()
            if blind_type == 'Small' or blind_type == 'Big' then
                PowerDecks.restock_vouchers()
            end
        end
    end,
}

-- Rarity line: Joker rarity weights are scaled by G.GAME.<rarity>_mod (1 when unset)
SMODS.Voucher {
    key = 'talent_scout',
    atlas = 'vouchers',
    pos = { x = 5, y = 0 },
    cost = 10,
    unlocked = true,
    config = { extra = { rate = 2 } },
    loc_vars = function(self, info_queue, card)
        return { vars = { (card and card.ability or self.config).extra.rate } }
    end,
    redeem = function(self, card)
        G.GAME.uncommon_mod = (G.GAME.uncommon_mod or 1) * card.ability.extra.rate
    end,
}

SMODS.Voucher {
    key = 'headhunter',
    atlas = 'vouchers',
    pos = { x = 6, y = 0 },
    cost = 10,
    unlocked = true,
    requires = { 'v_pwr_talent_scout' },
    config = { extra = { rate = 2 } },
    loc_vars = function(self, info_queue, card)
        return { vars = { (card and card.ability or self.config).extra.rate } }
    end,
    redeem = function(self, card)
        G.GAME.rare_mod = (G.GAME.rare_mod or 1) * card.ability.extra.rate
    end,
}
