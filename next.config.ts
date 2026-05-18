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
  // Use webpack aliases with canonical paths (realpathSync) to force single React instance
  // DO NOT use serverExternalPackages for react/react-dom - it breaks React 19's
  // conditional exports (react-server vs default) causing null useContext at runtime
  webpack: (config, { isServer }) => {
    // Force single React instance using canonical (real) paths
    const reactPath = getRealPath(path.resolve(process.cwd(), 'node_modules/react'));
    const reactDomPath = getRealPath(path.resolve(process.cwd(), 'node_modules/react-dom'));
    const schedulerPath = getRealPath(path.resolve(process.cwd(), 'node_modules/scheduler'));
    config.resolve.alias = {
      ...config.resolve.alias,
      'react': reactPath,
      'react/jsx-runtime': path.join(reactPath, 'jsx-runtime.js'),
      'react/jsx-dev-runtime': path.join(reactPath, 'jsx-dev-runtime.js'),
      'react-dom/client': path.join(reactDomPath, 'client.js'),
      'react-dom/server': path.join(reactDomPath, 'server.js'),
      'react-dom/server.browser': path.join(reactDomPath, 'server.browser.js'),
      'react-dom': reactDomPath,
      'scheduler': schedulerPath,
    };
    // Prevent webpack from resolving different React instances via symlinks
    config.resolve.symlinks = false;
    // Ensure React is bundled (not externalized) on server too
    config.externals = config.externals.filter(
      (e: string | RegExp | Function) => {
        if (typeof e === 'string') return e !== 'react' && e !== 'react-dom' && e !== 'scheduler';
        if (e instanceof RegExp) return !e.test('react') && !e.test('react-dom') && !e.test('scheduler');
        return true;
      }
    );
    return config;
  },
};

export default nextConfig;
