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

show([
    new Person("Ralph Wiggum", "Politician", 24),
    new Person("Lisa Simpson", "Physicist", 25),
    new Person("Nelson Muntz", "Psychologist", 26),
]);
