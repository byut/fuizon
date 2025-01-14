pub const event = @import("event.zig");
pub const Event = event.Event;
pub const KeyEvent = event.KeyEvent;
pub const KeyEventType = event.KeyEventType;
pub const ResizeEvent = event.ResizeEvent;
pub const KeyModifiers = event.KeyModifiers;

pub const anchors = @import("anchors.zig");
pub const VerticalAnchor = anchors.VerticalAnchor;
pub const HorizontalAnchor = anchors.HorizontalAnchor;

pub const attributes = @import("attributes.zig");
pub const Attributes = attributes.Attributes;

pub const color = @import("color.zig");
pub const Color = color.Color;
pub const RgbColor = color.RgbColor;
pub const AnsiColor = color.AnsiColor;

pub const style = @import("style.zig");
pub const Style = style.Style;

pub const frame = @import("frame.zig");
pub const Frame = frame.Frame;
pub const FrameCell = frame.FrameCell;

test "root" {
    try @import("std").testing.expect(true);
}
