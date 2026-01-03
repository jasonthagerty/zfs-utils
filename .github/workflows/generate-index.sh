#!/bin/bash
# Generate repository index.html

cat > "$1" <<'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>ArchZFS Custom Repository</title>
    <style>
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            max-width: 900px;
            margin: 40px auto;
            padding: 20px;
            line-height: 1.6;
            background: #f5f5f5;
        }
        .container {
            background: white;
            padding: 30px;
            border-radius: 8px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
        }
        h1 { color: #1793D1; border-bottom: 3px solid #1793D1; padding-bottom: 10px; }
        h2 { color: #333; margin-top: 30px; }
        code {
            background: #f4f4f4;
            padding: 2px 6px;
            border-radius: 3px;
            font-family: 'Courier New', monospace;
        }
        pre {
            background: #2d2d2d;
            color: #f8f8f2;
            padding: 15px;
            border-radius: 5px;
            overflow-x: auto;
        }
        pre code { background: none; color: #f8f8f2; padding: 0; }
        .warning {
            background: #fff3cd;
            border-left: 4px solid #ffc107;
            padding: 15px;
            margin: 20px 0;
        }
        .info {
            background: #d1ecf1;
            border-left: 4px solid #17a2b8;
            padding: 15px;
            margin: 20px 0;
        }
        ul { padding-left: 20px; }
        li { margin: 8px 0; }
        a { color: #1793D1; text-decoration: none; }
        a:hover { text-decoration: underline; }
    </style>
</head>
<body>
    <div class="container">
        <h1>ArchZFS Custom Repository</h1>

        <div class="info">
            <strong>Repository Status:</strong> Active and automatically updated every 6 hours
        </div>

        <h2>Installation</h2>
        <p>Add this repository to your <code>/etc/pacman.conf</code>:</p>
        <pre><code>[archzfs]
Server = https://jasonthagerty.github.io/zfs-utils/repo
SigLevel = Optional TrustAll</code></pre>

        <div class="warning">
            <strong>Note:</strong> This repository uses <code>SigLevel = Optional TrustAll</code> because packages are not GPG-signed.
            For production use, consider setting up GPG signing.
        </div>

        <h2>Update Package Database</h2>
        <pre><code>sudo pacman -Sy</code></pre>

        <h2>Install ZFS</h2>
        <p>Install the ZFS utilities and kernel modules:</p>
        <pre><code># Install ZFS userspace utilities
sudo pacman -S zfs-utils

# Install ZFS kernel modules for linux-zen
sudo pacman -S zfs-linux-zen</code></pre>

        <h2>Available Packages</h2>
        <ul>
            <li><code>zfs-utils</code> - ZFS userspace utilities and libraries</li>
        </ul>

        <h2>Automatic Updates</h2>
        <p>This repository automatically tracks the latest stable releases from:</p>
        <ul>
            <li>OpenZFS upstream releases</li>
            <li>Arch Linux linux-zen kernel packages</li>
        </ul>
        <p>Packages are automatically rebuilt and published when new versions are detected (checked every 6 hours).</p>

        <h2>Source Code</h2>
        <p>Repository source and PKGBUILD files: <a href="https://github.com/jasonthagerty/zfs-utils">github.com/jasonthagerty/zfs-utils</a></p>

        <h2>Package Files</h2>
        <ul id="package-list">
            <li>Loading...</li>
        </ul>

        <script>
        fetch('.')
            .then(response => response.text())
            .then(html => {
                const parser = new DOMParser();
                const doc = parser.parseFromString(html, 'text/html');
                const links = Array.from(doc.querySelectorAll('a'))
                    .filter(a => a.href.match(/\.(pkg\.tar\.zst|db|sig)$/))
                    .map(a => a.href.split('/').pop());

                const list = document.getElementById('package-list');
                if (links.length > 0) {
                    list.innerHTML = links.map(file =>
                        `<li><a href="${file}">${file}</a></li>`
                    ).join('');
                } else {
                    list.innerHTML = '<li>No packages found yet. Check back after the first build completes.</li>';
                }
            })
            .catch(() => {
                document.getElementById('package-list').innerHTML =
                    '<li>Unable to load package list</li>';
            });
        </script>
    </div>
</body>
</html>
EOF
