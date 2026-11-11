<?php

$flags_obj = new Flags();
$flags_obj->is_fast = $flags_obj->is_good = true;

$flags_int = Flags::is_fast | Flags::is_good;
var_dump($flags_obj);
var_dump((int) $flags_obj);
var_dump($flags_int);
