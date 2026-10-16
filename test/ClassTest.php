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

    public function testReadProperty(): void
    {
        $lines = $this->runTest("classes", "properties.php");
        $this->assertSame("number = 2001", $lines[0]);
        $this->assertSame("foo = (readProperty: foo) 4567", $lines[1]);
        $this->assertSame("bar = (readProperty: bar) Rats live on no evil star", $lines[2]);
        $this->assertSame("(writeProperty: foo)", $lines[3]);
        $this->assertSame("number = 777", $lines[4]);
        $this->assertSame("(readProperty: cow) no field named 'cow' in WithReadProperty", $lines[5]);
        $this->assertSame("(writeProperty: cow)", $lines[6]);
        $this->assertSame("no field named 'cow' in WithReadProperty", $lines[7]);
        $this->assertSame("(writeProperty: bar)", $lines[8]);
        $this->assertSame("unable to write field 'bar' in WithReadProperty: read only", $lines[9]);
        $this->assertSame("true", $lines[10]);
        $this->assertSame("(hasProperty: foo) (readProperty: foo) true", $lines[11]);
        $this->assertSame("(hasProperty: bar) (readProperty: bar) true", $lines[12]);
        $this->assertSame("(hasProperty: cow) false", $lines[13]);
        $this->assertSame("optional = 789", $lines[14]);
        $this->assertSame("optional =", $lines[15]);
        $this->assertSame("(unsetProperty: foo)", $lines[16]);
        $this->assertSame("foo = (readProperty: foo) -1", $lines[17]);
        $this->assertSame("unable to unset field 'number' in WithReadProperty: cannot be null", $lines[18]);
        $this->assertSame("(unsetProperty: cow)", $lines[19]);
        $this->assertSame("no field named 'cow' in WithReadProperty", $lines[20]);
    }

    public function testReadPropertyWithCache(): void
    {
        $lines = $this->runTest("classes", "properties-cache.php");
        $this->assertSame("number = 2001", $lines[0]);
        $this->assertSame("foo = (readProperty: foo) 4567", $lines[1]);
        $this->assertSame("bar = (readProperty: bar) Rats live on no evil star", $lines[2]);
        $this->assertSame("(writeProperty: foo)", $lines[3]);
        $this->assertSame("number = 777", $lines[4]);
        $this->assertSame("(readProperty: cow) no field named 'cow' in WithReadPropertyCache", $lines[5]);
        $this->assertSame("(writeProperty: cow)", $lines[6]);
        $this->assertSame("no field named 'cow' in WithReadPropertyCache", $lines[7]);
        $this->assertSame("(writeProperty: bar)", $lines[8]);
        $this->assertSame("unable to write field 'bar' in WithReadPropertyCache: read only", $lines[9]);
        $this->assertSame("true", $lines[10]);
        $this->assertSame("(hasProperty: foo) (readProperty: foo) true", $lines[11]);
        $this->assertSame("(hasProperty: bar) (readProperty: bar) true", $lines[12]);
        $this->assertSame("(hasProperty: cow) false", $lines[13]);
        $this->assertSame("optional = 789", $lines[14]);
        $this->assertSame("optional =", $lines[15]);
        $this->assertSame("(unsetProperty: foo)", $lines[16]);
        $this->assertSame("foo = (readProperty: foo) -1", $lines[17]);
        $this->assertSame("unable to unset field 'number' in WithReadPropertyCache: cannot be null", $lines[18]);
        $this->assertSame("(unsetProperty: cow)", $lines[19]);
        $this->assertSame("no field named 'cow' in WithReadPropertyCache", $lines[20]);
    }

    public function testReadDimension(): void
    {
        $lines = $this->runTest("classes", "dimension.php");
        $this->assertSame(<<<OUTPUT
        len = 8
        count = 8
        (readDimension: 4) 0
        (writeDimension: 4) (readDimension: 4) 1.25
        (writeDimension: 5) (readDimension: 5) 8.8
        (readDimension: 8) out of bound
        negative value
        not numeric
        (writeDimension: 3) not numeric
        (hasDimension: 4) true
        false
        (hasDimension: 8) false
        false
        (unsetDimension: 4) (readDimension: 4) NAN
        negative value
        OUTPUT, implode("\n", $lines));
    }

    public function testGetClassName(): void
    {
        $lines = $this->runTest("classes", "class-name.php");
        $this->assertSame(<<<OUTPUT
        getClassName
        DingoPower Object
        (
            [number] => 787
        )
        OUTPUT, implode("\n", $lines));
    }

    public function testGetProperties(): void
    {
        $lines = $this->runTest("classes", "property-array.php");
        $this->assertSame(<<<OUTPUT
        (getProperties: .debug) WithGetProperties Object
        (
            [number] => 1979
            [optional] =>
            [foo] => cowboy
            [bar] => mleczny
            [17] => 3.1415926535898
        )
        OUTPUT, implode("\n", $lines));
    }

    public function testGetPropertiesNoGetter(): void
    {
        $lines = $this->runTest("classes", "property-array-no-getters.php");
        $this->assertSame(<<<OUTPUT
        (getProperties: .debug) WithGetPropertiesNoGetters Object
        (
            [foo] => cowboy
            [bar] => mleczny
            [17] => 3.1415926535898
        )
        OUTPUT, implode("\n", $lines));
    }

    public function testGetMethod(): void
    {
        $lines = $this->runTest("classes", "method.php");        
        $this->assertSame(<<<OUTPUT
        foo
        getMethod
        bar
        OUTPUT, implode("\n", $lines));
    }

    public function testCompareWith(): void
    {
        $lines = $this->runTest("classes", "compare.php");        
        $this->assertSame(<<<OUTPUT
        compareWith: 4
        less than 4
        compareWith: 2.9
        greater than 2.9
        compareWith: 3
        equals 3
        not numeric
        OUTPUT, implode("\n", $lines));
    }

    public function testGetClosure(): void
    {
        $lines = $this->runTest("classes", "closure.php");        
        $this->assertSame(<<<OUTPUT
        getClosure: false
        .{ .number1 = 2.5, .number2 = 10 }
        result = 12.5
        OUTPUT, implode("\n", $lines));
    }

    public function testCastObject(): void
    {
        $lines = $this->runTest("classes", "cast.php");        
        $this->assertSame(<<<OUTPUT
        to bool => castObject
        true
        to int => castObject
        3
        to float => castObject
        3.141592653589793
        to string => castObject
        '3.141592653589793'
        OUTPUT, implode("\n", $lines));
    }

    public function testDoOperation(): void
    {
        $lines = $this->runTest("classes", "operation.php");        
        $this->assertSame(<<<OUTPUT
        doOperation: .add 3.141592653589793 2
        5.1415926535898
        doOperation: .sub 3.141592653589793 2
        1.1415926535898
        doOperation: .mul 3.141592653589793 2
        6.2831853071796
        doOperation: .div 3.141592653589793 2
        1.5707963267949
        OUTPUT, implode("\n", $lines));
    }

    public function testGetGarbageCollection(): void
    {
        $lines = $this->runTest("classes", "gc.php");
        $this->assertSame("getGarbageCollection", $lines[0]);
    }

    public function testIterate(): void
    {
        $lines = $this->runTest("classes", "iterate.php");
        $this->assertSame(<<<OUTPUT
        iterate
        0: 0
        1: 1
        2: 2
        3: 3
        4: 4
        greeting: Hello
        template: Hello, \$name!
        OUTPUT, implode("\n", $lines));
        // echo implode("\n", $lines);
    }

    public function testGetIterator(): void
    {
        $lines = $this->runTest("classes", "get-iterator.php");
        $this->assertSame(<<<OUTPUT
        getIterator
        0: 0
        1: 1
        2: 2
        3: 3
        4: 4
        OUTPUT, implode("\n", $lines));
    }   
}
