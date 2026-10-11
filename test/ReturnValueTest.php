<?php declare(strict_types=1);

require_once __DIR__ . '/ExtensionTestCase.php';

final class ReturnValueTest extends ExtensionTestCase
{   
    public function testSimpleRetval(): void
    {
        $lines = $this->runTest("return-value", "simple.php");
        $this->assertSame("bool = 1", $lines[0]);
        $this->assertSame("int = 1234", $lines[1]);
        $this->assertSame("float = 12.5", $lines[2]);
    }

    public function testStringRetval(): void
    {
        $lines = $this->runTest("return-value", "string.php");
        $this->assertSame("This is a test", $lines[0]);
        $this->assertSame("Hello world", $lines[1]);
    }   

    public function testEnumRetval(): void
    {
        $lines = $this->runTest("return-value", "enum.php");
        $this->assertSame("enum = 1", $lines[0]);
    }

    public function testFlagsRetval(): void
    {
        $lines = $this->runTest("return-value", "flags.php");
        $this->assertSame("flags = 5", $lines[0]);
    }

    public function testArrayRetval(): void
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
        OUTPUT, implode("\n", $lines));
    }

    public function testVectorRetval(): void
    {
        $lines = $this->runTest("return-value", "vector.php");
        $this->assertSame(<<<OUTPUT
        Array
        (
            [0] => 1.5
            [1] => 2.5
            [2] => 3.5
        )
        OUTPUT, implode("\n", $lines));
    }

    public function testOptionalRetval(): void
    {
        $lines = $this->runTest("return-value", "optional.php");
        $this->assertSame("Hello world", $lines[0]);
        $this->assertSame("", $lines[1]);
    }

    public function testStructRetval(): void
    {
        $lines = $this->runTest("return-value", "struct.php");
        $this->assertSame(<<<OUTPUT
        stdClass Object
        (
            [name] => Bigus Dickus
            [age] => 32
        )
        OUTPUT, implode("\n", $lines));
    }

    public function testStructArrayRetval(): void
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
        OUTPUT
        , implode("\n", $lines));
    }
}
