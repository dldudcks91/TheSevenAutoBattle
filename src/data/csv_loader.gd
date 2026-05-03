class_name CsvLoader

# Returns Array[Dictionary] — header keys -> cell strings.
# Lines starting with '#' and blank lines are skipped.
static func load_table(path: String) -> Array:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("CsvLoader: cannot open " + path)
		return []
	var headers: PackedStringArray = []
	var rows: Array = []
	var first := true
	while not f.eof_reached():
		var line := f.get_line()
		if line.strip_edges() == "" or line.begins_with("#"):
			continue
		# NOTE: replace with f.get_csv_line() if any cell value ever contains commas.
		var cells: PackedStringArray = line.split(",")
		if first:
			headers = cells
			first = false
			continue
		var row: Dictionary = {}
		for i in headers.size():
			row[headers[i]] = cells[i] if i < cells.size() else ""
		rows.append(row)
	return rows
