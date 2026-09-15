import axios from "axios";

export const http = axios.create({
  timeout: 5000,
  headers: {
    "Content-Type": "application/json",
  },
});