<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Illuminate\Routing\Controller as BaseController;

class HyperController extends BaseController {

    // Ensure the session is started since we need session to store any kind of state here
    public function __construct() {
        if (session_status() == PHP_SESSION_NONE) {
            session_start();
        }
    }

    // GET /hyper
    public function getHyper() {
        $quantity = session('quantity', 0);
        return response()->json(['quantity' => $quantity]);
    }

    // POST /hyper
    public function setHyper(Request $request) {
        $request->validate([
            'quantity' => 'required|integer|min:0',
        ]);

        session(['quantity' => $request->input('quantity')]);
        $quantity = session('quantity');

        return response()->json(['message' => "Quantity set successfully to $quantity Hyper"]);
    }

    // PUT /hyper/own
    public function ownHyper() {
        $quantity = session('quantity', 0);

        if ($quantity > 0) {
            $quantity--;
            session(['quantity' => $quantity]);
            return response()->json(['message' => 'Hyper acquired successfully']);
        }
        return response()->json(['message' => 'No Hyper available for you'], 404);
    }
}
