/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  // 서버 기능 없이 동작하므로 정적 사이트(out/)로 빌드
  output: "export",
};

export default nextConfig;
