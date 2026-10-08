class_name TKPcg32
extends RefCounted
## One PCG32 (XSH RR) stream, seeded from a global seed and a stream name.
##
## The algorithm is written out in full so Godot and Unreal give the same numbers:
##   x = seed xor fnv1a64(utf8(name))
##   initstate, initseq = the next two splitmix64 outputs from x
##   state = 0, inc = initseq << 1 | 1, step, state += initstate, step
## assets/source/fixtures/rng_pcg32.py is the reference; its output is the test fixture.
## GDScript ints are signed 64-bit and wrap on overflow, so the arithmetic is mod 2^64,
## with _lsr standing in for an unsigned shift.

const _MUL := 6364136223846793005
const _FNV_OFFSET := -3750763034362895579 # 0xcbf29ce484222325
const _FNV_PRIME := 1099511628211
const _GOLDEN := -7046029254386353131 # 0x9e3779b97f4a7c15
const _MIX1 := -4658895280553007687 # 0xbf58476d1ce4e5b9
const _MIX2 := -7723592293110705685 # 0x94d049bb133111eb
const _U32 := 0xFFFFFFFF

var _state := 0
var _inc := 0


func _init(seed: int = 1, stream_name: String = "default") -> void:
	var x := seed ^ fnv1a64(stream_name)
	x = x + _GOLDEN
	var init_state := _mix(x)
	x = x + _GOLDEN
	var init_seq := _mix(x)
	_state = 0
	_inc = (init_seq << 1) | 1
	next_u32()
	_state += init_state
	next_u32()


## Next 32-bit value, 0 to 4294967295.
func next_u32() -> int:
	var old := _state
	_state = old * _MUL + _inc
	var xorshifted := _lsr(_lsr(old, 18) ^ old, 27) & _U32
	var rot := _lsr(old, 59)
	return ((xorshifted >> rot) | (xorshifted << ((32 - rot) & 31))) & _U32


## Float in [0, 1).
func next_float() -> float:
	return float(next_u32()) / 4294967296.0


## Integer in [from, to], inclusive, without modulo bias.
func next_range(from: int, to: int) -> int:
	assert(to >= from, "next_range: to < from")
	var span := to - from + 1
	if span > _U32:
		return from + (((next_u32() << 32) | next_u32()) & 0x7FFFFFFFFFFFFFFF) % span
	var threshold := (0x100000000 - span) % span
	while true:
		var r := next_u32()
		if r >= threshold:
			return from + r % span
	return from


## Float in [from, to).
func next_float_range(from: float, to: float) -> float:
	return from + (to - from) * next_float()


static func fnv1a64(text: String) -> int:
	var h := _FNV_OFFSET
	for b in text.to_utf8_buffer():
		h = (h ^ b) * _FNV_PRIME
	return h


static func _mix(x: int) -> int:
	var z := x
	z = (z ^ _lsr(z, 30)) * _MIX1
	z = (z ^ _lsr(z, 27)) * _MIX2
	return z ^ _lsr(z, 31)


## Logical shift right for a 64-bit pattern held in a signed int.
static func _lsr(x: int, n: int) -> int:
	if n == 0:
		return x
	return (x >> n) & (0x7FFFFFFFFFFFFFFF >> (n - 1))
