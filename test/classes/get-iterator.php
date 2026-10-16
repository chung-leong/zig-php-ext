<?php

$object = new WithGetIterator();
foreach ($object as $key => $value) {
    echo "$key: $value\n";
}
