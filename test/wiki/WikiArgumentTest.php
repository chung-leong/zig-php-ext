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

}