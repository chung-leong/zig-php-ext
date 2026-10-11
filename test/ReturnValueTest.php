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
        $this->assertSame("Array", $lines[0]);
        $this->assertSame("(", $lines[1]);
        $this->assertSame("    [0] => 1", $lines[2]);
        $this->assertSame("    [1] => 2", $lines[3]);
        $this->assertSame("    [2] => 3", $lines[4]);
        $this->assertSame("    [3] => 4", $lines[5]);
        $this->assertSame(")", $lines[6]);
    }

    public function testVectorRetval(): void
    {
        $lines = $this->runTest("return-value", "vector.php");
        $this->assertSame("Array", $lines[0]);
        $this->assertSame("(", $lines[1]);
        $this->assertSame("    [0] => 1.5", $lines[2]);
        $this->assertSame("    [1] => 2.5", $lines[3]);
        $this->assertSame("    [2] => 3.5", $lines[4]);
        $this->assertSame(")", $lines[5]);
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
        $this->assertSame("stdClass Object", $lines[0]);
        $this->assertSame("(", $lines[1]);
        $this->assertSame("    [name] => Bigus Dickus", $lines[2]);
        $this->assertSame("    [age] => 32", $lines[3]);
        $this->assertSame(")", $lines[4]);
    }

    public function testStructArrayRetval(): void
    {
        $lines = $this->runTest("return-value", "struct-array.php");
        $this->assertSame("Array", $lines[0]);
        $this->assertSame("(", $lines[1]);
        $this->assertSame("    [0] => stdClass Object", $lines[2]);
        $this->assertSame("        (", $lines[3]);
        $this->assertSame("            [name] => Doctor Evil", $lines[4]);
        $this->assertSame("            [age] => 32", $lines[5]);
        $this->assertSame("        )", $lines[6]);
        $this->assertSame("", $lines[7]);
        $this->assertSame("    [1] => stdClass Object", $lines[8]);
        $this->assertSame("        (", $lines[9]);
        $this->assertSame("            [name] => Doctor Doom", $lines[10]);
        $this->assertSame("            [age] => 100", $lines[11]);
        $this->assertSame("        )", $lines[12]);
        $this->assertSame("", $lines[13]);
        $this->assertSame("    [2] => stdClass Object", $lines[14]);
        $this->assertSame("        (", $lines[15]);
        $this->assertSame("            [name] => Doctor Zhivago", $lines[16]);
        $this->assertSame("            [age] => 45", $lines[17]);
        $this->assertSame("        )", $lines[18]);
        $this->assertSame("", $lines[19]);
        $this->assertSame(")", $lines[20]);
    }
}
