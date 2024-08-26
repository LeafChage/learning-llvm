const std = @import("std");
const ascii = @import("std").ascii;
const mem = @import("std").mem;
const String = @import("./string.zig");

pub const Token = union(enum) {
    EOF: void,
    Def: void,
    Extern: void,
    Identifier: []const u8,
    Number: f32,
    Token: u8,

    const Self = @This();
    pub fn eql(left: Self, right: Self) bool {
        return switch (left) {
            .EOF => switch (right) {
                .EOF => true,
                else => false,
            },
            .Def => switch (right) {
                .Def => true,
                else => false,
            },
            .Extern => switch (right) {
                .Extern => true,
                else => false,
            },
            .Token => switch (right) {
                .Token => left.Token == right.Token,
                else => false,
            },
            .Identifier => switch (right) {
                .Identifier => std.mem.eql(u8, left.Identifier, right.Identifier),
                else => false,
            },
            .Number => switch (right) {
                .Number => left.Number == right.Number,
                else => false,
            },
        };
    }

    pub fn unwrapToken(self: Self) u8 {
        return switch (self) {
            .Token => self.Token,
            else => @panic("it's not Token.Token"),
        };
    }

    pub fn unwrapIdentifier(self: Self) []const u8 {
        return switch (self) {
            .Identifier => self.Identifier,
            else => @panic("it's not Token.Identifier"),
        };
    }

    // custom format
    pub fn format(self: Self, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        _ = options;

        try switch (self) {
            .EOF => writer.print("{s: <15}eof", .{"EOF"}),
            .Def => writer.print("{s: <15}def", .{"def"}),
            .Extern => writer.print("{s: <15}extern", .{"extern"}),
            .Token => writer.print("{s: <15}{s}", .{ "token", [_]u8{self.Token} }),
            .Identifier => writer.print("{s: <15}{s}", .{ "identifier", self.Identifier }),
            .Number => writer.print("{s: <15}{d}", .{ "number", self.Number }),
        };
    }
};
test "token eql" {
    try std.testing.expect(Token.eql(Token.EOF, Token.EOF));
    try std.testing.expect(Token.eql(Token.Def, Token.Def));
    try std.testing.expect(Token.eql(Token.Extern, Token.Extern));
    try std.testing.expect(Token.eql(Token{ .Identifier = "hello" }, Token{ .Identifier = "hello" }));
    try std.testing.expect(Token.eql(Token{ .Token = '!' }, Token{ .Token = '!' }));
    try std.testing.expect(Token.eql(Token{ .Number = 1 }, Token{ .Number = 1 }));
}
