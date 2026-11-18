class_name Seo


static func build_prompt(rules: String, desc: String) -> String:
	return "Write Zazzle SEO for this design.\n\nDesign: %s\n\nMy rules:\n%s\n\nGive me: Title, Description, and Tags (comma separated)." % [desc, rules]
