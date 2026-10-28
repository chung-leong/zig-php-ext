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
}
