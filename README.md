# zig-php-ext

Zig-php-ext is a framework for creating PHP extensions using the Zig programming language. It's 
designed, first and foremost, with ease of development in mind. Set-up is simple. The framework
has no dependencies aside from the Zig compiler and PHP itself. You do not need to install the 
C tool-chain or phpize. Deployment of your extension will be easy too. Thanks to Zig's powerful
cross-platform capability, you can compile for a Linux server from a Mac or a Windows PC.

The goal of the project is to enable everyday PHP programmers to create custom extensions in a
matter of hours.

Zig-php-ext is designed for Zig 0.17.0 and supports PHP 8.1 through 8.6.

## Getting started

First, install the Zig compiler if it's not on your computer. The easiest way is using 
[zvm](https://github.com/tristanisham/zvm#installing-zvm), the Zig Version Manager.

Then download the latest package from this project's 
[release page](https://github.com/chung-leong/zig-php-ext/releases). Unzip it into a directory,
change to it in a terminal and run `php build.php`. The build script will download the PHP SDK 
for the current version of PHP and compile the default "hello" extension. After a minute or so,
you should see the path of the end product:

```
Building extension at optimization level "ReleaseSmall" for PHP 8.5 (linux/x86_64)
Created 1 dynamic-linked library:

extensions/8.5/php_hello.so
```

You can test the extension with following command:

```sh
php -d extension=extensions/8.5/php_hello.so -r "greet('Alice');"
```
```
Hello, Alice!
```

## Compiling for different platforms

Run `php build.php menu` to activate the build menu:

![menu](img/menu.png)

It lets you to select multiple platforms to compile the extension for:

![menu](img/menu-os.png)

Note: On Windows, the menu only works when you launch it in Git Bash.

## Examining the code

Let us look at the actual code. First, the extension's entry point:

**src/main.zig**:

```zig
const std = @import("std");

const config = @import("config");

const php = @import("php/root.zig");

var module: php.Module.Custom(@import("extension.zig"), .{
    // ext name and version are extract from composer.json by build.zig
    .name = config.ext_name,
    .version = config.ext_version,
}) = .init();
comptime {
    module.register();
}

pub fn DllMain(
    _: std.os.windows.HINSTANCE,
    _: std.os.windows.DWORD,
    _: std.os.windows.LPVOID,
) std.os.windows.BOOL {
    return if (php.linkWindowsImports()) |_| .TRUE else |_| .FALSE;
}
```

`Module.Custom` is a parametric struct type for defining an extension. It accepts a
namespace and an option struct as arguments. The namespace is defined in `extension.zig`. This 
is the file that you'll be modifying for your own extension.

**src/extension.zig**:

```zig
const php = @import("php/root.zig");
const getter = php.IniEntry.getter;
const setter = php.IniEntry.setter;

pub const @"export CONSTANT" = "Hello world";
pub const @"export Enum" = enum { hello, world };

pub fn @"call greet"(self: *@This(), args: struct {
    name: []const u8,
}) !void {
    php.print("{s}, {s}!\n", .{ self.greeting, args.name });
}

pub const @"get greeting" = getter(@This(), .greeting);
pub const @"set greeting" = setter(@This(), .greeting);

greeting: [:0]const u8 = "Hello",
```

The function we called earlier, `greet()`, is defined by `@"call greet"()`. The `@"call` prefix indicates
a function is meant to be used in PHP. Arguments from PHP are contained in a struct. In this case
we have a single one, which is expected to be a string.

The `self` argument points to a struct containing the extension's settings. If we run the following command:

```sh
php -d extension=extensions/8.5/php_hello.so -r "ini_set('hello.greeting', 'Hi'); greet('Alice');"
```

We would get this:

```
Ahoj, Alice!
```

Ini entries are accessed through getters and setters. We use `php.IniEntry.getter` and
`php.IniEntry.setter` to generate generic functions for this purpose. The above declarations are
equivalent to:

```zig
pub fn @"get greeting"(self: *@This()) [:0]const u8 {
    return self.greeting;
}

pub fn @"set greeting"(self: *@This(), value: [:0]const u8) void {
    self.greeting = value;
}
```

## Receiving arguments of different types

We can use Zig [tagged unions](https://ziglang.org/documentation/0.17.0/#Tagged-union) to receive 
arguments of different types:

```zig
pub fn @"call greet"(self: *@This(), args: struct {
    recipient: union(enum) {
        one: []const u8,
        multiple: [][]const u8,
    },
}) !void {
    switch (args.recipient) {
        .one => |name| php.print("{s}, {s}!\n", .{ self.greeting, name }),
        .multiple => |names| for (names) |name| {
            php.print("{s}, {s}!\n", .{ self.greeting, name });
        },
    }
}
```
```php
<?php

greet('Alice');
greet([ 'Bob', 'Charlie', 'Dan' ]);

?>
```
```
Hello, Alice!
Hello, Bob!
Hello, Charlie!
Hello, Dan!
```

## Reporting error

Use Zig's standard error mechanism to trigger exceptions on the PHP side:

```zig
pub fn @"call greet"(self: *@This(), args: struct {
    recipient: union(enum) {
        one: []const u8,
        multiple: [][]const u8,
    },
}) !void {
    switch (args.recipient) {
        .one => |name| php.print("{s}, {s}!\n", .{ self.greeting, name }),
        .multiple => |names| for (names) |name| {
            if (std.mem.eql(u8, name, "Dan")) {
                return error.TheManIsDeaf;
            }
            php.print("{s}, {s}!\n", .{ self.greeting, name });
        },
    }
}
```
```php
<?php

greet('Alice');
greet([ 'Bob', 'Charlie', 'Dan' ]);

?>
```
```
Hello, Alice!
Hello, Bob!
Hello, Charlie!
PHP Fatal error:  Uncaught Exception: the man is deaf in /home/cleong/zig-php-ext/examples/hello/test.php:4
```

