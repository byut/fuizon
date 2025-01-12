const fuizon = @import("fuizon.zig");
const Color = fuizon.Color;

pub const Style = struct {
    foreground_color: ?Color,
    background_color: ?Color,
    underline_color: ?Color,
    attributes: u16,
};
