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
    }

    public function testGlobalConstantWithNamespace(): void
    {
        $lines = $this->runTest("constant-global-namespace", "test.php");
        $this->assertSame(<<<OUTPUT
        string(11) "Hello world"
        OUTPUT, implode(PHP_EOL, $lines));
    }

    public function testClassConstant(): void
    {
        $lines = $this->runTest("constant-class", "test.php");
        $this->assertSame(<<<OUTPUT
        string(11) "Hello world"
        int(12345)
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

    public function testArrayObjectConstant(): void
    {
        $lines = $this->runTest("constant-array-object", "test.php");
        if (PHP_MAJOR_VERSION > 8 or PHP_MINOR_VERSION >= 5) {
            $this->assertSame(<<<OUTPUT
            array(4) {
              [0]=>
              int(1)
              [1]=>
              int(2)
              [2]=>
              int(3)
              [3]=>
              int(4)
            }
            object(stdClass)#1 (2) {
              ["hello"]=>
              int(123)
              ["world"]=>
              int(456)
            }
            array(4) {
              [0]=>
              int(1)
              [1]=>
              int(2)
              [2]=>
              int(3)
              [3]=>
              int(4)
            }
            object(stdClass)#2 (2) {
              ["hello"]=>
              int(123)
              ["world"]=>
              int(456)
            }
            OUTPUT, implode(PHP_EOL, $lines));
        } else {
            $this->assertSame(<<<OUTPUT
            array(4) {
              [0]=>
              int(1)
              [1]=>
              int(2)
              [2]=>
              int(3)
              [3]=>
              int(4)
            }
            object(stdClass)#1 (2) {
              ["hello"]=>
              int(123)
              ["world"]=>
              int(456)
            }
            array(4) {
              [0]=>
              int(1)
              [1]=>
              int(2)
              [2]=>
              int(3)
              [3]=>
              int(4)
            }
            array(2) {
              ["hello"]=>
              int(123)
              ["world"]=>
              int(456)
            }
            OUTPUT, implode(PHP_EOL, $lines));
        }
    }
}