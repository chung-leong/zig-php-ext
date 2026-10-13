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
}
