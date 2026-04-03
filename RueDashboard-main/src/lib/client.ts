import axios, { AxiosError, type AxiosRequestConfig } from "axios";

const client = axios.create({
  baseURL: import.meta.env.VITE_API_URL ?? "http://187.124.33.153:8080",
  headers: { "Content-Type": "application/json" },
  timeout: 15_000,
});

client.interceptors.request.use((config) => {
  const token = localStorage.getItem("rue_token");
  if (token) config.headers.Authorization = `Bearer ${token}`;
  return config;
});

client.interceptors.response.use(
  (res) => res,
  (err: AxiosError) => {
    if (err.response?.status === 401) {
      localStorage.removeItem("rue_token");
      localStorage.removeItem("rue_user");
      window.location.href = "/login";
    }
    return Promise.reject(err);
  },
);

export default client;

/** Extract a human-readable error message from an axios error */
export function getErrorMessage(err: unknown): string {
  if (err instanceof AxiosError) {
    const data = err.response?.data as Record<string, unknown> | undefined;
    if (typeof data?.error === "string") return data.error;
    if (typeof data?.message === "string") return data.message;
    return err.message;
  }
  if (err instanceof Error) return err.message;
  return "An unexpected error occurred";
}
