<?php

namespace App\Services;

/**
 * This class was introduced since the default scope checkers only operate on "User" level,
 * however we're testing API-based authentication here therefore scope checking has to
 * be done manually until we find a better way.
 */
class ScopeService {

    private function parseToken(string $token): ?array {
        $parts = explode('.', $token);

        if (count($parts) !== 3) {
            return null;
        }

        $payloadBase64 = $parts[1];
        $payload = base64_decode($payloadBase64);

        if ($payload === false) {
            return null;
        }

        $payloadData = json_decode($payload, true);

        if (!is_array($payloadData)) {
            return null;
        }

        return $payloadData;
    }

    public function checkScope(string $token, string $requiredScope): bool {
        $payload = $this->parseToken($token);

        if ($payload && isset($payload['scopes'])) {
            return in_array($requiredScope, $payload['scopes']);
        }

        return false;
    }

}