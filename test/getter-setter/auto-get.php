<?php

$obj = new WithAutoGetters;
try {
    $obj->world = 777;
} catch (Exception $e) {
    echo $e->getMessage(), "\n";
}
print_r($obj);
