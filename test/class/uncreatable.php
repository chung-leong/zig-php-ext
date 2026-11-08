<?php

try {    
    $object = new Uncreatable(1);
} catch (Exception $e) {
    echo $e->getMessage(), "\n";
}
try {
    $object = new Uncreatable();
} catch (Exception $e) {
    echo $e->getMessage(), "\n";
}
unset($object);
