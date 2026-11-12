class_name BidMath
extends RefCounted
## Вероятностная математика ставок (биномиальное распределение по неизвестным кубикам).
## Распределения — PackedFloat64Array, где [k] = P(ровно k совпадений).


## Шанс, что один неизвестный кубик засчитается за грань face.
## Вне Palifico единицы — джокеры, поэтому для граней 2–6 шанс 2/6.
## М23: прилив (tide_face) — ещё один джокер: для остальных граней шанс 3/6.
static func match_chance(face: int, ones_wild: bool, tide_face := RoundRules.NO_TIDE) -> float:
	if face == PerudoRules.JOKER_FACE:
		return 1.0 / PerudoRules.FACES
	var faces := 1
	if ones_wild:
		faces += 1
	if tide_face != RoundRules.NO_TIDE and tide_face != face:
		faces += 1
	return float(faces) / PerudoRules.FACES


## Биномиальное распределение: n кубиков, у каждого шанс совпасть p.
static func binomial(n: int, p: float) -> PackedFloat64Array:
	var pmf := PackedFloat64Array()
	pmf.resize(n + 1)
	var coef := 1.0
	for k in n + 1:
		pmf[k] = coef * pow(p, k) * pow(1.0 - p, n - k)
		coef = coef * (n - k) / (k + 1)
	return pmf


## Распределение суммы двух независимых величин.
static func convolve(a: PackedFloat64Array, b: PackedFloat64Array) -> PackedFloat64Array:
	var out := PackedFloat64Array()
	out.resize(a.size() + b.size() - 1)
	for i in a.size():
		if a[i] == 0.0:
			continue
		for j in b.size():
			out[i + j] += a[i] * b[j]
	return out


## Смесь: с вероятностью weight — распределение b, иначе — a.
static func mix(a: PackedFloat64Array, b: PackedFloat64Array, weight: float) -> PackedFloat64Array:
	var out := PackedFloat64Array()
	out.resize(maxi(a.size(), b.size()))
	for i in a.size():
		out[i] += a[i] * (1.0 - weight)
	for i in b.size():
		out[i] += b[i] * weight
	return out


## Сдвиг на offset гарантированных совпадений.
static func shift(pmf: PackedFloat64Array, offset: int) -> PackedFloat64Array:
	var out := PackedFloat64Array()
	out.resize(offset)
	out.append_array(pmf)
	return out


static func at_least(pmf: PackedFloat64Array, k: int) -> float:
	if k <= 0:
		return 1.0
	var total := 0.0
	for i in range(k, pmf.size()):
		total += pmf[i]
	return clampf(total, 0.0, 1.0)


static func exactly(pmf: PackedFloat64Array, k: int) -> float:
	if k < 0 or k >= pmf.size():
		return 0.0
	return pmf[k]


static func expected(pmf: PackedFloat64Array) -> float:
	var total := 0.0
	for i in pmf.size():
		total += i * pmf[i]
	return total
