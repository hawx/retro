const cypress = require('cypress');
const { spawn } = require('child_process');
const { join } = require('path');

const retro = spawn(join(__dirname, '../out/retro'),
                    ['--test',
                     '--config', '/dev/null',
                     '--assets', join(__dirname, '../out/app/dist')]);

retro.stdout.on('data', (data) => {
  console.log(`stdout: ${data}`);
});

retro.stderr.on('data', (data) => {
  console.log(`stderr: ${data}`);
});

retro.on('close', (code) => {
  console.log(`child process exited with code ${code}`);
});

cypress
  .run({ project: __dirname })
  .then((results) => {
    retro.kill('SIGINT');
    process.exit(results.failures);
  })
  .catch((err) => {
    console.error(err);
    retro.kill('SIGINT');
    process.exit(1);
  });
