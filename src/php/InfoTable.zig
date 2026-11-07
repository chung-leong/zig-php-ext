//! Empty structure representing a table in the phpinfo page.
const php = @import("root.zig");
const pi = php.imports;

/// Start the table.
pub fn init() @This() {
    pi.php_info_print_table_start();
    return .{};
}
/// Make the end of the table.
pub fn end(_: *@This()) void {
    pi.php_info_print_table_end();
}
/// Add two headers to the table.
pub fn addTwoHeaders(_: *@This(), col0: [:0]const u8, col1: [:0]const u8) void {
    pi.php_info_print_table_header(2, col0.ptr, col1.ptr);
}
/// Add three headers to the table
pub fn addThreeHeaders(_: *@This(), col0: [:0]const u8, col1: [:0]const u8, col2: [:0]const u8) void {
    pi.php_info_print_table_header(3, col0.ptr, col1.ptr, col2.ptr);
}
/// Add a single header to a table that has two columns.
pub fn addHeaderSpanTwo(_: *@This(), header: [:0]const u8) void {
    pi.php_info_print_table_colspan_header(2, header);
}
/// Add a single header to a table that has three columns.
pub fn addHeaderSpanThree(_: *@This(), header: [:0]const u8) void {
    pi.php_info_print_table_colspan_header(3, header);
}
/// Add a row with two columns to the table.
pub fn addTwoColumns(_: *@This(), col0: [:0]const u8, col1: [:0]const u8) void {
    pi.php_info_print_table_row(2, col0.ptr, col1.ptr);
}
/// Add a row with three columns to the table.
pub fn addThreeColumns(_: *@This(), col0: [:0]const u8, col1: [:0]const u8, col2: [:0]const u8) void {
    pi.php_info_print_table_row(3, col0.ptr, col1.ptr, col2.ptr);
}
