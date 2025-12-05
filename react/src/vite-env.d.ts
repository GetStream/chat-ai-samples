interface ImportMetaEnv {
	readonly VITE_STREAM_API_KEY: string | undefined;
	readonly VITE_STREAM_USER_TOKEN: string | undefined;
}

interface ImportMeta {
	readonly env: ImportMetaEnv;
}
