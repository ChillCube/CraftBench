@icon("res://addons/CraftBench/icon_hammer.png")
extends Node2D
class_name CraftBench

var output_items: Array[Item] = []  ## Stores items you have created, so you could walk away and pick them up later
var active_crafts: Dictionary = {}  ## Maps CraftableItem to remaining craft time
var active_breakdowns: Dictionary = {}  ## Maps CraftableItem to remaining breakdown time

signal item_outputted(item: Item)
signal craft_started(item: CraftableItem, duration: float)
signal craft_completed(item: CraftableItem, results: Array[Item])
signal breakdown_started(item: CraftableItem, duration: float)
signal breakdown_completed(item: CraftableItem, results: Array[Item])
signal output_collected(item: Item)

func _process(delta: float) -> void:
	# Process active crafts
	var completed_crafts: Array = []
	for craft_key in active_crafts.keys():
		active_crafts[craft_key] -= delta
		if active_crafts[craft_key] <= 0:
			completed_crafts.append(craft_key)
	
	# Complete finished crafts
	for craft_key in completed_crafts:
		var craftable = craft_key as CraftableItem
		_complete_craft(craftable)
		active_crafts.erase(craft_key)
	
	# Process active breakdowns
	var completed_breakdowns: Array = []
	for breakdown_key in active_breakdowns.keys():
		active_breakdowns[breakdown_key] -= delta
		if active_breakdowns[breakdown_key] <= 0:
			completed_breakdowns.append(breakdown_key)
	
	# Complete finished breakdowns
	for breakdown_key in completed_breakdowns:
		var craftable = breakdown_key as CraftableItem
		_complete_breakdown(craftable)
		active_breakdowns.erase(breakdown_key)

## Start crafting an item (with timer)
func craft(item: CraftableItem) -> bool:
	# Check if already crafting this exact item
	if active_crafts.has(item):
		return false
	
	# Use crafting_time from the item
	if item.crafting_time > 0:
		active_crafts[item] = item.crafting_time
		craft_started.emit(item, item.crafting_time)
		return true
	else:
		# Craft instantly
		return _complete_craft(item)

## Start breaking down an item (with timer)
func break_down(item: CraftableItem) -> bool:
	if not item.can_be_broken_down:
		return false
	
	# Check if already breaking down this exact item
	if active_breakdowns.has(item):
		return false
	
	# Use crafting_time from the item
	if item.crafting_time > 0:
		active_breakdowns[item] = item.crafting_time
		breakdown_started.emit(item, item.crafting_time)
		return true
	else:
		# Break down instantly
		return _complete_breakdown(item)

## Complete crafting (called when timer finishes or instantly)
func _complete_craft(item: CraftableItem) -> bool:
	var results: Array[Item] = []
	
	# Add the crafted item itself
	var crafted_item = item.duplicate()
	results.append(crafted_item)
	output_items.append(crafted_item)
	item_outputted.emit(crafted_item)
	
	# Add byproducts (from the item's byproducts array)
	for byproduct_item in item.byproducts:
		var byproduct_copy = byproduct_item.duplicate()
		results.append(byproduct_copy)
		output_items.append(byproduct_copy)
		item_outputted.emit(byproduct_copy)
	
	craft_completed.emit(item, results)
	return true

## Complete breakdown (called when timer finishes or instantly)
func _complete_breakdown(item: CraftableItem) -> bool:
	var results: Array[Item] = []
	
	# Get breakdown materials (all materials except blacklisted ones)
	for craft_material in item.materials:
		if not _is_blacklisted(item, craft_material):
			var material_copy = craft_material.duplicate()
			results.append(material_copy)
			output_items.append(material_copy)
			item_outputted.emit(material_copy)
	
	breakdown_completed.emit(item, results)
	return true

## Check if a material is blacklisted
func _is_blacklisted(item: CraftableItem, check_material: Item) -> bool:
	for blacklisted in item.broken_down_loss_blacklist:
		if check_material == blacklisted:
			return true
	return false

## Collect all output items (clears the output storage)
func collect_all_outputs() -> Array[Item]:
	var items = output_items.duplicate()
	output_items.clear()
	for collected_item in items:
		output_collected.emit(collected_item)
	return items

## Collect specific output item
func collect_output(index: int) -> Item:
	if index >= 0 and index < output_items.size():
		var collected_item = output_items[index]
		output_items.remove_at(index)
		output_collected.emit(collected_item)
		return collected_item
	return null

## Check if output items are available
func has_output() -> bool:
	return not output_items.is_empty()

## Get output count
func get_output_count() -> int:
	return output_items.size()

## Check if bench is currently busy
func is_busy() -> bool:
	return not active_crafts.is_empty() or not active_breakdowns.is_empty()

## Check if currently crafting a specific item
func is_crafting(item: CraftableItem) -> bool:
	return active_crafts.has(item)

## Check if currently breaking down a specific item
func is_breaking_down(item: CraftableItem) -> bool:
	return active_breakdowns.has(item)

## Cancel current craft
func cancel_craft(item: CraftableItem) -> bool:
	if active_crafts.has(item):
		active_crafts.erase(item)
		return true
	return false

## Cancel current breakdown
func cancel_breakdown(item: CraftableItem) -> bool:
	if active_breakdowns.has(item):
		active_breakdowns.erase(item)
		return true
	return false

## Get remaining time for current craft
func get_craft_remaining_time(item: CraftableItem) -> float:
	return active_crafts.get(item, -1.0)

## Get remaining time for current breakdown
func get_breakdown_remaining_time(item: CraftableItem) -> float:
	return active_breakdowns.get(item, -1.0)

## Clear all outputs
func clear_outputs() -> void:
	output_items.clear()

## Craft using inventory directly (consumes materials and outputs to bench)
func craft_from_inventory(item: CraftableItem, inventory: Inventory) -> bool:
	if not item.can_craft(inventory):
		return false
	
	# Consume materials
	for craft_material in item.materials:
		inventory.delete_item(craft_material)
	
	# Start crafting
	return craft(item)

## Break down using inventory (removes item from inventory and outputs to bench)
func break_down_from_inventory(item: CraftableItem, inventory: Inventory) -> bool:
	if not item.can_be_broken_down:
		return false
	
	# Check if inventory has the item
	if not inventory.has_item(item):
		return false
	
	# Remove item from inventory
	inventory.delete_item(item)
	
	# Start breakdown
	return break_down(item)
