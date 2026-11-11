<?php declare(strict_types=1);

require_once __DIR__ . '/../ExtensionTestCase.php';

final class WikiFunctionTest extends ExtensionTestCase
{   
    public function testFunctionExportSyntax(): void
    {
        $lines = $this->runTest("function-basic", "test.php");
        $this->assertSame(<<<OUTPUT
        foobar
        OUTPUT, implode(PHP_EOL, $lines));
    }

    public function testFunctionSelfPointer(): void
    {
        $lines = $this->runTest("function-self", "test.php");
        $this->assertSame(<<<OUTPUT
        Cześć, Agnieszko!
        OUTPUT, implode(PHP_EOL, $lines));
    }
}