<?php

namespace Tests\Feature;

use App\Http\Controllers\HyperController;
use Tests\TestCase;

class HyperControllerTest extends TestCase
{
    public function test_get_hyper_returns_correct_quantity()
    {
        var_dump(xdebug_is_debugger_active());
        // Arrange
        $expectedQuantity = 5;
        session(['quantity' => $expectedQuantity]);

        // Act
        $response = $this->get('/api/hyper');

        // Assert
        $response->assertStatus(200)
                 ->assertJson(['quantity' => $expectedQuantity]);
    }

    public function test_get_hyper_returns_zero_when_not_set()
    {
        // Act
        $response = $this->get('/api/hyper');

        // Assert
        $response->assertStatus(200)
                 ->assertJson(['quantity' => 0]);
    }
}