import {
  ensureAppleIntelligence,
  shutdownAppleIntelligence,
  EnsureOptions,
} from "./launcher";
import OpenAI from "openai";

export { ensureAppleIntelligence, shutdownAppleIntelligence };

export async function createOpenAIClient(
  options?: EnsureOptions
): Promise<OpenAI> {
  const state = await ensureAppleIntelligence(options);

  return new OpenAI({
    baseURL: state.baseURL,
    apiKey: state.token || "local", // Use token if available, else dummy
    defaultHeaders: state.token
      ? { Authorization: `Bearer ${state.token}` }
      : {},
  });
}
