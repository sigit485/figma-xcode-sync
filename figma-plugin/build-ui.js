const fs = require('fs');
fs.mkdirSync('dist', { recursive: true });
fs.copyFileSync('src/ui.html', 'dist/ui.html');
