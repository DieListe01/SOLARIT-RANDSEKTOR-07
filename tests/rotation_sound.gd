extends SceneTree
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
 checks+=1
 if not ok: failures+=1; push_error("ROTATION/SOUND: "+message)
func _initialize() -> void: call_deferred("run")
func capture(name_value: String) -> void:
 await process_frame; await process_frame
 root.get_texture().get_image().save_png("res://test-output/"+name_value+".png")
func run() -> void:
 var game: Control = load("res://scenes/main.tscn").instantiate()
 root.add_child(game); await process_frame
 game.skip_intro(); game.start_game(); game.set_process(false)
 game.catalog_click("power",false)
 var event := InputEventKey.new(); event.keycode=KEY_E; event.pressed=true; Input.parse_input_event(event)
 await process_frame
 event=InputEventKey.new();event.keycode=KEY_E;event.pressed=false;Input.parse_input_event(event)
 check(game.placement_rotation==1 and game.renderer.placement_rotation==1,"Real E key rotates preview")
 game.details_button.pressed.emit()
 check(game.placement_rotation==2,"Visible rotation button works")
 game.rotate_placement(-1); game.rotate_placement(-1)
 check(game.placement_rotation==0,"Reverse rotation returns to zero")
 var sim: Simulation = game.sim
 sim.ai_timer=99999
 var power_id := sim.spawn("power",0,Vector2(14,43)*32,true)
 var before := JSON.stringify(sim.snapshot())
 for bad in [-1,4,1.5,"1"]:
  check(not sim.submit_command({"type":"build","owner_id":0,"kind":"refinery","cell":[14,47],"rotation":bad},0) and JSON.stringify(sim.snapshot())==before,"Invalid rotation rejected atomically")
 check(sim.submit_command({"type":"build","owner_id":0,"kind":"refinery","cell":[14,47],"rotation":1},0),"Rotated construction accepted")
 var refinery: Dictionary = sim.buildings(0,"refinery",false)[0]
 check(sim.footprint(refinery)==[2,3] and refinery.rotation==1,"Rectangular footprint swaps dimensions")
 check(sim.grid.occupancy.has("14,49") and not sim.grid.occupancy.has("16,47"),"Grid occupies rotated cells only")
 var restored := Simulation.new(sim.db)
 check(restored.restore(sim.snapshot())==OK and restored.entities[refinery.id].rotation==1 and restored.footprint(restored.entities[refinery.id])==[2,3],"Save/load preserves orientation and dimensions")
 var legacy := sim.snapshot()
 for e in legacy.entities: e.erase("rotation")
 check(restored.restore(legacy)==OK,"Legacy saves without orientation remain loadable")
 var bad_save := sim.snapshot(); bad_save.entities[0].rotation=8
 check(restored.restore(bad_save)==ERR_INVALID_DATA,"Invalid saved orientation rejected")
 sim.destroy(refinery.id)
 check(not sim.grid.occupancy.has("14,49"),"Demolition releases entire rotated footprint")
 var factory_id := sim.spawn("factory",0,Vector2(18,47)*32,true,true,1)
 var factory: Dictionary = sim.entities[factory_id]
 var exit_value := sim.exit_cell(factory)
 check(sim.grid.center(exit_value).x<factory.pos.x and factory.rally.x<factory.pos.x,"Rotated factory prefers front-side exit and rally")
 for family in CombatEffects.FAMILIES:
  for event_name in ["shot","impact"]:
   var cue_name: String = family.to_lower()+"_"+event_name
   check(game.music.variants[cue_name].size()==3,"Three sound variants: "+cue_name)
 check(game.music.voices.size()==24 and AudioServer.get_bus_effect_count(AudioServer.get_bus_index("SFX"))>0,"Bounded voices and SFX limiter")
 for voice in game.music.voices: voice.stop()
 game.music.cue_cooldowns.clear(); game.music.cue("energy_shot");game.music.cue("ballistic_heavy_shot")
 check(game.music.voices.filter(func(v):return v.playing).size()==2,"Distinct weapon families do not suppress each other")
 check(game.music.samples.has("rotate") and game.music.samples.has("repair"),"Rotation and repair feedback available")
 game.placement="";game.renderer.placement="";game.paused=true
 for e in sim.entities.values():
  if e.building: sim.grid.reserve(e.cell,sim.footprint(e),0,false)
 sim.entities.clear();sim.known=[{},{}]
 for rotation in 4: sim.spawn("refinery",0,Vector2(10+rotation*5,40)*32,true,true,rotation)
 sim.fog[0].fill(1);sim.explored[0].fill(1)
 game.renderer.camera=Vector2(700,1325);game.renderer.zoom=1.95
 game.category="buildings";game.build_hud()
 await capture("rotation_modern")
 game.set_classic(true);await capture("rotation_classic")
 game.music.shutdown();game.queue_free();await process_frame
 print("ROTATION/SOUND: %d checks, %d failures" % [checks,failures])
 quit(1 if failures else 0)
