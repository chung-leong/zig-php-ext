<?php declare(strict_types=1);

require_once __DIR__ . '/ExtensionTestCase.php';

final class ConfigTest extends ExtensionTestCase
{   
    public function testCustomConfig(): void
    {
        $lines = $this->runTest("custom-config", "print.php");
        $this->assertSame(<<<OUTPUT
        ext_name = custom-config
        ext_version = 0.1.0
        cfg_string = Hello world
        cfg_int = 1234
        cfg_float = 0.1234
        cfg_bool = true
        cfg_flag = .{ .alpha = true, .beta = true, .gamma = false }
        some_enum = .cantaloupe
        OUTPUT, implode(PHP_EOL, $lines));
    }
}
