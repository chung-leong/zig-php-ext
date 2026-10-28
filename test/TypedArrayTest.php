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
}
