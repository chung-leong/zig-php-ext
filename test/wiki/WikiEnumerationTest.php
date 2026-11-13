<?php declare(strict_types=1);

require_once __DIR__ . '/../ExtensionTestCase.php';

final class WikiEnumerationTest extends ExtensionTestCase
{   
    public function testBasicEnumeration(): void
    {
        $lines = $this->runTest("enumeration-basic", "test.php");
        $this->assertSame(<<<OUTPUT
        Array
        (
            [0] => Fruit Enum:int
                (
                    [name] => apple
                    [value] => 0
                )

            [1] => Fruit Enum:int
                (
                    [name] => banana
                    [value] => 1
                )

            [2] => Fruit Enum:int
                (
                    [name] => cherry
                    [value] => 2
                )

            [3] => Fruit Enum:int
                (
                    [name] => durian
                    [value] => 3
                )

        )
        OUTPUT, implode(PHP_EOL, $lines));
        echo implode(PHP_EOL, $lines), "\n";
    }

    public function testEnumerationAlias(): void
    {
        $lines = $this->runTest("enumeration-alias", "test.php");
        $this->assertSame(<<<OUTPUT
        Fruit Enum:int
        (
            [name] => banana
            [value] => 1
        )
        Fruit Enum:int
        (
            [name] => banana
            [value] => 1
        )
        OUTPUT, implode(PHP_EOL, $lines));
    }

    public function testEnumerationMethod(): void
    {
        $lines = $this->runTest("enumeration-method", "test.php");
        $this->assertSame(<<<OUTPUT
        Fruit #3: cherry
        OUTPUT, implode(PHP_EOL, $lines));
    }

    public function testEnumerationStaticMethod(): void
    {
        $lines = $this->runTest("enumeration-method-static", "test.php");
        $this->assertSame(<<<OUTPUT
        Fruit #1: apple
        Fruit #2: banana <-- special
        Fruit #3: cherry
        Fruit #4: durian
        ---
        Fruit #1: apple
        Fruit #2: banana
        Fruit #3: cherry <-- special
        Fruit #4: durian
        OUTPUT, implode(PHP_EOL, $lines));
    }
}