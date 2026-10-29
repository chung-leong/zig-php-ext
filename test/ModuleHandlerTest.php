<?php declare(strict_types=1);

require_once __DIR__ . '/ExtensionTestCase.php';

final class ModuleHandlerTest extends ExtensionTestCase
{   
    public function testHandlers(): void
    {
        $lines = $this->runTest("module-handlers", "test.php");
        $this->assertSame(<<<OUTPUT
        moduleStartup: .persistent
        requestStartup: .persistent
        Hello world
        requestShutdown: .persistent
        moduleShutdown: .persistent
        OUTPUT, implode(PHP_EOL, $lines));
    }
}
