_addon.name = 'EraMobDrops'
_addon.author = 'DiscipleOfEris'
_addon.version = '1.0.0'
_addon.commands = {'eramobdrops', 'emd'}

config = require('config')
texts = require('texts')
require('tables')
res = require('resources')
require('sqlite3')

defaults = {}
defaults.header = "${name} (Lv.${lvl_min}-${lvl_max}, Respawn: ${respawn}s)"
defaults.noDrops = "No Drops"
defaults.display = {}
defaults.display.pos = {}
defaults.display.pos.x = 0
defaults.display.pos.y = 0
defaults.display.bg = {}
defaults.display.bg.red = 0
defaults.display.bg.green = 0
defaults.display.bg.blue = 0
defaults.display.bg.alpha = 102
defaults.display.text = {}
defaults.display.text.font = 'Consolas'
defaults.display.text.red = 255
defaults.display.text.green = 255
defaults.display.text.blue = 255
defaults.display.text.alpha = 255
defaults.display.text.size = 12

settings = config.load(defaults)

box = texts.new("", settings.display, settings)

zones = res.zones
items = res.items

local mobKeys = {'mob_id', 'name', 'zone_id', 'drop_id', 'respawn', 'lvl_min', 'lvl_max'}
local dropKeys = {'drop_id', 'drop_type', 'item_id', 'item_rate'}

DROP_TYPE = { NORMAL=0x0, GROUPED=0x1, STEAL=0x2, DESPOIL=0x4 }

windower.register_event('load',function()
  db = sqlite3.open(windower.addon_path..'/mobs_drops.db', sqlite3.OPEN_READONLY)
  
  if not windower.ffxi.get_info().logged_in then return end
  
  local target = windower.ffxi.get_mob_by_target('st') or windower.ffxi.get_mob_by_target('t') or windower.ffxi.get_player()
  info = getTargetInfo(target)
  updateInfo(info)
end)

windower.register_event('unload', function()
  db:close()
end)

windower.register_event('target change', function(index)
  local player = windower.ffxi.get_player()
  local target = windower.ffxi.get_mob_by_target('st') or windower.ffxi.get_mob_by_target('t') or player
  
  info = getTargetInfo(target)
  updateInfo(info)
end)

function getTargetInfo(target)
  local info = {}

  if target.spawn_type == 16 then
    local zone_id = windower.ffxi.get_info().zone
    local mob, drops = getMobInfo(target, zone_id)
    
    info.type = 'mob'
    info.mob = mob
    info.drops = drops
  end
  
  return info
end

function getMobInfo(target, zone_id)
  if not db:isopen() then return end
  
  local mob = false
  local drops = {}
  
  local idQuery = 'SELECT * FROM mobs WHERE mob_id='..target.id..''
  for mobRow in db:rows(idQuery) do
    mob = kvZip(mobKeys, mobRow)
    drops = dbGetDrops(mob.drop_id)
  end
  
  return mob, drops
end

function updateInfo(info)
  if info.type ~= 'mob' then
    box:text('')
    box:visible(false)
    return
  end
  
  local steal = ''
  local lines = {}
  local drops = info and info.drops or {}
  for _, drop in pairs(drops) do
    if not (testflag(drop.drop_type, DROP_TYPE.STEAL) or testflag(drop.drop_type, DROP_TYPE.DESPOIL)) then
      table.insert(lines, items[drop.item_id].en..': '..(drop.item_rate/10)..'%')
    elseif testflag(drop.drop_type, DROP_TYPE.STEAL) then
      steal = steal..'Steal: '..items[drop.item_id].en..'\n'
    end
  end
  
  local header = ""
  if #settings.header > 0 then header = settings.header..'\n' end
  
  if #steal > 0 or #lines > 0 then
    box:text(header..steal..table.concat(lines, '\n'))
  else
    box:text(header..settings.noDrops)
  end
  
  box:update(info.mob)
  box:visible(true)
end

function dbGetDrops(drop_id)
  local query = 'SELECT * FROM drops WHERE drop_id='..drop_id
  drops = {}
  for row in db:rows(query) do
    table.insert(drops, kvZip(dropKeys, row))
  end
  
  return drops
end

function values(t, keys)
  list = {}
  
  if type(keys) == 'table' then
    for i=1, #keys do
      table.insert(list, t[keys[i]])
    end
  else
    for k, v in pairs(t) do
      table.insert(list, v)
    end
  end
  
  return list
end

function testflag(set, flag)
  return set % (2*flag) >= flag
end

-- Return an associative array that takes two lists and uses the first for its keys and the second for its values.
function kvZip(keys, values)
  len = math.min(#keys, #values)
  t = {}
  
  for i=1, len do
    t[keys[i]] = values[i]
  end
  
  return t
end