<?php

class Person {
    var $name;
    var $profession;
    var $age;
    
    function __construct($name, $profession, $age) {
        $this->name = $name;
        $this->profession = $profession;
        $this->age = $age;
    }
};

$person = new Person("Ralph Wiggum", "Politician", 24);
show($person);
show([ "name" => "Ralph Wiggum", "profession" => "Politician", "age" => 24 ]);