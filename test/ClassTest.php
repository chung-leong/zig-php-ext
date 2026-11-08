<?php declare(strict_types=1);

require_once __DIR__ . '/ExtensionTestCase.php';

final class ClassTest extends ExtensionTestCase
{   
    public function testSimpleClass(): void
    {
        $lines = $this->runTest("class", "simple.php");
        $this->assertSame(<<<OUTPUT
        Hello, Bob!
        Hello
        Hi, Alice!
        OUTPUT, implode(PHP_EOL, $lines));
    }

    public function testOptionalFields(): void
    {
        $lines = $this->runTest("class", "optional.php");
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
        OUTPUT, implode(PHP_EOL, $lines));
    }

    public function testDefaultConstructor(): void
    {
        $lines = $this->runTest("class", "def-constructor.php");
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
        OUTPUT, implode(PHP_EOL, $lines));
    }

    public function testComputedProperty(): void
    {
        $lines = $this->runTest("class", "computed.php");
        $this->assertSame("normal = 5", $lines[0]);
        $this->assertSame("template = Hi, \$name!", $lines[1]);
    }

    public function testConstructor(): void
    {
        $lines = $this->runTest("class", "constructor.php");
        $this->assertSame(<<<OUTPUT
        Cat (.pet)
        Martin (.wild)
        Croissant (.wild)
        OUTPUT, implode(PHP_EOL, $lines));
    }

    public function testStaticMethod(): void
    {
        $lines = $this->runTest("class", "static-method.php");
        $this->assertSame(<<<OUTPUT
        number = 123
        text = Chicken
        OUTPUT, implode(PHP_EOL, $lines));
    }

    public function testStaticConstant(): void
    {
        $lines = $this->runTest("class", "static-constant.php");
        $this->assertSame(<<<OUTPUT
        number = 1234
        text = Hello world
        array = Array
        (
            [0] => 1.23
            [1] => 0.234
            [2] => 3.45
        )
        Enum = WithStatic\Enum
        cat = 0
        dog = 1
        dog = 1
        Flag = WithStatic\Flag
        pork = 4
        OUTPUT, implode(PHP_EOL, $lines));
    }

    public function testFreeObject(): void
    {
        $lines = $this->runTest("class", "free-object.php");
        $this->assertSame(<<<OUTPUT
        destroyObject
        freeObject
        OUTPUT, implode(PHP_EOL, $lines));
    }

    public function testGetConstructor(): void
    {
        $lines = $this->runTest("class", "get-constructor.php");
        // no "init" or "deinit"
        $this->assertSame(<<<OUTPUT
        getConstructor
        constructor: 1234, Hello world
        destroyObject
        freeObject
        OUTPUT, implode(PHP_EOL, $lines));
    }

    public function testCloneObject(): void
    {
        $lines = $this->runTest("class", "clone-object.php");
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
        OUTPUT, implode(PHP_EOL, $lines));
    }

    public function testClone(): void
    {
        $lines = $this->runTest("class", "clone.php");
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
        OUTPUT, implode(PHP_EOL, $lines));
    }

    public function testReadProperty(): void
    {
        $lines = $this->runTest("class", "properties.php");
        $this->assertSame(<<<OUTPUT
        number = 2001
        foo = (readProperty: foo) 4567
        bar = (readProperty: bar) Rats live on no evil star
        (writeProperty: foo)
        number = 777
        (readProperty: cow) no property named 'cow' in WithReadProperty
        (writeProperty: cow)
        (hasProperty: cow) no property named 'cow' in WithReadProperty
        (writeProperty: bar)
        unable to write property 'bar' in WithReadProperty - read only
        true
        (hasProperty: foo) (readProperty: foo) true
        (hasProperty: bar) (readProperty: bar) true
        (hasProperty: cow) false
        optional = 789
        optional =
        (unsetProperty: foo)
        foo = (readProperty: foo) -1
        unable to unset property 'number' in WithReadProperty - cannot be null
        (unsetProperty: cow)
        no property named 'cow' in WithReadProperty
        OUTPUT, implode(PHP_EOL, $lines));
    }

    public function testReadPropertyWithCache(): void
    {
        $lines = $this->runTest("class", "properties-cache.php");
        $this->assertSame(<<<OUTPUT
        number = 2001
        foo = (readProperty: foo) 4567
        bar = (readProperty: bar) Rats live on no evil star
        (writeProperty: foo)
        number = 777
        (readProperty: cow) no property named 'cow' in WithReadPropertyCache
        (writeProperty: cow)
        (hasProperty: cow) no property named 'cow' in WithReadPropertyCache
        (writeProperty: bar)
        unable to write property 'bar' in WithReadPropertyCache - read only
        true
        (hasProperty: foo) (readProperty: foo) true
        (hasProperty: bar) (readProperty: bar) true
        (hasProperty: cow) false
        optional = 789
        optional =
        (unsetProperty: foo)
        foo = (readProperty: foo) -1
        unable to unset property 'number' in WithReadPropertyCache - cannot be null
        (unsetProperty: cow)
        no property named 'cow' in WithReadPropertyCache
        OUTPUT, implode(PHP_EOL, $lines));
    }

    public function testReadDimension(): void
    {
        $lines = $this->runTest("class", "dimension.php");
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
        OUTPUT, implode(PHP_EOL, $lines));
    }

    public function testGetClassName(): void
    {
        $lines = $this->runTest("class", "class-name.php");
        $this->assertSame(<<<OUTPUT
        getClassName
        DingoPower Object
        (
            [number] => 787
        )
        OUTPUT, implode(PHP_EOL, $lines));
    }

    public function testGetProperties(): void
    {
        $lines = $this->runTest("class", "property-array.php");
        $this->assertSame(<<<OUTPUT
        (getProperties: .debug) WithGetProperties Object
        (
            [number] => 1979
            [optional] =>
            [foo] => cowboy
            [bar] => mleczny
            [17] => 3.1415926535898
        )
        OUTPUT, implode(PHP_EOL, $lines));
    }

    public function testGetPropertiesNoGetter(): void
    {
        $lines = $this->runTest("class", "property-array-no-getters.php");
        $this->assertSame(<<<OUTPUT
        (getProperties: .debug) WithGetPropertiesNoGetters Object
        (
            [foo] => cowboy
            [bar] => mleczny
            [17] => 3.1415926535898
        )
        OUTPUT, implode(PHP_EOL, $lines));
    }

    public function testGetMethod(): void
    {
        $lines = $this->runTest("class", "method.php");        
        echo 
        $this->assertSame(<<<OUTPUT
        foo
        getMethod
        bar
        hello world
        hello world
        getMethod
        bar
        OUTPUT, implode(PHP_EOL, $lines));
    }

    public function testCompareWith(): void
    {
        $lines = $this->runTest("class", "compare.php");        
        $this->assertSame(<<<OUTPUT
        compareWith: 4
        less than 4
        compareWith: 2.9
        greater than 2.9
        compareWith: 3
        equals 3
        not numeric
        OUTPUT, implode(PHP_EOL, $lines));
    }

    public function testGetClosure(): void
    {
        $lines = $this->runTest("class", "closure.php");        
        $this->assertSame(<<<OUTPUT
        getClosure: false
        .{ .number1 = 2.5, .number2 = 10 }
        result = 12.5
        OUTPUT, implode(PHP_EOL, $lines));
    }

    public function testCastObject(): void
    {
        $lines = $this->runTest("class", "cast.php");        
        $this->assertSame(<<<OUTPUT
        to bool => castObject
        true
        to int => castObject
        3
        to float => castObject
        3.141592653589793
        to string => castObject
        '3.141592653589793'
        OUTPUT, implode(PHP_EOL, $lines));
    }

    public function testDoOperation(): void
    {
        $lines = $this->runTest("class", "operation.php");        
        $this->assertSame(<<<OUTPUT
        doOperation: .add 3.141592653589793 2
        5.1415926535898
        doOperation: .sub 3.141592653589793 2
        1.1415926535898
        doOperation: .mul 3.141592653589793 2
        6.2831853071796
        doOperation: .div 3.141592653589793 2
        1.5707963267949
        OUTPUT, implode(PHP_EOL, $lines));
    }

    public function testGetGarbageCollection(): void
    {
        $lines = $this->runTest("class", "gc.php");
        $this->assertSame("getGarbageCollection", $lines[0]);
    }

    public function testIterate(): void
    {
        $lines = $this->runTest("class", "iterate.php");
        $this->assertSame(<<<OUTPUT
        iterate
        0: 0
        1: 1
        2: 2
        3: 3
        4: 4
        greeting: Hello
        template: Hello, \$name!
        OUTPUT, implode(PHP_EOL, $lines));
        // echo implode(PHP_EOL, $lines);
    }

    public function testGetIterator(): void
    {
        $lines = $this->runTest("class", "get-iterator.php");
        $this->assertSame(<<<OUTPUT
        getIterator
        0: 0
        1: 1
        2: 2
        3: 3
        4: 4
        OUTPUT, implode(PHP_EOL, $lines));
    }

    public function testSubclass(): void
    {
        $lines = $this->runTest("class", "subclass.php");
        $this->assertSame(<<<OUTPUT
        Hello
        2
        Hello world
        Hello world
        OUTPUT, implode(PHP_EOL, $lines));
    }

    public function testObjectArgument(): void
    {
        $lines = $this->runTest("class", "obj-argument.php");
        $this->assertSame("x = 1.23, y = 4.56", $lines[0]);
    }

    public function testComplexProperties(): void
    {
        $lines = $this->runTest("class", "complex.php");
        $this->assertSame(<<<OUTPUT
        ComplexProperties Object
        (
            [string] =>
            [strings] => Array
                (
                    [0] => A
                    [1] => B
                )

            [array] => Array
                (
                )

            [object] => stdClass Object
                (
                )

            [child] => ComplexProperties\Child Object
                (
                    [number] => 1
                )

            [children] => Array
                (
                    [0] => ComplexProperties\Child Object
                        (
                            [number] => 100
                        )

                    [1] => ComplexProperties\Child Object
                        (
                            [number] => 101
                        )

                    [2] => ComplexProperties\Child Object
                        (
                            [number] => 102
                        )

                )

            [twins] => Array
                (
                    [0] => ComplexProperties\Child Object
                        (
                            [number] => 201
                        )

                    [1] => ComplexProperties\Child Object
                        (
                            [number] => 202
                        )

                )

            [friends] => stdClass Object
                (
                    [bob] => ComplexProperties\Child Object
                        (
                            [number] => 41
                        )

                    [jack] => ComplexProperties\Child Object
                        (
                            [number] => 42
                        )

                )

        )
        ComplexProperties Object
        (
            [string] => This is a test
            [strings] => Array
                (
                    [0] => Hello
                    [1] => world
                    [2] => Whatever
                    [3] => ?
                )

            [array] => Array
                (
                    [0] => 1
                    [1] => 2
                    [2] => 3
                )

            [object] => stdClass Object
                (
                    [chicken] => 5
                    [cow] => 10
                )

            [child] => ComplexProperties\Child Object
                (
                    [number] => 77
                )

            [children] => Array
                (
                    [0] => ComplexProperties\Child Object
                        (
                            [number] => 100
                        )

                    [1] => ComplexProperties\Child Object
                        (
                            [number] => 101
                        )

                    [2] => ComplexProperties\Child Object
                        (
                            [number] => 102
                        )

                )

            [twins] => Array
                (
                    [0] => ComplexProperties\Child Object
                        (
                            [number] => 301
                        )

                    [1] => ComplexProperties\Child Object
                        (
                            [number] => 302
                        )

                )

            [friends] => stdClass Object
                (
                    [bob] => ComplexProperties\Child Object
                        (
                            [number] => 51
                        )

                    [jack] => ComplexProperties\Child Object
                        (
                            [number] => 52
                        )

                )

        )
        OUTPUT, implode(PHP_EOL, $lines));
    }

    public function testObjectReturnValue(): void
    {
        $lines = $this->runTest("class", "obj-retval.php");
        $this->assertSame(<<<OUTPUT
        Point Object
        (
            [x] => 1234.5
            [y] => 4567.8
            [normal] => 4731.6790983751
        )
        OUTPUT, implode(PHP_EOL, $lines));
    }

    public function testMixedReturnValue(): void
    {
        $lines = $this->runTest("class", "mixed-retval.php");
        $this->assertSame(<<<OUTPUT
        Array
        (
            [0] => Point Object
                (
                    [x] => 1234.5
                    [y] => 4567.8
                    [normal] => 4731.6790983751
                )

            [1] => Hello world
        )
        OUTPUT, implode(PHP_EOL, $lines));
    }

    public function testClassConstant(): void
    {
        $lines = $this->runTest("class", "constant.php");
        if (PHP_MINOR_VERSION >= 5 || PHP_MAJOR_VERSION > 8) {
            $this->assertSame(<<<OUTPUT
            1234
            Array
            (
                [0] => 1
                [1] => 2
                [2] => 3
                [3] => 4
            )
            Array
            (
                [0] => 1
                [1] => 2
                [2] => Hello world
            )
            stdClass Object
            (
                [cow] => 123
                [pig] => 456
            )
            OUTPUT, implode(PHP_EOL, $lines));
        } else {
            $this->assertSame(<<<OUTPUT
            1234
            Array
            (
                [0] => 1
                [1] => 2
                [2] => 3
                [3] => 4
            )
            Array
            (
                [0] => 1
                [1] => 2
                [2] => Hello world
            )
            Array
            (
                [cow] => 123
                [pig] => 456
            )
            OUTPUT, implode(PHP_EOL, $lines));
        }
    }

    public function testDeinitAvoidance(): void
    {
        $lines = $this->runTest("class", "uncreatable.php");
        $this->assertSame(<<<OUTPUT
        init
        uncreatable
        construct() expects exactly 1 argument, 0 given
        OUTPUT, implode(PHP_EOL, $lines));
    }
}
