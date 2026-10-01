import {defineConfig} from 'vite';
import react from '@vitejs/plugin-react';
import {VitePWA} from 'vite-plugin-pwa';
export default defineConfig({plugins:[react(),VitePWA({registerType:'autoUpdate',injectRegister:null,includeAssets:['icon-180.png','icon-192.png','icon-512.png','launch-iphone17pro.png'],manifest:{name:'Ediz OS',short_name:'Ediz OS',description:'Ediz’s personal operating system',id:'/',scope:'/',theme_color:'#0e0d0b',background_color:'#0e0d0b',display:'standalone',orientation:'portrait-primary',start_url:'/',icons:[{src:'/icon-192.png',sizes:'192x192',type:'image/png'},{src:'/icon-512.png',sizes:'512x512',type:'image/png',purpose:'any maskable'}]},workbox:{navigateFallback:'/index.html',globPatterns:['**/*.{js,css,html,png,jpg,svg,woff,woff2,webmanifest}']}})]});
