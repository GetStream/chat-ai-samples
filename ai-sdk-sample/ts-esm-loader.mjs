import { readFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import ts from 'typescript';

const tsConfigUrl = new URL('./tsconfig.json', import.meta.url);
const tsConfigDir = path.dirname(fileURLToPath(tsConfigUrl));
const tsConfig = JSON.parse(await readFile(tsConfigUrl, 'utf8'));

const compilerOptions = ts.convertCompilerOptionsFromJson(
  tsConfig.compilerOptions ?? {},
  tsConfigDir,
).options;

export async function load(url, context, defaultLoad) {
  if (url.endsWith('.ts')) {
    const source = await readFile(new URL(url));
    const { outputText } = ts.transpileModule(source.toString(), {
      compilerOptions: {
        ...compilerOptions,
        sourceMap: false,
      },
      fileName: fileURLToPath(url),
    });

    return {
      format: 'module',
      shortCircuit: true,
      source: outputText,
    };
  }

  return defaultLoad(url, context, defaultLoad);
}
