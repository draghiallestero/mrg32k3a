# mrg32k3a
Zig implementation of the MRG32k3a random number generator

Based on paper "Good parameters and implementations for combined multiple
recursive random number generators" by L'Ecuyer. 

Compatible with zig's Random API. Notably, outputs 32 bit integers instead of
doubles between 0 and 1 to comply with the std.Random API.

Functions are provided to jump ahead by any given number of draws with a
complexity of log2(draws). The user has full control over how the period of
~2^191 is divided.
