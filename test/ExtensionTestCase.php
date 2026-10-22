<?php declare(strict_types=1);
use PHPUnit\Framework\TestCase;
use Revolt\EventLoop;

class ExtensionTestCase extends TestCase
{   
    protected function runTest($test_name, $script_name): array
    {
        chdir(__DIR__ . "/$test_name");
        if (exec("php build.php") === false) {
            throw new Exception("Unable to build extension: $test_name");
        }
        $php_version = substr(PHP_VERSION, 0, strrpos(PHP_VERSION, '.'));
        switch (PHP_OS_FAMILY) {
            case 'Windows': $so_ext = 'dll'; break;
            case 'Darwin': $so_ext = 'dylib'; break;
            default: $so_ext = 'so'; break;
        }
        $parts = [ __DIR__, $test_name, 'extensions', $php_version, "php_$test_name.$so_ext" ];
        $ext_path =  implode(DIRECTORY_SEPARATOR, $parts);
        $cmd = "php -d extension=\"$ext_path\" \"$script_name\"";
        $result = exec($cmd, $lines, $code);
        if ($result === false) {
            throw new Exception("Unable to run PHP with extension: $test_name");
        } else if ($code !== 0) {
            throw new Exception($result);
        }
        return $lines;
    }
}
