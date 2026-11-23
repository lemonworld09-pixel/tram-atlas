@tool
extends RefCounted
## An immutable index for the two large GTFS tables. Keep compressed-feed members
## as UTF-8 bytes and decode only a small block when a trip or shape is requested.

const BLOCK_SIZE := 512 * 1024
const FIELD := '(?:"(?:[^"\r\n]|"")*"|[^,"\r\n]*)'
var header: PackedStringArray
var error := ""
var _bytes: PackedByteArray
var _blocks := PackedInt64Array()
var _groups := {}
var _cached_block := -1
var _cached_text := ""


static func fields(line: String) -> PackedStringArray:
	if not line.contains('"'):
		return line.split(",")
	var result := PackedStringArray()
	var pos := 0
	while pos <= line.length():
		if pos < line.length() and line[pos] == '"':
			var start := pos + 1
			var end := line.find('"', start)
			while end >= 0 and end + 1 < line.length() and line[end + 1] == '"':
				end = line.find('"', end + 2)
			if end < 0:
				return PackedStringArray()
			result.append(line.substr(start, end - start).replace('""', '"'))
			pos = end + 1
			if pos < line.length() and line[pos] != ",":
				return PackedStringArray()
			else:
				pos += 1
		else:
			var comma := line.find(",", pos)
			if comma < 0:
				result.append(line.substr(pos))
				break
			result.append(line.substr(pos, comma - pos))
			pos = comma + 1
	return result


func build(bytes: PackedByteArray, key: String, required: Array) -> bool:
	_bytes = bytes
	var newline := _bytes.find(10)
	if newline < 0:
		error = "Missing header or data rows."
		return false
	header = fields(_bytes.slice(0, newline).get_string_from_utf8().trim_prefix("\uFEFF").trim_suffix("\r"))
	for column in required:
		if not header.has(column):
			error = "Missing column '%s'." % column
			return false
	# GTFS field values cannot contain line breaks. Match an entire consecutive
	# run in native PCRE, indexing unordered/noncontiguous runs separately.
	var prefix := "(?:%s,){%d}" % [FIELD, header.find(key)]
	var pattern := RegEx.new()
	if pattern.compile("(?m)^%s(%s)(?=,|\\r?$)[^\\r\\n]*(?:\\r?\\n%s\\1(?=,|\\r?$)[^\\r\\n]*)*+" % [prefix, FIELD, prefix]) != OK:
		error = "Could not initialize the CSV index."
		return false
	var start := newline + 1
	while start < _bytes.size():
		var end := _bytes.find(10, start + BLOCK_SIZE) if start + BLOCK_SIZE < _bytes.size() else -1
		end = _bytes.size() if end == -1 else end + 1
		var text := _bytes.slice(start, end).get_string_from_utf8()
		var block_number := _blocks.size()
		_blocks.append(start)
		for run in pattern.search_all(text):
			var id := run.get_string(1)
			if id.begins_with('"'):
				id = id.substr(1, id.length() - 2).replace('""', '"')
			if id.is_empty():
				continue
			if not _groups.has(id):
				_groups[id] = PackedInt32Array()
			_groups[id].append_array(PackedInt32Array([block_number, run.get_start(), run.get_end()]))
		start = end
	_blocks.append(_bytes.size())
	return true


func rows(id: String) -> Array[PackedStringArray]:
	var result: Array[PackedStringArray] = []
	var runs: PackedInt32Array = _groups.get(id, PackedInt32Array())
	for i in range(0, runs.size(), 3):
		var block := runs[i]
		if block != _cached_block:
			_cached_block = block
			_cached_text = _bytes.slice(_blocks[block], _blocks[block + 1]).get_string_from_utf8()
		for line in _cached_text.substr(runs[i + 1], runs[i + 2] - runs[i + 1]).split("\n", false):
			result.append(fields(line.trim_suffix("\r")))
	return result
