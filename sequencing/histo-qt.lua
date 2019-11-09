-- histo quantizer - draw from learned CV distribution
monitor = false

major = {  0 / 12
	,  2 / 12
	,  4 / 12
	,  5 / 12
	,  7 / 12
	,  9 / 12
	, 11 / 12
        }

bin_depth = 25

function set_scale(scale)
  curr_scale = {}
  for i=1,5 do
    for j=1,#scale do
      curr_scale[(i - 1) * #scale + (j - 1) + 1] = (i - 1) + scale[j]
    end
  end
end

function set_halflife(halflife)
  leak_coeff = math.pow(0.5, (1 / halflife))
end

function quantize(volts, scale)
  local min = 1000
  local min_ix = 1
  for i=1,#scale do
    local d = math.abs(volts - scale[i])
    if d < min then
       min = d
       min_ix = i
    end
  end
  return min, min_ix
end

function flush_histo()
  for i=1,#curr_scale do
    histo[i] = { count = 0
	       , degree = i
               , cdf = i / #curr_scale
               }
  end
end

function sum_clip_bin(count, incr)
  if count < bin_depth then
     count = count + 1
  end
  return count
end

function update_histo(deg)
  for i=1,#histo do
     histo[i].count = leak_coeff * histo[i].count
     if histo[i].degree == deg then
	histo[i].count = sum_clip_bin(histo[i].count, 1)
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
      samples[i] = curr_scale[histo[j].degree]
      if histo[j].cdf >= r then
        break
      end
    end
  end
  return samples
end

input[1].stream = function(v)
  _c.tell('stream', 1, v)
  local err, ix = quantize(v, curr_scale)
  update_histo(ix)
end

input[2].change = function (v)
  update_cdf()
  local samples = draw_samples(4)
  for i=1,3 do
    output[i].volts = samples[i]
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
  set_halflife(60)
  set_scale(major)
  flush_histo()
  update_cdf()

  input[1].mode('stream', 0.1)
  input[2].mode('change', 1, 0.1, 'rising')
  metro[1].time = 1
  metro[1]:start()
  print('loaded')
end
