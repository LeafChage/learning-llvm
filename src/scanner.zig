const std = @import("std");
const ascii = @import("std").ascii;
const mem = @import("std").mem;
const String = @import("./string.zig");

const IdentifierStr = []const u8;
const NumVal = f32;

const Token = union(enum) {
    EOF: void,
    Def: void,
    Extern: void,
    Identifer: IdentifierStr,
    Number: NumVal,
};

pub const Scanner = struct {
    i: usize,
    src: []const u8,
    const Self = @This();

    pub fn init(src: []const u8) Self {
        return Self{ .i = 0, .src = src };
    }

    fn next(self: *Self) u8 {
        if (self.i < self.src.len) {
            const v = self.src[self.i];
            self.i += 1;
            return v;
        } else {
            return 0;
        }
    }

    fn check(self: Self) u8 {
        if (self.i < self.src.len) {
            return self.src[self.i];
        } else {
            return 0;
        }
    }

    fn skipWhiteSpace(self: *Self) void {
        while (ascii.isWhitespace(self.check())) {
            _ = self.next();
        }
    }

    fn identifier(self: *Self) !?Token {
        var id = try String.init("");
        while (ascii.isAlphanumeric(self.check())) {
            try id.add(self.next());
        }
        if (id.length() == 0) {
            return null;
        }
        const id_str = id.str();
        if (mem.eql(u8, id_str, "def")) {
            return Token.Def;
        }
        if (mem.eql(u8, id_str, "extern")) {
            return Token.Extern;
        }
        return Token{ .Identifer = id_str };
    }

    fn number(self: *Self) !?Token {
        var numStr = try String.init("");
        while (ascii.isDigit(self.check()) or self.check() == '.') {
            try numStr.add(self.next());
        }
        if (numStr.length() == 0) {
            return null;
        }
        return Token{ .Number = try std.fmt.parseFloat(f32, numStr.str()) };
    }

    fn comment(self: *Self) void {
        if (self.check() == '#') {
            _ = self.next();
            var v = self.next();
            while (!(v == '\n' or v == '\r' or v == '0')) : (v = self.next()) {}
        }
    }

    pub fn nextToken(self: *Self) !Token {
        self.skipWhiteSpace();
        if (try self.identifier() orelse try self.number()) |token| {
            return token;
        } else {
            self.comment();
            if (self.next() == '0') {
                return Token.EOF;
            } else {
                return self.nextToken();
            }
        }
    }
};

test "def" {
    const src = "def ";
    var scanner = Scanner.init(src);
    const v = try scanner.identifier();
    try std.testing.expectEqual(v, Token.Def);
}

test "extern" {
    const src = "extern ";
    var scanner = Scanner.init(src);
    const v = try scanner.identifier();
    try std.testing.expectEqual(v, Token.Extern);
}

// test "identifier" {
//     const src = "name ";
//     var scanner = Scanner.init(src);
//     const v: Token = try scanner.identifier() orelse @panic("unexpected");
//     try std.testing.expect(std.meta.eql(v, Token{ .Identifer = "name" }));
// }
//
// test "number" {
//     const src = "123";
//     var scanner = Scanner.init(src);
//     const v: Token = try scanner.number() orelse @panic("unexpected");
//     try std.testing.expect(std.meta.eql(v, Token{ .Number = @as(123, f32) }));
// }

test "nextToken" {
    const src = "##........ \n extern  def name";
    var scanner = Scanner.init(src);
    try std.testing.expectEqual(try scanner.nextToken(), Token.Extern);
    try std.testing.expectEqual(try scanner.nextToken(), Token.Def);
}
