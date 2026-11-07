//! Data structure holding a callable value.
//!
//! `value` can be a string, a closure object, or a two-element array.
const php = @import("root.zig");
const Value = php.Value;

value: Value,
