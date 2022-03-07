const fs = require('fs');
const os = require('os');
const crypto = require('crypto');

const path = require('path');
const axios = require('axios');
const fileType = require('file-type');

const { promisify } = require('util')
const untar = promisify(require('tar').extract);
const unzip = require('extract-zip');

const core = require('@actions/core');
const cache = require('@actions/cache');

async function run() {
  try {
    const platform = os.platform();
    const arch = os.arch();

    const name = core.getInput('name');
    const workingDirectory = function() {
      const workingDirectory = core.getInput('working-directory');
      if (workingDirectory == '') {
        return os.tmpdir();
      } else {
        return workingDirectory;
      }
    }();
    const installDirectory = function() {
      const installDirectory = core.getInput('install-directory');
      if (installDirectory == '') {
        if (platform == 'windows') {
          return '/usr/bin';
        } else {
          return '/usr/local/bin';
        }
      } else {
        return installDirectory;
      }
    }();
    const cacheEnabled = core.getBooleanInput('cache');

    const directory = fs.mkdirSync(path.join(workingDirectory, name));

    const version = await (async function() {
      const version = core.getInput('version');
      if (version == '') {
        return await axios.get(`https://dist.ipfs.io/${name}/versions`)
          .then(versions => {
            return versions.data.trim().split('\n').reverse()[0];
          });
      } else {
        return version;
      }
    }());

    const source = await axios.get(`https://dist.ipfs.io/${name}/${version}/dist.json`)
      .then(dist => {
        return dist.data.platforms[platform].archs[arch]
      });
    const archive = path.basename(source.link);
    const archivePath = path.join(directory, archive);

    const cacheKey = `dist-v0-${archive}`;
    const cacheRestored = await (async function() {
      if (cacheEnabled) {
        const cacheHit = await cache.restoreCache([directory], cacheKey);
        if (cacheHit == undefined) {
          return false;
        } else {
          return true;
        }
      } else {
        return false;
      }
    }());

    if (! cacheRestored) {
      await axios.get(`https://dist.ipfs.io/${name}/${version}${source.link}`, { responseType: 'stream' })
        .then(package => {
          package.data.pipe(fs.createWriteStream(archivePath));
        });
      await cache.saveCache([directory], cacheKey);
    }

    if (source.sha512 != '') {
      const sha512 = crypto.createHash('sha512')
        .update(fs.readFileSync(archivePath), 'utf8')
        .digest('hex');
      if (source.sha512 != sha512) {
        throw new Error(`sha512 mismatch: ${sha512} != ${source.sha512}`)
      }
    }

    const archiveType = await fileType.fileTypeFromFile(archivePath)

    if (archiveType.mime == 'application/zip') {
      await unzip(archivePath, { dir: directory })
    } else {
      await untar({ file: archivePath, cwd: directory })
    }

    const executables = []
    for (const file of fs.readdirSync(directory)) {
      const type = await fileType.fileTypeFromFile(file)
      if (type.mime != 'text/x-shellscript') {
        console.log(file)
        console.log(type)
        // fs.copyFileSync(file, path.join(installDirectory, fs.basename(file)))
        executables.push(fs.basename(file))
      }
    }

    core.setOutput('executable', executables[0]);
    core.setOutput('executables', executables);
    core.setOutput('cache-hit', cacheRestored);
  } catch (error) {
    core.setFailed(error.message);
  }
}

run();
