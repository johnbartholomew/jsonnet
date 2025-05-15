// Left shifting a value is not allowed to shift into the sign bit of the 64-bit signed integer representation.
local large_value = 4503599627370496;  // 2^52
large_value << 11
