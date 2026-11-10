<?php declare(strict_types=1);

require_once __DIR__ . '/../ExtensionTestCase.php';

final class WikiArgumentTest extends ExtensionTestCase
{   
    public function testBasicArguments(): void
    {
        $lines = $this->runTest("argument-basic", "test.php");
        $this->assertSame(<<<OUTPUT
        x = 1, y = 2, z = 3
        x = 1, y = 2, z = 3
        OUTPUT, implode(PHP_EOL, $lines));
    }

    public function testOptionalArguments(): void
    {
        $lines = $this->runTest("argument-optional", "test.php");
        $this->assertSame(<<<OUTPUT
        x = 1, y = 2, z = 3333
        OUTPUT, implode(PHP_EOL, $lines));
    }

    public function testOptionalBeforeRequiredArguments(): void
    {
        $lines = $this->runTest("argument-optional-before-required", "test.php");
        $this->assertSame(<<<OUTPUT
        boolean = true, number1 = 123, number2 = 456
        OUTPUT, implode(PHP_EOL, $lines));
    }

    public function testStringArgument(): void
    {
        $lines = $this->runTest("argument-string", "test.php");
        $this->assertSame(<<<OUTPUT
        Hello, world!
        OUTPUT, implode(PHP_EOL, $lines));
    }

    public function testStringArgumentWithDefault(): void
    {
        $lines = $this->runTest("argument-string-default", "test.php");
        $this->assertSame(<<<OUTPUT
        Hello, world!
        OUTPUT, implode(PHP_EOL, $lines));
    }

    public function testPhpStringArgument(): void
    {
        $lines = $this->runTest("argument-string-php", "test.php");
        $this->assertSame(<<<OUTPUT
        Hello, world!
        OUTPUT, implode(PHP_EOL, $lines));
    }

    public function testPhpStringFromSlice(): void
    {
        $lines = $this->runTest("argument-string-from-slice", "test.php");
        $this->assertMatchesRegularExpression('/address of name = (\d+)\s+address of str\.slice\(\) = \1/', implode(PHP_EOL, $lines));
    }

    public function testStructArgument(): void
    {
        $lines = $this->runTest("argument-object", "test.php");
        $this->assertSame(<<<OUTPUT
        Name: Ralph Wiggum
        Profession: Politician
        Age: 24
        Name: Ralph Wiggum
        Profession: Politician
        Age: 24
        OUTPUT, implode(PHP_EOL, $lines));
    }

    public function testArrayArgument(): void
    {
        $lines = $this->runTest("argument-object-array", "test.php");
        $this->assertSame(<<<OUTPUT
        #1.
        Name: Ralph Wiggum
        Profession: Politician
        Age: 24
        #2.
        Name: Lisa Simpson
        Profession: Physicist
        Age: 25
        #3.
        Name: Nelson Muntz
        Profession: Psychologist
        Age: 26
        OUTPUT, implode(PHP_EOL, $lines));
    }

    public function testCustomObjectArgument(): void
    {
        $lines = $this->runTest("argument-custom-object", "test.php");
        $this->assertSame(<<<OUTPUT
        opaque_ptr = 0xDEADBEEF
        OUTPUT, implode(PHP_EOL, $lines));
    }

    public function testUnionTypeArgument(): void
    {
        $lines = $this->runTest("argument-union-type", "test.php");
        $this->assertSame(<<<OUTPUT
        integer = 123
        float = 3.141592653589793
        boolean = false
        OUTPUT, implode(PHP_EOL, $lines));
    }

    public function testUnionTypeObjectArgument(): void
    {
        $lines = $this->runTest("argument-union-type-class", "test.php");
        $this->assertSame(<<<OUTPUT
        dog: woof
        cat: meow
        fox: ????
        poke(): argument #1 (\$animal) is incorrect - not Cat, Dog, or Fox
        OUTPUT, implode(PHP_EOL, $lines));
    }

    public function testByRefArgument(): void
    {
        $lines = $this->runTest("argument-reference", "test.php");
        $this->assertSame(<<<OUTPUT
        Hello world
        OUTPUT, implode(PHP_EOL, $lines));
    }

    public function testVariadicArguments(): void
    {
        $lines = $this->runTest("argument-variadic", "test.php");
        $this->assertSame(<<<OUTPUT
        arg0 = 1234
        .integer
        .float
        .string
        .boolean
        .null
        .object
        OUTPUT, implode(PHP_EOL, $lines));
    }

    public function testVariadicNamedArguments(): void
    {
        $lines = $this->runTest("argument-variadic-named", "test.php");
        $this->assertSame(<<<OUTPUT
        arg0 = 4567
        .boolean
        cow = .string
        chicken = .integer
        OUTPUT, implode(PHP_EOL, $lines));
    }
}