<?php

$object = new ComplexProperties();
$object = new ComplexProperties();
print_r($object);
$object->string = "This is a test";
$object->strings = [ "Hello", "world", "Whatever", "?" ];
$object->array = [ 1, 2, 3];
$object->object = (object) [ 'chicken' => 5, 'cow' => 10 ];
$object->child = new ComplexProperties\Child(77);
print_r($object);

