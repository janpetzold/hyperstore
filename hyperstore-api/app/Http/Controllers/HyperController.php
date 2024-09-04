<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Illuminate\Routing\Controller as BaseController;

use App\Services\InventoryService;

class HyperController extends BaseController {

    private $inventoryService;

    public function __construct(InventoryService $inventoryService) {
        $this->inventoryService = $inventoryService;
    }

    // GET /hyper
    public function getHyper() {
        $quantity = $this->inventoryService->getInventory();
        return response()->json(['quantity' => $quantity]);
    }

    // POST /hyper
    public function setHyper(Request $request) {
        $request->validate([
            'quantity' => 'required|integer|min:0',
        ]);

        $quantity = $request->input('quantity');
        $this->inventoryService->setInventory($quantity);

        return response()->json(['message' => "Quantity set successfully to $quantity Hyper"]);
    }

    // PUT /hyper/own
    public function ownHyper() {
        $quantity = $this->inventoryService->getInventory();

        if ($quantity > 0) {
            $quantity--;
            $this->inventoryService->decrementInventory();
            return response()->json(['message' => 'Hyper acquired successfully']);
        }
        return response()->json(['message' => 'No Hyper available for you'], 404);
    }
}
