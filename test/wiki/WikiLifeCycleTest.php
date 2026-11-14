<?php declare(strict_types=1);

require_once __DIR__ . '/../ExtensionTestCase.php';

final class WikiLifeCycleTest extends ExtensionTestCase
{   
    public function testModuleStartupShutdown(): void
    {
        $lines = $this->runTest("module-startup-shutdown", "test.php");
        $this->assertMatchesRegularExpression(
            '/init\nmoduleStartup: .persistent, (\d+)\nmoduleShutdown: .persistent, \1\ndeinit/',
            implode("\n", $lines)
        );
    }

    public function testRequestStartupShutdown(): void
    {
        $lines = $this->runTest("request-startup-shutdown", "test.php");
        echo implode(PHP_EOL, $lines);
        $this->assertMatchesRegularExpression(
            '/init: counter = 0\nrequestStartup: counter = 1\nrequestShutdown: counter = 1\ndeinit: counter = 0/',
            implode("\n", $lines)
        );
    }
}