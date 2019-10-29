-- histo quantizer - draw from learned CV distribution
decay = 0.98
monitor = false

major = {0, 2, 4, 5, 7, 9, 11, 12 }
curr_scale = major

function quantize(volts, scale)
  local octave = math.floor(volts)
  local interval = volts - octave
  local semitones = interval * #scale
  local degree = 1
  while degree < #scale and semitones > scale[degree+1]  do
    degree = degree + 1
  end
  local above = scale[degree+1] - semitones
  local below = semitones - scale[degree]
  if below > above then
    degree = degree + 1
  end
  return octave, degree
end

function flush_histo()
  for i=1,5*#curr_scale do
    histo[i] = { count = 0
	       , degree = i
               , cdf = i / #curr_scale
               }
  end
end

function update_histo(deg)
  for i=1,#histo do
     if histo[i].degree == deg then
	local incr = 1
	if histo[i].count > 25 then
	  incr = math.exp(25 - histo[i].count)
	end
	histo[i].count = histo[i].count + incr
     else
	histo[i].count = histo[i].count * decay
     end
  end
end

function update_cdf()
  table.sort(histo, function(a,b) return a.count < b.count end)

  local sum = 0
  for i=1,#histo do
    histo[i].cdf = sum
    sum = sum + histo[i].count
  end
  if sum == 0 then sum = 1 end
  for i=1,#histo do
    histo[i].cdf = histo[i].cdf / sum
  end
end

function draw_samples(count)
  local samples = {}
  for i=1,count do
    local r = math.random()
    local j = 1
    for j=1,#histo do
      local d = histo[j].degree % #curr_scale
      local o = math.floor(histo[j].degree / #curr_scale)
      samples[i] = o*#curr_scale + curr_scale[d + 1]
      if histo[j].cdf >= r then
        break
      end
    end
  end
  return samples
end

input[1].stream = function(v)
  _c.tell('stream', 1, v)
  local oct, deg = quantize(v, curr_scale)
  if oct < 0 then
     oct = 0
  elseif oct > 4 then
     oct = 4
  end
  update_histo(oct*#curr_scale + deg)
end

function select_notes(samples)
  notes = {}
  for i=1,#samples do
    notes[i] = samples[i]
  end
  return notes
end

input[2].change = function (v)
  update_cdf()
  local samples = draw_samples(4)
  local notes = select_notes(samples)
  for i=1,3 do
    output[i].volts = notes[i] / 12
  end
end

metro[1].event = function()
  if monitor then
     print(#histo .. ' bins')
     print('==============')
     table.sort(histo, function(a,b) return a.degree < b.degree end)
     for i=1,#histo do
	local s = '|'
	local count = math.floor(histo[i].count)
	for j=1,count do
	   s = s .. '#'
	end
	print(s)
     end
     print('==============')
  end
end

function init()
  histo = {}
  flush_histo()
  update_cdf()
  for i=1,4 do
    output[i].slew = 0.05
  end
  input[1].mode('stream', 0.1)
  input[2].mode('change', 1, 0.1, 'rising')
  metro[1].time = 3
  metro[1]:start()
  output[4].action = lfo(1, 1)
  output[4]()
  print('loaded')
end
