function roots_of_unity(n)
  local roots = {}
  for i=1,n do
    local angle = i * 2 * math.pi / n
    table.insert(roots, {math.cos(angle), math.sin(angle)})
  end
  return roots
end

function sq_distance(r1, r2)
  dx = r1[1] - r2[1]
  dy = r1[2] - r2[2]
  return dx*dx + dy*dy
end

function set_volume(ch, pitch, src_locs, observer_loc)
  r_sq = sq_distance(src_locs[ch], observer_loc)
  if r_sq < 0.05 then
    v = 1
  else
     v = 1 / (4 * math.pi * r_sq)
  end
  ii.wsyn.play_voice(ch, pitch, 5 * v)
end

observer_pos = {0, 0}
input[1].stream = function(v)
  if (v > 5) then
    v = 5
  end
  observer_pos[1] = v / 5
  _c.tell('stream', 1, v)
end
input[2].stream = function(v)
  if (v > 5) then
    v = 5
  end
  observer_pos[2] = v / 5
  _c.tell('stream', 2, v)
end

positions = roots_of_unity(7)
degrees = {0, 1, 2, 3, 4, 5, 6}
scale = {0, 2 / 12, 4 / 12, 5 / 12, 7 / 12, 9 / 12, 11 / 12}

function update_degrees(n)
  for i=1,#positions do
    if n % i == 0 then
      if i % 2 == 0 then
	degrees[i] = (degrees[i] + 1) % #scale
      else
	degrees[i] = (degrees[i] - 1) % #scale
      end
    end
  end
end

function set_volumes()
  for i=1,#positions do
    set_volume(i, scale[degrees[i] + 1], positions, observer_pos)
  end
end

function update_ratios()
  for i=1,#positions do
    ii.wsyn.fm_ratio(7, i)
  end
end

function init()
  update_ratios()
  input[1].mode = 'stream'
  input[2].mode = 'stream'
  volume_metro = metro.init { event = set_volumes
			    , time = 0.01
			    , count = -1
                            }
  pitch_metro = metro.init { event = update_degrees
                           , time = 0.25
                           , count = -1
                           }
  volume_metro:start()
  pitch_metro:start()
  print('ok')
end
