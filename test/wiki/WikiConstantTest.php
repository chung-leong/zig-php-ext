<?php declare(strict_types=1);

require_once __DIR__ . '/../ExtensionTestCase.php';

final class WikiConstantTest extends ExtensionTestCase
{   
    public function testGlobalConstants(): void
    {
        $lines = $this->runTest("constant-global", "test.php");
        $this->assertSame(<<<OUTPUT
        string(11) "Hello world"
        int(1234)
        float(3.14159265359)
        int(1234)
        OUTPUT, implode(PHP_EOL, $lines));
        echo implode(PHP_EOL, $lines), "\n";
    }

    public function testGlobalConstantWithNamespace(): void
    {
        $lines = $this->runTest("constant-global-namespace", "test.php");
        $this->assertSame(<<<OUTPUT
        string(11) "Hello world"
        OUTPUT, implode(PHP_EOL, $lines));
    }

    public function testPackStructConstants(): void
    {
        $lines = $this->runTest("constant-packed-struct", "test.php");
        $this->assertSame(<<<OUTPUT
        object(Flags)#1 (3) {
        ["is_cheap"]=>
        bool(false)
        ["is_fast"]=>
        bool(true)
        ["is_good"]=>
        bool(true)
        }
        int(6)
        int(6)
        OUTPUT, implode(PHP_EOL, $lines));
    }

}