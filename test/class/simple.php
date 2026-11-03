<?php

$greeting = new Greeting;
$greeting->greet("Bob");
echo $greeting->greeting, "\n"; 
$greeting->greeting = "Hi";
$greeting->greet("Alice");
