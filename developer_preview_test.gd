extends SceneTree

const Main = preload("res://main.tscn")
const Sim = preload("res://simulation.gd")
const Market = preload("res://market_view.gd")

var failures := 0

func _initialize() -> void:
	run.call_deferred()

func expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func run() -> void:
	var app := Main.instantiate()
	root.size = Vector2i(1366, 768)
	root.add_child(app)
	await process_frame
	app.sim = Sim.new(Sim.register("Preview CEO", "Preview Co", "Preview", 0, 0, 1, 513))
	app.screen = "Game"
	app.page = "Market"
	app.set_meta(Market.CATALOG_STAGE_META, "categories")
	app.render()
	await process_frame
	var original_state: Dictionary = app.sim.state.duplicate(true)
	for viewport in [Vector2(1920, 1080), Vector2(1366, 768), Vector2(900, 1200), Vector2(768, 1024), Vector2(390, 844), Vector2(375, 667), Vector2(844, 390)]:
		app.size = viewport
		Market.update_responsive_layout(app)
		var grid := app.find_child("ProductCategoryGrid", true, false) as GridContainer
		expect(grid != null and grid.columns == Market._category_columns(viewport.x), "Category layout follows viewport width %s" % viewport)
		expect(app.sim.state == original_state, "Changing responsive preview dimensions does not mutate simulation state at %s" % viewport)
		app.render()
		var header_balance: Label = app.find_child("HeaderBankBalanceValue", true, false)
		expect(header_balance != null and app.find_child("DeveloperModeButton", true, false) != null,
			"Debug header keeps Bank Balance and Developer Mode available at %s" % viewport)
	var inner_width := Market._supplier_card_width(390.0)
	expect(inner_width <= 310.0 and inner_width > 0.0, "Mobile supplier cards fit within the padded 390px content area")
	var shell := FileAccess.get_file_as_string("res://browser/online_business_loader.html")
	var main_source := FileAccess.get_file_as_string("res://main.gd")
	expect(shell.contains("previewPresets = { desktop: [900, 1200], tablet: [768, 1024], mobile: [390, 844] }"), "Preview presets use the approved whole-game logical viewport sizes")
	expect(shell.contains("body.dev-preview #preview-host { inset: var(--dev-toolbar-bottom, 48px) 0 0;") and shell.contains("#dev-toolbar"), "Developer controls stay outside the game canvas and remain available over portrait previews")
	expect(shell.contains("requestLogicalSize(width, height)") and main_source.contains("var requested := Vector2i(width, height)")
		and main_source.contains("get_window().content_scale_size = requested"), "Preview updates Godot's logical viewport size as well as the CSS canvas frame")
	expect(not shell.contains("actualDesktop()") and shell.contains("OBTDevPreview = {")
		and main_source.contains("developer_mode_unlocked = true")
		and main_source.contains("if OS.is_debug_build():") and main_source.contains("obtRunDevCommand"),
		"Release builds retain player-facing device previews while only debug builds expose the automation bridge")
	app.queue_free()
	await process_frame
	print("Developer responsive preview: %d failures" % failures)
	quit(0 if failures == 0 else 1)
