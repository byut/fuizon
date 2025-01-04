pub const event = @import("event.zig");
pub const Event = event.Event;
pub const KeyEvent = event.KeyEvent;
pub const KeyEventType = event.KeyEventType;
pub const ResizeEvent = event.ResizeEvent;

test "root" {
    try @import("std").testing.expect(true);
}
