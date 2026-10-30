<?php declare(strict_types=1);

require_once __DIR__ . '/ExtensionTestCase.php';

final class ZstdTest extends ExtensionTestCase
{   
    public function testCompression(): void
    {
        $lines = $this->runTest("zstd", "compress.php");
        $this->assertSame(<<<OUTPUT
            To-morrow, and to-morrow, and to-morrow,
            Creeps in this petty pace from day to day,
            To the last syllable of recorded time;
            And all our yesterdays have lighted fools
            The way to dusty death. Out, out, brief candle!
            Life's but a walking shadow, a poor player,
            That struts and frets his hour upon the stage,
            And then is heard no more. It is a tale
            Told by an idiot, full of sound and fury,
            Signifying nothing.
        OUTPUT, implode(PHP_EOL, $lines));
    }
}
