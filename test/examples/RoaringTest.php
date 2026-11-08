<?php declare(strict_types=1);

require_once __DIR__ . '/../ExtensionTestCase.php';

final class RoaringTest extends ExtensionTestCase
{   
    public function testBasicOperation(): void
    {
        $lines = $this->runTest("roaring", "basic.php");
        $this->assertSame(<<<OUTPUT
        1 => 1
        4000 => 1
        4001 =>
        OUTPUT, implode(PHP_EOL, $lines));
    }

    public function testProperties(): void
    {
        $lines = $this->runTest("roaring", "properties.php");
        $this->assertSame(<<<OUTPUT
        zig\\roaring\\Bitmap Object
        (
            [frozen] =>
            [1] => 1
            [2] => 1
            [3] => 1
            [4000] => 1
        )
        OUTPUT, implode(PHP_EOL, $lines));
    }

    public function testFreezing(): void
    {
        $lines = $this->runTest("roaring", "freeze.php");
        $this->assertSame(<<<OUTPUT
        3 => 1
        78900 =>
        frozen
        zig\\roaring\\Bitmap Object
        (
            [frozen] => 1
            [1] => 1
            [2] => 1
            [3] => 1
            [4] => 1
            [4000] => 1
        )
        OUTPUT, implode(PHP_EOL, $lines));
    }

    public function testComparison(): void
    {
        $lines = $this->runTest("roaring", "compare.php");
        $this->assertSame(<<<OUTPUT
        equal = 1
        equal =
        OUTPUT, implode(PHP_EOL, $lines));
    }

    public function testBitwiseOperators(): void
    {
        $lines = $this->runTest("roaring", "operators.php");
        $this->assertSame(<<<OUTPUT
        zig\\roaring\\Bitmap Object
        (
            [frozen] =>
            [1] => 1
            [3] => 1
        )
        zig\\roaring\\Bitmap Object
        (
            [frozen] =>
            [1] => 1
            [2] => 1
            [3] => 1
            [4] => 1
            [4000] => 1
            [4001] => 1
        )
        zig\\roaring\\Bitmap Object
        (
            [frozen] =>
            [2] => 1
            [4] => 1
            [4000] => 1
            [4001] => 1
        )
        OUTPUT, implode(PHP_EOL, $lines));
    }

    public function testStringCasting(): void
    {
        $lines = $this->runTest("roaring", "string.php");
        $this->assertSame(<<<OUTPUT
        length = 19
        zig\\roaring\\Bitmap Object
        (
            [frozen] => 1
            [1] => 1
            [2] => 1
            [3] => 1
            [47] => 1
            [4000] => 1
        )
        OUTPUT, implode(PHP_EOL, $lines));
    }
}
