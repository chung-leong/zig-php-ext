<?php declare(strict_types=1);

require_once __DIR__ . '/ExtensionTestCase.php';

final class ConstantTest extends ExtensionTestCase
{   
    public function testSimpleConstant(): void
    {
        $lines = $this->runTest("constant", "simple.php");
        $this->assertSame("bool = 1", $lines[0]);
        $this->assertSame("int = 1234", $lines[1]);
        $this->assertSame("float = 3.1415926535898", $lines[2]);
    }

    public function testStringConstant(): void
    {
        $lines = $this->runTest("constant", "string.php");
        $this->assertSame("string = Hello world", $lines[0]);
    }

    public function testArrayConstant(): void
    {
        $lines = $this->runTest("constant", "array.php");
        $this->assertSame(<<<OUTPUT
        Array
        (
            [0] => 1
            [1] => 2
            [2] => 3
            [3] => 4
        )
        Array
        (
            [0] => Hello
            [1] => world
        )
        stdClass Object
        (
            [cow] => 123
            [pig] => 456
        )
        OUTPUT, implode(PHP_EOL, $lines));
    }

    public function testFindConstant(): void
    {
        $lines = $this->runTest("constant", "show.php");
        $this->assertSame("Hello world", $lines[0]);
        $this->assertSame("1234", $lines[1]);
        $this->assertSame("3.1415926535898", $lines[2]);
    }

    public function testEnumConstant(): void
    {
        $lines = $this->runTest("constant", "enum.php");
        $this->assertSame(<<<OUTPUT
        exists
        hello = 0
        world = 1
        alpha = 123
        beta = 456
        gamma = 789
        a = ConstType Enum:int
        (
            [name] => alpha
            [value] => 123
        )
        b = ConstType Enum:int
        (
            [name] => beta
            [value] => 456
        )
        OUTPUT, implode(PHP_EOL, $lines));
    }

    public function testPackedStructConstant(): void
    {
        $lines = $this->runTest("constant", "packed.php");
        $this->assertSame(<<<OUTPUT
        option_a = 1
        option_b = 2
        option_c = 4
        option_a = 1
        option_b = 2
        OUTPUT, implode(PHP_EOL, $lines));
    }

    public function testEnumWithConstant(): void {
        $lines = $this->runTest("constant", "enum-with-const.php");
        echo implode(PHP_EOL, $lines);
    }
}
