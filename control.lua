require 'utils.data_stages'
_LIFECYCLE = _STAGE.control -- Control stage
_DEBUG = false
_DUMP_ENV = false

require 'zk-lib/lualibs/control_stage/GuiTemplater'
require 'modules.anti_blueprint_spam'
require 'utils.server'
require 'utils.server_commands'
require 'utils.command_handler'
require 'utils.utils'
require 'utils.pause_game'
require 'utils.table'
require 'utils.chatbot'
require 'utils.commands'
require 'utils.debug.command'
require 'modules.corpse_markers'
require 'modules.floaty_chat'
require 'modules.inserter_drops_pickup'
require 'modules.autostash'
require 'modules.blueprint_requesting'
require 'modules.charging_station'
require 'modules.limited_crafting_queue'

require 'utils.gui'
require 'utils.gui.player_list'
require 'utils.gui.admin'
require 'utils.gui.group'
require 'utils.gui.score'
require 'utils.gui.config'
require 'utils.gui.poll'

require 'maps.wasteland.main'

if _DUMP_ENV then
    require 'utils.dump_env'
    require 'utils.profiler'
end

local function on_player_created(event)
    local player = game.players[event.player_index]
    player.gui.top.style = 'slot_table_spacing_horizontal_flow'
    player.gui.left.style = 'slot_table_spacing_vertical_flow'
end

local loaded = _G.package.loaded
function require(path)
    return loaded[path] or error('Can only require files at runtime that have been required in the control stage.', 2)
end


local Event = require 'utils.event'
Event.add(defines.events.on_player_created, on_player_created)
