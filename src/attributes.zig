// zig fmt: off
pub const Attributes = struct {
    pub const RESET:      u16 = 1 << 1;
    pub const BOLD:       u16 = 1 << 2;
    pub const DIM:        u16 = 1 << 3;
    pub const UNDERLINED: u16 = 1 << 5;
    pub const REVERSE:    u16 = 1 << 12;
    pub const HIDDEN:     u16 = 1 << 13;
};
// zig fmt: on
