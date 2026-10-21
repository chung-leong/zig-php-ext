<?php

use hello\world\WithSubclasses;

echo WithSubclasses::SubclassA::hello, "\n";
echo hello\world\WithSubclasses\SubclassA::Animal::cow, "\n";

$object = new hello\world\WithSubclasses\SubclassB();
echo $object->hello, "\n";
$object = new (hello\world\WithSubclasses::SubclassB)();
echo $object->hello, "\n";
