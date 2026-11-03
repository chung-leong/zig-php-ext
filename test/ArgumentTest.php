<?php declare(strict_types=1);

require_once __DIR__ . '/ExtensionTestCase.php';

final class ArgumentTest extends ExtensionTestCase
{   
    public function testSimpleArgs(): void
    {
        $lines = $this->runTest("argument", "simple.php");
        $this->assertSame("boolean = true", $lines[0]);
        $this->assertSame("boolean = false", $lines[1]);
        $this->assertSame("int = 1234", $lines[2]);
        $this->assertSame("uint = 4567", $lines[3]);
        $this->assertSame("int = 100, float1 = 42.5, float2 = 3.14", $lines[4]);
    }

    public function testStringArgs(): void
    {
        $lines = $this->runTest("argument", "string.php");
        $this->assertSame("string = Hello world", $lines[0]);
        $this->assertSame("string1 = foo, string2 = bar", $lines[1]);
    }

    public function testEnumArgs(): void
    {
        $lines = $this->runTest("argument", "enum.php");
        $this->assertSame("enum = .cat", $lines[0]);
        $this->assertSame("enum = .dog", $lines[1]);
        $this->assertSame("enum = .monkey", $lines[2]);
    }

    public function testFlagsArgs(): void
    {
        $lines = $this->runTest("argument", "flags.php");
        $this->assertSame("flags = .{ .option1 = true, .option2 = false, .option3 = true, .option4 = false, ._ = 0 }", $lines[0]);
        $this->assertSame("flags = .{ .option1 = false, .option2 = false, .option3 = false, .option4 = true, ._ = 0 }", $lines[1]);
        $this->assertSame("flags = .{ .option1 = false, .option2 = false, .option3 = false, .option4 = false, ._ = 0 }", $lines[2]);
    }

    public function testListArgs(): void
    {
        $lines = $this->runTest("argument", "list.php");
        $this->assertSame("0: hello", $lines[0]);
        $this->assertSame("1: world", $lines[1]);
        $this->assertSame("2: chicken", $lines[2]);
    }

    public function testStructArgs(): void
    {
        $lines = $this->runTest("argument", "struct.php");
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
        $lines = $this->runTest("argument", "union.php");
        $this->assertSame("number = 1234", $lines[0]); 
        $this->assertSame("string = Hello world", $lines[1]);
    }

    public function testArrayArgs(): void
    {
        $lines = $this->runTest("argument", "array.php");
        $this->assertSame("array = { 1.5, 2.3, 789 }", $lines[0]); 
    }

    public function testVectorArgs(): void
    {
        $lines = $this->runTest("argument", "vector.php");
        $this->assertSame("vector = { 1.5, 2.3, 789 }", $lines[0]); 
    }

    public function testOptionalArgs(): void
    {
        $lines = $this->runTest("argument", "optional.php");
        $this->assertSame("int = 100, float1 = 42.5, float2 = 8.88", $lines[0]);
        $this->assertSame("string = Dingo ate my baby!", $lines[1]);
    }

    public function testByRefArgs(): void
    {
        $lines = $this->runTest("argument", "ref.php");
        $this->assertSame(<<<OUTPUT
        Hello world
        Hello world
        This is a test
        OUTPUT, implode(PHP_EOL, $lines));
    }

    public function testVariadicFunction(): void
    {
        $lines = $this->runTest("argument", "many-unnamed.php");
        $this->assertSame(<<<OUTPUT
        arg1 = 1234
        extra = 4
        0 = 4567
        1 = Hello world
        2 = 3.1415926535898
        3 = Cow
        OUTPUT, implode(PHP_EOL, $lines));
    }

    public function testVariadicFunctionWithNamedArguments(): void
    {
        $lines = $this->runTest("argument", "many-named.php");
        $this->assertSame(<<<OUTPUT
        arg1 = 1234
        extra = 4
        0 = 4567
        1 = Hello world
        2 = 3.1415926535898
        3 = Cow
        hello = world
        chicken = 12345
        OUTPUT, implode(PHP_EOL, $lines));
    }

    public function testNamedArgumentsToStruct(): void
    {
        $lines = $this->runTest("argument", "options.php");
        $this->assertSame(<<<OUTPUT
        arg1 = 100
        options = .{ .alpha = false, .beta = .pig }
        arg1 = 101
        options = .{ .alpha = true, .beta = .pig }
        arg1 = 102
        options = .{ .alpha = true, .beta = .cow }
        OUTPUT, implode(PHP_EOL, $lines));
    }

    public function testArgumentErrorMessages(): void
    {
        $lines = $this->runTest("argument", "errors.php");
        $this->assertSame(<<<OUTPUT
        printBool() expects exactly 1 argument, 0 given
        printIntFloats() expects at most 3 arguments, 4 given
        printIntFloats(): argument #1 (\$int) is incorrect - not integer
        printBool(): argument #1 (\$boolean) is incorrect - not boolean
        printUnion(): argument #1 (\$input) is incorrect - not string, array, or floating pointer number
        printIntOrFloat(): argument #1 (\$input) is incorrect - not integer or floating pointer number
        acceptPoultry(): argument #1 (\$animal) is incorrect - not Chicken or Turkey
        acceptOptions(): argument #2 (\$options) is incorrect - unable to obtain value for field 'alpha' - not boolean
        acceptOptions(): argument #2 (\$options) is incorrect - unable to obtain value for field 'beta' - 'hello' is not a recognized enum member, which has to be 'cow', 'pig', or 'chicken'
        acceptOptions(): argument #2 (\$options) is incorrect - encountered unknown field 'gamma', expecting 'alpha' and 'beta'
        printStruct(): argument #1 (\$data) is incorrect - 'number' is a required field
        printStructRequireTwo(): argument #1 (\$data) is incorrect - 'list' and 'number' are required fields
        printStructRequireMultiple(): argument #1 (\$data) is incorrect - 'list', 'number', and 'boolean' are required fields
        OUTPUT, implode(PHP_EOL, $lines));
    }
}
