const https = require('https');
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

// ── Token de Vercel ──
// Ya NO va escrito aquí. Se lee de (en orden):
//   1. la variable de entorno VERCEL_TOKEN
//   2. el archivo vercel_token.txt junto a este script (está en .gitignore)
// Si cambias el token, solo actualiza vercel_token.txt — no hay que tocar código.
function leerToken() {
    if (process.env.VERCEL_TOKEN) return process.env.VERCEL_TOKEN.trim();
    const f = path.join(__dirname, 'vercel_token.txt');
    if (fs.existsSync(f)) {
        const t = fs.readFileSync(f, 'utf8').trim();
        if (t) return t;
    }
    console.error('\nERROR: no se encontró el token de Vercel.');
    console.error('Crea el archivo vercel_token.txt en esta carpeta con el token adentro,');
    console.error('o define la variable de entorno VERCEL_TOKEN.\n');
    process.exit(1);
}

const token = leerToken();
const teamId = 'team_Crh14Al7vlA4XukCIsSorIMv';
const projectId = 'prj_ZPcK26zmGolKAd0KSwW5D4lPyqd0';
const dir = __dirname;
const archivosObligatorios = [
    'index.html',
    'erp-nuevo.html',
    'acceso-padres.html',
    'vercel.json',
    'manifest.json',
    'sw.js'
];

console.log('========================================');
console.log('  LPI - Desplegando a Vercel');
console.log('========================================\n');
console.log('Carpeta fuente: ' + fs.realpathSync(dir));

function sha1(buffer) {
    return crypto.createHash('sha1').update(buffer).digest('hex');
}

function uploadFileOnce(buffer, digest) {
    return new Promise((resolve, reject) => {
        const options = {
            hostname: 'api.vercel.com',
            path: '/v2/files',
            method: 'POST',
            headers: {
                'Authorization': 'Bearer ' + token,
                'Content-Type': 'application/octet-stream',
                'Content-Length': buffer.length,
                'x-vercel-digest': digest
            }
        };
        const req = https.request(options, (res) => {
            let data = '';
            res.on('data', c => data += c);
            res.on('end', () => {
                // 200 = uploaded, 409 = already exists (both are fine)
                if (res.statusCode === 200 || res.statusCode === 409) resolve(true);
                else reject(new Error('Upload failed: ' + res.statusCode + ' ' + data));
            });
        });
        req.on('error', reject);
        req.write(buffer);
        req.end();
    });
}

async function uploadFile(buffer, digest) {
    let lastErr;
    for (let attempt = 1; attempt <= 4; attempt++) {
        try { return await uploadFileOnce(buffer, digest); }
        catch (e) {
            lastErr = e;
            process.stdout.write(' (reintento ' + attempt + ') ');
            await new Promise(r => setTimeout(r, 900 * attempt));
        }
    }
    throw lastErr;
}

function deploy(files) {
    return new Promise((resolve, reject) => {
        const body = JSON.stringify({
            name: 'institutelearningproject-project',
            files: files,
            projectSettings: { framework: null, outputDirectory: null, buildCommand: null },
            target: 'production'
        });
        const options = {
            hostname: 'api.vercel.com',
            path: '/v13/deployments?teamId=' + teamId + '&projectId=' + projectId,
            method: 'POST',
            headers: {
                'Authorization': 'Bearer ' + token,
                'Content-Type': 'application/json',
                'Content-Length': Buffer.byteLength(body)
            }
        };
        const req = https.request(options, (res) => {
            let data = '';
            res.on('data', c => data += c);
            res.on('end', () => resolve(JSON.parse(data)));
        });
        req.on('error', reject);
        req.write(body);
        req.end();
    });
}

function deploymentStatus(id) {
    return new Promise((resolve, reject) => {
        const options = {
            hostname: 'api.vercel.com',
            path: '/v13/deployments/' + encodeURIComponent(id) + '?teamId=' + teamId,
            method: 'GET',
            headers: { 'Authorization': 'Bearer ' + token }
        };
        const req = https.request(options, (res) => {
            let data = '';
            res.on('data', c => data += c);
            res.on('end', () => {
                try {
                    const parsed = JSON.parse(data);
                    if (res.statusCode >= 200 && res.statusCode < 300) resolve(parsed);
                    else reject(new Error('Status failed: ' + res.statusCode + ' ' + data));
                } catch (e) {
                    reject(new Error('Respuesta inválida de Vercel: ' + data.substring(0, 300)));
                }
            });
        });
        req.on('error', reject);
        req.end();
    });
}

async function esperarDeployment(id) {
    for (let intento = 1; intento <= 30; intento++) {
        const estado = await deploymentStatus(id);
        const fase = estado.readyState || estado.status || 'DESCONOCIDO';
        process.stdout.write('\rEstado Vercel: ' + fase + '          ');
        if (fase === 'READY') {
            console.log();
            return estado;
        }
        if (fase === 'ERROR' || fase === 'CANCELED') {
            console.log();
            throw new Error('Vercel terminó con estado ' + fase);
        }
        await new Promise(r => setTimeout(r, 2000));
    }
    console.log();
    throw new Error('Vercel no confirmó READY después de 60 segundos.');
}

async function main() {
    const fileManifest = [];
    for (const filename of archivosObligatorios) {
        const filepath = path.join(dir, filename);
        if (!fs.existsSync(filepath)) {
            throw new Error('Falta el archivo obligatorio: ' + filepath);
        }
    }

    const erpPath = path.join(dir, 'erp-nuevo.html');
    const erpBuffer = fs.readFileSync(erpPath);
    const erpSha = sha1(erpBuffer);
    const erpStat = fs.statSync(erpPath);
    const deployTime = new Date().toISOString();
    console.log('ERP exacto: ' + erpPath);
    console.log('ERP tamaño: ' + erpBuffer.length + ' bytes');
    console.log('ERP SHA-1:  ' + erpSha);
    console.log('ERP editado: ' + erpStat.mtime.toISOString());
    console.log();

    // ── Archivos de texto — inline ──
    for (const filename of ['index.html', 'erp.html', 'erp-nuevo.html', 'inscripciones-secundaria.html', 'acceso-padres.html', 'vercel.json', 'manifest.json', 'sw.js', 'assetlinks.json']) {
        const filepath = path.join(dir, filename);
        if (!fs.existsSync(filepath)) continue;
        const content = fs.readFileSync(filepath, 'utf8');
        fileManifest.push({ file: filename, data: content, encoding: 'utf-8' });
        console.log('+ ' + filename + ' (' + Math.round(content.length / 1024) + ' KB)');
    }

    const buildInfo = JSON.stringify({
        deployedAt: deployTime,
        erpFile: 'erp-nuevo.html',
        erpBytes: erpBuffer.length,
        erpSha1: erpSha
    }, null, 2);
    fileManifest.push({ file: 'build-info.json', data: buildInfo, encoding: 'utf-8' });
    console.log('+ build-info.json (verificación de versión)');

    // ── Fotos ──
    const fotosDir = path.join(dir, 'fotos');
    if (fs.existsSync(fotosDir)) {
        const imgs = fs.readdirSync(fotosDir)
            .filter(f => /\.(jpg|jpeg|png|webp)$/i.test(f) && !/^(slider-|nivel-|nosotros-|cambridge|programa-|oso-|app-icon-|screen-|pagina-principal|instalacion-|maternales|kinder|preescolar|primaria|secundaria)/i.test(f))
            .sort()
            .reverse(); // últimas fotos primero

        console.log('\nSubiendo ' + imgs.length + ' fotos...\n');

        // Slider: saltar las primeras 5 (no gustaron), usar el resto
        const sliderImgs = imgs.slice(5);
        for (let i = 0; i < sliderImgs.length; i++) {
            const nombre = 'slider-' + (i + 1) + '.jpg';
            const buffer = fs.readFileSync(path.join(fotosDir, sliderImgs[i]));
            const digest = sha1(buffer);
            process.stdout.write('  [' + (i + 1) + '/' + sliderImgs.length + '] fotos/' + nombre + ' ... ');
            await uploadFile(buffer, digest);
            console.log('OK');
            fileManifest.push({ file: 'fotos/' + nombre, sha: digest, size: buffer.length });
        }

        // Secciones: reutilizan fotos del slider
        const seccionMap = [
            ['nosotros-1.jpg', 0], ['nosotros-2.jpg', 1],
            ['nivel-maternal.jpg', 2], ['nivel-preescolar.jpg', 3],
            ['nivel-primaria.jpg', 4], ['nivel-secundaria.jpg', 5],
            ['cambridge.jpg', 6],
            ['programa-robotica.jpg', 7], ['programa-mun.jpg', 8], ['programa-nasa.jpg', 9]
        ];
        for (const [nombre, idx] of seccionMap) {
            if (imgs[idx]) {
                const buffer = fs.readFileSync(path.join(fotosDir, imgs[idx]));
                const digest = sha1(buffer);
                await uploadFile(buffer, digest);
                fileManifest.push({ file: 'fotos/' + nombre, sha: digest, size: buffer.length });
            }
        }

        // Ositos (y otros assets) por su propio nombre
        const extras = fs.readdirSync(fotosDir).filter(f => /^(oso-|app-icon-|screen-|pagina-principal|instalacion-|maternales|kinder|preescolar|primaria|secundaria).*\.(png|jpg|jpeg|webp)$/i.test(f));
        for (const nombre of extras) {
            const buffer = fs.readFileSync(path.join(fotosDir, nombre));
            const digest = sha1(buffer);
            process.stdout.write('  + fotos/' + nombre + ' ... ');
            await uploadFile(buffer, digest);
            console.log('OK');
            fileManifest.push({ file: 'fotos/' + nombre, sha: digest, size: buffer.length });
        }
    }

    // ── Crear deployment ──
    console.log('\nCreando deployment...');
    const resp = await deploy(fileManifest);

    if (!resp.id || !resp.url) {
        throw new Error('Vercel no creó el deployment: ' + JSON.stringify(resp).substring(0, 600));
    }

    console.log('Deployment: ' + resp.id);
    await esperarDeployment(resp.id);
    console.log('\n✓ LISTO Y CONFIRMADO');
    console.log('Web: https://institutelearningproject-project.vercel.app/erp');
    console.log('Versión: https://institutelearningproject-project.vercel.app/build-info.json');
    console.log('SHA-1 esperado: ' + erpSha);
}

main().catch(e => {
    console.error('\nERROR:', e.message);
    process.exitCode = 1;
});
