<?php declare(strict_types=1);

require_once __DIR__ . '/../ExtensionTestCase.php';

final class WikiAllocatorTest extends ExtensionTestCase
{   
    public function testAllocatorLifeCycle(): void
    {
        $lines = $this->runTest("allocator-life-cycle", "test.php");
        $this->assertSame(<<<OUTPUT
        persistent string: some text
        string = Hello world
        OUTPUT, implode(PHP_EOL, $lines));
    }

    public function testAllocatorOutOfMemoryError(): void
    {
        try {
            $this->runTest("allocator-out-of-mem", "test.php");
            $this->fail();
        } catch (Exception $e) {
            $msg = $e->getMessage();
            $this->assertStringContainsString("exhausted", $e->getMessage());
        }
    }

    public function testAllocatorOutOfMemoryErrorFromIntOverflow(): void
    {
        $lines = $this->runTest("allocator-out-of-mem-overflow", "test.php");
        $this->assertSame(<<<OUTPUT
        Error: error.OutOfMemory
        OUTPUT, implode(PHP_EOL, $lines));
    }

    public function testStringAllocator(): void
    {
        $lines = $this->runTest("allocator-string", "test.php");
        echo implode(PHP_EOL, $lines), "\n";
        $this->assertSame(<<<OUTPUT
        address of allocated memory = 0x7577d9a82068
        Hello, Joe!
        address of string contents = 0x7577d9a82068
        OUTPUT, implode(PHP_EOL, $lines));
    }
}