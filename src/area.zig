const std = @import("std");
const fuizon = @import("fuizon.zig");

const Coordinate = fuizon.coordinate.Coordinate;

/// ...
pub const Area = struct {
    width: u16,
    height: u16,
    origin: Coordinate,

    /// Returns the topmost coordinate of the area.
    pub fn top(self: Area) u16 {
        return self.origin.y;
    }

    /// Returns the bottommost coordinate of the area.
    pub fn bottom(self: Area) u16 {
        return self.height + self.origin.y;
    }

    /// Returns the leftmost coordinate of the area.
    pub fn left(self: Area) u16 {
        return self.origin.x;
    }

    /// Returns the rightmost coordinate of the area.
    pub fn right(self: Area) u16 {
        return self.width + self.origin.x;
    }
};

//
// Tests
//

test "top() should return the topmost coordinate" {
    try std.testing.expectEqual(5, (Area{
        .width = 5,
        .height = 9,
        .origin = .{ .x = 1, .y = 5 },
    }).top());
}

test "bottom() should return the bottommost coordinate" {
    try std.testing.expectEqual(14, (Area{
        .width = 5,
        .height = 9,
        .origin = .{ .x = 1, .y = 5 },
    }).bottom());
}

test "left() should return the leftmost coordinate" {
    try std.testing.expectEqual(1, (Area{
        .width = 5,
        .height = 9,
        .origin = .{ .x = 1, .y = 5 },
    }).left());
}

test "right() should return the rightmost coordinate" {
    try std.testing.expectEqual(6, (Area{
        .width = 5,
        .height = 9,
        .origin = .{ .x = 1, .y = 5 },
    }).right());
}
