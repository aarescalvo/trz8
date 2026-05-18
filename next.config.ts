import type { NextConfig } from "next";
import path from "path";

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

// Version: 3.18.0 - Security hardening + quality improvements
const nextConfig: NextConfig = {
  output: 'standalone',
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
  // (e.g. C:\TrazaAlan vs C:\Trazaalan produce different webpack cache keys)
  webpack: (config) => {
    config.resolve.alias = {
      ...config.resolve.alias,
      'react': path.resolve(process.cwd(), 'node_modules/react'),
      'react-dom': path.resolve(process.cwd(), 'node_modules/react-dom'),
    };
    return config;
  },
};

export default nextConfig;
