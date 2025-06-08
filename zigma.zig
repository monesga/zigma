// $ zigma -h
//
// zigma verion 0.0.1 - hierarchical expression calculator
// parse text expression lines and use hierarchy to compute subtotals
//
// usage: zigma [-s | -p | -n | -f | -d | -t | -h] [file] [expression]
//
// -s    tokenize and print tokens
// -p    parse and print output
// -n    don't produce output lines
// -f    filter with children
// -d    filter without childred
// -b    black and white
// -t    don't show file total
// -h    show this help message
//
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
    return c == ':' or c == '=' or c == '(' or c == ')' or c == '+' or c == '-' or c == '/' or c == '*';
}

fn isNumChar(c: u8, hasDot: bool, hasExp: bool) bool {
    if (c >= '0' and c <= '9') {
        return true;
    }
    if (c == '.' and !hasDot) {
        return true;
    }
    if ((c == 'e' or c == 'E') and !hasExp) {
        return true;
    }
    return false;
}

// scan a line of source into tokens
// assumes source already broken down into lines and we scan one
// line at a time
fn scan_line(source: []const u8, allocator: std.mem.Allocator) !std.ArrayList(Token) {
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
            try tokens.append(Token{ .start = i, .end = i, .value = null });
            continue;
        }

        // handle words
        if (isAlpha(c)) {
            const start = i;
            c = source[i];
            while (i < source.len) : (i += 1) {
                c = source[i];
                if (!isAlpha(c) and !isNum(c)) {
                    break;
                }
            }
            try tokens.append(Token{ .start = start, .end = i - 1, .value = null });
            i -= 1; // adjust for the loop increment
            continue;
        }

        if (isNum(c)) {
            const start = i;

            var hasDot = false;
            var hasExp = false;
            while (i < source.len) : (i += 1) {
                c = source[i];
                if (!isNumChar(c, hasDot, hasExp)) {
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
            try tokens.append(Token{ .start = start, .end = i - 1, .value = value });
            i -= 1; // adjust for the loop increment
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
    const allocator = std.testing.allocator;
    var tokens = try scan_line("", allocator);
    defer tokens.deinit();
    try expectEqual(0, tokens.items.len);
}

test "scan all spaces line" {
    const allocator = std.testing.allocator;
    var tokens = try scan_line("    ", allocator);
    defer tokens.deinit();
    try expectEqual(0, tokens.items.len);
}

test "scan word" {
    const allocator = std.testing.allocator;
    var tokens = try scan_line("hello", allocator);
    defer tokens.deinit();
    try expectEqual(1, tokens.items.len);
    try expectEqual(0, tokens.items[0].start);
    try expectEqual(4, tokens.items[0].end);
    try expectEqual(null, tokens.items[0].value);
}

test "scan integer" {
    const allocator = std.testing.allocator;
    var tokens = try scan_line("1234", allocator);
    defer tokens.deinit();
    try expectEqual(1, tokens.items.len);
    try expectEqual(0, tokens.items[0].start);
    try expectEqual(3, tokens.items[0].end);
    try expectEqual(1234.0, tokens.items[0].value);
}

test "scan spaces and word" {
    const allocator = std.testing.allocator;
    var tokens = try scan_line("    hello", allocator);
    defer tokens.deinit();
    try expectEqual(1, tokens.items.len);
    try expectEqual(4, tokens.items[0].start);
    try expectEqual(8, tokens.items[0].end);
    try expectEqual(null, tokens.items[0].value);
}

test "title:12" {
    const allocator = std.testing.allocator;
    const source = "title:12";
    var tokens = try scan_line(source, allocator);
    defer tokens.deinit();
    try expectEqual(3, tokens.items.len);
    try expectEqual(0, tokens.items[0].start);
    try expectEqual(4, tokens.items[0].end);
    try expectEqual(null, tokens.items[0].value);
    try expectEqual(5, tokens.items[1].start);
    try expectEqual(5, tokens.items[1].end);
    try expectEqual(6, tokens.items[2].start);
    try expectEqual(7, tokens.items[2].end);
    try expectEqual(12.0, tokens.items[2].value);
}

test "x=9.3" {
    const allocator = std.testing.allocator;
    const source = "x=9.3";
    var tokens = try scan_line(source, allocator);
    defer tokens.deinit();
    try expectEqual(3, tokens.items.len);
    try expectEqual(0, tokens.items[0].start);
    try expectEqual(0, tokens.items[0].end);
    try expectEqual(null, tokens.items[0].value);
    try expectEqual(1, tokens.items[1].start);
    try expectEqual(1, tokens.items[1].end);
    try expectEqual(9.3, tokens.items[2].value);
}

test "note: (12.3+4.5)/6.7" {
    const allocator = std.testing.allocator;
    const source = "note: (12.3+4.5)/6.7";
    var tokens = try scan_line(source, allocator);
    defer tokens.deinit();
    try expectEqual(9, tokens.items.len);
    try expectEqual(0, tokens.items[0].start);
    try expectEqual(3, tokens.items[0].end);
    try expectEqual(':', source[tokens.items[1].start]);
    try expectEqual('(', source[tokens.items[2].start]);
    try expectEqual(12.3, tokens.items[3].value);
    try expectEqual('+', source[tokens.items[4].start]);
    try expectEqual(4.5, tokens.items[5].value);
    try expectEqual(')', source[tokens.items[6].start]);
    try expectEqual('/', source[tokens.items[7].start]);
    try expectEqual(6.7, tokens.items[8].value);
}
