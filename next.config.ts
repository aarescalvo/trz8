import type { NextConfig } from "next";
import path from "path";
import fs from "fs";

// Obtener origins permitidos desde variable de entorno, con fallback para desarrollo
const getAllowedOrigins = (): string[] => {
  const envOrigins = process.env.NEXT_PUBLIC_APP_URL;
  if (envOrigins) {
    return envOrigins.split(',').map(o => o.trim());
  }
  // En desarrollo permitir localhost
  return [
    'http://localhost:3000',
    'http://localhost:3001',
  ];
};

// Use realpathSync to get canonical path (fixes Windows case-insensitive duplication)
const getRealPath = (p: string) => {
  try { return fs.realpathSync(p); } catch { return p; }
};

// Version: 3.18.0 - Security hardening + quality improvements
const nextConfig: NextConfig = {
  typescript: {
    ignoreBuildErrors: false,
  },
  reactStrictMode: false,
  // Permitir requests cross-origin en desarrollo (red local, IP dinámica)
  allowedDevOrigins: ['http://192.168.1.153:3000'],
  experimental: {
    serverActions: {
      allowedOrigins: getAllowedOrigins(),
    },
  },
  // Fix Windows case-insensitive path causing duplicate React instances
  // Don't bundle react/react-dom for server - let Node.js resolve them at runtime
  serverExternalPackages: ['react', 'react-dom'],
  webpack: (config) => {
    // Force single React instance using canonical (real) paths
    const reactPath = getRealPath(path.resolve(process.cwd(), 'node_modules/react'));
    const reactDomPath = getRealPath(path.resolve(process.cwd(), 'node_modules/react-dom'));
    const schedulerPath = getRealPath(path.resolve(process.cwd(), 'node_modules/scheduler'));
    config.resolve.alias = {
      ...config.resolve.alias,
      'react': reactPath,
      'react-dom/client': path.join(reactDomPath, 'client.js'),
      'react-dom/server': path.join(reactDomPath, 'server.js'),
      'react-dom/server.browser': path.join(reactDomPath, 'server.browser.js'),
      'react-dom': reactDomPath,
      'scheduler': schedulerPath,
    };
    return config;
  },
};

export default nextConfig;
