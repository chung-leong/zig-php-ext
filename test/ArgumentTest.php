<?php declare(strict_types=1);

require_once __DIR__ . '/ExtensionTestCase.php';

final class ArgumentTest extends ExtensionTestCase
{   
    public function testSimpleArguments(): void
    {
        $lines = $this->runTest("argument", "simple.php");
        $this->assertSame(<<<OUTPUT
        boolean = true
        boolean = false
        int = 1234
        uint = 4567
        int = 100, float1 = 42.5, float2 = 3.14
        OUTPUT, implode(PHP_EOL, $lines));
    }

    public function testStringArguments(): void
    {
        $lines = $this->runTest("argument", "string.php");
        $this->assertSame(<<<OUTPUT
        string = Hello world
        string1 = foo, string2 = bar
        OUTPUT, implode(PHP_EOL, $lines));
    }

    public function testEnumArguments(): void
    {
        $lines = $this->runTest("argument", "enum.php");
        $this->assertSame(<<<OUTPUT
        enum = .cat
        enum = .dog
        enum = .monkey
        enum = .monkey
        enum = .monkey
        enum = .dog
        enum = .turkey
        OUTPUT, implode(PHP_EOL, $lines));
    }

    public function testFlagsArguments(): void
    {
        $lines = $this->runTest("argument", "flags.php");
        $this->assertSame(<<<OUTPUT
        flags = .{ .option1 = true, .option2 = false, .option3 = true, .option4 = false, ._ = 0 }
        flags = .{ .option1 = false, .option2 = false, .option3 = false, .option4 = true, ._ = 0 }
        flags = .{ .option1 = false, .option2 = false, .option3 = false, .option4 = false, ._ = 0 }
        OUTPUT, implode(PHP_EOL, $lines));
    }

    public function testListArguments(): void
    {
        $lines = $this->runTest("argument", "list.php");
        $this->assertSame(<<<OUTPUT
        0: hello
        1: world
        2: chicken
        OUTPUT, implode(PHP_EOL, $lines));
    }

    public function testStructArguments(): void
    {
        $lines = $this->runTest("argument", "struct.php");
        $this->assertSame(<<<OUTPUT
        number = 1234
        0: hello
        1: world
        2: chicken
        number = 4567
        0: hello
        1: world
        OUTPUT, implode(PHP_EOL, $lines));
    }

    public function testUnionArguments(): void
    {
        $lines = $this->runTest("argument", "union.php");
        $this->assertSame(<<<OUTPUT
        number = 1234
        string = Hello world
        OUTPUT, implode(PHP_EOL, $lines));
    }

    public function testArrayArguments(): void
    {
        $lines = $this->runTest("argument", "array.php");
        $this->assertSame(<<<OUTPUT
        array = { 1.5, 2.3, 789 }
        OUTPUT, implode(PHP_EOL, $lines));
    }

    public function testVectorArguments(): void
    {
        $lines = $this->runTest("argument", "vector.php");
        $this->assertSame(<<<OUTPUT
        vector = { 1.5, 2.3, 789 }
        OUTPUT, implode(PHP_EOL, $lines));
    }

    public function testOptionalArguments(): void
    {
        $lines = $this->runTest("argument", "optional.php");
        $this->assertSame(<<<OUTPUT
        int = 100, float1 = 42.5, float2 = 8.88
        string = Dingo ate my baby!
        OUTPUT, implode(PHP_EOL, $lines));
    }

    public function testByRefArguments(): void
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

    public function testPackedStructConstructor(): void
    {
        $lines = $this->runTest("argument", "packed.php");
        $this->assertSame(<<<OUTPUT
        Packed Object
        (
            [a] =>
            [b] =>
            [c] =>
            [d] => 1
        )
        OUTPUT, implode(PHP_EOL, $lines));
    }
}
