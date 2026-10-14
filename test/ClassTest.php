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

    public function testConstructor(): void
    {
        $lines = $this->runTest("classes", "constructor.php");
        $this->assertSame(<<<OUTPUT
        Cat (.pet)
        Martin (.wild)
        Croissant (.wild)
        OUTPUT, implode("\n", $lines));
    }

    public function testStaticMethod(): void
    {
        $lines = $this->runTest("classes", "static-method.php");
        $this->assertSame(<<<OUTPUT
        number = 123
        text = Chicken
        OUTPUT, implode("\n", $lines));
    }

    public function testStaticConstant(): void
    {
        $lines = $this->runTest("classes", "static-constant.php");
        $this->assertSame(<<<OUTPUT
        number = 1234
        text = Hello world
        enum = 0
        enum = 1
        enum = 2
        flag = 1
        flag = 2
        flag = 4
        OUTPUT, implode("\n", $lines));
    }

    public function testFreeObject(): void
    {
        $lines = $this->runTest("classes", "free-object.php");
        $this->assertSame(<<<OUTPUT
        destroyObject
        freeObject
        OUTPUT, implode("\n", $lines));
    }

    public function testGetConstructor(): void
    {
        $lines = $this->runTest("classes", "get-constructor.php");
        // no "init" or "deinit"
        $this->assertSame(<<<OUTPUT
        getConstructor
        constructor: 1234, Hello world
        destroyObject
        freeObject
        OUTPUT, implode("\n", $lines));
    }

    public function testCloneObject(): void
    {
        $lines = $this->runTest("classes", "clone-object.php");
        $this->assertSame(<<<OUTPUT
        WithCloneObject Object
        (
            [number] => 4567
            [text] => I am Groot
        )
        cloneObject
        WithCloneObject Object
        (
            [number] => 4567
            [text] => I am Groot
        )
        OUTPUT, implode("\n", $lines));
    }

    public function testClone(): void
    {
        $lines = $this->runTest("classes", "clone.php");
        $this->assertSame(<<<OUTPUT
        WithClone Object
        (
            [number] => 4567
            [text] => I am Groot
        )
        clone
        WithClone Object
        (
            [number] => 4567
            [text] => I am Groot
        )
        OUTPUT, implode("\n", $lines));
    }

}
