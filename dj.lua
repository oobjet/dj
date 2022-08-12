-- dj_norns
-- K2 : sustain tape fx
-- K3 : sustainfxFX
-- E1 : adjust tempo
-- E2 : select tape fx
-- E3 : select fx
-- sync on input midi clock

local Passthrough = include("lib/midisync")


tape_fx = {"backward", "stutter", "stop", "sequence", "double", "timemachine"}
fx = {"filter_down", "filter_up", "delay", "reverb", "compressor"}
tape_fx_sel = 1
tape_fx_on = 0
fx_sel = 1
fx_on = 0
tempo = 130
loop_length = 1/tempo*60*16
step = 1
timemachine_empty = 1

-- io.write(params:get("clock_tempo") .. "\n")
-- io.write(params:get("clock_midi_out") .. "\n")
-- params:set("clock_tempo", load_bpm)
-- params:set("clock_midi_out", load_clock)

function init ()
  -- add midi clock sync to parameters
  Passthrough.init()
    -- softcut init
    -- send audio input to softcut input
	audio.level_adc_cut(1)
    softcut.buffer_clear()
    audio.level_cut(1)
    audio.level_adc_cut(1)
    audio.level_eng_cut(1)
    softcut.level_slew_time(1,0.1)
	softcut.enable(1,1)
	softcut.buffer(1,1) -- each voice uses buffer 1
	softcut.level(1,0.4)
	softcut.loop(1,1)
	softcut.rate(1,1)
	softcut.loop_start(1,0)
  softcut.loop_end(1,loop_length)
	softcut.position(1,0)
	softcut.play(1,0)
	softcut.rec(1,0)
	  -- set input rec level: input channel, voice, level
	  softcut.level_input_cut(1,1,1.0)
	  softcut.level_input_cut(2,1,1.0)
	  -- set voice 1 record level
	  softcut.rec_level(1,1.0)
	  -- set voice 1 pre level
	  softcut.pre_level(1,0)
	  -- slewtime
	  softcut.level_slew_time (1, 0.0001)
	  softcut.recpre_slew_time (1, 0.0001)
	  softcut.rate_slew_time(1,0.1)
	  softcut.fade_time(1, 0.001)
	  softcut.filter_dry(1, 1)
	  softcut.pan(1, 0)
	
    -- start recording in buffer
    idle ()
    redraw()
    
    -- poll
end

function update_pos()
  -- get playhead position
end

function clock.transport.start()
  print("we begin")
  id = clock.run(pulse)
end

function clock.transport.stop()
  clock.cancel(id)
end

function idle ()
    -- record input into a buffer constantly
  softcut.rate_slew_time(1,0.1)
  softcut.rate(1,1)
	softcut.rec(1,1)
  softcut.play(1,0)
  softcut.loop_start(1,0)
  softcut.loop_end(1,clock.get_beat_sec()*16)
  print (clock.get_beat_sec()*16)
    -- input -> output
  audio.level_monitor (1)
  -- turn off fx
  audio.rev_off ()
  audio.comp_off()
  -- turn filter off
  softcut.post_filter_lp (1, 0)
    -- buffer muted
  print ("recording")
end

function backward ()
    -- reverse the speed of buffer
    softcut.rate(1,-1)
    -- play buffer
    softcut.play(1,1)
    softcut.rec(1,0)
    -- buffer -> output
    -- input muted
    audio.level_monitor (0)
    print ("backward")
end

function stutter ()
    -- play the latest beats of the loop
    softcut.play(1,1)
    softcut.rec(1,0)
    softcut.loop_start(1,0)
    softcut.loop_end(1,clock.get_beat_sec()/4)
    -- input muted
    audio.level_monitor (0)
    print("stutter")
end

function stop ()
    -- slow down the loop
    softcut.play(1,1)
    softcut.rec(1,0)
    softcut.rate_slew_time(1,clock.get_beat_sec()*4)
    softcut.rate(1,0)
    -- input muted
    audio.level_monitor (0)
    print("stop")
    
end

function seq()
  step = 0
  while tape_fx_on==1 do
  -- input muted
    audio.level_monitor (0)
    step=step+1
    clock.sync(1/4)
    softcut.play(1,0)
    softcut.position (1,clock.get_beat_sec()/4*(16-step%16))
    softcut.play(1,1)
  end 
  softcut.play(1,0)
end

function sequence ()
    -- play the loop
    softcut.play(1,1)
    softcut.rec(1,0)
    -- input muted
    audio.level_monitor (0)
    --play a sequence
    clock.run(seq)
    -- input not muted
end

function double ()
    -- move starting point
    softcut.position(1, clock.get_beat_sec()*2)
    -- play buffer
    softcut.play(1,1)
    softcut.rec(1,0)
    -- input muted
    -- audio.level_monitor (0)
end

function timemachine()
  -- record a loop and play it later !
  if timemachine_empty == 1 then
    softcut.buffer_write_mono ("timemachinerec.aif", 0, clock.get_beat_sec()*4, 1)
    timemachine_empty = 0
  else
    softcut.buffer_read_mono ("timemachinerec.aif", 0, 0, clock.get_beat_sec()*4, 1, 1)
    teimemachine_empty = 1
    -- play buffer
    softcut.play(1,1)
    softcut.rec(1,0)
    -- buffer -> output
    -- input muted
    audio.level_monitor (0)
  end
    print ("timemeachine")
end


function filter_down ()
    -- lower the filter frequency
    softcut.post_filter_lp (1, 1)
end

function fliter_up ()
    -- raise the filter frequency
end

function delay ()
    -- send input + tape_fx to delay
end

function reverb ()
    -- send input + tape_fx to reverb
    audio.rev_on ()
    print ('reverb')
end

function compressor ()
    -- send input + tape_fx to reverb
    audio.comp_on ()
    print ('compressor')
end

function key(n,z)
    if n == 2 then
        tape_fx_on = z
        if tape_fx_on == 1 then 
          -- enter tape_fx
          _G[tape_fx[tape_fx_sel]]()
        else
        -- quit tape_fx
        idle()
      end
    end
    if n == 3 then
        fx_on = z
        if fx_on == 1 then 
          -- enter fx
          _G[fx[fx_sel]]()
        elseif tape_fx_on == 0 then
        -- quit fx
        idle()
      end
    end
end

function enc(n,d)
    if n == 2 then
        if tape_fx_on == 0 then
            -- change selected tape_fx
            tape_fx_sel = util.clamp(tape_fx_sel+d,1,#tape_fx)
            redraw()
        end
        if tape_fx_on == 1 then
            -- change parameter of tape_fx
        end
    end
    if n == 3 then
        if fx_on == 0 then
            -- change selected fx
            fx_sel = util.clamp(fx_sel+d,1,#fx)
            redraw()
        end
        if fx_on == 1 then
            -- change parameter of fx
        end
    end
end

function redraw()
    screen.clear()
    screen.aa(0)
    screen.line_width(1)
    -- show selected tape_fx
    for i = 1,#tape_fx do
        if i == tape_fx_sel then screen.level(15) else screen.level (5) end
        screen.move(10, 10+i*40/#tape_fx)
        screen.text(tape_fx[i])
    end
    -- show selected fx
     for i = 1,#fx do
        if i == fx_sel then screen.level(15) else screen.level (5) end
        screen.move(80, 10+i*40/#fx)
        screen.text(fx[i])
    end   
    -- show tempo
    screen.level(5)
    screen.move(100,10)
    screen.text(math.floor(clock.get_tempo()))
    screen.update()
end