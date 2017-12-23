const cypress = require('cypress');
const { spawn } = require('child_process');

const retro = spawn('../out/retro', ['--test', '--config', '/dev/null', '--assets', '../out/app/dist']);

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
  .run()
  .then((results) => {
    console.log(results);
    retro.kill('SIGINT');
  })
  .catch((err) => {
    console.error(err);
    retro.kill('SIGINT');
    process.exit(1);
  });
