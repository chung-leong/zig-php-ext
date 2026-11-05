<?php

print_r(new WithNoGettersOrSetters);
$obj = new WithNoGettersOrSetters(hello: 45);
print_r($obj);
$obj->world = 777;
print_r($obj);
