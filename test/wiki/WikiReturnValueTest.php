<?php declare(strict_types=1);

require_once __DIR__ . '/../ExtensionTestCase.php';

final class WikiReturnValueTest extends ExtensionTestCase
{   
    public function testStaticStringReturnValue(): void
    {
        $lines = $this->runTest("retval-string-static", "test.php");
        $this->assertSame(<<<OUTPUT
        string(11) "Hello world"
        OUTPUT, implode(PHP_EOL, $lines));
        // echo implode(PHP_EOL, $lines), "\n";
    }

    public function testStringReturnValueWithLeak(): void
    {
        $lines = $this->runTest("retval-string-leak", "test.php");
        if (PHP_DEBUG) {
            $this->assertStringContainsString("1 memory leaks detected", implode(PHP_EOL, $lines));
        } else {
            $this->assertSame(<<<OUTPUT
            string(11) "Hello, Bob!"
            OUTPUT, implode(PHP_EOL, $lines));
        }
    }

    public function testStringReturnValue(): void
    {
        $lines = $this->runTest("retval-string", "test.php");
        $this->assertSame(<<<OUTPUT
        string(11) "Hello, Bob!"
        OUTPUT, implode(PHP_EOL, $lines));
    }

    public function testFixedArrayReturnValue(): void
    {
        $lines = $this->runTest("retval-array-fixed", "test.php");
        $this->assertSame(<<<OUTPUT
        Array
        (
            [0] => 10
            [1] => 20
            [2] => 30
            [3] => 40
        )
        OUTPUT, implode(PHP_EOL, $lines));
    }

    public function testArrayReturnValue(): void
    {
        $lines = $this->runTest("retval-array", "test.php");
        $this->assertSame(<<<OUTPUT
        Array
        (
            [0] => 10
            [1] => 20
            [2] => 30
            [3] => 40
            [4] => 50
        )
        OUTPUT, implode(PHP_EOL, $lines));
    }

    public function testPlainObjectReturnValue(): void
    {
        $lines = $this->runTest("retval-stdclass", "test.php");
        $this->assertSame(<<<OUTPUT
        stdClass Object
        (
            [x] => 123
            [y] => 456
        )
        OUTPUT, implode(PHP_EOL, $lines));
    }

    public function testPlainObjectArrayReturnValue(): void
    {
        $lines = $this->runTest("retval-stdclass-array", "test.php");
        $this->assertSame(<<<OUTPUT
        Array
        (
            [0] => stdClass Object
                (
                    [name] => Joe Montana
                    [profession] => Football player
                )

            [1] => stdClass Object
                (
                    [name] => Joe DiMaggio
                    [profession] => Baseball player
                )

            [2] => stdClass Object
                (
                    [name] => Joe Frazier
                    [profession] => Boxer
                )

        )
        OUTPUT, implode(PHP_EOL, $lines));
    }

    public function testTupleReturnValue(): void
    {
        $lines = $this->runTest("retval-tuple", "test.php");
        $this->assertSame(<<<OUTPUT
        string(11) "Hello world"
        int(1234)
        OUTPUT, implode(PHP_EOL, $lines));
        // echo implode(PHP_EOL, $lines), "\n";
    }
}