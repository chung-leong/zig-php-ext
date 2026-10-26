<?php declare(strict_types=1);
use PHPUnit\Framework\TestCase;
use Revolt\EventLoop;

class ExtensionTestCase extends TestCase
{   
    protected function runTest($test_name, $script_name): array
    {
        chdir(__DIR__ . "/$test_name");
        $result = exec("php build.php", $lines, $code);
        if ($result === false) {
            throw new Exception("Unable to run build script: $test_name");
        } else if ($code !== 0) {
            throw new Exception($result);
        }
        unset($lines);
        $php_version = substr(PHP_VERSION, 0, strrpos(PHP_VERSION, '.'));
        switch (PHP_OS_FAMILY) {
            case 'Windows': $so_ext = 'dll'; break;
            case 'Darwin': $so_ext = 'dylib'; break;
            default: $so_ext = 'so'; break;
        }
        $parts = [ __DIR__, $test_name, 'extensions', $php_version ];
        if (PHP_ZTS) {
            $parts[] = "TS";
        }
        $parts[] = "php_" . strtr($test_name, '-', '_') . ".$so_ext";
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
