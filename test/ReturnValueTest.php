<?php declare(strict_types=1);

require_once __DIR__ . '/ExtensionTestCase.php';

final class ReturnValueTest extends ExtensionTestCase
{   
    public function testSimpleReturnValue(): void
    {
        $lines = $this->runTest("return-value", "simple.php");
        $this->assertSame("bool = 1", $lines[0]);
        $this->assertSame("int = 1234", $lines[1]);
        $this->assertSame("float = 12.5", $lines[2]);
    }

    public function testStringReturnValue(): void
    {
        $lines = $this->runTest("return-value", "string.php");
        $this->assertSame("This is a test", $lines[0]);
        $this->assertSame("Hello world", $lines[1]);
        $this->assertSame("Hello, Alice", $lines[2]);
    }   

    public function testEnumReturnValue(): void
    {
        $lines = $this->runTest("return-value", "enum.php");
        $this->assertSame(<<<OUTPUT
        enum = Animal Enum:int
        (
            [name] => dog
            [value] => 1
        )
        stdClass Object
        (
            [name] =>
            [value] => 123
        )
        OUTPUT, implode(PHP_EOL, $lines));
    }

    public function testFlagsReturnValue(): void
    {
        $lines = $this->runTest("return-value", "flags.php");
        $this->assertSame("flags = 5", $lines[0]);
    }

    public function testArrayReturnValue(): void
    {
        $lines = $this->runTest("return-value", "array.php");
        $this->assertSame(<<<OUTPUT
        Array
        (
            [0] => 1
            [1] => 2
            [2] => 3
            [3] => 4
        )
        OUTPUT, implode(PHP_EOL, $lines));
    }

    public function testVectorReturnValue(): void
    {
        $lines = $this->runTest("return-value", "vector.php");
        $this->assertSame(<<<OUTPUT
        Array
        (
            [0] => 1.5
            [1] => 2.5
            [2] => 3.5
        )
        OUTPUT, implode(PHP_EOL, $lines));
    }

    public function testOptionalReturnValue(): void
    {
        $lines = $this->runTest("return-value", "optional.php");
        $this->assertSame("Hello world", $lines[0]);
        $this->assertSame("", $lines[1]);
    }

    public function testStructReturnValue(): void
    {
        $lines = $this->runTest("return-value", "struct.php");
        $this->assertSame(<<<OUTPUT
        stdClass Object
        (
            [name] => Bigus Dickus
            [age] => 32
        )
        OUTPUT, implode(PHP_EOL, $lines));
    }

    public function testStructArrayReturnValue(): void
    {
        $lines = $this->runTest("return-value", "struct-array.php");
        $this->assertSame(<<<OUTPUT
        Array
        (
            [0] => stdClass Object
                (
                    [name] => Doctor Evil
                    [age] => 32
                )

            [1] => stdClass Object
                (
                    [name] => Doctor Doom
                    [age] => 100
                )

            [2] => stdClass Object
                (
                    [name] => Doctor Zhivago
                    [age] => 45
                )

        )
        OUTPUT, implode(PHP_EOL, $lines));
    }

    public function testAssociativeArrayReturnValue(): void
    {
        $lines = $this->runTest("return-value", "assoc-array.php");
        $this->assertSame(<<<OUTPUT
        Array
        (
            [name] => Doctor Evil
            [age] => 32
        )
        OUTPUT, implode(PHP_EOL, $lines));
    }

    public function testStdClass(): void
    {
        $lines = $this->runTest("return-value", "stdclass.php");
        $this->assertSame(<<<OUTPUT
        stdClass Object
        (
            [name] => Doctor Evil
            [age] => 32
        )
        OUTPUT, implode(PHP_EOL, $lines));
    }

}
