<?php

$obj = new WithNoGettersNoAutoSet;
try {
    $obj->world = 777;
} catch (Exception $e) {
    echo $e->getMessage(), "\n";
}
print_r($obj);
