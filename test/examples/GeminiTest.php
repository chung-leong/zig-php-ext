<?php declare(strict_types=1);

require_once __DIR__ . '/../ExtensionTestCase.php';

final class GeminiTest extends ExtensionTestCase
{   
    public function testTextReplacementFunction(): void
    {
        $lines = $this->runTest("gemini", "replace.php");
        $this->assertSame(<<<OUTPUT
        The initial phase of our corporate relocation strategy began in **California**, where the tech division evaluated the fast-growing markets of the West Coast. Team members traveled north into **Oregon** and **Washington** to analyze the Pacific Northwest corridor, before heading inland through **Nevada** and **Idaho** to look at renewable energy infrastructure. The logistics group then mapped a route through the rugged terrains of **Montana**, **Wyoming**, and **Utah** to evaluate overland shipping lanes. Meanwhile, our agricultural analytics team focused heavily on the central plains, starting in **Colorado** and moving east through **Nebraska**, **Kansas**, and **Oklahoma**.

        To coordinate these regional findings, the executive board convened a summit down in **Texas**. The southern expansion strategy plotted a path across **Louisiana**, **Mississippi**, and **Alabama**, focusing on Gulf Coast port access. From there, representatives flew into **Florida** to assess the southeastern consumer market before moving northward up the Atlantic coast through **Georgia**, **South Carolina**, and **North Carolina**. The final leg of the survey took the team through the historical industrial centers of **Virginia**, **Maryland**, and **Delaware**, before concluding the massive field study with a wrap-up meeting in **Pennsylvania**.

        OUTPUT, implode(PHP_EOL, $lines));
    }

    public function testRegularExpressionFunction(): void {
        $lines = $this->runTest("gemini", "regexp.php");
        $this->assertSame(<<<OUTPUT
        is_variable_name("hello world") =>
        is_variable_name("\\\$hello") => 1
        OUTPUT, implode(PHP_EOL, $lines));
    }
}
