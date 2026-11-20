extends SceneTree

var failures := 0

func _initialize() -> void:
	var shell := FileAccess.get_file_as_string("res://browser/online_business_loader.html")
	var main_source := FileAccess.get_file_as_string("res://main.gd")
	var presets := FileAccess.get_file_as_string("res://export_presets.cfg")
	expect(not shell.is_empty(), "Custom pre-engine Web loading shell is present")
	expect(presets.contains('html/custom_html_shell="res://browser/online_business_loader.html"'),
		"Web export preset selects the durable custom HTML shell")
	for token in ["$GODOT_URL", "$GODOT_CONFIG", "$GODOT_THREADS_ENABLED", "$GODOT_HEAD_INCLUDE"]:
		expect(shell.contains(token), "Custom shell retains the Godot 4.7.2 export token %s" % token)
	expect(shell.contains("onProgress: setProgress") and shell.contains("async function startGame()")
		and shell.contains("await engine.startGame"), "Loading progress uses Godot's real startGame progress callback")
	expect(shell.contains("Math.min(99, Math.floor(ratio * 100))")
		and shell.find("await engine.startGame") < shell.find("setAttribute('aria-valuenow', '100')"),
		"Progress cannot show 100% until Godot initialization resolves")
	expect(shell.contains("Initializing engine…") and shell.contains("Preparing your business world…")
		and shell.contains("Finalizing game assets…") and shell.contains("Ready to play."),
		"Loading statuses cover initialization, asset preparation, finalization, and readiness")
	expect(shell.contains('id="error-panel"') and shell.contains('id="retry-button"')
		and shell.contains("window.location.reload()"), "A startup failure exposes a working Retry action")
	expect(shell.contains('id="game-preview-frame"') and not shell.contains('id="dev-launcher"')
		and shell.contains('id="dev-toolbar"'), "Debug preview toolbar stays outside the interactive game canvas and is launched by the Godot debug UI")
	for preset in ["desktop: [900, 1200]", "tablet: [768, 1024]", "mobile: [390, 844]"]:
		expect(shell.contains(preset), "Developer preview includes the approved portrait preset %s" % preset)
	expect(not shell.contains("actualDesktop()") and shell.contains("OBTDevPreview = {")
		and shell.contains("select(name)") and main_source.contains("window.OBTDevPreview && window.OBTDevPreview.enable();"),
		"Developer preview supports touch and mouse and is enabled only after Developer Mode is unlocked")
	expect(shell.contains("previewFrame.style.width = width + 'px'")
		and shell.contains("previewFrame.style.height = height + 'px'")
		and shell.contains("previewFrame.style.transform = 'scale(' + scale + ')'")
		and shell.contains("window.dispatchEvent(new Event('resize'))"), "Responsive preview resizes the real canvas frame and notifies Godot")
	expect(shell.contains("body.dev-preview #preview-host { inset: var(--dev-toolbar-bottom, 48px) 0 0;")
		and shell.contains("devToolbar.classList.remove('is-visible')") and shell.contains("devToolbar.hidden = true"), "Preview keeps its external toolbar accessible and restores the normal game view on exit")
	expect(shell.contains("UR TRADE NETWORK</p>") and shell.contains("PRESENTS</p>")
		and shell.contains("<span>ONLINE</span><span>BUSINESS</span><span>TYCOON</span>")
		and shell.contains("A Game by <strong>UphyRaop</strong>"),
		"Approved company, presents, game title, and creator lines appear in the shell")
	expect(shell.contains("@media (prefers-reduced-motion: reduce)")
		and shell.contains("env(safe-area-inset-top)") and shell.contains("max-width: 380px"),
		"Shell respects reduced-motion and small/mobile safe-area layouts")
	expect(not shell.contains('id="status-splash"') and not shell.contains('id="status-notice"'),
		"Default Godot splash/notice markup is replaced rather than displayed underneath")
	print("Custom Web loader shell: %d failures" % failures)
	quit(0 if failures == 0 else 1)

func expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
