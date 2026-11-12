<?php declare(strict_types=1);

require_once __DIR__ . '/../ExtensionTestCase.php';

final class WikiErrorTest extends ExtensionTestCase
{   
    public function testFactorialError(): void
    {
        $lines = $this->runTest("error-factorial", "test.php");
        $this->assertSame(<<<OUTPUT
        120
        too large
        OUTPUT, implode(PHP_EOL, $lines));
    }
}