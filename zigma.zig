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
fn scan_line(source: []const u8, offset: u16, allocator: std.mem.Allocator) !std.ArrayList(Token) {
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
            try tokens.append(Token{ .start = offset + i, .end = offset + i, .value = null });
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
            try tokens.append(Token{ .start = offset + start, .end = offset + i - 1, .value = null });
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
            try tokens.append(Token{ .start = offset + start, .end = offset + i - 1, .value = value });
            i -= 1; // adjust for the loop increment
            continue;
        }

        // Unexpected character
        return ScanError.UnexpectedCharacter;
    }

    return tokens;
}

fn scan_lines(source: []const u8, allocator: std.mem.Allocator) !std.ArrayList(std.ArrayList(Token)) {
    var lines: std.ArrayList(std.ArrayList(Token)) = std.ArrayList(std.ArrayList(Token)).init(allocator);
    var line_start: usize = 0;

    for (source, 0..) |c, i| {
        if (c == '\n' or c == '\r') {
            const line = source[line_start..i];
            const offset: u16 = @intCast(line_start);
            const tokens = try scan_line(line, offset, allocator);
            try lines.append(tokens);
            line_start = i + 1;
        }
    }

    // Handle the last line if it doesn't end with a newline
    if (line_start < source.len) {
        const line = source[line_start..];
        const offset: u16 = @intCast(line_start);
        const tokens = try scan_line(line, offset, allocator);
        try lines.append(tokens);
    }

    return lines;
}

fn free_lines(lines: std.ArrayList(std.ArrayList(Token))) void {
    for (lines.items) |line| {
        line.deinit();
    }
    lines.deinit();
}

const Theme = enum { mono, light, dark };

fn print_line(
    stdout: anytype,
    source: []const u8,
    line: std.ArrayList(Token),
    line_start: u16,
    theme: Theme,
) !void {
    const reset_color: []const u8 = switch (theme) {
        .mono => "",
        .light => "\x1b[0m",
        .dark => "\x1b[0m",
    };
    const word_color: []const u8 = switch (theme) {
        .mono => "",
        .light => "\x1b[37m",
        .dark => "\x1b[90m",
    };
    const number_color: []const u8 = switch (theme) {
        .mono => "",
        .light => "\x1b[32m",
        .dark => "\x1b[92m",
    };
    const punctuator_color: []const u8 = switch (theme) {
        .mono => "",
        .light => "\x1b[34m",
        .dark => "\x1b[94m",
    };

    var current: u16 = line_start;
    for (line.items) |token| {
        // print spaces before the token
        if (token.start > current) {
            const spaces = source[current..token.start];
            try stdout.print("{s}", .{spaces});
        }
        current = token.end + 1;
        // print the token
        const word = source[token.start .. token.end + 1];
        const start_char = word[0];
        if (isAlpha(start_char)) {
            try stdout.print("{s}", .{word_color});
        } else if (isNum(start_char)) {
            try stdout.print("{s}", .{number_color});
        } else if (isPunctuator(start_char)) {
            try stdout.print("{s}", .{punctuator_color});
        } else {
            return ScanError.UnexpectedCharacter;
        }
        try stdout.print("{s}{s}", .{ word, reset_color });
    }
    try stdout.print("\n", .{});
}

fn print_lines(
    stdout: anytype,
    source: []const u8,
    lines: std.ArrayList(std.ArrayList(Token)),
    show_line_numbers: bool,
    theme: Theme,
) !void {
    const reset_color: []const u8 = switch (theme) {
        .mono => "",
        .light => "\x1b[0m",
        .dark => "\x1b[0m",
    };
    const line_color = switch (theme) {
        .mono => "",
        .light => "\x1b[90m",
        .dark => "\x1b[90m",
    };

    const numLines: i32 = @intCast(lines.items.len);
    const count: f32 = @floatFromInt(numLines);
    const digits = if (count == 0) 1 else @log10(count) + 1;

    var line_start: usize = 0;
    for (lines.items, 0..) |line, i| {
        if (show_line_numbers) {
            // print n spaces before the line number
            const ln: i32 = @intCast(i + 1);
            const f: f32 = @floatFromInt(ln);
            const lineWidth = @log10(f) + 1;
            const gap = digits - lineWidth;
            const ss: usize = @intCast(@as(i32, @intFromFloat(gap)));
            for (0..ss) |_| {
                try stdout.print(" ", .{});
            }
            const line_number = i + 1;
            try stdout.print("{s}{d}{s} ", .{ line_color, line_number, reset_color });
        }
        if (line.items.len == 0) {
            try stdout.print("\n", .{});
            line_start += 1; // account for the newline
            continue;
        }

        const start: u16 = @intCast(line_start);
        try print_line(stdout, source, line, start, theme);

        // Find the end of this line to calculate next line_start
        var end = line_start;
        while (end < source.len and source[end] != '\n' and source[end] != '\r') {
            end += 1;
        }
        if (end < source.len) {
            end += 1; // skip the newline
        }
        line_start = end;
    }
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
    var tokens = try scan_line("", 0, allocator);
    defer tokens.deinit();
    try expectEqual(0, tokens.items.len);
}

test "scan all spaces line" {
    const allocator = std.testing.allocator;
    var tokens = try scan_line("    ", 0, allocator);
    defer tokens.deinit();
    try expectEqual(0, tokens.items.len);
}

test "scan word" {
    const allocator = std.testing.allocator;
    var tokens = try scan_line("hello", 0, allocator);
    defer tokens.deinit();
    try expectEqual(1, tokens.items.len);
    try expectEqual(0, tokens.items[0].start);
    try expectEqual(4, tokens.items[0].end);
    try expectEqual(null, tokens.items[0].value);
}

test "scan integer" {
    const allocator = std.testing.allocator;
    var tokens = try scan_line("1234", 0, allocator);
    defer tokens.deinit();
    try expectEqual(1, tokens.items.len);
    try expectEqual(0, tokens.items[0].start);
    try expectEqual(3, tokens.items[0].end);
    try expectEqual(1234.0, tokens.items[0].value);
}

test "scan spaces and word" {
    const allocator = std.testing.allocator;
    var tokens = try scan_line("    hello", 0, allocator);
    defer tokens.deinit();
    try expectEqual(1, tokens.items.len);
    try expectEqual(4, tokens.items[0].start);
    try expectEqual(8, tokens.items[0].end);
    try expectEqual(null, tokens.items[0].value);
}

test "title:12" {
    const allocator = std.testing.allocator;
    const source = "title:12";
    var tokens = try scan_line(source, 0, allocator);
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
    var tokens = try scan_line(source, 0, allocator);
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
    var tokens = try scan_line(source, 0, allocator);
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

test "scan_lines with empty string" {
    const allocator = std.testing.allocator;
    var lines = try scan_lines("", allocator);
    defer lines.deinit();
    try expectEqual(0, lines.items.len);
}

test "scan_lines with single line" {
    const allocator = std.testing.allocator;
    const lines = try scan_lines("hello", allocator);
    defer free_lines(lines);
    try expectEqual(1, lines.items.len);
    try expectEqual(1, lines.items[0].items.len);
    try expectEqual(0, lines.items[0].items[0].start);
    try expectEqual(4, lines.items[0].items[0].end);
    try expectEqual(null, lines.items[0].items[0].value);
}

test "scan_lines with multiple lines" {
    const allocator = std.testing.allocator;
    const source = "line1\nline2\nline3";
    const lines = try scan_lines(source, allocator);
    defer free_lines(lines);
    try expectEqual(3, lines.items.len);

    try expectEqual(1, lines.items[0].items.len);
    try expectEqual(0, lines.items[0].items[0].start);
    try expectEqual(4, lines.items[0].items[0].end);
    try expectEqual(null, lines.items[0].items[0].value);

    try expectEqual(1, lines.items[1].items.len);
    try expectEqual(6, lines.items[1].items[0].start);
    try expectEqual(10, lines.items[1].items[0].end);
    try expectEqual(null, lines.items[1].items[0].value);

    try expectEqual(1, lines.items[2].items.len);
    try expectEqual(12, lines.items[2].items[0].start);
    try expectEqual(16, lines.items[2].items[0].end);
    try expectEqual(null, lines.items[2].items[0].value);
}

test "scan_lines with some blank lines" {
    const allocator = std.testing.allocator;
    const source = "line1\n\nline2\nline3\n\n";
    const lines = try scan_lines(source, allocator);
    defer free_lines(lines);
    try expectEqual(5, lines.items.len);

    try expectEqual(1, lines.items[0].items.len);
    try expectEqual(0, lines.items[0].items[0].start);
    try expectEqual(4, lines.items[0].items[0].end);
    try expectEqual(null, lines.items[0].items[0].value);

    try expectEqual(0, lines.items[1].items.len); // blank line

    try expectEqual(1, lines.items[2].items.len);
    try expectEqual(7, lines.items[2].items[0].start);
    try expectEqual(11, lines.items[2].items[0].end);
    try expectEqual(null, lines.items[2].items[0].value);

    try expectEqual(1, lines.items[3].items.len);
    try expectEqual(13, lines.items[3].items[0].start);
    try expectEqual(17, lines.items[3].items[0].end);
    try expectEqual(null, lines.items[3].items[0].value);

    try expectEqual(0, lines.items[4].items.len); // blank line
}

test "print_line with empty line" {
    const allocator = std.testing.allocator;
    const source = "";
    var tokens = try scan_line(source, 0, allocator);
    defer tokens.deinit();

    var buffer = std.ArrayList(u8).init(allocator);
    defer buffer.deinit();
    try print_line(buffer.writer(), source, tokens, 0, .light);

    try expectEqual(1, buffer.items.len);
    try expectEqual('\n', buffer.items[0]);
}

test "print_line with colored output" {
    const allocator = std.testing.allocator;
    const source = "hello:123";
    var tokens = try scan_line(source, 0, allocator);
    defer tokens.deinit();

    var buffer = std.ArrayList(u8).init(allocator);
    defer buffer.deinit();
    try print_line(buffer.writer(), source, tokens, 0, .light);

    const expected = "\x1b[37mhello\x1b[0m\x1b[34m:\x1b[0m\x1b[32m123\x1b[0m\n";
    try std.testing.expectEqualStrings(expected, buffer.items);
}

test "print_line with mono theme" {
    const allocator = std.testing.allocator;
    const source = "hello:123";
    var tokens = try scan_line(source, 0, allocator);
    defer tokens.deinit();

    var buffer = std.ArrayList(u8).init(allocator);
    defer buffer.deinit();
    try print_line(buffer.writer(), source, tokens, 0, .mono);

    const expected = "hello:123\n";
    try std.testing.expectEqualStrings(expected, buffer.items);
}

test "print_lines with empty lines" {
    const allocator = std.testing.allocator;
    const source = "word1\n\nword2";
    const lines = try scan_lines(source, allocator);
    defer free_lines(lines);

    var buffer = std.ArrayList(u8).init(allocator);
    defer buffer.deinit();
    try print_lines(buffer.writer(), source, lines, true, .mono);

    const expected = "1 word1\n2 \n3 word2\n";
    try std.testing.expectEqualStrings(expected, buffer.items);
}
