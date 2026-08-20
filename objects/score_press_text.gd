extends Control

# perfect faab00
# great b4cb09
# good 73da41
# ok 6cd695
# miss c6bd9a


func SetTextInfo(text: String):
	$ScoreLevelText.text = "[center]" + text
	
	match text:
		"PERFECT":
			$ScoreLevelText.set("theme_override_colors/default_color", Color("faab00"))
		"GREAT":
			$ScoreLevelText.set("theme_override_colors/default_color", Color("b4cb09"))
		"GOOD":
			$ScoreLevelText.set("theme_override_colors/default_color", Color("73da41"))
		"OK":
			$ScoreLevelText.set("theme_override_colors/default_color", Color("6cd695"))
		_:
			$ScoreLevelText.set("theme_override_colors/default_color", Color("c6bd9a"))
