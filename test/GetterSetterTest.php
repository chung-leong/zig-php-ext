<?php declare(strict_types=1);

require_once __DIR__ . '/ExtensionTestCase.php';

final class GetterSetterTest extends ExtensionTestCase
{   
    public function testStructWithNoGettersOrSetters(): void
    {
        $lines = $this->runTest("getter-setter", "no-get-no-set.php");
        $this->assertSame(<<<OUTPUT
        WithNoGettersOrSetters Object
        (
            [hello] => 123
            [world] => 456
        )
        WithNoGettersOrSetters Object
        (
            [hello] => 45
            [world] => 456
        )
        WithNoGettersOrSetters Object
        (
            [hello] => 45
            [world] => 777
        )
        OUTPUT, implode(PHP_EOL, $lines));
    }

    public function testStructWithNoGettersNoAutoSetters(): void
    {
        $lines = $this->runTest("getter-setter", "no-get-no-auto-set.php");
        $this->assertSame(<<<OUTPUT
        unable to write property 'world' in WithNoGettersNoAutoSet - read only
        WithNoGettersNoAutoSet Object
        (
            [hello] => 123
            [world] => 456
        )
        OUTPUT, implode(PHP_EOL, $lines));
    }

    public function testStructWithOneGetter(): void
    {
        $lines = $this->runTest("getter-setter", "one-getter.php");
        $this->assertSame(<<<OUTPUT
        no property named 'world' in WithOneGetter
        WithOneGetter Object
        (
            [hello] => 246
        )
        OUTPUT, implode(PHP_EOL, $lines));
    }

    public function testStructWithOneGetterAutoGet(): void
    {
        $lines = $this->runTest("getter-setter", "one-getter-auto-get.php");
        $this->assertSame(<<<OUTPUT
        unable to write property 'world' in WithOneGetterAutoGet - read only
        WithOneGetterAutoGet Object
        (
            [hello] => 246
            [world] => 456
        )
        unable to write property 'hello' in WithOneGetterAutoGet - pants on fire
        OUTPUT, implode(PHP_EOL, $lines));
    }

    public function testStructWithNoGettersOrSettersOneFunction(): void
    {
        $lines = $this->runTest("getter-setter", "no-get-no-set-func.php");
        $this->assertSame(<<<OUTPUT
        WithNoGettersOrSettersOneFunction Object
        OUTPUT, implode(PHP_EOL, $lines));
    }
}
