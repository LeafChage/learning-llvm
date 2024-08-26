const std = @import("std");
const _scanner = @import("scanner.zig");
const Scanner = _scanner.Scanner;
const Token = @import("token.zig").Token;
const ast = @import("ast.zig");

fn logError(comptime ReturnType: type, msg: []const u8) ?ReturnType {
    std.debug.print("{s} \n", .{msg});
    return null;
}

const Parser = struct {
    binaryOperatorPrecedence: std.AutoHashMap(u8, isize),
    currentToken: Token,
    scanner: *Scanner,

    const Self = @This();
    pub fn init(scanner: *Scanner) Self {
        var hash = std.AutoHashMap(u8, isize).init(std.testing.allocator);
        hash.put('<', 10) catch unreachable;
        hash.put('+', 20) catch unreachable;
        hash.put('-', 20) catch unreachable;
        hash.put('*', 40) catch unreachable;

        var parser = Self{
            .binaryOperatorPrecedence = hash,
            .currentToken = Token.EOF,
            .scanner = scanner,
        };

        parser.moveNext();
        return parser;
    }

    pub fn deinit(self: *Self) void {
        self.binaryOperatorPrecedence.deinit();
    }

    fn getTokenPrecedence(self: *Self) isize {
        if (!self.nextIsAscii()) {
            return -1;
        }
        const t = switch (self.currentToken) {
            .Token => self.currentToken.Token,
            else => unreachable,
        };
        const prec = self.binaryOperatorPrecedence.get(t) orelse 0;
        return if (prec <= 0) -1 else prec;
    }

    fn moveNext(self: *Self) void {
        const n = self.scanner.nextToken() catch @panic("scanner is empty");
        std.debug.print("{s}\n", .{n});
        self.currentToken = n;
    }

    fn nextIs(self: Self, target: Token) bool {
        return Token.eql(self.currentToken, target);
    }

    fn nextIsAscii(self: Self) bool {
        return switch (self.currentToken) {
            .Token => std.ascii.isASCII(self.currentToken.Token),
            else => false,
        };
    }

    // numberexpr ::= number
    fn parseNumber(self: *Self) ?ast.ExprAst {
        const num = switch (self.currentToken) {
            .Number => ast.ExprAst{ .Number = ast.NumberExpr.init(self.currentToken.Number) },
            else => unreachable,
        };
        self.moveNext();
        return num;
    }

    // parenexpr ::= '(' expression ')'
    fn parseParenExpr(self: *Self) ?ast.ExprAst {
        if (!self.nextIs(Token{ .Token = '(' })) {
            return logError(ast.ExprAst, "expected '('");
        }

        const v = self.parseExpression() orelse {
            return null;
        };

        self.moveNext();
        if (!self.nextIs(Token{ .Token = ')' })) {
            return logError(ast.ExprAst, "expected ')'");
        }

        return v;
    }

    // identifierexpr
    //   ::= identifier
    //   ::= identifier '(' expression* ')' // function call
    fn parseIdentifierExpr(self: *Self) ?ast.ExprAst {
        const name = self.currentToken.unwrapIdentifier();
        self.moveNext();

        if (!self.nextIs(Token{ .Token = '(' })) {
            return ast.ExprAst{ .Variable = ast.VariableExpr.init(name) };
        }

        self.moveNext();
        var args = std.ArrayList(ast.ExprAst).init(std.testing.allocator);
        defer args.deinit();

        if (!self.nextIs(Token{ .Token = ')' })) {
            while (true) {
                const arg = self.parseExpression() orelse {
                    return null;
                };
                args.append(arg) catch {
                    return null;
                };

                if (self.nextIs(Token{ .Token = ')' })) {
                    break;
                }
                if (!self.nextIs(Token{ .Token = ',' })) {
                    return logError(ast.ExprAst, "Expected ')' or ',' in argument list");
                }
                self.moveNext();
            }
        }
        self.moveNext();
        return ast.ExprAst{ .Call = ast.CallExpr.init(name, args.items) };
    }

    // primary
    //   ::= identifierexpr
    //   ::= numberexpr
    //   ::= parenexpr
    fn parsePrimary(self: *Self) ?ast.ExprAst {
        return switch (self.currentToken) {
            .Identifier => self.parseIdentifierExpr(),
            .Number => self.parseNumber(),
            Token{ .Token = '(' } => self.parseParenExpr(),
            else => logError(ast.ExprAst, "unknown token when expecting an expression"),
        };
    }

    // expression
    //   ::= primary binoprhs
    fn parseExpression(self: *Self) ?ast.ExprAst {
        return if (self.parsePrimary()) |left| {
            return self.parseBinOpRhs(0, left);
        } else {
            return null;
        };
    }

    // binoprhs
    //   ::= ('+' primary)*
    fn parseBinOpRhs(self: *Self, currentPrecedence: isize, left: ast.ExprAst) ?ast.ExprAst {
        var leftNode = left;
        while (true) {
            const prec = self.getTokenPrecedence();
            if (prec < currentPrecedence) {
                return leftNode;
            }

            const binOp = self.currentToken.unwrapToken();
            self.moveNext();

            var rightNode = if (self.parsePrimary()) |right| right else {
                return null;
            };

            const nextPrec = self.getTokenPrecedence();
            if (prec < nextPrec) {
                // move forward right node
                rightNode = if (self.parseBinOpRhs(prec + 1, rightNode)) |right| right else {
                    return null;
                };

                // merge left & right
                leftNode = ast.ExprAst{ .Binary = ast.BinaryExpr.init(binOp, &leftNode, &rightNode) };
            }
        }
    }

    // prototype
    //   ::= id '(' id* ')'
    fn parsePrototype(self: *Self) ?ast.PrototypeAst {
        if (!std.mem.eql(u8, @tagName(self.currentToken), "Identifier")) {
            return logError(ast.PrototypeAst, "Expected function name in prototype");
        }

        const fnName = self.currentToken.unwrapIdentifier();
        self.moveNext(); // eat fnname

        if (!self.nextIs(Token{ .Token = '(' })) {
            return logError(ast.PrototypeAst, "Expected '(' in prototype");
        }
        self.moveNext(); // eat '('
        //
        var args = std.ArrayList([]const u8).init(std.testing.allocator);
        defer args.deinit();

        while (std.mem.eql(u8, @tagName(self.currentToken), "Identifier")) {
            args.append(self.currentToken.unwrapIdentifier()) catch {
                return null;
            };
            self.moveNext();
        }

        if (!self.nextIs(Token{ .Token = ')' })) {
            return logError(ast.PrototypeAst, "Expected ')' in prototype");
        }
        self.moveNext(); // eat ')'

        return ast.PrototypeAst.init(fnName, args.items);
    }

    // definition ::= 'def' prototype expression
    fn parseDefinition(self: *Self) ?ast.FunctionAst {
        if (!self.nextIs(Token.Def)) {
            unreachable;
        }
        self.moveNext(); // eat def

        if (self.parsePrototype()) |proto| {
            if (self.parseExpression()) |e| {
                return ast.FunctionAst.init(proto, e);
            }
        }
        return null;
    }

    // definition ::= 'def' prototype expression
    fn parseExtern(self: *Self) ?ast.PrototypeAst {
        if (!self.nextIs(Token.Extern)) {
            unreachable;
        }
        self.moveNext(); // eat extern
        return self.parsePrototype();
    }

    // toplevelexpr ::= expression
    fn parseTopLevelExpr(self: *Self) ?ast.FunctionAst {
        if (self.parseExpression()) |e| {
            const proto = ast.PrototypeAst.init("", &[_][]const u8{});
            return ast.FunctionAst.init(proto, e);
        }
        return null;
    }

    /// top ::= definition | external | expression | ';'
    fn mainLoop(self: *Self) void {
        while (true) {
            switch (self.currentToken) {
                .EOF => return,
                Token{ .Token = ';' } => {
                    _ = self.moveNext();
                },
                Token.Def => {
                    _ = self.parseDefinition() orelse {
                        return;
                    };
                },
                Token.Extern => {
                    _ = self.parseExtern() orelse {
                        return;
                    };
                },
                else => {
                    _ = self.parseTopLevelExpr() orelse {
                        return;
                    };
                },
            }
        }
    }
};

test "mainLoop" {
    const src = "def foo(x y) x+foo(y, 4.0);";
    std.debug.print("src => {s}\n", .{src});
    var scanner = Scanner.init(src);
    var parse = Parser.init(&scanner);
    defer parse.deinit();
    parse.mainLoop();
}

test "mainLoop2" {
    const src = "extern sin(a)";
    std.debug.print("src => {s}\n", .{src});
    var scanner = Scanner.init(src);
    var parse = Parser.init(&scanner);
    defer parse.deinit();
    parse.mainLoop();
}
