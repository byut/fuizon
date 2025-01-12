pub const event = @import("event.zig");
pub const Event = event.Event;
pub const KeyEvent = event.KeyEvent;
pub const KeyEventType = event.KeyEventType;
pub const ResizeEvent = event.ResizeEvent;
pub const KeyModifiers = event.KeyModifiers;

pub const color = @import("color.zig");
pub const Color = color.Color;
pub const RgbColor = color.RgbColor;
pub const AnsiColor = color.AnsiColor;

test "root" {
    try @import("std").testing.expect(true);
}
