# Scripts

A collection of reusable scripts for general-purpose automation and utility tasks. Each script lives in its own directory with dedicated documentation.

## Scripts

| Script | Description |
|--------|-------------|
| [setup-github-deploy-key](./setup-github-deploy-key/) | Generate and register SSH deploy keys on GitHub repos |
| [update-github-deploy-key](./update-github-deploy-key/) | Rotate an existing deploy key on a GitHub repo (list, pick, swap) |

## Usage

Each script directory contains its own `README.md` with prerequisites, usage instructions, and examples. Browse the folder or run directly:

```bash
# Run any script directly from GitHub
curl -sL https://raw.githubusercontent.com/DishantPal/scripts/master/<script-folder>/script.sh | bash
```

## Structure

```
scripts/
├── README.md
├── setup-github-deploy-key/
│   ├── script.sh
│   └── README.md
├── update-github-deploy-key/
│   ├── script.sh
│   └── README.md
└── ...
```

Each script is self-contained — grab just the folder you need.