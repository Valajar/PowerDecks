-- Dev self-test. Only loaded while dev/RUN_SELFTEST exists.
-- Starts throwaway runs on every PowerDeck and sleeve, compares the live game state against what each
-- item promises, prints [PWRTEST] lines to the Lovely log, then quits. Saving is blocked for the whole
-- session, so the profile and any run in progress are left untouched.

local T = { pass = 0, fail = 0, steps = {}, index = 1 }
PowerDecks.selftest = T

local DECKS = { 'b_pwr_titan', 'b_pwr_signet', 'b_pwr_tycoon', 'b_pwr_jack', 'b_pwr_master' }
local SLEEVES = { 'titan', 'signet', 'tycoon', 'jack', 'master' }
local VOUCHERS = { 'v_pwr_tempered_glass', 'v_pwr_laminated_glass', 'v_pwr_bulletproof_glass', 'v_pwr_supplier', 'v_pwr_wholesaler', 'v_pwr_talent_scout', 'v_pwr_headhunter' }
local JOKERS = { 'j_pwr_coupon_clipper', 'j_pwr_piggy_bank', 'j_pwr_toil_and_trouble', 'j_pwr_purple_card', 'j_pwr_stanczyk', 'j_pwr_dagonet' }

local function log(msg) print('[PWRTEST] ' .. msg) end

local function check(name, got, want)
    if got == want then
        T.pass = T.pass + 1
        log('PASS ' .. name .. ' = ' .. tostring(got))
    else
        T.fail = T.fail + 1
        log('FAIL ' .. name .. ' got ' .. tostring(got) .. ', want ' .. tostring(want))
    end
end

local function near(a, b) return type(a) == 'number' and math.abs(a - b) < 1e-9 end

-- Lands in the game's save folder; the launcher script collects and removes these
local function shot(name)
    love.graphics.captureScreenshot('pwr_selftest_' .. name .. '.png')
end

local function step(name, ready, settle, fn)
    T.steps[#T.steps + 1] = { name = name, ready = ready, settle = settle, fn = fn }
end

local function always() return true end

local function block_saving()
    G.F_NO_SAVING = true
    local channel = G.SAVE_MANAGER.channel
    G.SAVE_MANAGER.channel = {
        push = function(_, msg)
            -- Still let the save thread shut down on quit
            if type(msg) == 'table' and msg.type == 'kill' then channel:push(msg) end
        end
    }
end

local function in_blind_select()
    return G.STAGE == G.STAGES.RUN and G.STATE == G.STATES.BLIND_SELECT and G.jokers and G.consumeables and G.hand
end

-- PartnerAPI opens a partner picker over every new run
local function dismiss_overlay()
    if G.OVERLAY_MENU and G.FUNCS.skip_partner then G.FUNCS.skip_partner() end
end

local function start_run(deck, sleeve)
    G.viewed_sleeve = sleeve or 'sleeve_casl_none'
    if Galdur and Galdur.run_setup and Galdur.run_setup.choices then
        Galdur.run_setup.choices.deck = Back(G.P_CENTERS[deck])
    end
    G.FUNCS.start_run(nil, { stake = 1, deck = G.P_CENTERS[deck] })
end

local function consumable_keys()
    local keys = {}
    for _, card in ipairs(G.consumeables.cards) do
        -- Stacking mods (Noituus, Incantation, Overflow) merge identical consumables into one card
        local qty = card.getQty and card:getQty() or 1
        for _ = 1, qty do keys[#keys + 1] = card.config.center.key end
    end
    table.sort(keys)
    return keys
end

local function snapshot()
    local keys = consumable_keys()
    return {
        jokers = G.jokers.config.card_limit,
        hand = G.hand.config.card_limit,
        consumables = G.consumeables.config.card_limit,
        dollars = to_number(G.GAME.dollars),
        shop = G.GAME.shop.joker_max,
        boosters = G.GAME.modifiers.extra_boosters or 0,
        cards = table.concat(keys, ','),
        card_count = #keys,
    }
end

local base
local seal_all = 'c_deja_vu,c_medium,c_talisman,c_trance'

-- want: deltas against the Red Deck baseline; cards = exact consumable list, card_count = how many in total
local function scenario(deck, sleeve, want)
    local label = deck .. (sleeve and (' + ' .. sleeve) or '')
    step('start ' .. label, always, 0.5, function() start_run(deck, sleeve) end)
    step('settle ' .. label, in_blind_select, 2.5, dismiss_overlay)
    step('check ' .. label, always, 1.2, function()
        local now = snapshot()
        if want.shot then shot(want.shot) end
        check(label .. ' deck', G.GAME.selected_back.effect.center.key, deck)
        if CardSleeves then check(label .. ' sleeve', G.GAME.selected_sleeve, sleeve or 'sleeve_casl_none') end
        if not base then
            base = now
            log('BASE jokers=' .. now.jokers .. ' hand=' .. now.hand .. ' consumables=' .. now.consumables
                .. ' dollars=' .. now.dollars .. ' shop=' .. now.shop .. ' boosters=' .. now.boosters)
            return
        end
        for _, k in ipairs({ 'jokers', 'hand', 'consumables', 'dollars', 'shop', 'boosters' }) do
            check(label .. ' ' .. k, now[k] - base[k], want[k] or 0)
        end
        if want.cards then
            check(label .. ' cards', now.cards, want.cards)
        else
            check(label .. ' card count', now.card_count, want.card_count or 0)
            for _, key in ipairs(consumable_keys()) do
                check(label .. ' card is a seal spectral (' .. key .. ')', seal_all:find(key, 1, true) ~= nil, true)
            end
        end
    end)
end

local function redeem(key)
    G.GAME.used_vouchers[key] = true
    Card.apply_to_run(nil, G.P_CENTERS[key])
end

local function voucher_card(key)
    for _, card in ipairs(G.vouchers.cards) do
        if card.config.center.key == key then return card end
    end
end

local function calc(card, context)
    return card.config.center:calculate(card, context)
end

-- Fires a voucher's end-of-round logic for a blind of the given name; true if the shop vouchers were rerolled
local function restocks(key, blind_name)
    local before = G.GAME.current_round.voucher
    local real_name = G.GAME.blind.name
    G.GAME.blind.name = blind_name
    calc(voucher_card(key), { end_of_round = true, main_eval = true, game_over = false })
    G.GAME.blind.name = real_name
    local after = G.GAME.current_round.voucher
    return after ~= before and type(after) == 'table' and #after >= 1 and type(after.spawn) == 'table'
end

-------------------------------------------------------------------------------------------------------

step('boot', function() return G.STAGE == G.STAGES.MAIN_MENU and G.STATE == G.STATES.MENU end, 3, function()
    local loc = G.localization.descriptions
    for _, key in ipairs(DECKS) do
        check('registered ' .. key, G.P_CENTERS[key] ~= nil, true)
        check('text ' .. key, loc.Back[key] ~= nil and loc.Back[key].name ~= nil, true)
    end
    for _, key in ipairs(VOUCHERS) do
        check('registered ' .. key, G.P_CENTERS[key] ~= nil, true)
        check('text ' .. key, loc.Voucher[key] ~= nil and loc.Voucher[key].name ~= nil, true)
    end
    for _, key in ipairs(JOKERS) do
        check('registered ' .. key, G.P_CENTERS[key] ~= nil, true)
        check('text ' .. key, loc.Joker[key] ~= nil and loc.Joker[key].name ~= nil, true)
    end
    check('coupon clipper rarity', G.P_CENTERS.j_pwr_coupon_clipper.rarity, 2)
    check('stanczyk rarity', G.P_CENTERS.j_pwr_stanczyk.rarity, 4)
    check('dagonet rarity', G.P_CENTERS.j_pwr_dagonet.rarity, 4)
    for _, name in ipairs({ 'pwr_decks', 'pwr_vouchers', 'pwr_jokers' }) do
        check('atlas ' .. name, G.ASSET_ATLAS[name] ~= nil and G.ASSET_ATLAS[name].image ~= nil, true)
    end
    check('post_trigger feature enabled', SMODS.optional_features.post_trigger, true)
    check('amulet knows e_mult', Talisman.effects.list.e_mult ~= nil, true)
    check('amulet knows e_chips', Talisman.effects.list.e_chips ~= nil, true)
    if CardSleeves then
        check('atlas pwr_sleeves', G.ASSET_ATLAS.pwr_sleeves ~= nil and G.ASSET_ATLAS.pwr_sleeves.image ~= nil, true)
        for _, key in ipairs(SLEEVES) do
            local full = 'sleeve_pwr_' .. key
            check('registered ' .. full, CardSleeves.Sleeve:get_obj(full) ~= nil, true)
            check('text ' .. full, loc.Sleeve[full] ~= nil and loc.Sleeve[full .. '_alt'] ~= nil, true)
        end
    else
        log('SKIP CardSleeves is not loaded')
    end
end)

local master = { jokers = 1, hand = 2, consumables = 2, dollars = 14, shop = 2, boosters = 1, cards = seal_all }

scenario('b_red', nil, {})
scenario('b_pwr_titan', nil, { jokers = 1, hand = 2 })
scenario('b_pwr_signet', nil, { consumables = 2, cards = seal_all })
scenario('b_pwr_tycoon', nil, { dollars = 14, shop = 2, boosters = 1 })
scenario('b_pwr_jack', nil, { hand = 1, consumables = 1, dollars = 7, shop = 1, card_count = 2 })
scenario('b_pwr_master', nil, master)

if CardSleeves then
    scenario('b_red', 'sleeve_pwr_titan', { jokers = 1, hand = 2 })
    scenario('b_red', 'sleeve_pwr_signet', { consumables = 2, cards = seal_all })
    scenario('b_red', 'sleeve_pwr_tycoon', { dollars = 14, shop = 2, boosters = 1 })
    scenario('b_red', 'sleeve_pwr_jack', { hand = 1, consumables = 1, dollars = 7, shop = 1, card_count = 2 })
    scenario('b_red', 'sleeve_pwr_master', master)
    -- A sleeve on its own deck gives the smaller "_alt" bonus
    scenario('b_pwr_titan', 'sleeve_pwr_titan', { jokers = 2, hand = 2, shot = 'titan' })
    scenario('b_pwr_signet', 'sleeve_pwr_signet', { consumables = 4, cards = seal_all, shot = 'signet' })
    scenario('b_pwr_tycoon', 'sleeve_pwr_tycoon', { dollars = 28, shop = 2, boosters = 2, shot = 'tycoon' })
    scenario('b_pwr_jack', 'sleeve_pwr_jack', { jokers = 1, hand = 1, consumables = 1, dollars = 7, shop = 1, boosters = 1, card_count = 2, shot = 'jack' })
    -- Master deck + its sleeve: everything, plus Jack of All Trades (4 fixed Spectrals and 2 random ones)
    scenario('b_pwr_master', 'sleeve_pwr_master', { jokers = 1, hand = 3, consumables = 3, dollars = 21, shop = 3, boosters = 1, card_count = 6, shot = 'master' })
    -- Mixed: "start with" cards are always handed out, even past the slot limit
    scenario('b_pwr_signet', 'sleeve_pwr_jack', { hand = 1, consumables = 3, dollars = 7, shop = 1, card_count = 6 })
end

step('start item run', always, 0.5, function() start_run('b_red') end)
step('settle item run', in_blind_select, 2.5, dismiss_overlay)

step('glass vouchers', always, 1, function()
    local n0, d0 = SMODS.get_probability_vars(nil, 1, 4, 'glass')
    check('glass base odds', n0 .. ' in ' .. d0, '1 in 4')
    local other_n, other_d = SMODS.get_probability_vars(nil, 1, 4, 'wheel_of_fortune')

    redeem('v_pwr_tempered_glass')
    local n, d = SMODS.get_probability_vars(nil, 1, 4, 'glass')
    check('tempered glass odds', n .. ' in ' .. d, '1 in 8')

    redeem('v_pwr_laminated_glass')
    n, d = SMODS.get_probability_vars(nil, 1, 4, 'glass')
    check('tempered + laminated glass odds', n .. ' in ' .. d, '1 in 16')

    local n2, d2 = SMODS.get_probability_vars(nil, 1, 4, 'wheel_of_fortune')
    check('other probabilities untouched', n2 .. ' in ' .. d2, other_n .. ' in ' .. other_d)

    redeem('v_pwr_bulletproof_glass')
    n, d = SMODS.get_probability_vars(nil, 1, 4, 'glass')
    check('bulletproof glass numerator', n, 0)
    local broke = false
    for _ = 1, 200 do
        if SMODS.pseudorandom_probability(nil, 'glass', 1, 4) then broke = true end
    end
    check('bulletproof glass breaks in 200 rolls', broke, false)
end)

step('laminated glass alone', always, 0.5, function()
    -- Without Tempered Glass the second tier still has to give the full 4X
    G.GAME.used_vouchers.v_pwr_tempered_glass = nil
    G.GAME.used_vouchers.v_pwr_bulletproof_glass = nil
    voucher_card('v_pwr_tempered_glass'):remove()
    voucher_card('v_pwr_bulletproof_glass'):remove()
    local n, d = SMODS.get_probability_vars(nil, 1, 4, 'glass')
    check('laminated glass alone odds', n .. ' in ' .. d, '1 in 16')
end)

step('restock vouchers', always, 0.5, function()
    redeem('v_pwr_supplier')
    check('supplier restocks after Big Blind', restocks('v_pwr_supplier', 'Big Blind'), true)
    check('supplier restocks after Small Blind', restocks('v_pwr_supplier', 'Small Blind'), false)
    check('supplier restocks after Boss Blind', restocks('v_pwr_supplier', 'The Hook'), false)

    redeem('v_pwr_wholesaler')
    check('wholesaler restocks after Small Blind', restocks('v_pwr_wholesaler', 'Small Blind'), true)
    check('wholesaler restocks after Big Blind', restocks('v_pwr_wholesaler', 'Big Blind'), true)
    check('wholesaler restocks after Boss Blind', restocks('v_pwr_wholesaler', 'The Hook'), false)
    check('supplier defers to wholesaler on Big Blind', restocks('v_pwr_supplier', 'Big Blind'), false)

    local next_key = G.GAME.current_round.voucher[1]
    check('restocked voucher is a real voucher', G.P_CENTERS[next_key] ~= nil and G.P_CENTERS[next_key].set == 'Voucher', true)
    check('restocked voucher is not one already redeemed', G.GAME.used_vouchers[next_key] == true, false)
end)

step('rarity vouchers', always, 0.5, function()
    local function odds()
        local weights = {}
        for _, v in ipairs(SMODS.ObjectTypes.Joker.rarities) do
            weights[v.key] = v.weight * (G.GAME[tostring(v.key):lower() .. '_mod'] or 1)
        end
        return weights
    end
    local before = odds()
    redeem('v_pwr_talent_scout')
    local mid = odds()
    check('talent scout doubles Uncommon weight', near(mid.Uncommon, before.Uncommon * 2), true)
    check('talent scout leaves Rare weight', near(mid.Rare, before.Rare), true)
    check('talent scout leaves Common weight', near(mid.Common, before.Common), true)
    redeem('v_pwr_headhunter')
    local after = odds()
    check('headhunter doubles Rare weight', near(after.Rare, before.Rare * 2), true)
    check('headhunter keeps Uncommon at 2X', near(after.Uncommon, before.Uncommon * 2), true)
    -- The real roll, sampled: Uncommon and Rare should now come up noticeably more often
    local counts = { [1] = 0, [2] = 0, [3] = 0 }
    for i = 1, 10000 do
        local r = SMODS.poll_rarity('Joker', 'pwr_selftest_rarity' .. i)
        if counts[r] then counts[r] = counts[r] + 1 end
    end
    log('rarity sample after both vouchers: common=' .. counts[1] .. ' uncommon=' .. counts[2] .. ' rare=' .. counts[3])
    -- Expected 7.7% (10 of 130 weight) against a base of 5%; 6.3% sits about five standard deviations from both
    check('rare share above the base 5% after Headhunter', counts[3] / 10000 > 0.063, true)
    for _, key in ipairs({ 'v_pwr_talent_scout', 'v_pwr_headhunter' }) do
        G.GAME.used_vouchers[key] = nil
        voucher_card(key):remove()
    end
    G.GAME.uncommon_mod, G.GAME.rare_mod = 1, 1
end)

local joker = {}

step('voucher jokers', always, 0.5, function()
    local count = PowerDecks.voucher_count()
    check('redeemed voucher count', count, 3)

    joker.clipper = SMODS.add_card({ key = 'j_pwr_coupon_clipper' })
    local ret = calc(joker.clipper, { joker_main = true, cardarea = G.jokers })
    check('coupon clipper xmult', ret and ret.xmult, 1 + 0.75 * count)
    check('coupon clipper ignores other contexts', calc(joker.clipper, { before = true, cardarea = G.jokers }), nil)

    joker.pig = SMODS.add_card({ key = 'j_pwr_piggy_bank' })
    check('piggy bank payout', joker.pig.config.center:calc_dollar_bonus(joker.pig), 3 + 2 * count)

    for key, _ in pairs(G.GAME.used_vouchers) do G.GAME.used_vouchers[key] = nil end
    check('coupon clipper with no vouchers', calc(joker.clipper, { joker_main = true, cardarea = G.jokers }), nil)
    check('piggy bank payout with no vouchers', joker.pig.config.center:calc_dollar_bonus(joker.pig), 3)
end)

step('toil and trouble', always, 0.5, function()
    check('consumables empty before generators', #G.consumeables.cards, 0)
    joker.toil = SMODS.add_card({ key = 'j_pwr_toil_and_trouble' })
    check('toil ignores Small and Big Blinds', calc(joker.toil, { end_of_round = true, main_eval = true, beat_boss = false, game_over = false }), nil)
    check('toil ignores a lost round', calc(joker.toil, { end_of_round = true, main_eval = true, beat_boss = true, game_over = true }), nil)
    check('toil ignores per-card end of round', calc(joker.toil, { end_of_round = true, individual = true, beat_boss = true, game_over = false }), nil)
    local ret = calc(joker.toil, { end_of_round = true, main_eval = true, beat_boss = true, game_over = false })
    check('toil triggers on Boss Blind', type(ret) == 'table' and ret.message ~= nil, true)
end)

step('toil result', always, 1.5, function()
    check('toil created a card', #G.consumeables.cards, 1)
    check('toil created a Spectral', G.consumeables.cards[1] and G.consumeables.cards[1].ability.set, 'Spectral')
    check('consumable buffer released', G.GAME.consumeable_buffer, 0)

    joker.purple = SMODS.add_card({ key = 'j_pwr_purple_card' })
    check('purple card ignores other contexts', calc(joker.purple, { open_booster = true }), nil)
    local ret = calc(joker.purple, { skipping_booster = true })
    check('purple card triggers on skip', type(ret) == 'table' and ret.message ~= nil, true)
end)

step('purple card result', always, 1.5, function()
    check('purple card created a card', #G.consumeables.cards, 2)
    check('purple card created a Tarot', G.consumeables.cards[2] and G.consumeables.cards[2].ability.set, 'Tarot')
    -- Both slots are now full
    check('toil needs room', calc(joker.toil, { end_of_round = true, main_eval = true, beat_boss = true, game_over = false }), nil)
    check('purple card needs room', calc(joker.purple, { skipping_booster = true }), nil)
end)

step('legendary jokers', always, 1, function()
    joker.stan = SMODS.add_card({ key = 'j_pwr_stanczyk' })
    joker.dag = SMODS.add_card({ key = 'j_pwr_dagonet' })
    local cavendish = SMODS.add_card({ key = 'j_cavendish' })   -- X3 Mult
    local stuntman = SMODS.add_card({ key = 'j_stuntman' })     -- +250 Chips
    local plain = SMODS.add_card({ key = 'j_joker' })           -- +4 Mult
    local ctx = { joker_main = true, cardarea = G.jokers, full_hand = {}, scoring_hand = {}, scoring_name = 'High Card', poker_hands = {} }

    check('stanczyk gives nothing at ^1', calc(joker.stan, ctx), nil)
    check('dagonet gives nothing at ^1', calc(joker.dag, ctx), nil)

    -- eval_card is the game's own path: it runs the Joker, then tells every other Joker it triggered
    eval_card(plain, ctx)
    check('+Mult Joker does not grow stanczyk', near(joker.stan.ability.extra.power, 1), true)
    check('+Mult Joker does not grow dagonet', near(joker.dag.ability.extra.power, 1), true)

    eval_card(cavendish, ctx)
    check('X Mult Joker grows stanczyk', near(joker.stan.ability.extra.power, 1.01), true)
    check('X Mult Joker does not grow dagonet', near(joker.dag.ability.extra.power, 1), true)

    eval_card(stuntman, ctx)
    check('Chips Joker grows dagonet', near(joker.dag.ability.extra.power, 1.01), true)
    check('Chips Joker does not grow stanczyk', near(joker.stan.ability.extra.power, 1.01), true)

    eval_card(cavendish, ctx)
    check('stanczyk keeps growing', near(joker.stan.ability.extra.power, 1.02), true)

    local stan_ret, dag_ret = calc(joker.stan, ctx), calc(joker.dag, ctx)
    check('stanczyk pays out ^Mult', near(stan_ret and stan_ret.e_mult, 1.02), true)
    check('dagonet pays out ^Chips', near(dag_ret and dag_ret.e_chips, 1.01), true)

    -- Their own triggers must not feed themselves or each other
    eval_card(joker.stan, ctx)
    eval_card(joker.dag, ctx)
    check('stanczyk does not feed itself', near(joker.stan.ability.extra.power, 1.02), true)
    check('dagonet does not feed itself', near(joker.dag.ability.extra.power, 1.01), true)

    cavendish:remove(); stuntman:remove(); plain:remove()
end)

step('tooltips', always, 0.5, function()
    local function builds(name, fn)
        local ok, err = pcall(fn)
        check('tooltip ' .. name, ok and true or tostring(err), true)
    end
    for _, card in ipairs(G.jokers.cards) do
        builds(card.config.center.key, function() return card:generate_UIBox_ability_table() end)
    end
    for _, card in ipairs(G.vouchers.cards) do
        builds(card.config.center.key, function() return card:generate_UIBox_ability_table() end)
    end
    for _, key in ipairs({ 'v_pwr_tempered_glass', 'v_pwr_bulletproof_glass' }) do
        builds(key, function()
            local card = Card(0, 0, G.CARD_W, G.CARD_H, G.P_CARDS.empty, G.P_CENTERS[key])
            local ui = card:generate_UIBox_ability_table()
            card:remove()
            return ui
        end)
    end
    for _, key in ipairs(DECKS) do
        builds(key, function() return Back(G.P_CENTERS[key]):generate_UI() end)
    end
    if CardSleeves then
        local decks = { 'b_red' }
        for _, key in ipairs(DECKS) do decks[#decks + 1] = key end
        for _, deck in ipairs(decks) do
            if Galdur and Galdur.run_setup and Galdur.run_setup.choices then
                Galdur.run_setup.choices.deck = Back(G.P_CENTERS[deck])
            end
            G.GAME.viewed_back = Back(G.P_CENTERS[deck])
            for _, key in ipairs(SLEEVES) do
                builds('sleeve_pwr_' .. key .. ' on ' .. deck, function()
                    return G.UIDEF.sleeve_description('sleeve_pwr_' .. key, 5.5)
                end)
            end
        end
    end
end)

-- Lines every voucher up next to the Jokers so one screenshot shows all the item art
step('gallery', always, 0.5, function()
    for i = #G.consumeables.cards, 1, -1 do G.consumeables.cards[i]:remove() end
    for _, key in ipairs(VOUCHERS) do
        local card = Card(G.jokers.T.x, G.jokers.T.y, G.CARD_W, G.CARD_H, G.P_CARDS.empty, G.P_CENTERS[key],
            { bypass_discovery_center = true, bypass_discovery_ui = true })
        G.consumeables:emplace(card)
    end
end)

step('gallery shot', always, 2.5, function()
    shot('items')
end)

step('done', always, 1, function()
    log('DONE pass=' .. T.pass .. ' fail=' .. T.fail)
    love.event.quit()
end)

-------------------------------------------------------------------------------------------------------

local started
local game_update = Game.update
function Game:update(dt)
    game_update(self, dt)
    local s = T.steps[T.index]
    if not s then return end
    -- Nothing runs until saving is blocked
    if not T.saving_blocked then
        if not (G.SAVE_MANAGER and G.SAVE_MANAGER.channel) then return end
        block_saving()
        T.saving_blocked = true
        log('saving blocked for this session')
    end
    local now = love.timer.getTime()
    started = started or now
    s.began = s.began or now
    if now - started > 600 then
        log('FAIL watchdog expired during step "' .. s.name .. '"')
        log('DONE pass=' .. T.pass .. ' fail=' .. (T.fail + 1))
        T.index = #T.steps + 1
        love.event.quit()
        return
    end
    if not s.since then
        if s.ready() then
            s.since = now
        elseif now - s.began > 45 then
            T.fail = T.fail + 1
            log('FAIL step "' .. s.name .. '" never became ready')
            T.index = T.index + 1
        end
    elseif now - s.since >= s.settle then
        T.index = T.index + 1
        local ok, err = xpcall(s.fn, debug.traceback)
        if not ok then
            T.fail = T.fail + 1
            log('FAIL step "' .. s.name .. '" errored: ' .. tostring(err))
        end
    end
end
