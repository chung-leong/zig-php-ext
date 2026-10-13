<?php declare(strict_types=1);

require_once __DIR__ . '/ExtensionTestCase.php';

final class ClassTest extends ExtensionTestCase
{   
    public function testSimpleClass(): void
    {
        $lines = $this->runTest("classes", "simple.php");
        $this->assertSame("Hello, Bob!", $lines[0]);
        $this->assertSame("Hello", $lines[1]);
        $this->assertSame("Hi, Alice!", $lines[2]);
    }

    public function testOptionalFields(): void
    {
        $lines = $this->runTest("classes", "optional.php");
        $this->assertSame(<<<OUTPUT
        Superhero Object
        (
            [real_name] => Tony Stark
            [superhero_name] =>
        )
        Superhero Object
        (
            [real_name] => Tony Stark
            [superhero_name] => Ironman
        )
        OUTPUT, implode("\n", $lines));
    }

    public function testDefaultConstructor(): void
    {
        $lines = $this->runTest("classes", "def-constructor.php");
        $this->assertSame(<<<OUTPUT
        Point Object
        (
            [x] => 200
            [y] => 4000
            [normal] => 4004.9968789002
        )
        Point Object
        (
            [x] => 123
            [y] => 0
            [normal] => 123
        )
        Point Object
        (
            [x] => 123
            [y] => 456
            [normal] => 472.29757568719
        )
        OUTPUT, implode("\n", $lines));
    }

    public function testComputedProperty(): void
    {
        $lines = $this->runTest("classes", "computed.php");
        $this->assertSame("normal = 5", $lines[0]);
        $this->assertSame("template = Hi, \$name!", $lines[1]);
    }
}
