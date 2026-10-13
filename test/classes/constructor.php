<?php

$list = new ObjectList;
$list->print();
$list = new ObjectList([
    [ 'name' => 'Cat', 'type' => 'pet' ],
    [ 'name' => 'Martin', 'type' => 'wild' ],
    [ 'name' => 'Croissant', 'type' => 'wild' ],
]);
$list->print();
