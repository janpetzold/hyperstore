<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Illuminate\Routing\Controller as BaseController;

use Laravel\Passport\Token;

use App\Services\InventoryService;
use App\Services\ScopeService;

class HyperController extends BaseController {

    private $inventoryService;
    private $scopeService;

    public function __construct(InventoryService $inventoryService, ScopeService $scopeService) {
        $this->inventoryService = $inventoryService;
        $this->scopeService = $scopeService;
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

        // Check if the access token has the "stock" scope
        $accessToken = $request->bearerToken();

        if (!$this->scopeService->checkScope($accessToken, "stock")) {
            return response()->json(['message' => 'Insufficient scope.'], 403);
        }

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
