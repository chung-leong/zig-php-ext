<?php declare(strict_types=1);

require_once __DIR__ . '/ExtensionTestCase.php';

final class ConstantTest extends ExtensionTestCase
{   
    public function testSimpleConstant(): void
    {
        $lines = $this->runTest("constants", "simple.php");
        $this->assertSame("bool = 1", $lines[0]);
        $this->assertSame("int = 1234", $lines[1]);
        $this->assertSame("float = 3.1415926535898", $lines[2]);
    }

    public function testStringConstant(): void
    {
        $lines = $this->runTest("constants", "string.php");
        $this->assertSame("string = Hello world", $lines[0]);
    }

    public function testEnumConstants(): void
    {
        $lines = $this->runTest("constants", "enum.php");
        $this->assertSame("hello = 0", $lines[0]);
        $this->assertSame("world = 1", $lines[1]);
    }

    public function testPackedStructConstants(): void
    {
        $lines = $this->runTest("constants", "flags.php");
        $this->assertSame("option_a = 1", $lines[0]);
        $this->assertSame("option_b = 2", $lines[1]);
        $this->assertSame("option_c = 4", $lines[2]);
        $this->assertSame("option_a = 1", $lines[3]);
        $this->assertSame("option_b = 2", $lines[4]);
        $this->assertSame("_ => undefined", $lines[5]);
    }

    public function testArrayConstant(): void
    {
        $lines = $this->runTest("constants", "array.php");
        echo implode("\n", $lines);
    }

    public function testFindConstant(): void
    {
        $lines = $this->runTest("constants", "show.php");
        $this->assertSame("Hello world", $lines[0]);
        $this->assertSame("0", $lines[1]);
        $this->assertSame("1", $lines[2]);
    }
}
