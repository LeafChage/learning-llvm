const std = @import("std");

buf: std.ArrayList(u8),
const Self = @This();

fn new(allocator: std.mem.Allocator) Self {
    return Self{ .buf = std.ArrayList(u8).init(allocator) };
}

pub fn length(self: Self) usize {
    return self.buf.items.len;
}

pub fn str(self: Self) []const u8 {
    return self.buf.items;
}

pub fn init(def: []const u8) !Self {
    var string = Self.new(std.heap.page_allocator);
    try string.addSlice(def);
    return string;
}

pub fn deinit(self: *Self) void {
    return self.buf.deinit();
}

pub fn add(self: *Self, v: u8) !void {
    return self.buf.append(v);
}

pub fn addSlice(self: *Self, v: []const u8) !void {
    return self.buf.appendSlice(v);
}

test "str" {
    var buf = std.ArrayList(u8).init(std.testing.allocator);
    try buf.appendSlice("hello");
    var s = Self{ .buf = buf };
    defer s.deinit();
    try std.testing.expectEqualSlices(u8, s.str(), "hello");
}

test "addSlice" {
    var s = Self.new(std.testing.allocator);
    defer s.deinit();

    try s.addSlice("hello");
    try s.addSlice("world");
    try std.testing.expectEqualSlices(u8, s.buf.items, "helloworld");
}

test "init" {
    var s = try Self.init("hello");
    defer s.deinit();
    try std.testing.expectEqualSlices(u8, s.buf.items, "hello");
}

test "length" {
    var s = try Self.init("hello");
    defer s.deinit();
    try std.testing.expectEqual(s.length(), 5);
}
