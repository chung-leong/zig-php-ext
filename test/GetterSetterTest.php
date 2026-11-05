<?php declare(strict_types=1);

require_once __DIR__ . '/ExtensionTestCase.php';

final class GetterSetterTest extends ExtensionTestCase
{   
    public function testStructWithNoGettersOrSetters(): void
    {
        $lines = $this->runTest("getter-setter", "no-get-no-set.php");
        echo implode(PHP_EOL, $lines), "\n";
    }
}
