const std = @import("std");
const ascii = @import("std").ascii;
const mem = @import("std").mem;
const String = @import("./string.zig");
const Token = @import("./token.zig").Token;

pub const Scanner = struct {
    i: usize,
    src: []const u8,
    const Self = @This();

    pub fn init(src: []const u8) Self {
        return Self{ .i = 0, .src = src };
    }

    fn skipNext(self: *Self) void {
        self.i += 1;
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
        if (!ascii.isAlphabetic(self.check())) {
            return null;
        }

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
        return Token{ .Identifier = id_str };
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

    fn token(self: *Self) !Token {
        const v = self.next();
        return Token{ .Token = v };
    }

    fn comment(self: *Self) ![]const u8 {
        var str = try String.init("");
        self.skipNext();

        var v = self.next();
        while (!(v == '\n' or v == '\r' or v == '0')) : (v = self.next()) {
            try str.add(v);
        }
        return str.str();
    }

    pub fn nextToken(self: *Self) !Token {
        self.skipWhiteSpace();
        if (try self.identifier() orelse try self.number()) |t| {
            return t;
        }
        if (self.check() == 0) {
            return Token.EOF;
        }
        if (self.check() == '#') {
            _ = try self.comment();
            self.skipNext();
            return self.nextToken();
        } else {
            return self.token();
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

test "identifier" {
    const src = "name ";
    var scanner = Scanner.init(src);
    const v: Token = try scanner.identifier() orelse @panic("unexpected");
    try std.testing.expectEqualDeep(v, Token{ .Identifier = "name" });
}

test "not identifier" {
    const src = "123.1";
    var scanner = Scanner.init(src);
    const v = try scanner.identifier();
    try std.testing.expectEqual(v, null);
}

test "number" {
    const src = "123";
    var scanner = Scanner.init(src);
    const v: Token = try scanner.number() orelse @panic("unexpected");
    try std.testing.expectEqualDeep(v, Token{ .Number = @as(f32, 123) });
}

test "float" {
    const src = "123.1";
    var scanner = Scanner.init(src);
    const v: Token = try scanner.number() orelse @panic("unexpected");
    try std.testing.expectEqualDeep(v, Token{ .Number = @as(f32, 123.1) });
}

test "nextToken" {
    const src = "##........ \n extern  def name (";
    var scanner = Scanner.init(src);
    try std.testing.expectEqual(try scanner.nextToken(), Token.Extern);
    try std.testing.expectEqual(try scanner.nextToken(), Token.Def);
    try std.testing.expectEqualDeep(try scanner.nextToken(), Token{ .Identifier = "name" });
    try std.testing.expectEqualDeep(try scanner.nextToken(), Token{ .Token = '(' });
    try std.testing.expectEqualDeep(try scanner.nextToken(), Token.EOF);
}
