<?php

$object = new WithReadDimension();
echo "len = ", $object->len, "\n";
echo "count = ", count($object), "\n";

echo $object[4], "\n";
$object[4] = 1.25;
echo $object[4], "\n";
$object['5'] = '8.8';
echo $object[5.0], "\n";

try {
    echo $object[8];
} catch (Exception $e) {
    echo $e->getMessage(), "\n";
}
try {
    echo $object[-2];
} catch (Exception $e) {
    echo $e->getMessage(), "\n";
}
try {
    echo $object['hello'];
} catch (Exception $e) {
    echo $e->getMessage(), "\n";
}
try {
    $object[3] = 'foobar';
} catch (Exception $e) {
    echo $e->getMessage(), "\n";
}

echo isset($object[4]) ? 'true' : 'false', "\n";
echo isset($object[-2]) ? 'true' : 'false', "\n";
echo isset($object[8]) ? 'true' : 'false', "\n";
echo isset($object['hello']) ? 'true' : 'false', "\n";

unset($object[4]);
echo $object[4], "\n";

try {
    unset($object[-2]);
} catch (Exception $e) {
    echo $e->getMessage(), "\n";
}
