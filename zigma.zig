// $ zigma -h
//
// zigma verion 0.0.1 - hierarchical expression calculator
// parse text expression lines and use hierarchy to compute subtotals
//
// usage: zigma [-s | -p | -n | -f | -d] [file] [expression]
//
// --scan     -s    tokenize and print tokens
// --parse    -p    parse and print output
// --no-lines -n    don't produce output lines
// --filter   -f    filter with children
// --find     -d    filter without childred
// --no-color -b    output without colors
// --no-total -t    don't show file total

const std = @import("std");
const builtin = @import("builtin");
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const VER = @import("version.zig").version;

const Token = struct { start: u16, end: u16, value: ?f64 };

const ScanError = error{UnexpectedCharacter};

fn isAlpha(c: u8) bool {
    return (c >= 'a' and c <= 'z') or (c >= 'A' and c <= 'Z') or (c == '_');
}

fn isNum(c: u8) bool {
    return c >= '0' and c <= '9';
}

fn isSpace(c: u8) bool {
    return c == ' ' or c == '\n' or c == '\r';
}

fn isPunctuator(c: u8) bool {
    return c == ':' or c == '=';
}

// scan a line of source into tokens
// assumes source already broken down into lines and we scan one
// line at a time
fn scan(source: []const u8, allocator: std.mem.Allocator) !std.ArrayList(Token) {
    var tokens: std.ArrayList(Token) = std.ArrayList(Token).init(allocator);
    // empty line
    if (source.len == 0) {
        return tokens;
    }

    // scan the line
    var i: u16 = 0;

    while (i < source.len) : (i += 1) {
        var c: u8 = source[i];

        // skip spaces
        if (isSpace(c)) {
            continue;
        }

        // punctuators
        if (isPunctuator(c)) {
            try tokens.append(Token{ .start = i, .end = i + 1, .value = null });
            continue;
        }

        // handle words
        if (isAlpha(c)) {
            const start = i;
            c = source[i];
            while (i < source.len and (isAlpha(c) or isNum(c))) : (i += 1) {
                c = source[i];
            }
            try tokens.append(Token{ .start = start, .end = i - 1, .value = null });
            continue;
        }

        if (isNum(c)) {
            const start = i;

            var hasDot = false;
            var hasExp = false;
            while (isNum(c) or (c == '.' and !hasDot) or ((c == 'e' or c == 'E') and !hasExp)) : (i += 1) {
                if (i >= source.len) {
                    break;
                }

                if (c == '.') {
                    hasDot = true;
                    continue;
                }

                if (c == 'e' or c == 'E') {
                    hasExp = true;
                    continue;
                }
            }
            const slice = source[start..i];
            const value = try std.fmt.parseFloat(f64, slice);
            try tokens.append(Token{ .start = start, .end = i, .value = value });
            continue;
        }

        // Unexpected character
        return ScanError.UnexpectedCharacter;
    }

    return tokens;
}

pub fn main() !void {
    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();
    try stdout.print("zigma version {d}.{d}.{d}.\n", .{ VER.major, VER.minor, VER.patch });
    try bw.flush();
    std.debug.print("stderr: initialized\n", .{});
}

test "scan empty line" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    var tokens = try scan("", allocator);
    defer tokens.deinit();
    try expectEqual(tokens.items.len, 0);
}

test "var const" {
    var a: i32 = 1;
    const b: i32 = 2;
    a = b;
    // b = 30; // This will fail to compile, because `b` is a constant.
}

test "undefined" {
    var a: i32 = undefined;
    a = 1;
}

test "underscore" {
    const a: i32 = 1_000_000;
    _ = a;
}

test "var mutate" {
    var a: i32 = 1;
    a = 9; // if this line is removed we get a compile error
    const b = a;
    _ = b;
}

test "array declaration" {
    const a1 = [4]u8{ 1, 2, 3, 4 };
    const a2 = [_]u8{ 1, 2, 3, 4 };
    _ = a1;
    _ = a2;
}

test "array indexing" {
    const a1 = [4]u8{ 1, 2, 3, 4 };
    const b = a1[2];
    try expectEqual(@as(u8, 3), b);
}

test "slice" {
    const a1 = [4]u8{ 1, 2, 3, 4 };
    const b = a1[1..3];
    try expectEqual(@as(u8, 2), b[0]);
    try expectEqual(@as(u8, 3), b[1]);
    try expectEqual(@as(u32, 2), b.len);
    const c = a1[1..];
    try expectEqual(@as(u8, 2), c[0]);
    try expectEqual(@as(u8, 3), c[1]);
    try expectEqual(@as(u8, 4), c[2]);
    try expectEqual(@as(u32, 3), c.len);
}

test "array concat" {
    const a1 = [4]u8{ 1, 2, 3, 4 };
    const a2 = [4]u8{ 5, 6, 7, 8 };
    const b = a1 ++ a2;
    try expectEqual(@as(u8, 1), b[0]);
    try expectEqual(@as(u8, 2), b[1]);
    try expectEqual(@as(u8, 3), b[2]);
    try expectEqual(@as(u8, 4), b[3]);
    try expectEqual(@as(u8, 5), b[4]);
    try expectEqual(@as(u8, 6), b[5]);
    try expectEqual(@as(u8, 7), b[6]);
    try expectEqual(@as(u8, 8), b[7]);
    try expectEqual(@as(u32, 8), b.len);
}

test "array replicate" {
    const a = [_]u8{ 1, 2 };
    const b = a ** 2;
    try expectEqual(@as(u8, 1), b[0]);
    try expectEqual(@as(u8, 2), b[1]);
    try expectEqual(@as(u8, 1), b[2]);
    try expectEqual(@as(u8, 2), b[3]);
    try expectEqual(@as(u32, 4), b.len);
}

test "dynamic slice" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    var n: usize = 0;

    if (builtin.target.os.tag == .windows) {
        n = 10;
    } else if (builtin.target.os.tag == .linux) {
        n = 20;
    } else {
        n = 30;
    }
    const buffer = try allocator.alloc(u8, n);
    defer allocator.free(buffer);
    const slice = buffer[0..];
    try expectEqual(@as(usize, n), slice.len);
}

test "blocks" {
    var y: i32 = 123;
    const x = add_one: {
        y += 1;
        break :add_one y;
    };
    try expectEqual(@as(i32, 124), x);
    try expectEqual(@as(i32, 124), y);
}

test "basic strings" {
    const stdout = std.io.getStdErr().writer();
    const str: []const u8 = "Hello, world!";
    try expectEqual(@as(u32, 13), str.len);
    try expectEqual(@as(u8, 'H'), str[0]);
    try expectEqual(@as(u8, 'o'), str[4]);
    try expectEqual(@as(u8, '!'), str[12]);
    try stdout.print(
        "<<string: {s} ",
        .{str},
    );
    try stdout.print(
        "slice[0..5]: {s}>> ",
        .{str[0..5]},
    );
}

test "string hex loop" {
    const stdout = std.io.getStdErr().writer();
    const str: []const u8 = "ABC";
    try stdout.print("<<str: {s} hex: ", .{str});
    for (str) |c| {
        try stdout.print("{X} ", .{c});
    }
    try stdout.print(">>", .{});
}

test "string length" {
    const str = "0123456789012345678901234567890123";
    const len = str.len;
    try expectEqual(@as(u32, 34), len);
}

test "@TypeOf" {
    const arr = [_]u8{ 1, 2, 3, 4 };
    try expectEqual(@TypeOf(arr), [4]u8);

    const str = "ABC";
    try expectEqual(@TypeOf(str), *const [3:0]u8);

    const pa = &arr;
    try expectEqual(@TypeOf(pa), *const [4]u8);

    const stdout = std.io.getStdErr().writer();
    try stdout.print("<<arr:{}, str:{}, pa:{}>>", .{ @TypeOf(arr), @TypeOf(str), @TypeOf(pa) });
}

test "UTF-8 raw codepoint" {
    const str = "Ⱥ";
    const c0 = str[0];
    const c1 = str[1];
    try expectEqual(@as(u8, 0xC8), c0);
    try expectEqual(@as(u8, 0xBA), c1);
    try expectEqual(@as(usize, 2), str.len);
}

test "UTF-8 view" {
    var utf8 = (try std.unicode.Utf8View.init("Ⱥ")).iterator();

    const codepoint = utf8.nextCodepoint();
    try expectEqual(@as(u21, 570), codepoint);
}

test "string equality " {
    const name: []const u8 = "Mohsen";
    try expectEqual(
        true,
        std.mem.eql(u8, name, "Mohsen"),
    );
}

test "string concat" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    const concat = try std.mem.concat(allocator, u8, &[_][]const u8{
        "Hello, ",
        "world!",
    });
    defer allocator.free(concat);
    try expectEqual(
        true,
        std.mem.eql(u8, concat, "Hello, world!"),
    );
}

test "string startsWith" {
    const str = "Hello, world!";
    try expectEqual(
        true,
        std.mem.startsWith(u8, str, "Hello"),
    );
    try expectEqual(
        false,
        std.mem.startsWith(u8, str, "world"),
    );
}

test "string replace" {
    const str = "Hello";
    var buffer: [5]u8 = undefined;
    const nrep = std.mem.replace(u8, str, "el", "37", buffer[0..]);
    try expectEqual(
        true,
        std.mem.eql(u8, &buffer, "H37lo"),
    );
    try expectEqual(
        @as(u32, 1),
        nrep,
    );
}

test "if statement" {
    var a: i32 = undefined;
    const t = true;

    if (t) {
        a = 1;
    } else {
        a = 2;
    }
    try expectEqual(@as(i32, 1), a);
}

test "switch statement" {
    const Kind = enum { Mammal, Bird, Fish };
    var desc: []const u8 = undefined;
    const kind = Kind.Mammal;

    switch (kind) {
        Kind.Mammal => {
            desc = "Mammal";
        },
        Kind.Bird => {
            desc = "Bird";
        },
        Kind.Fish => {
            desc = "Fish";
        },
    }

    try expectEqual(@as(u32, 6), desc.len);
    try expectEqual(true, std.mem.eql(u8, desc, "Mammal"));
}

test "switch else" {
    const n: i32 = 7;
    var y: i32 = undefined;

    switch (n) {
        1, 2, 3 => y = 1,
        4, 5, 6 => y = 2,
        else => y = 3,
    }
    try expectEqual(@as(i32, 3), y);
}

test "switch value" {
    const n: i32 = 7;
    const desc = switch (n) {
        1, 2, 3 => "one",
        4, 5, 6 => "two",
        else => "three",
    };
    try expectEqual(std.mem.eql(u8, desc, "three"), true);
}

test "switch ranges" {
    const n: i32 = 65;
    const desc = switch (n) {
        1...10 => "one",
        11...20 => "two",
        21...30 => "three",
        31...40 => "four",
        41...50 => "five",
        51...60 => "six",
        else => "seven",
    };
    try expectEqual(std.mem.eql(u8, desc, "seven"), true);
}

test "labeled switch" {
    const v: i32 = 1;
    var val: i32 = undefined;
    cont: switch (v) {
        1 => continue :cont 2,
        2 => continue :cont 3,
        3 => val = 4,
        else => val = 5,
    }
    try expectEqual(@as(u8, 4), val);
}

test "defer" {
    var a: i32 = 0;

    if (true) {
        defer a += 1;
        defer a *= 3; // Last in first out
        a += 1;
    }
    try expectEqual(@as(i32, 4), a);
}

test "for loop" {
    const arr = [_]u8{ 1, 2, 3, 4 };
    var sum: i32 = 0;
    for (arr) |i| {
        sum += i;
    }
    try expectEqual(@as(i32, 10), sum);
}

test "for index and value" {
    const arr = [_]u8{ 1, 2, 3, 4 };
    var sum: usize = 0;
    for (arr, 0..) |i, j| {
        sum += i + j;
    }
    try expectEqual(@as(usize, 16), sum);
}

test "while loop" {
    var i: i32 = 0;
    while (i < 10) {
        i += 1;
    }
    try expectEqual(@as(i32, 10), i);
}

test "while loop with increment expression" {
    var i: i32 = 0;
    var j: i32 = 0;
    while (i < 10) : (i += 1) {
        j += 1;
    }
    try expectEqual(@as(i32, 10), i);
    try expectEqual(@as(i32, 10), j);
}

test "break" {
    var i: i32 = 0;
    while (true) {
        i += 1;
        if (i == 10) {
            break;
        }
    }
    try expectEqual(@as(i32, 10), i);
}

test "continue" {
    var i: i32 = 0;
    var j: i32 = 0;
    while (i < 10) : (i += 1) {
        if (@mod(i, 2) == 0) {
            continue;
        }
        j += i;
    }
    try expectEqual(@as(i32, 1 + 3 + 5 + 7 + 9), j);
}

fn add2(x: *i32) void {
    x.* += 2;
}

test "reference and dereference" {
    var a: i32 = 1;
    add2(&a);
    try expectEqual(@as(i32, 3), a);
}

const Point = struct {
    x: i32,
    y: i32,

    pub fn init(x: i32, y: i32) Point {
        return Point{ .x = x, .y = y };
    }
};
test "struct basics" {
    const p1 = Point{ .x = 1, .y = 2 };
    try expectEqual(@as(i32, 1), p1.x);
    try expectEqual(@as(i32, 2), p1.y);
    const p2 = Point.init(3, 4);
    try expectEqual(@as(i32, 3), p2.x);
    try expectEqual(@as(i32, 4), p2.y);
}

const Vec3 = struct {
    x: f64,
    y: f64,
    z: f64,

    fn d2(a: f64, b: f64) f64 {
        const m = std.math;
        return m.pow(f64, a - b, 2);
    }

    pub fn distance(self: Vec3, other: Vec3) f64 {
        const m = std.math;
        return m.sqrt(
            d2(self.x, other.x) +
                d2(self.y, other.y) +
                d2(self.z, other.z),
        );
    }

    pub fn double(self: *Vec3) void {
        self.x *= 2;
        self.y *= 2;
        self.z *= 2;
    }
};

test "self" {
    const p1 = Vec3{ .x = 1, .y = 2, .z = 3 };
    const p2 = Vec3{ .x = 4, .y = 5, .z = 6 };
    const d = p1.distance(p2);
    try expectEqual(@as(f64, 5.196152422706632), d);
    var p3 = Vec3{ .x = 1, .y = 2, .z = 3 };
    p3.double();
    try expectEqual(@as(f64, 2), p3.x);
    try expectEqual(@as(f64, 4), p3.y);
    try expectEqual(@as(f64, 6), p3.z);
}

test "type inference with dot" {
    const Fruit = enum { Apple, Orange, Banana };
    const fruit: Fruit = .Apple;
    try expectEqual(.Apple, fruit);
}

test "type casting with as" {
    const a: usize = 65535;
    const b: u32 = @as(u32, a);
    try expectEqual(@as(u32, 65535), b);
    try expectEqual(@TypeOf(b), u32);
}

test "specialized type casting" {
    const a: usize = 422;
    const b: f32 = @floatFromInt(a);
    try expectEqual(@as(f32, 422), b);
    try expectEqual(@TypeOf(b), f32);
}

test "ptrCast" {
    const bytes align(@alignOf(u32)) = [_]u8{ 1, 2, 3, 4 };
    const u32_ptr: *const u32 = @ptrCast(&bytes);
    try expectEqual(@TypeOf(u32_ptr), *const u32);
}

test "allocPrint" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    const str = try std.fmt.allocPrint(allocator, "Hello {s}", .{"World"});
    defer allocator.free(str);
    try expectEqual(std.mem.eql(u8, str, "Hello World"), true);
}

test "GeneralPurposeAllocator create, destroy" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    const num = try allocator.create(u8);
    defer allocator.destroy(num);
    num.* = 10;
    try expectEqual(@as(u32, 10), num.*);
}

test "BufferAllocator" {
    var buffer: [10]u8 = undefined;
    for (0..buffer.len) |i| {
        buffer[i] = 0;
    }
    var fba = std.heap.FixedBufferAllocator.init(&buffer);
    const allocator = fba.allocator();
    const num = try allocator.alloc(u8, 5);
    defer allocator.free(num);
    for (0..5) |i| {
        num[i] = @intCast(i);
    }
    try expectEqual(@as(u8, 0), num[0]);
    try expectEqual(@as(u8, 1), num[1]);
    try expectEqual(@as(u8, 2), num[2]);
    try expectEqual(@as(u8, 3), num[3]);
    try expectEqual(@as(u8, 4), num[4]);
}

test "ArenaAllocator" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var aa = std.heap.ArenaAllocator.init(gpa.allocator());
    defer aa.deinit(); // this will free all allocations in the arena
    const allocator = aa.allocator();
    const in1 = allocator.alloc(u8, 5);
    const in2 = allocator.alloc(u8, 10);
    const in3 = allocator.alloc(u8, 15);
    _ = try in1;
    _ = try in2;
    _ = try in3;
}

test "alloc free" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    const num = try allocator.alloc(u8, 5);
    defer allocator.free(num);
    for (0..5) |i| {
        num[i] = @intCast(i);
    }
    try expectEqual(@as(u8, 0), num[0]);
    try expectEqual(@as(u8, 1), num[1]);
    try expectEqual(@as(u8, 2), num[2]);
    try expectEqual(@as(u8, 3), num[3]);
    try expectEqual(@as(u8, 4), num[4]);
}

fn test_stdin() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const stdin = std.io.getStdIn().reader();
    const stdout = std.io.getStdOut().writer();

    const buffer_opt = try stdin.readUntilDelimiterOrEofAlloc(allocator, '\n', 100);
    if (buffer_opt) |buffer| {
        defer allocator.free(buffer);
        try stdout.print("<<stdin: {s}>>\n", .{buffer});
    } else {
        try stdout.print("<<stdin: EOF>>\n", .{});
    }
}

test "struct create destroy" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    const User = struct {
        name: []const u8,
        age: u32,
    };
    const user = try allocator.create(User);
    defer allocator.destroy(user);
    user.* = User{ .name = "Mohsen", .age = 30 };
    try expectEqual(std.mem.eql(u8, user.name, "Mohsen"), true);
    try expectEqual(@as(u32, 30), user.age);
}

const Base64 = struct {
    _table: *const [64]u8,

    pub fn init() Base64 {
        const upper = "ABCDEFGHIJKLMNOPQRSTUVWXYZ";
        const lower = "abcdefghijklmnopqrstuvwxyz";
        const digits = "0123456789+/";
        return Base64{ ._table = upper ++ lower ++ digits };
    }

    pub fn _char_at(self: Base64, index: u8) u8 {
        return self._table[index];
    }

    fn _calc_encode_length(input: []const u8) !usize {
        if (input.len < 3) {
            return 4;
        }

        return try std.math.divCeil(usize, input.len, 3) * 4;
    }

    fn _calc_decode_length(input: []const u8) !usize {
        if (input.len < 4) {
            return 3;
        }
        return try std.math.divFloor(usize, input.len, 4) * 3;
    }

    pub fn encode(self: Base64, allocator: std.mem.Allocator, input: []const u8) ![]u8 {
        if (input.len == 0) {
            return allocator.alloc(u8, 0);
        }

        const n_out = try _calc_encode_length(input);
        var out = try allocator.alloc(u8, n_out);
        var buf = [3]u8{ 0, 0, 0 };
        var count: u8 = 0;
        var iout: u64 = 0;

        for (input, 0..) |_, i| {
            buf[count] = input[i];
            count += 1;
            if (count == 3) {
                out[iout] = self._char_at(buf[0] >> 2);
                out[iout + 1] = self._char_at(((buf[0] & 0x03) << 4) | (buf[1] >> 4));
                out[iout + 2] = self._char_at(((buf[1] & 0x0F) << 2) | (buf[2] >> 6));
                out[iout + 3] = self._char_at(buf[2] & 0x3F);
                iout += 4;
                count = 0;
            }
        }

        if (count == 1) {
            out[iout] = self._char_at(buf[0] >> 2);
            out[iout + 1] = self._char_at((buf[0] & 0x03) << 4);
            out[iout + 2] = '=';
            out[iout + 3] = '=';
        } else if (count == 2) {
            out[iout] = self._char_at(buf[0] >> 2);
            out[iout + 1] = self._char_at(((buf[0] & 0x03) << 4) | (buf[1] >> 4));
            out[iout + 2] = self._char_at((buf[1] & 0x0F) << 2);
            out[iout + 3] = '=';
        }

        return out;
    }

    fn _char_index(c: u8) u8 {
        if (c >= 'A' and c <= 'Z') {
            return c - 'A';
        } else if (c >= 'a' and c <= 'z') {
            return c - 'a' + 26;
        } else if (c >= '0' and c <= '9') {
            return c - '0' + 52;
        } else if (c == '+') {
            return 62;
        } else if (c == '/') {
            return 63;
        }
        return 64; // Invalid character
    }

    pub fn decode(self: Base64, allocator: std.mem.Allocator, input: []const u8) ![]u8 {
        _ = self;
        if (input.len == 0) {
            return allocator.alloc(u8, 0);
        }

        const n_out = try _calc_decode_length(input);
        var out = try allocator.alloc(u8, n_out);
        var buf = [4]u8{ 0, 0, 0, 0 };
        var count: u8 = 0;
        var iout: u64 = 0;

        for (0..input.len) |i| {
            buf[count] = _char_index(input[i]);
            count += 1;
            if (count == 4) {
                out[iout] = (buf[0] << 2) | (buf[1] >> 4);
                if (buf[2] != 64) {
                    out[iout + 1] = ((buf[1] & 0x0F) << 4) | (buf[2] >> 2);
                } else {
                    out[iout + 1] = 0;
                }
                if (buf[3] != 64) {
                    out[iout + 2] = ((buf[2] & 0x03) << 6) | buf[3];
                } else {
                    out[iout + 2] = 0;
                }
                iout += 3;
                count = 0;
            }
        }

        return out;
    }
};

test "Base64 init" {
    const base64 = Base64.init();
    try expectEqual(@as(u8, 'c'), base64._char_at(28));
}

test "Base64 encode" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    const base64 = Base64.init();
    const inp1 = "Hello, world!";
    const enc1 = try base64.encode(allocator, inp1);
    defer allocator.free(enc1);
    try expectEqual(std.mem.eql(u8, enc1, "SGVsbG8sIHdvcmxkIQ=="), true);
    const inp2 = "Hi";
    const enc2 = try base64.encode(allocator, inp2);
    defer allocator.free(enc2);
    try expectEqual(std.mem.eql(u8, enc2, "SGk="), true);
    const inp3 = "A";
    const enc3 = try base64.encode(allocator, inp3);
    defer allocator.free(enc3);
    try expectEqual(std.mem.eql(u8, enc3, "QQ=="), true);
    const inp4 = "";
    const enc4 = try base64.encode(allocator, inp4);
    defer allocator.free(enc4);
    try expectEqual(std.mem.eql(u8, enc4, ""), true);
}

test "Base64 decode" {
    var mem: [1000]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&mem);
    const allocator = fba.allocator();
    const base64 = Base64.init();

    const inp4 = "";
    const dec4 = try base64.decode(allocator, inp4);
    try expectEqual(std.mem.eql(u8, dec4, ""), true);

    const inp3 = "QQ==";
    const dec3 = try base64.decode(allocator, inp3);
    try expectEqual(std.mem.eql(u8, dec3, &.{ 'A', 0, 0 }), true);

    const inp2 = "SGk=";
    const dec2 = try base64.decode(allocator, inp2);
    try expectEqual(std.mem.eql(u8, dec2, &.{ 'H', 'i', 0 }), true);

    const inp1 = "SGVsbG8sIHdvcmxkIQ==";
    const dec1 = try base64.decode(allocator, inp1);
    try expectEqual(std.mem.eql(u8, dec1, &.{ 'H', 'e', 'l', 'l', 'o', ',', ' ', 'w', 'o', 'r', 'l', 'd', '!', 0, 0 }), true);
}

test "pointer" {
    const a: i32 = 1;
    const b = &a;
    try expectEqual(@as(i32, 1), b.*);
    try expectEqual(@TypeOf(b), *const i32);
}

test "pointer dereference chaining" {
    const User = struct {
        name: []const u8,
        age: u32,
    };

    const u = User{ .name = "Mohsen", .age = 30 };
    const p = &u;
    try expectEqual(30, p.*.age);
}

test "const pointer to var" {
    var a: i32 = 1;
    const b = &a;
    b.* = 2; // This is allowed because `b` is a pointer to a variable.
    try expectEqual(@as(i32, 2), a);
}

test "var pointer to different const" {
    const a: i32 = 1;
    const b: i32 = 2;
    var p = &a;
    try expectEqual(@as(i32, 1), p.*);
    p = &b;
    try expectEqual(@as(i32, 2), p.*);
}

test "pointer arithmetic" {
    var arr = [_]u8{ 1, 2, 3, 4 };
    var p: [*]const u8 = &arr;
    const el1 = p[0];
    p = p + 1;
    const el2 = p[0];
    p = p + 1;
    const el3 = p[0];
    p = p + 1;
    const el4 = p[0];
    try expectEqual(@as(u8, 1), el1);
    try expectEqual(@as(u8, 2), el2);
    try expectEqual(@as(u8, 3), el3);
    try expectEqual(@as(u8, 4), el4);
}

test "optional" {
    var a: ?i32 = 0;
    a = null;
}

test "optional pointer" {
    var a: i32 = 1;
    var p: ?*i32 = &a;
    p = null;
}

test "unwrap optional with if" {
    const a: ?i32 = 1;
    if (a) |v| {
        try expectEqual(@as(i32, 1), v);
    } else {
        unreachable;
    }
}

test "orelse" {
    const a: ?i32 = null;
    const b: i32 = (a orelse 3) * 2;
    try expectEqual(@as(i32, 6), b);
}

const HttpServer = struct {
    const Socket = struct {
        _address: std.net.Address,
        _stream: std.net.Stream,

        pub fn init() !Socket {
            const host = [4]u8{ 127, 0, 0, 1 };
            const port = 8080;
            const addr = std.net.Address.initIp4(host, port);
            const sock_fd: i32 = try std.posix.socket(addr.any.family, std.posix.SOCK.STREAM, std.posix.IPPROTO.TCP);
            const stream = std.net.Stream{ .handle = sock_fd };
            return Socket{ ._address = addr, ._stream = stream };
        }
    };

    const Connection = std.net.Server.Connection;
    pub fn read_request(conn: Connection, buffer: []u8) !void {
        const reader = conn.stream.reader();
        _ = try reader.read(buffer);
    }

    const Method = enum {
        GET,

        pub fn init(text: []const u8) !Method {
            return MethodMap.get(text).?;
        }

        pub fn is_supported(m: []const u8) bool {
            return MethodMap.contains(m);
        }
    };

    const Map = std.static_string_map.StaticStringMap;
    const MethodMap = Map(Method).initComptime(.{.{ "GET", .GET }});
    const Request = struct {
        method: Method,
        version: []const u8,
        uri: []const u8,
        pub fn init(method: Method, uri: []const u8, version: []const u8) Request {
            return Request{ .method = method, .uri = uri, .version = version };
        }
    };
    fn parse_request(text: []u8) !Request {
        const line_index = std.mem.indexOfScalar(u8, text, '\n') orelse text.len;
        var iterator = std.mem.splitScalar(u8, text[0..line_index], ' ');
        const method_str = iterator.next();
        const method = try Method.init(method_str.?);
        const uri = iterator.next().?;
        const version = iterator.next().?;
        const request = Request.init(method, uri, version);
        return request;
    }
    fn send_200(conn: Connection) !void {
        const response = ("HTTP/1.1 200 OK\nContent-Length: 48" ++ "\nContent-Type: text/html\n" ++ "Connection: Closed\n\n" ++ "<html><body><h1>Hello, World!</h1></body></html>");
        _ = try conn.stream.write(response);
    }

    fn send_404(conn: Connection) !void {
        const response = ("HTTP/1.1 404 Not Found\nContent-Length: 50" ++ "\nContent-Type: text/html\n" ++ "Connection: Closed\n\n");
        _ = try conn.stream.write(response);
    }
    pub fn start(self: HttpServer) !void {
        _ = self;
        const socket = try Socket.init();
        std.debug.print("Socket initialized {any}.\n", .{socket._address});
        var server = try socket._address.listen(.{});
        const connection = try server.accept();
        var buffer: [1024]u8 = undefined;
        for (0..buffer.len) |i| {
            buffer[i] = 0;
        }
        _ = try read_request(connection, buffer[0..buffer.len]);
        const request = try parse_request(buffer[0..]);
        if (request.method == .GET) {
            if (std.mem.eql(u8, request.uri, "/")) {
                try send_200(connection);
            } else {
                try send_404(connection);
            }
        }
    }
};

fn alloc_100(allocator: std.mem.Allocator) ![]u8 {
    const buffer = try allocator.alloc(u8, 100);
    defer allocator.free(buffer);
    for (0..buffer.len) |i| {
        buffer[i] = @intCast(i);
    }
    return buffer;
}

test "expectError" {
    var buffer: [10]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buffer);
    const allocator = fba.allocator();
    try std.testing.expectError(error.OutOfMemory, alloc_100(allocator));
}

test "expectEqualSlices" {
    const a = [_]u8{ 1, 2, 3, 4 };
    const b = [_]u8{ 1, 2, 3, 4 };
    try std.testing.expectEqualSlices(u8, &a, &b);
}

test "expectEqualStrings" {
    const a = "Hello, world!";
    const b = "Hello, world!";
    try std.testing.expectEqualStrings(a, b);
}

test "basic error checking" {
    const dir = std.fs.cwd();
    // _ = dir.openFile("main.zig", .{}); // this will not compile
    _ = try dir.openFile("zigma.zig", .{}); // this will compile
}

const TestError = error{
    Unexcpected,
    OutOfMemory,
};

fn test_error() TestError!void {
    return TestError.Unexcpected;
}

test "error enum" {
    const err = test_error();
    try std.testing.expectEqual(err, TestError.Unexcpected);
}

const TestSubError = error{
    OutOfMemory,
};

fn test_sub_error() TestSubError!void {
    return TestSubError.OutOfMemory;
}

test "casting suberrors" {
    const err = test_sub_error();
    try std.testing.expectEqual(err, TestError.OutOfMemory);
}

fn conditional_error(a: i32) TestError!i32 {
    if (a == 0) {
        return TestError.Unexcpected;
    }
    return 27;
}
test "catch error" {
    const e = conditional_error(0) catch 20;
    try expectEqual(@as(i32, 20), e);
}

test "catch to default error values" {
    // parse a string into an integer
    const n1 = std.fmt.parseInt(i32, "1234", 10) catch 0;
    try expectEqual(@as(i32, 1234), n1);
    const n2 = std.fmt.parseInt(i32, "abc", 10) catch -1;
    try expectEqual(@as(i32, -1), n2);
}

test "using if to catch errors" {
    if (std.fmt.parseInt(i32, "422", 10)) |n| {
        try expectEqual(@as(i32, 422), n);
    } else |err| {
        switch (err) {
            error.Overflow => unreachable,
            error.InvalidCharacter => unreachable,
        }
    }
}

fn testErrDefer(ptr: *i32) !void {
    errdefer ptr.* = 0;
    _ = try conditional_error(0);
}
test "errdefer" {
    var val: i32 = 12;
    testErrDefer(&val) catch |err| {
        switch (err) {
            TestError.Unexcpected => {},
            else => unreachable,
        }
    };
    try expectEqual(@as(i32, 0), val);
}

test "tagged union" {
    const JsVar = union(enum) {
        nVal: f64,
        sVal: []const u8,
        bVal: bool,
    };

    var jsVar = JsVar{ .nVal = 1.0 };
    try expectEqual(@as(f64, 1.0), jsVar.nVal);
    jsVar = JsVar{ .sVal = "Hello" };
    try std.testing.expectEqualStrings("Hello", jsVar.sVal);

    var stringFound: ?[]const u8 = null;
    switch (jsVar) {
        .nVal => stringFound = null,
        .sVal => stringFound = jsVar.sVal,
        .bVal => stringFound = null,
    }
    try std.testing.expectEqualStrings("Hello", stringFound.?);
}

test "ArrayList" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    var list = std.ArrayList(u8).init(allocator);
    defer list.deinit();
    try list.append('H');
    try list.append('e');
    try list.append('l');
    try list.append('l');
    try list.append('o');
    try list.appendSlice(" World!");

    try expect(std.mem.eql(u8, list.items, "Hello World!"));
    try expectEqual(@as(usize, 12), list.items.len);
    const char: u8 = list.pop() orelse 0;
    try expectEqual(@as(u8, '!'), char);
    try expectEqual(@as(usize, 11), list.items.len);
    const c2: u8 = list.orderedRemove(2);
    try expectEqual(@as(u8, 'l'), c2);
    try list.insert(2, 'l');
    try std.testing.expectEqualStrings("Hello World", list.items);
    try list.insertSlice(0, "OK ");
    try std.testing.expectEqualStrings("OK Hello World", list.items);
}

test "AutoHashMap" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    var map = std.hash_map.AutoHashMap(u32, u16).init(allocator);
    defer map.deinit();
    try map.put(422, 1966);
    try map.put(815, 1989);
    try map.put(617, 1966);
    try map.put(609, 1994);
    try expectEqual(@as(usize, 4), map.count());
    try expectEqual(@as(u16, 1989), map.get(815));
    const a = map.remove(422);
    const b = map.get(422) orelse 0;
    try expectEqual(@as(u16, 0), b);
    try expectEqual(true, a);
    var sumk: u32 = 0;
    var sumv: u16 = 0;
    var it = map.iterator();
    while (it.next()) |kv| {
        sumk += kv.key_ptr.*;
        sumv += kv.value_ptr.*;
    }

    try expectEqual(@as(u32, 1989 + 1966 + 1994), sumv);

    var kit = map.keyIterator();
    sumk = 0;
    while (kit.next()) |k| {
        sumk += k.*;
    }
    try expectEqual(@as(u16, 815 + 617 + 609), sumk);
}

test "AutoArrayHashMap" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    var map = std.array_hash_map.AutoArrayHashMap(u32, u16).init(allocator);
    defer map.deinit();
    try map.put(422, 1966);
    try map.put(815, 1989);
    try map.put(617, 1966);
    try map.put(609, 1994);
    try expectEqual(@as(usize, 4), map.count());
    try expectEqual(@as(u16, 1989), map.get(815));
    const a = map.orderedRemove(422);
    const b = map.get(422) orelse 0;
    try expectEqual(@as(u16, 0), b);
    try expectEqual(true, a);
    var sumk: u32 = 0;
    var sumv: u16 = 0;
    var it = map.iterator();
    while (it.next()) |kv| {
        sumk += kv.key_ptr.*;
        sumv += kv.value_ptr.*;
    }

    try expectEqual(@as(u32, 1989 + 1966 + 1994), sumv);
}

test "StringHashMap" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    var map = std.StringHashMap(u16).init(allocator);
    defer map.deinit();
    try map.put("Mo", 1966);
    try map.put("Le", 1966);
    try map.put("Sa", 1989);
    try map.put("Na", 1994);

    const mo = map.get("Mo");
    const le = map.get("Le");
    const sa = map.get("Sa");
    const na = map.get("Na");

    try expectEqual(@as(u16, 1966), mo);
    try expectEqual(@as(u16, 1966), le);
    try expectEqual(@as(u16, 1989), sa);
    try expectEqual(@as(u16, 1994), na);
}

test "SinglyLinkedList" {
    const Lu32 = std.SinglyLinkedList(u32);
    var list = Lu32{};
    var one = Lu32.Node{ .data = 1 };
    var two = Lu32.Node{ .data = 2 };
    var three = Lu32.Node{ .data = 3 };
    list.prepend(&one);
    one.insertAfter(&two);
    two.insertAfter(&three);
}

test "DoublyLinkedList" {
    const Lu32 = std.DoublyLinkedList(u32);
    var list = Lu32{};
    var one = Lu32.Node{ .data = 1 };
    list.append(&one);
    var two = Lu32.Node{ .data = 2 };
    list.append(&two);
    const o = list.popFirst();
    try expectEqual(@as(u32, 1), o.?.data);
}

test "MultiArrayList" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    const Person = struct {
        name: []const u8,
        age: u8,
        height: f32,
    };
    const PersonArray = std.MultiArrayList(Person);
    var people = PersonArray{};
    defer people.deinit(allocator);

    try people.append(allocator, .{ .name = "Mo", .age = 59, .height = 173 });
    try people.append(allocator, .{ .name = "Le", .age = 59, .height = 160 });
    try people.append(allocator, .{ .name = "Sa", .age = 35, .height = 180 });
    try people.append(allocator, .{ .name = "Na", .age = 30, .height = 160 });

    var sumh: f32 = 0;
    for (people.items(.height)) |*h| { // don't do this, slower
        sumh += h.*;
    }
    try expectEqual(@as(f32, 173 + 160 + 180 + 160), sumh);
    var suma: u32 = 0;
    var slice = people.slice(); // do this better performance
    for (slice.items(.age)) |*a| {
        suma += a.*;
    }
    try expectEqual(@as(u32, 59 * 2 + 35 + 30), suma);
}

test "comptime args" {
    const S = struct {
        pub fn double(self: @This(), comptime n: u32) u32 {
            _ = self;
            return n * 2;
        }
    };

    const s = S{};
    const n = s.double(5); // this will not compile if runtime value
    try expectEqual(@as(u32, 10), n);
}

test "type return" {
    const S = struct {
        pub fn makeArray(self: @This(), comptime size: usize) type {
            _ = self;
            return [size]u8;
        }
    };

    const s = S{};
    const a = s.makeArray(12);
    try expectEqual(@TypeOf(a), type);
}

pub fn fib(i: u32) u32 {
    if (i == 0) return 0;
    if (i == 1) return 1;
    return fib(i - 1) + fib(i - 2);
}

test "more comptime" {
    try expectEqual(@as(u32, 13), fib(7));
    try comptime expectEqual(@as(u32, 13), fib(7));
}

test "comptime block" {
    const x = comptime blk: {
        const n1 = 3;
        const n2 = 4;
        const n3 = n1 + n2;
        try expectEqual(@as(u32, 13), fib(n3));
        break :blk n3;
    };
    _ = x;
}

test "generics" {
    const S = struct {
        pub fn max(self: @This(), comptime T: type, a: T, b: T) T {
            _ = self;
            return if (a > b) a else b;
        }
    };

    const s = S{};
    const n = s.max(u32, 2, 3); // this will not compile if runtime value
    try expectEqual(@as(u32, 3), n);
    const i = s.max(i32, -2, -3); // this will not compile if runtime value
    try expectEqual(@as(i32, -2), i);
}

fn Stack(comptime T: type) type {
    return struct {
        items: []T,
        count: usize,
        allocator: std.mem.Allocator,

        const Self = @This();

        pub fn init(allocator: std.mem.Allocator, size: usize) !Stack(T) {
            const items = try allocator.alloc(T, size);
            return Stack(T){ .items = items, .count = 0, .allocator = allocator };
        }

        pub fn deinit(self: *Stack(T)) void {
            self.allocator.free(self.items);
        }

        pub fn push(self: *Stack(T), item: T) !void {
            if (self.count >= self.items.len) {
                var buff = try self.allocator.alloc(T, self.count * 2);
                for (0..self.items.len) |i| {
                    buff[i] = self.items[i];
                }
                self.allocator.free(self.items);
                self.items = buff;
            }
            self.items[self.count] = item;
            self.count += 1;
        }

        pub fn pop(self: *Stack(T)) ?T {
            if (self.count == 0) {
                return null;
            }
            self.count -= 1;
            return self.items[self.count];
        }
    };
}

test "Stack" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    const StackU32 = Stack(u32);
    var stack = try StackU32.init(allocator, 10);
    defer stack.deinit();

    for (0..10) |i| {
        try stack.push(@intCast(i));
    }

    // force stack to expand
    for (10..20) |i| {
        try stack.push(@intCast(i));
    }

    for (0..20) |i| {
        const item = stack.pop() orelse 0;
        const val: u32 = @intCast(19 - i);
        try expectEqual(val, item);
    }
}

test "File system" {
    const cwd = std.fs.cwd();
    try cwd.makeDir("test_dir");

    const newFile = try cwd.createFile("test_dir/test_file.txt", .{});
    var fw = newFile.writer();
    _ = try fw.writeAll("Hello, World!");
    newFile.close();

    const readFile = try cwd.openFile("test_dir/test_file.txt", .{});
    var fr = readFile.reader();
    var buffer: [100]u8 = undefined;
    @memset(buffer[0..100], 0);
    try readFile.seekFromEnd(0);
    try readFile.seekTo(0);
    const bytesRead = try fr.read(buffer[0..]);
    try expectEqual(@as(u32, 13), bytesRead);
    try expectEqual(std.mem.eql(u8, buffer[0..bytesRead], "Hello, World!"), true);
    readFile.close();

    try cwd.copyFile("test_dir/test_file.txt", cwd, "test_dir/test_file_copy.txt", .{});

    var fileCount: u32 = 0;
    var d = try cwd.openDir("test_dir", .{ .iterate = true });
    defer d.close();
    var it = d.iterate();
    while (try it.next()) |_| {
        fileCount += 1;
    }
    try expectEqual(@as(u32, 2), fileCount);

    try cwd.deleteFile("test_dir/test_file_copy.txt");
    try cwd.deleteFile("test_dir/test_file.txt");

    try cwd.deleteDir("test_dir");
}

pub fn sleep(ms: u64) void {
    std.time.sleep(ms * std.time.ns_per_ms);
}

test "thread join" {
    const thread = try std.Thread.spawn(.{}, sleep, .{10});
    thread.join(); // this will block waiting for sleep
}

test "thread detatch" {
    const thread = try std.Thread.spawn(.{}, sleep, .{10});
    thread.detach(); // this will not block waiting for sleep
}

test "thread pool" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    var pool: std.Thread.Pool = undefined;
    const opts = std.Thread.Pool.Options{
        .allocator = allocator,
        .n_jobs = 2,
    };
    _ = try pool.init(opts);
    defer pool.deinit();

    _ = try pool.spawn(sleep, .{10});
    _ = try pool.spawn(sleep, .{10});
    _ = try pool.spawn(sleep, .{10});
    // deinit() will wait for all threads to finish
}

var counter: u64 = 0;

fn increment(mutex: *std.Thread.Mutex) void {
    for (0..100) |_| {
        mutex.lock();
        counter += 1;
        mutex.unlock();
    }
}

test "mutex" {
    var mutex: std.Thread.Mutex = .{};

    const thread1 = try std.Thread.spawn(.{}, increment, .{&mutex});
    const thread2 = try std.Thread.spawn(.{}, increment, .{&mutex});
    thread1.join();
    thread2.join();

    try expectEqual(@as(u64, 200), counter);
}

test "SIMD vector" {
    const v1 = @Vector(4, u32){ 1, 2, 3, 4 };
    const v2 = @Vector(4, u32){ 5, 6, 7, 8 };
    const v3 = v1 + v2; // this is parallel if SIMD present
    try expectEqual(@as(u32, 6), v3[0]);
    try expectEqual(@as(u32, 8), v3[1]);
    try expectEqual(@as(u32, 10), v3[2]);
    try expectEqual(@as(u32, 12), v3[3]);
    const a1 = [4]u32{ 1, 2, 3, 4 };
    const v4: @Vector(4, u32) = a1; // convert array to vector
    try expectEqual(@as(u32, 1), v4[0]);
    const v5: @Vector(10, u32) = @splat(32); // repeat 32 into 10 elements
    try expectEqual(@as(u32, 32), v5[0]);
    try expectEqual(@as(u32, 32), v5[9]);
}
