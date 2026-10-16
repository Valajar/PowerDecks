-- Start-of-run bonuses shared by decks and sleeves

-- The four Spectral cards that add a Seal
PowerDecks.seal_spectrals = { 'c_deja_vu', 'c_trance', 'c_medium', 'c_talisman' }

-- Everything the Titan, Signet and Tycoon decks give, used by Master of All Trades
function PowerDecks.master_config()
    return {
        joker_slot = 1, hand_size = 2,
        consumable_slot = 2, consumables = copy_table(PowerDecks.seal_spectrals),
        dollars = 14, shop_size = 2, extra_boosters = 1,
    }
end

-- Half of the above, rounded down, used by Jack of All Trades
function PowerDecks.jack_config()
    return { hand_size = 1, consumable_slot = 1, dollars = 7, shop_size = 1, random_seal_spectrals = 2 }
end

-- Applies the bonuses the base game has no deck config key for.
-- joker_slot, hand_size, consumable_slot, consumables and dollars are handled by the game itself.
function PowerDecks.apply_bonus(config)
    if config.shop_size then
        G.GAME.shop.joker_max = G.GAME.shop.joker_max + config.shop_size
    end
    if config.extra_boosters then
        G.GAME.modifiers.extra_boosters = (G.GAME.modifiers.extra_boosters or 0) + config.extra_boosters
    end
    if config.random_seal_spectrals then
        delay(0.4)
        G.E_MANAGER:add_event(Event({
            func = function()
                local pool = copy_table(PowerDecks.seal_spectrals)
                pseudoshuffle(pool, pseudoseed('pwr_seal_spectrals'))
                for i = 1, math.min(config.random_seal_spectrals, #pool) do
                    SMODS.add_card({ key = pool[i], key_append = 'pwr_deck' })
                end
                return true
            end
        }))
    end
end

function PowerDecks.voucher_count()
    local count = 0
    for _, redeemed in pairs(G.GAME and G.GAME.used_vouchers or {}) do
        if redeemed then count = count + 1 end
    end
    return count
end

function PowerDecks.restock_vouchers()
    G.GAME.current_round.voucher = SMODS.get_next_vouchers()
end

function PowerDecks.spectral_names(keys)
    local names = {}
    for _, key in ipairs(keys) do
        names[#names + 1] = localize { type = 'name_text', key = key, set = 'Spectral' }
    end
    return names
end

-- Creates one consumable of the given set if there is room, the way the base game's Jokers do.
-- Returns true if a card is on its way.
function PowerDecks.create_consumable(set, key_append)
    if #G.consumeables.cards + G.GAME.consumeable_buffer >= G.consumeables.config.card_limit then return false end
    G.GAME.consumeable_buffer = G.GAME.consumeable_buffer + 1
    G.E_MANAGER:add_event(Event({
        func = function()
            SMODS.add_card({ set = set, key_append = key_append })
            G.GAME.consumeable_buffer = 0
            return true
        end
    }))
    return true
end

-- Return keys a Joker uses to give X Mult or Chips
PowerDecks.xmult_keys = { 'x_mult', 'Xmult', 'xmult', 'x_mult_mod', 'Xmult_mod' }
PowerDecks.chip_keys = { 'chips', 'h_chips', 'chip_mod', 'x_chips', 'xchips', 'Xchip_mod' }

-- True if a calculate return table, or an `extra` table chained inside it, uses one of the keys
function PowerDecks.effect_has(effect, keys, depth)
    depth = depth or 0
    if type(effect) ~= 'table' or depth > 4 then return false end
    for _, key in ipairs(keys) do
        if effect[key] then return true end
    end
    for _, value in pairs(effect) do
        -- plain tables only: cards and other objects carry a metatable
        if type(value) == 'table' and getmetatable(value) == nil and PowerDecks.effect_has(value, keys, depth + 1) then
            return true
        end
    end
    return false
end

-- Shared by the Legendary Jokers: grow whenever another Joker's trigger uses one of `watch_keys`,
-- then pay out as `effect_key` (an Amulet hyperoperation key) on this Joker's own trigger.
function PowerDecks.calculate_power(card, context, watch_keys, effect_key)
    if context.post_trigger and not context.blueprint and context.other_card ~= card then
        local other = context.other_card
        if type(other) == 'table' and type(other.ability) == 'table' and other.ability.set == 'Joker'
            and context.other_ret and PowerDecks.effect_has(context.other_ret.jokers, watch_keys) then
            card.ability.extra.power = card.ability.extra.power + card.ability.extra.gain
            return { message = localize('k_upgrade_ex'), colour = G.C.DARK_EDITION, message_card = card }
        end
    end
    if context.joker_main and card.ability.extra.power > 1 then
        return { [effect_key] = card.ability.extra.power }
    end
end
