<?php
// Set the content type to text/plain
header('Content-Type: text/plain');

// Function to print "Hello, World!"
function printHelloWorld() {
    echo "Hello, World!\n";
     ob_flush();
    flush();
}

// Print "Hello, World!" initially
printHelloWorld();

// Loop indefinitely
while (true) {
    // Sleep for 5 seconds
    sleep(5);
    // Print "Hello, World!"
    printHelloWorld();
}
?>