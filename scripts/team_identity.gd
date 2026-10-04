extends RefCounted
class_name TeamIdentity

# Presentation palette belongs to player identity, independently of faction bonuses.
# Additional slots are reserved for future scenarios; no networking is implied.
const COLORS = [Color("19ddd4"),Color("f34c32"),Color("b967ef"),Color("408bf4"),Color("f1c744"),Color("74ce47"),Color("f478bf"),Color("eee0bc")]

static func color(owner: int) -> Color:
	return COLORS[posmod(owner,COLORS.size())] if owner>=0 else Color("eac557")

static func symbol(owner: int) -> String:
	return "◆" if owner==1 else ("○" if owner==2 else "■")

static func health(ratio: float) -> Color:
	return Color("e84c36") if ratio<0.3 else (Color("edbd49") if ratio<0.65 else Color("79d665"))
