pub const NumberExpr = struct {
    val: f32,
    pub fn init(val: f32) @This() {
        return @This(){ .val = val };
    }
};

pub const VariableExpr = struct {
    name: []const u8,
    pub fn init(name: []const u8) @This() {
        return @This(){ .name = name };
    }
};

pub const BinaryExpr = struct {
    op: u8,
    right: *ExprAst,
    left: *ExprAst,
    pub fn init(op: u8, right: *ExprAst, left: *ExprAst) @This() {
        return @This(){
            .op = op,
            .right = right,
            .left = left,
        };
    }
};

pub const CallExpr = struct {
    callee: []const u8,
    args: []ExprAst,

    pub fn init(callee: []const u8, args: []ExprAst) @This() {
        return @This(){
            .callee = callee,
            .args = args,
        };
    }
};

pub const ExprAst = union(enum) {
    Number: NumberExpr,
    Variable: VariableExpr,
    Binary: BinaryExpr,
    Call: CallExpr,
};

pub const PrototypeAst = struct {
    name: []const u8,
    args: [][]const u8,
    pub fn init(name: []const u8, args: [][]const u8) @This() {
        return @This(){
            .name = name,
            .args = args,
        };
    }
};

pub const FunctionAst = struct {
    prototype: PrototypeAst,
    body: ExprAst,
    pub fn init(prototype: PrototypeAst, body: ExprAst) @This() {
        return @This(){
            .prototype = prototype,
            .body = body,
        };
    }
};
