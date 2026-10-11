extends SceneTree

const SpecialOrdersScript = preload("res://scripts/special_orders.gd")
const ProfileScript = preload("res://scripts/player_profile.gd")
var failures: Array[String] = []
var checks := 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error("SPECIAL ORDERS FAIL: " + message)

func run() -> void:
	var base := Catalog.read_json("res://data/veyra.json")
	var campaign_before := JSON.stringify(base)
	var quick := SpecialOrdersScript.generate(base, 184726, "basis_ausschalten", "forge", "normal")
	check(not quick.is_empty() and int(quick.seed) == 184726, "Quick/custom order generator returns a seeded mission")
	var repeat := SpecialOrdersScript.generate(base, 184726, "basis_ausschalten", "forge", "normal")
	check(JSON.stringify(quick) == JSON.stringify(repeat), "Identical seed produces byte-equivalent mission, modifiers, doctrine and objectives")
	var different := SpecialOrdersScript.generate(base, 184727, "basis_ausschalten", "forge", "normal")
	check(JSON.stringify(quick.mission) != JSON.stringify(different.mission), "Different seed changes generated mission conditions")
	check(quick.optional_objectives.size() == 2 and quick.mission.objectives.filter(func(o): return bool(o.get("optional", false))).size() == 2, "Generated mission has functional optional objectives")
	check(SpecialOrdersScript.MODIFIERS.size() >= 8 and SpecialOrdersScript.DOCTRINES.size() >= 4 and SpecialOrdersScript.OPTIONALS.size() >= 8, "First release catalog meets modifier, doctrine and optional-goal minimums")
	var secure := SpecialOrdersScript.generate(base, 111, "gebiet_sichern", "forge", "normal")
	var zone_sim := Simulation.new(_catalog_from_mission(secure.mission), "forge", "normal")
	var zone_objective: Dictionary = secure.mission.objectives.filter(func(o): return o.get("type", "") == "control_zone")[0]
	zone_sim.spawn("scout", 0, zone_sim.grid.center(Vector2i(zone_objective.cell[0], zone_objective.cell[1])), false)
	zone_sim.update_control_zone_objectives(35.0)
	check(zone_sim.objective_complete(zone_objective), "Area-secure objective requires and recognizes captured-zone progress")
	zone_sim.spawn("scout", 1, zone_sim.grid.center(Vector2i(zone_objective.cell[0], zone_objective.cell[1])), false)
	zone_sim.update_control_zone_objectives(5.0)
	check(not zone_sim.objective_complete(zone_objective), "Enemy presence contests an uncaptured control zone")
	var harvest := SpecialOrdersScript.generate(base, 222, "solarit_foerderung", "forge", "normal")
	var harvest_sim := Simulation.new(_catalog_from_mission(harvest.mission), "forge", "normal")
	harvest_sim.stats.gathered = 3500
	check(harvest_sim.objective_complete(harvest.mission.objectives.filter(func(o): return o.get("id", "") == "harvest_goal")[0]), "Solarit order main objective completes at its specified extraction target")
	var hold := SpecialOrdersScript.generate(base, 333, "stellung_halten", "forge", "normal")
	var hold_sim := Simulation.new(_catalog_from_mission(hold.mission), "forge", "normal")
	hold_sim.time = 720
	check(hold_sim.objective_complete(hold.mission.objectives.filter(func(o): return o.get("id", "") == "hold_position")[0]), "Hold-position objective completes at its stated time")
	for mission_type in SpecialOrdersScript.TYPES:
		var typed_order: Dictionary = SpecialOrdersScript.generate(base, 440 + SpecialOrdersScript.TYPES.find(mission_type), mission_type, "forge", "normal")
		var typed_catalog := _catalog_from_mission(typed_order.mission)
		check(typed_catalog.errors.is_empty(), "%s generated mission passes catalog and objective validation" % SpecialOrdersScript.TYPE_NAMES[mission_type])
	var scoring_sim := Simulation.new(_catalog_from_mission(quick.mission), "forge", "normal")
	scoring_sim.stats.gathered = 4000
	var score := SpecialOrdersScript.score_run(quick, scoring_sim)
	check(int(score.score) > 0 and str(score.medal) in ["BRONZE", "SILBER", "GOLD", "PLATIN"], "Transparent deterministic score and medal thresholds return a valid result")
	var weekly_a := SpecialOrdersScript.weekly_order(base, 1791734400, "forge", "normal")
	var weekly_b := SpecialOrdersScript.weekly_order(base, 1791734400, "forge", "normal")
	check(JSON.stringify(weekly_a) == JSON.stringify(weekly_b), "Same UTC week produces the same official weekly assignment")
	check(SpecialOrdersScript.weekly_order(base, 1791734400, "forge", "normal").seed == SpecialOrdersScript.weekly_order(base, 1791734400 + 3600, "forge", "normal").seed, "Weekly assignment is stable within its week")
	var save_sim := Simulation.new(_catalog_from_mission(secure.mission), "forge", "normal")
	save_sim.control_zone_progress["control_zone"] = 17.5
	var snapshot: Dictionary = JSON.parse_string(JSON.stringify(save_sim.snapshot()))
	var saved_package: Dictionary = JSON.parse_string(JSON.stringify({"mission":secure.mission.id,"special_order_run":secure,"snapshot":snapshot}))
	var restore_db := _catalog_from_mission(secure.mission)
	var restore_sim := Simulation.new(restore_db, "forge", "normal")
	restore_db.mission=saved_package.special_order_run.mission.duplicate(true)
	check(restore_sim.restore(saved_package.snapshot) == OK and is_equal_approx(float(restore_sim.control_zone_progress.get("control_zone", 0.0)), 17.5), "Save/load restores special mission identity and zone progress")
	check(saved_package.mission == secure.mission.id and int(saved_package.special_order_run.seed) == int(secure.seed) and str(saved_package.special_order_run.enemy_doctrine) == str(secure.enemy_doctrine), "Save/load package preserves special-order identity, seed and enemy doctrine")
	check(saved_package.special_order_run.modifier_ids == secure.modifier_ids and saved_package.special_order_run.optional_objectives.size() == secure.optional_objectives.size(), "Save/load package preserves sector modifiers and optional goals")
	check(_canonical(saved_package.special_order_run.mission) == _canonical(secure.mission), "Save/load package preserves the exact generated mission data")
	var profile_path := "user://special_orders_test_profile.json"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(profile_path))
	var profile := SpecialOrdersScript.profile_default()
	var result := {"outcome":"victory", "score":int(score.score), "medal":str(score.medal), "solarite":4000}
	check(SpecialOrdersScript.record_result(profile, weekly_a, result, profile_path), "Special profile result and personal weekly leaderboard persist")
	var reloaded := SpecialOrdersScript.load_profile(profile_path)
	check(int(reloaded.completed) == 1 and int(reloaded.wins) == 1 and reloaded.leaderboards.has("weekly"), "Profile statistics and weekly leaderboard survive reload")
	var campaign_after := Catalog.read_json("res://data/veyra.json")
	check(JSON.stringify(campaign_after) == campaign_before, "Special generation does not mutate the authored campaign")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(profile_path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(profile_path + ".tmp"))
	print("SPECIAL ORDERS: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func _catalog_from_mission(mission: Dictionary) -> Catalog:
	var result := Catalog.new("res://data/veyra.json")
	result.mission = mission.duplicate(true)
	return result

func _canonical(value: Variant) -> Variant:
	if value is Dictionary:
		var keys: Array = value.keys()
		keys.sort_custom(func(a: Variant, b: Variant) -> bool: return str(a) < str(b))
		var pairs: Array = []
		for key in keys: pairs.append([str(key), _canonical(value[key])])
		return pairs
	if value is Array:
		var items: Array = []
		for item in value: items.append(_canonical(item))
		return items
	if value is int or value is float: return float(value)
	return value

func _initialize() -> void:
	call_deferred("run")
