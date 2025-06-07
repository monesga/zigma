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
