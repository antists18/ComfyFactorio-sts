local Public = {}

local ScenarioTable = require 'maps.wasteland.table'
local Event = require 'utils.event'
local PvPTownShield = require 'maps.wasteland.pvp_town_shield'
local Utils = require 'maps.wasteland.utils'
local Team = require 'maps.wasteland.team'
local Score = require 'maps.wasteland.score'
local ResearchBalance = require 'maps.wasteland.research_balance'
local TeamBasics = require 'maps.wasteland.team_basics'
local GuiTemplater = require 'zk-lib/lualibs/control_stage/GuiTemplater'
local TownCenter = require 'maps.wasteland.town_center'

local button_id = 'towny-score-button'

local function spairs(t, order)
    local keys = {}
    for k in pairs(t) do
        keys[#keys + 1] = k
    end
    if order then
        table.sort(
                keys,
                function(a, b)
                    return order(t, a, b)
                end
        )
    else
        table.sort(keys)
    end
    local i = 0
    return function()
        i = i + 1
        if keys[i] then
            return keys[i], t[keys[i]]
        end
    end
end

function Public.add_score_button(player)
    if player.gui.top[button_id] then
        player.gui.top[button_id].destroy()
    end
    local button = player.gui.top.add {
        type = 'sprite-button',
        caption = 'Towns',
        name = button_id
    }
    button.style.font = 'default-bold'
    button.style.font_color = {r = 1, g = 0.7, b = 0.1}
    button.style.minimal_height = 38
    button.style.minimal_width = 80
    button.style.top_padding = 2
    button.style.left_padding = 4
    button.style.right_padding = 4
    button.style.bottom_padding = 2
end

local function on_gui_click(event)
    local element = event.element
    if not element.valid or element.name ~= button_id then
        return
    end

    local player = game.get_player(event.player_index)
    local this = ScenarioTable.get_table()
    local saved_frame = this.score_gui_frame[player.index]
    if saved_frame.parent.visible then
        saved_frame.clear()
    end
    saved_frame.parent.visible = not saved_frame.parent.visible
end

local function init_score_board(player)
    local this = ScenarioTable.get_table()
    local player_index = player.index
    local saved_frame = this.score_gui_frame[player_index]
    if saved_frame and saved_frame.valid then
        return
    end

    local flow, frame, top_flow = GuiTemplater.create_hollow_screen_window(player, "wasteland_leaderboard_frame", 'Town leaderboard')
    top_flow.children[#top_flow.children].name = button_id
    this.score_gui_frame[player_index] = flow
    local offset_y = -200 - (33 * table_size(this.town_centers) * player.display_scale)
    local new_location = GuiTemplater.get_location_by_percentage_with_offset(
        player, 0, 0.5,
        nil, offset_y, -- x (left), y (top) offsets
        nil, 100       --  min x (left), y (top)
    )
    new_location.x = 20
    frame.location = new_location
end

local function format_score(score)
    return string.format('%.1f', math.floor(score * 10) / 10)
end

local function format_town_with_player_names(town_center)
    local player_names = ""
    local player_in_town_name = false
    for _, player in pairs(town_center.market.force.players) do
        if not string.find(town_center.town_name, player.name) then
            if player_names ~= "" then
                player_names = player_names .. ", "
            end
            player_names = player_names .. player.name
        else
            player_in_town_name = true
        end
    end
    if player_names ~= "" then
        if player_in_town_name then
            player_names = "+" .. player_names
        end
        player_names = " (" .. player_names .. ")"
    end
    return town_center.town_name .. player_names
end

local function update_score()
    local this = ScenarioTable.get_table()
    local score_to_win = 100

    local outlander_online = 0
    for _, player in pairs(game.players) do
        if TeamBasics.is_outlander_force(player.force) then
            if player.connected then
                outlander_online = outlander_online + 1
            end
        end
    end

    for _, player in pairs(game.connected_players) do
        local frame = this.score_gui_frame[player.index]
        if not (frame and frame.valid) then
            init_score_board(player)
        end
        if frame and frame.valid then
            frame.clear()

            local inner_frame = frame.add {type = 'frame', style = 'inside_shallow_frame', direction = 'vertical'}

            local subheader = inner_frame.add {type = 'frame', style = 'subheader_frame'}
            subheader.style.horizontally_stretchable = true
            subheader.style.vertical_align = 'center'

            subheader.add {type = 'label', style = 'subheader_label', caption = {'', 'Reach ' .. score_to_win .. ' points to win!'
            .. '                   Players online: ' .. #game.connected_players}}

            if not next(subheader.children) then
                subheader.destroy()
            end

            local ranking_table = inner_frame.add { type = 'table', column_count = 6, style = 'bordered_table'}
            ranking_table.style.margin = 4

            for _, caption in pairs({'Rank', 'Town', 'League', 'Research', 'Age', 'Score'}) do
                local label = ranking_table.add { type = 'label', caption = caption}
                label.style.font = 'default-bold'
            end

            local town_total_scores = {}
            for _, town_center in pairs(this.town_centers) do
                if town_center ~= nil then
                    town_total_scores[town_center] = Score.total_score(town_center)

                    if town_total_scores[town_center] >= score_to_win and this.winner == nil then
                        local winner_force = town_center.market.force
                        this.winner = town_center.town_name
                        local town_with_player_names = format_town_with_player_names(town_center)

                        game.print(town_with_player_names .. " has won the game! Their town now has artillery. The server will be reset by an admin soon.", Utils.scenario_color)
                        Team.enable_artillery(winner_force, game.permissions.get_group((winner_force.name)))
                        winner_force.technologies["artillery"].researched = true
                        log("WINNER_STORE=\"" .. town_with_player_names .. "\"")
                    end
                end
            end

            local rank = 1

            for town_center, _ in spairs(
                    town_total_scores,
                    function(t, a, b)
                        return t[b] < t[a]
                    end
            ) do
                local force = town_center.market.force
                local position = ranking_table.add { type = 'label', caption = '#' .. rank}
                if town_center == this.town_centers[player.force.name] then
                    position.style.font = 'default-semibold'
                    position.style.font_color = {r = 1, g = 1}
                end

                local label_extra = ""
                if town_center.marked_afk then
                    label_extra = " (AFK)"
                end
                if town_center.pvp_shield_mgmt.is_abandoned then
                    label_extra = " [color=red](Abandoned)[/color]"
                end

                local label =
                ranking_table.add {
                    type = 'label',
                    caption = town_center.town_name .. ' (' .. #force.connected_players .. '/' .. #force.players .. ')' .. label_extra
                }
                label.style.font = 'default-semibold'
                label.style.font_color = town_center.color
                label.tooltip = "Town rest bonus: " .. TownCenter.format_rest_modifier(town_center.town_rest.current_modifier)
                        .."\n - Mining+Scrap productivity: " .. TownCenter.format_boost_modifier(town_center.town_rest.mining_prod_bonus)

                local league = ranking_table.add { type = 'label', caption = PvPTownShield.get_town_league(town_center)}
                ranking_table.style.column_alignments[3] = 'right'
                league.tooltip = town_center.pvp_shield_mgmt.shield_info

                local res = ranking_table.add { type = 'label', caption = format_score(Score.research_score(town_center))}
                ranking_table.style.column_alignments[4] = 'right'

                res.tooltip = "Research cost: " .. ResearchBalance.format_town_modifier(town_center.research_balance.current_modifier)
                ranking_table.add { type = 'label', caption = string.format('%.1fh', Score.age_h(town_center))}
                ranking_table.style.column_alignments[5] = 'right'

                local total = ranking_table.add { type = 'label', caption = format_score(town_total_scores[town_center])}
                ranking_table.style.column_alignments[6] = 'right'
                total.tooltip = format_score(Score.research_score(town_center)) .. " (Research) + "
                        .. format_score(Score.survival_score(town_center)) .. " (Age)"

                rank = rank + 1
            end

            -- Outlander section
            ranking_table.add { type = 'label', caption = '-'}

            local label =
            ranking_table.add {
                type = 'label',
                caption = 'Outlanders' .. ' (' .. outlander_online .. ')'
            }
            label.style.font_color = {170, 170, 170}
            ranking_table.add { type = 'label', caption = '-'}
            ranking_table.add { type = 'label', caption = '-'}
            ranking_table.add { type = 'label', caption = '-'}
            ranking_table.add { type = 'label', caption = '-'}
        end
    end
end

Event.add(defines.events.on_gui_click, on_gui_click)
Event.on_nth_tick(60, update_score)

return Public
