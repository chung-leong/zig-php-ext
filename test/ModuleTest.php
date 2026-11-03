<?php declare(strict_types=1);

require_once __DIR__ . '/ExtensionTestCase.php';

final class ModuleTest extends ExtensionTestCase
{   
    public function testLifecycleHandler(): void
    {
        $lines = $this->runTest("module", "test.php");
        $this->assertSame(<<<OUTPUT
        moduleStartup: .persistent
        requestStartup: .persistent
        Hello world
        requestShutdown: .persistent
        moduleShutdown: .persistent
        OUTPUT, implode(PHP_EOL, $lines));
    }
}
