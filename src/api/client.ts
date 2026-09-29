import { API_URL } from "../config/react";

export async function getLab() {
    const response = await fetch(`${API_URL}/lab`);

    if (!response.ok) {
        throw new Error(`HTTP ${response.status}`);
    }

    return response.json();
}

export async function getHealth() {
    const response = await fetch(`${API_URL}/health`);

    if (!response.ok) {
        throw new Error(`HTTP ${response.status}`);
    }

    return response.json();
}