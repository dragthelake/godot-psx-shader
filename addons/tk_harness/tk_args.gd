class_name TKArgs
extends RefCounted
## Reads --key=value and --flag user arguments, the ones after "--" on the command line.


static func value(key: String, default: String = "") -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--" + key + "="):
			return arg.substr(key.length() + 3)
	return default


static func has(key: String) -> bool:
	for arg in OS.get_cmdline_user_args():
		if arg == "--" + key or arg.begins_with("--" + key + "="):
			return true
	return false
