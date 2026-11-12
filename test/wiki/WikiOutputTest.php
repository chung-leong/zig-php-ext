<?php declare(strict_types=1);

require_once __DIR__ . '/../ExtensionTestCase.php';

final class WikiOutputTest extends ExtensionTestCase
{   
    public function testPrint(): void
    {
        $lines = $this->runTest("output-print", "test.php");
        $this->assertSame(<<<OUTPUT
        "Hello world", 0xdeadbeef 3.141592653589793 false .{ .x = 123, .y = 456 }
        OUTPUT, implode(PHP_EOL, $lines));
    }

    public function testWrite(): void
    {
        $lines = $this->runTest("output-write", "test.php");
        $this->assertSame(<<<OUTPUT
        Hello world
        written = 12
        OUTPUT, implode(PHP_EOL, $lines));
    }
}
