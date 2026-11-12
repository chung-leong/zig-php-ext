<?php declare(strict_types=1);

require_once __DIR__ . '/../ExtensionTestCase.php';

final class WikiClassTest extends ExtensionTestCase
{   
    public function testBareBoneClass(): void
    {
        $lines = $this->runTest("class-bare-bone", "test.php");
        if (PHP_MAJOR_VERSION > 8 or PHP_MINOR_VERSION >= 3) { 
            $this->assertSame(<<<OUTPUT
            Point Object
            (
            )
            OUTPUT, implode(PHP_EOL, $lines));
        } else {
            $this->assertSame(<<<OUTPUT
            Point Object
            OUTPUT, implode(PHP_EOL, $lines));
        }
    }

    public function testManualGetterSetter(): void
    {
        $lines = $this->runTest("class-getter-setter-manual", "test.php");
        $this->assertSame(<<<OUTPUT
        Point Object
        (
            [x] => 123
            [y] => 456
            [normal] => 472.29757568719
        )
        OUTPUT, implode(PHP_EOL, $lines));
    }

    public function testGetterSetter(): void
    {
        $lines = $this->runTest("class-getter-setter", "test.php");
        $this->assertSame(<<<OUTPUT
        Point Object
        (
            [x] => 123
            [y] => 456
            [normal] => 472.29757568719
        )
        OUTPUT, implode(PHP_EOL, $lines));
    }

    public function testAutoGetterSetter(): void
    {
        $lines = $this->runTest("class-getter-setter-auto", "test.php");
        $this->assertSame(<<<OUTPUT
        Point Object
        (
            [x] => 123
            [y] => 456
            [normal] => 472.29757568719
        )
        OUTPUT, implode(PHP_EOL, $lines));
    }
}