<?php declare(strict_types=1);

require_once __DIR__ . '/ExtensionTestCase.php';

final class TypedArrayTest extends ExtensionTestCase
{   
    public function testArrayBuffer(): void
    {
        $lines = $this->runTest("typed-array", "array-buffer.php");       
        $this->assertSame("byteLength = 80", $lines[0]);
        $this->assertSame("detached =", $lines[1]);
        $this->assertSame("maxByteLength = 160", $lines[2]);
        $this->assertSame("resizable = 1", $lines[3]);
        $this->assertSame("strlen = 80", $lines[4]);
        $this->assertSame("strlen = 9", $lines[5]);
        $this->assertSame("strlen = 5", $lines[6]);
        $this->assertSame("detached = 1", $lines[7]);
        $this->assertSame("byteLength = 80", $lines[8]);
    }

    public function testInt32Array(): void
    {
        $lines = $this->runTest("typed-array", "int32-array.php");       
        $this->assertSame(<<<OUTPUT
        42
        2
        4
        31
        21
        4
        OUTPUT, implode(PHP_EOL, $lines));
    }

    public function testFloat64Array(): void
    {
        $lines = $this->runTest("typed-array", "float64-array.php");       
        $this->assertSame(<<<OUTPUT
        42.5
        2
        8
        31.5
        21.5
        8
        OUTPUT, implode(PHP_EOL, $lines));
    }

    public function testUint8ClampedArray(): void
    {
        $lines = $this->runTest("typed-array", "uint8-clamped-array.php");       
        $this->assertSame(<<<OUTPUT
        42
        255
        2
        1
        31
        21
        1
        OUTPUT, implode(PHP_EOL, $lines));
    }

    public function testReverse(): void
    {
        $lines = $this->runTest("typed-array", "reverse.php");       
        $this->assertSame(<<<OUTPUT
        Uint8Array Object
        (
            [buffer] => ArrayBuffer Object
                (
                    [byteLength] => 3
                    [detached] =>
                    [maxByteLength] => 3
                    [resizable] =>
                )

            [byteLength] => 3
            [byteOffset] => 0
            [length] => 3
            [[ITEMS]] => Array
                (
                    [0] => 3
                    [1] => 2
                    [2] => 1
                )

        )
        OUTPUT, implode(PHP_EOL, $lines));
    }

    public function testIterate(): void
    {
        $lines = $this->runTest("typed-array", "iterate.php");       
        $this->assertSame(<<<OUTPUT
        3.140625
        6.28125
        9.421875
        OUTPUT, implode(PHP_EOL, $lines));
    }

    public function testIncludes(): void
    {
        $lines = $this->runTest("typed-array", "includes.php");
        $this->assertSame(<<<OUTPUT
        1
        
        
        OUTPUT, implode(PHP_EOL, $lines));
    }

    public function testIndexOf(): void
    {
        $lines = $this->runTest("typed-array", "index-of.php");
        $this->assertSame(<<<OUTPUT
        4
        -1
        -1
        OUTPUT, implode(PHP_EOL, $lines));
    }

    public function testLastIndexOf(): void
    {
        $lines = $this->runTest("typed-array", "last-index-of.php");
        $this->assertSame(<<<OUTPUT
        3
        -1
        3
        0
        0
        3
        OUTPUT, implode(PHP_EOL, $lines));
        // echo implode(PHP_EOL, $lines);
    }

    public function testSet(): void
    {
        $lines = $this->runTest("typed-array", "set.php");       
        $this->assertSame(<<<OUTPUT
        Uint8Array Object
        (
            [buffer] => ArrayBuffer Object
                (
                    [byteLength] => 8
                    [detached] =>
                    [maxByteLength] => 8
                    [resizable] =>
                )

            [byteLength] => 8
            [byteOffset] => 0
            [length] => 8
            [[ITEMS]] => Array
                (
                    [0] => 0
                    [1] => 0
                    [2] => 0
                    [3] => 1
                    [4] => 2
                    [5] => 3
                    [6] => 0
                    [7] => 0
                )

        )
        OUTPUT, implode(PHP_EOL, $lines));
    }

    public function testSort(): void
    {
        $lines = $this->runTest("typed-array", "sort.php");
        $this->assertSame(<<<OUTPUT
        Uint8Array Object
        (
            [buffer] => ArrayBuffer Object
                (
                    [byteLength] => 4
                    [detached] =>
                    [maxByteLength] => 4
                    [resizable] =>
                )

            [byteLength] => 4
            [byteOffset] => 0
            [length] => 4
            [[ITEMS]] => Array
                (
                    [0] => 1
                    [1] => 5
                    [2] => 40
                    [3] => 200
                )

        )
        OUTPUT, implode(PHP_EOL, $lines));
    }
}
