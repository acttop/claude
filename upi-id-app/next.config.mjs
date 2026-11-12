/** @type {import('next').NextConfig} */
const basePath = process.env.PAGES_BASE_PATH || "";

const nextConfig = {
  reactStrictMode: true,
  // 서버 기능 없이 동작하므로 정적 사이트(out/)로 빌드
  output: "export",
  // GitHub Pages 하위 경로 배포용 (예: PAGES_BASE_PATH=/claude/upi)
  basePath,
  trailingSlash: true,
};

export default nextConfig;
