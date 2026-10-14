<?php

$object = new WithClone(4567, "I am Groot");
print_r($object);
$new_object = clone $object;
print_r($new_object);
