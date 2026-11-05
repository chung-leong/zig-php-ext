<?php

$obj = new WithOneGetterAutoGet;
try {
    $obj->world = 777;
} catch (Exception $e) {
    echo $e->getMessage(), "\n";
}
print_r($obj);
try {
    $obj->hello = 777;
} catch (Exception $e) {
    echo $e->getMessage(), "\n";
}
