extends Node2D

var font := SystemFont.new()

func _draw() -> void:
	font.font_names = PackedStringArray(["Consolas", "DejaVu Sans Mono", "monospace"])
	font.font_weight = 600
	font.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	for i in range(96):
		draw_string(font, Vector2((i % 16) * 20 + 2, (i / 16) * 32 + 25), String.chr(i + 32), HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color.WHITE)
