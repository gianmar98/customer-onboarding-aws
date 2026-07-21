import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  /* config options here */
    output: "export", //built to static HTML/JS in ./out
    images: {unoptimized: true}, //Next Image optimizer needs a server, we dont have one
};

export default nextConfig;
