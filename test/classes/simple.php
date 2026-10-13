<?php

$greeting = new Greeting("Hello");
$greeting->greet("Bob");
echo $greeting->greeting, "\n"; 
$greeting->greeting = "Hi";
$greeting->greet("Alice");
