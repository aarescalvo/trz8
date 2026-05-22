import type { NextConfig } from "next";

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
  // Fix: evitar que React se externalice en el server bundle
  // Sin esto, los componentes del servidor obtienen null al llamar useContext()
  webpack: (config, { isServer }) => {
    if (isServer) {
      // Convertir config.externals a función para filtrar react
      const originalExternals = config.externals;
      if (typeof originalExternals === 'string' || Array.isArray(originalExternals)) {
        config.externals = (ctx, cb) => {
          (Array.isArray(originalExternals) ? originalExternals : [originalExternals]).forEach(ext => {
            if (typeof ext === 'string' && !['react', 'react-dom', 'scheduler'].includes(ext)) {
              ctx.addExternal(ext);
            }
          });
          cb();
        };
      } else if (typeof originalExternals === 'function') {
        config.externals = (ctx, cb, done) => {
          originalExternals(ctx, (err, externals) => {
            if (err) { cb(err); return; }
            const filtered = Array.isArray(externals)
              ? externals.filter(e => typeof e !== 'string' || !['react', 'react-dom', 'scheduler'].includes(e))
              : externals;
            cb(null, filtered);
          }, done);
        };
      } else if (Array.isArray(originalExternals)) {
        config.externals = originalExternals.filter(
          e => typeof e !== 'string' || !['react', 'react-dom', 'scheduler'].includes(e)
        );
      }
    }
    return config;
  },
};

export default nextConfig;
