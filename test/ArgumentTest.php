<?php declare(strict_types=1);

require_once __DIR__ . '/ExtensionTestCase.php';

final class ArgumentTest extends ExtensionTestCase
{   
    public function testSimpleArgs(): void
    {
        $lines = $this->runTest("arguments", "simple.php");
        $this->assertSame("boolean = true", $lines[0]);
        $this->assertSame("boolean = false", $lines[1]);
        $this->assertSame("int = 1234", $lines[2]);
        $this->assertSame("uint = 4567", $lines[3]);
        $this->assertSame("int = 100, float1 = 42.5, float2 = 3.14", $lines[4]);
    }

    public function testStringArgs(): void
    {
        $lines = $this->runTest("arguments", "string.php");
        $this->assertSame("string = Hello world", $lines[0]);
        $this->assertSame("string1 = foo, string2 = bar", $lines[1]);
    }

    public function testEnumArgs(): void
    {
        $lines = $this->runTest("arguments", "enum.php");
        $this->assertSame("enum = .cat", $lines[0]);
        $this->assertSame("enum = .dog", $lines[1]);
        $this->assertSame("enum = .monkey", $lines[2]);
    }

    public function testFlagsArgs(): void
    {
        $lines = $this->runTest("arguments", "flags.php");
        $this->assertSame("flags = .{ .option1 = true, .option2 = false, .option3 = true, .option4 = false, ._ = 0 }", $lines[0]);
        $this->assertSame("flags = .{ .option1 = false, .option2 = false, .option3 = false, .option4 = true, ._ = 0 }", $lines[1]);
        $this->assertSame("flags = .{ .option1 = false, .option2 = false, .option3 = false, .option4 = false, ._ = 0 }", $lines[2]);
    }

    public function testListArgs(): void
    {
        $lines = $this->runTest("arguments", "list.php");
        $this->assertSame("0: hello", $lines[0]);
        $this->assertSame("1: world", $lines[1]);
        $this->assertSame("2: chicken", $lines[2]);
    }

    public function testStructArgs(): void
    {
        $lines = $this->runTest("arguments", "struct.php");
        $this->assertSame("number = 1234", $lines[0]); 
        $this->assertSame("0: hello", $lines[1]);
        $this->assertSame("1: world", $lines[2]);
        $this->assertSame("2: chicken", $lines[3]);
        $this->assertSame("number = 4567", $lines[4]);
        $this->assertSame("0: hello", $lines[5]);
        $this->assertSame("1: world", $lines[6]);
    }

    public function testUnionArgs(): void
    {
        $lines = $this->runTest("arguments", "union.php");
        $this->assertSame("number = 1234", $lines[0]); 
        $this->assertSame("string = Hello world", $lines[1]);
    }

    public function testArrayArgs(): void
    {
        $lines = $this->runTest("arguments", "array.php");
        $this->assertSame("array = { 1.5, 2.3, 789 }", $lines[0]); 
    }

    public function testVectorArgs(): void
    {
        $lines = $this->runTest("arguments", "vector.php");
        $this->assertSame("vector = { 1.5, 2.3, 789 }", $lines[0]); 
    }

    public function testOptionalArgs(): void
    {
        $lines = $this->runTest("arguments", "optional.php");
        $this->assertSame("int = 100, float1 = 42.5, float2 = 8.88", $lines[0]);
        $this->assertSame("string = Dingo ate my baby!", $lines[1]);
    }
}
