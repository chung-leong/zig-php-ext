<?php

print_r(new WithAutoGettersAutoSetters);
$obj = new WithAutoGettersAutoSetters(hello: 45);
print_r($obj);
$obj->world = 777;
print_r($obj);
