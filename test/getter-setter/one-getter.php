<?php

$obj = new WithOneGetter;
try {
    echo $obj->world;
} catch (Exception $e) {
    echo $e->getMessage(), "\n";
}
print_r($obj);
