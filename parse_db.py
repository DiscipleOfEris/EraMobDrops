
import re
import sqlite3

con = sqlite3.connect('mobs_drops.db')
cur = con.cursor()

cur.executescript('''
DROP TABLE IF EXISTS mobs;
DROP INDEX IF EXISTS idx_mobs_dropid;
DROP INDEX IF EXISTS idx_mobs_mobiname_zone_drop;
CREATE TABLE mobs (
  mob_id INTEGER,
  mob_name TEXT,
  mob_iname TEXT,
  zone_id INTEGER,
  drop_id INTEGER,
  respawn INTEGER,
  lvl_min INTEGER,
  lvl_max INTEGER,
  PRIMARY KEY (mob_id));
CREATE INDEX idx_mobs_dropsid on mobs(drop_id);
CREATE INDEX idx_mobs_mobiname_zone_drop on mobs(mob_iname, zone_id, drop_id);''')
cur.executescript('''
DROP TABLE IF EXISTS drops;
DROP INDEX IF EXISTS idx_drops_dropid;
DROP INDEX IF EXISTS idx_drops_itemid;
CREATE TABLE drops (
  drop_id INTEGER,
  drop_type INTEGER,
  item_id INTEGER,
  item_rate INTEGER);
CREATE INDEX idx_drops_dropid ON drops(drop_id);
CREATE INDEX idx_drops_itemid ON drops(item_id);''')

con.commit()

def mob_generator():
  count = 0
  with open('sql/mob_groups.sql') as file:
    groups_str = file.read()
  
  with open('sql/mob_spawn_points.sql') as file:
    mobPattern = re.compile('VALUES \((\d+), \'([^,]+)\', \'([^,]*)\', (\d+),')
    for line in file.readlines():
      mobMatch = mobPattern.search(line)
      #print(mobMatch)
      if not mobMatch:
        continue
      
      count += 1
      
      mob_id = mobMatch.group(1)
      alt_name = mobMatch.group(2).replace('_', ' ')
      mob_name = mobMatch.group(3).replace('\\', '')
      mob_iname = re.sub('[\'\"\-\(\)\,\. ]', '', mob_name.lower())
      group_id = mobMatch.group(4)
      
      if len(mob_name) == 0:
        mob_name = alt_name
      
      #print('searching mob_groups for', group_id)
      grpMatch = re.search('VALUES \('+group_id+', \d+, (\d+), (\d+), \d+, (\d+), \d+, \d+, (\d+), (\d+),', groups_str)
      #print(grpMatch)
      
      if not grpMatch:
        continue
      
      zone_id = grpMatch.group(1)
      respawn = grpMatch.group(2)
      drop_id = grpMatch.group(3)
      lvl_min = grpMatch.group(4)
      lvl_max = grpMatch.group(5)
      
      if count % 1000 == 0: print(count, 'mob:', mob_id, mob_name, mob_iname, zone_id, drop_id, respawn, lvl_min, lvl_max)
      
      yield (mob_id, mob_name, mob_iname, zone_id, drop_id, respawn, lvl_min, lvl_max)

cur.executemany('INSERT INTO mobs (mob_id, mob_name, mob_iname, zone_id, drop_id, respawn, lvl_min, lvl_max) VALUES (?, ?, ?, ?, ?, ?, ?, ?)', mob_generator())

con.commit()

def drop_generator():
  count = 0
  with open('sql/mob_droplist.sql') as file:
    dropPattern = re.compile('VALUES \((\d+), (\d+), [^,]+, [^,]+, (\d+), (\d+)\)')
    
    for line in file.readlines():
      dropMatch = dropPattern.search(line)
      if not dropMatch: continue
      
      count += 1
      
      drop_id = dropMatch.group(1)
      drop_type = dropMatch.group(2)
      item_id = dropMatch.group(3)
      item_rate = dropMatch.group(4)
      
      if count % 1000 == 0: print(count, 'drop:', drop_id, drop_type, item_id, item_rate)
      
      yield (drop_id, drop_type, item_id, item_rate)

cur.executemany('INSERT INTO drops (drop_id, drop_type, item_id, item_rate) VALUES (?, ?, ?, ?)', drop_generator())

con.commit()