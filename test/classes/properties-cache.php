<?php

$object = new WithReadPropertyCache();
echo "number = ", $object->number, "\n";
$object->number = 4567;
echo "foo = ", $object->foo, "\n";
echo "bar = ", $object->bar, "\n";
$object->foo = 777;
echo "number = ", $object->number, "\n";

try {
    echo $object->cow;
} catch (Exception $e) {
    echo $e->getMessage(), "\n";
}
try {
    $object->cow = 72;
} catch (Exception $e) {
    echo $e->getMessage(), "\n";
}
try {
    $object->bar = "Evil donuts";
} catch (Exception $e) {
    echo $e->getMessage(), "\n";
}

echo isset($object->number) ? 'true' : 'false', "\n";
echo isset($object->foo) ? 'true' : 'false', "\n";
echo isset($object->bar) ? 'true' : 'false', "\n";
echo isset($object->cow) ? 'true' : 'false', "\n";

echo "optional = ", $object->optional, "\n";
unset($object->optional);
echo "optional = ", $object->optional, "\n";
unset($object->foo);
echo "foo = ", $object->foo, "\n";

try {
    unset($object->number);
} catch (Exception $e) {
    echo $e->getMessage(), "\n";
}
try {
    unset($object->cow);
} catch (Exception $e) {
    echo $e->getMessage(), "\n";
}
