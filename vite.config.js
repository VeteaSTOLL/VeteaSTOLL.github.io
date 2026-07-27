import { defineConfig } from 'vite';
import { resolve } from 'path';

export default defineConfig({
	base: '/',
	build: {
		outDir: 'dist',
		rollupOptions: {
			input: {
				main: resolve(__dirname, 'index.html'),
				shadercool: resolve(__dirname, 'shadercool.html'),
				mandelbrot: resolve(__dirname, 'mandelbrot.html'),
			},
		},
	},
});
