<?php

function capture($f) {
    try {
        $f();
    } catch (Exception $e) {
        echo $e->getMessage(), "\n";
        return;
    }
    throw new Exception("Exception expected");
}

capture(function() { 
    printBool();
});
capture(function() { 
    printIntFloats(1, 123.3, 45, 777); 
});
capture(function() { 
    printIntFloats(1.3, 123.3, 45); 
});
capture(function() { 
    printBool([]); 
});
capture(function() { 
    printUnion(new stdClass); 
});
capture(function() { 
    printIntOrFloat('Hello'); 
});
capture(function() { 
    acceptPoultry('Hello'); 
});
capture(function() { 
    acceptOptions(1234, alpha: "hello"); 
});
capture(function() { 
    acceptOptions(1234, beta: "hello"); 
});
capture(function() { 
    acceptOptions(1234, gamma: "hello"); 
});
capture(function() {
    printStruct([]);
});
capture(function() {
    printStructRequireTwo([]);
});
capture(function() {
    printStructRequireMultiple([]);
});


