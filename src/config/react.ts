import {
    BACKEND_HOST,
    BACKEND_PORT,
    API_PREFIX,
} from "./config_socle";

export const BACKEND_URL =
    `http://${BACKEND_HOST}:${BACKEND_PORT}`;

export const API_URL =
    `${BACKEND_URL}${API_PREFIX}`;
