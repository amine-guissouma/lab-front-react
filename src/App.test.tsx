import { render, screen } from "@testing-library/react";
import {describe, expect, it, vi} from "vitest";

import App from "./App.tsx";

vi.mock("./api/client", () => ({
    getLab: vi.fn().mockResolvedValue({
        name: "lab-back-django",
    }),
}));

describe("Socle frontend", () => {
    it("affiche le nom du frontend", async () => {
        render(<App />);

        expect(
            screen.getByText(/LAB FRONT/i)
        ).toBeInTheDocument();
    });

    it("affiche le nom du backend", async () => {
        render(<App />);

        expect(
            await screen.findByText(/lab-back-django__/i)
        ).toBeInTheDocument();
    });
});
