import "@testing-library/jest-dom";
import { vi } from "vitest";

// Mock server-only in test environment
vi.mock("server-only", () => ({}));
