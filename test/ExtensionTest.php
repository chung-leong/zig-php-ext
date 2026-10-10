<?php declare(strict_types=1);
use PHPUnit\Framework\TestCase;
use Revolt\EventLoop;

final class ExtensionTest extends TestCase
{   
    public function testSimpleArgs(): void
    {
        $lines = $this->runTest("arguments", "simple.php");
        $this->assertSame("boolean = true", $lines[0]);
        $this->assertSame("boolean = false", $lines[1]);
        $this->assertSame("int = 1234", $lines[2]);
        $this->assertSame("uint = 4567", $lines[3]);
        $this->assertSame("int = 100, float1 = 42.5, float2 = 3.14", $lines[4]);
    }

    public function testStringArgs(): void
    {
        $lines = $this->runTest("arguments", "string.php");
        $this->assertSame("string = Hello world", $lines[0]);
        $this->assertSame("string1 = foo, string2 = bar", $lines[1]);
    }

    public function testEnumArgs(): void
    {
        $lines = $this->runTest("arguments", "enum.php");
        $this->assertSame("enum = .cat", $lines[0]);
        $this->assertSame("enum = .dog", $lines[1]);
        $this->assertSame("enum = .monkey", $lines[2]);
    }

    public function testFlagsArgs(): void
    {
        $lines = $this->runTest("arguments", "flags.php");
        $this->assertSame("flags = .{ .option1 = true, .option2 = false, .option3 = true, .option4 = false, ._ = 0 }", $lines[0]);
        $this->assertSame("flags = .{ .option1 = false, .option2 = false, .option3 = false, .option4 = true, ._ = 0 }", $lines[1]);
        $this->assertSame("flags = .{ .option1 = false, .option2 = false, .option3 = false, .option4 = false, ._ = 0 }", $lines[2]);
    }

    private function runTest($test_name, $script_name): array
    {
        chdir(__DIR__ . "/$test_name");
        if (exec("./build") === false) {
            throw new Exception("Unable to build extension: $test_name");
        }
        $php_version = substr(PHP_VERSION, 0, strrpos(PHP_VERSION, '.'));
        switch (PHP_OS_FAMILY) {
            case 'Windows': $so_ext = 'dll'; break;
            case 'Darwin': $so_ext = 'dylib'; break;
            default: $so_ext = 'so'; break;
        }
        $ext_path = __DIR__ . "/$test_name/extensions/$php_version/php_$test_name.$so_ext";
        $result = exec("php -d extension='$ext_path' '$script_name'", $lines, $code);
        if ($result === false) {
            throw new Exception("Unable to run PHP with extension: $test_name");
        } else if ($code !== 0) {
            throw new Exception($result);
        }
        return $lines;
    }
}
