<?php

$object = new WithIterate();
foreach ($object as $key => $value) {
    echo "$key: $value\n";
}
$greeting = new Greeting;
foreach ($greeting as $key => $value) {
    echo "$key: $value\n";
}