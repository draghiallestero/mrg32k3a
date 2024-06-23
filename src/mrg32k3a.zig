const std = @import("std");
const reference = @cImport({
    @cInclude("reference.h");
});

pub const MRG32k3a = struct {
    // Held sub-state
    const State = [3]u64;
    // Matrix used to advance sub-state by one or more draws
    const StateMatrix = [9]u64;

    // Algorithm constants
    const m1: u64 = 4294967087;
    const m2: u64 = 4294944443;
    const a12: u64 = 1403580;
    const a13: u64 = 810728;
    const a21: u64 = 527612;
    const a23: u64 = 1370589;

    // Matrix which advances sub-state by one draw
    const a1: StateMatrix = [_]u64{ 0, 1, 0, 0, 0, 1, m1 - a13, a12, 0 };
    const a2: StateMatrix = [_]u64{ 0, 1, 0, 0, 0, 1, m2 - a23, 0, a21 };

    // Current sub-states of the generator
    s1: State,
    s2: State,

    // Return a new random generator. Seed used becomes initial state
    pub fn init(seed: [6]u32) MRG32k3a {
        // Coerce state
        var s1: State = undefined;
        var s2: State = undefined;
        inline for (0..3) |i| {
            s1[i] = seed[i];
            s2[i] = seed[i + 3];
        }
        return MRG32k3a{ .s1 = s1, .s2 = s2 };
    }

    // Return std.Random object
    pub fn random(self: *MRG32k3a) std.Random {
        return std.Random.init(self, MRG32k3a.fill);
    }

    // std.Random API requirement: fill in bytes with random numbers
    pub fn fill(self: *MRG32k3a, buf: []u8) void {
        // Full u32s
        const draw_size = @sizeOf(u32);
        const full_draws_in_buf = buf.len / draw_size;
        var byte: usize = 0;
        for (0..full_draws_in_buf) |_| {
            var draw = self.next();
            inline for (0..draw_size) |_| {
                buf[byte] = @truncate(draw);
                draw >>= 8;
                byte += 1;
            }
        }

        // Partial last u32
        const leftover_bytes = buf.len % draw_size;
        if (leftover_bytes != 0) {
            var draw = self.next();
            for (0..leftover_bytes) |_| {
                buf[byte] = @truncate(draw);
                draw >>= 8;
                byte += 1;
            }
        }
    }

    // Generate a state matrix that is the result of applying the provided state matrix draws times
    pub fn generate_state_matrix(state_matrix: StateMatrix, draws: u64, comptime max_value: u64) StateMatrix {
        // Early exits
        if (draws == 0) {
            return StateMatrix{ 1, 0, 0, 0, 1, 0, 0, 0, 1 };
        }
        if (draws == 1) {
            return state_matrix;
        }
        // Divide and conquer matrix multiplication algorithm
        var recursive_result = generate_state_matrix(state_matrix, draws / 2, max_value);
        recursive_result = multiply_state_matrix_and_state_matrix(recursive_result, recursive_result, max_value);
        if (draws % 2 == 0) {
            return recursive_result;
        }
        return multiply_state_matrix_and_state_matrix(state_matrix, recursive_result, max_value);
    }

    // Advance state using the provided state matrix
    pub fn jump(self: *MRG32k3a, state_matrix_1: StateMatrix, state_matrix_2: StateMatrix) void {
        self.s1 = multiply_state_matrix_and_state(state_matrix_1, self.s1, m1);
        self.s2 = multiply_state_matrix_and_state(state_matrix_2, self.s2, m2);
    }

    // Calculate next draw
    fn next(self: *MRG32k3a) u32 {
        // Implementation notes:
        //
        // The state is made of u64 to speed up calculations. During the
        // calculation of p1, for example, we see that the subtraction can
        // underflow, causing the modulo operation to produce incorrect results.
        // To fix this, add maximum(u64) / 2 (specifically, a multiple of m1
        // close to it). This works because if the subtraction happens to
        // underflow the addition will kick the "negative" number back into the
        // "positive" range.

        // Update first half of state
        const adjustment1 = std.math.maxInt(u64) / 2 / m1 * m1;
        const p1 = (a12 * self.s1[1] + adjustment1 - a13 * self.s1[0]) % m1;
        self.s1[0] = self.s1[1];
        self.s1[1] = self.s1[2];
        self.s1[2] = p1;

        // Update second half of state
        const adjustment2 = std.math.maxInt(u64) / 2 / m2 * m2;
        const p2 = (a21 * self.s2[2] + adjustment2 - a23 * self.s2[0]) % m2;
        self.s2[0] = self.s2[1];
        self.s2[1] = self.s2[2];
        self.s2[2] = p2;

        return @truncate((p1 + m1 - p2) % m1);
    }

    // Multiply two state matrices together
    fn multiply_state_matrix_and_state(lhs: StateMatrix, rhs: State, comptime max_value: u64) State {
        var new_state: State = undefined;
        for (0..3) |i| {
            var sum: u128 = 0;
            for (0..3) |j| {
                sum += lhs[3 * i + j] * rhs[j];
            }
            new_state[i] = @truncate(sum % max_value);
        }
        return new_state;
    }

    // Multiply two state matrices together
    fn multiply_state_matrix_and_state_matrix(lhs: StateMatrix, rhs: StateMatrix, comptime max_value: u64) StateMatrix {
        var new_state_matrix: StateMatrix = undefined;
        for (0..3) |i| {
            for (0..3) |j| {
                var sum: u128 = 0;
                for (0..3) |k| {
                    sum += lhs[3 * i + k] * rhs[3 * k + j];
                }
                new_state_matrix[3 * i + j] = @truncate(sum % max_value);
            }
        }
        return new_state_matrix;
    }
};

test "Compare to reference" {
    // Reference state
    const state: *reference.state = reference.init();

    // Generator
    var generator = MRG32k3a.init([_]u32{12345} ** 6);
    var rand = generator.random();

    // Generate number of draws. Done so that the compiler doesn't try to unroll
    // a gigantic loop given a fixed iteration count
    const bound = 10000000;
    var loop_count_rand = std.rand.DefaultPrng.init(0);
    const n = loop_count_rand.random().intRangeAtMost(u32, bound, bound + 10);

    // Perform draws and compare
    for (0..n) |_| {
        const reference_draw = reference.draw(state);
        const draw = rand.int(u32);
        try std.testing.expect(reference_draw == draw);
    }
}

test "Compare to reference after jump" {
    // Reference state
    const reference_state: *reference.state = reference.init();

    // Generator
    var generator = MRG32k3a.init([_]u32{12345} ** 6);
    var rand = generator.random();

    // Advance reference by arbitrary number of draws
    const jump = 10000000;
    for (0..jump) |_| {
        _ = reference.draw(reference_state);
    }

    // Advance generator by same number of draws
    const state_matrix_1 = MRG32k3a.generate_state_matrix(MRG32k3a.a1, jump, MRG32k3a.m1);
    const state_matrix_2 = MRG32k3a.generate_state_matrix(MRG32k3a.a2, jump, MRG32k3a.m2);
    generator.jump(state_matrix_1, state_matrix_2);

    // Generate number of draws. Done so that the compiler doesn't try to unroll
    // a gigantic loop given a fixed iteration count
    const bound = 10000000;
    var loop_count_rand = std.rand.DefaultPrng.init(0);
    const n = loop_count_rand.random().intRangeAtMost(u32, bound, bound + 10);
    for (0..n) |_| {
        const reference_draw = reference.draw(reference_state);
        const draw = rand.int(u32);
        try std.testing.expect(reference_draw == draw);
    }
}
