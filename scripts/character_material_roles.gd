extends RefCounted

const PRIMARY_TEAM_ROLE := &"TeamPrimary"
const SECONDARY_TEAM_ROLE := &"TeamSecondary"
const PRIMARY_TEAM_SEED_MATERIAL := &"Team primary seed"
const SECONDARY_TEAM_SEED_MATERIAL := &"Team secondary seed"


static func apply(root: Node, primary_material: Material, secondary_material: Material) -> bool:
	var applied_primary := false
	var applied_secondary := false
	for child in root.find_children("*", "MeshInstance3D", true, false):
		var mesh := child as MeshInstance3D
		if mesh.name == PRIMARY_TEAM_ROLE:
			mesh.material_override = primary_material
			applied_primary = true
		elif mesh.name == SECONDARY_TEAM_ROLE:
			mesh.material_override = secondary_material
			applied_secondary = true
	return applied_primary and applied_secondary
