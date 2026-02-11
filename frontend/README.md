# StakeFlow Frontend

React-based Web3 frontend for the StakeFlow staking protocol.

## Features

- 🎨 Modern UI with Tailwind CSS
- 🔗 RainbowKit wallet connection
- ⚡ Fast development with Vite
- 📊 Real-time data with Wagmi
- 📱 Responsive design

## Development

```bash
# Install dependencies
npm install

# Start dev server
npm run dev

# Build for production
npm run build

# Preview production build
npm run preview
```

## Structure

```
src/
├── abis/           # Contract ABIs
├── components/     # React components
├── hooks/          # Web3 custom hooks
├── utils/          # Utilities & config
├── App.tsx         # Main app
└── main.tsx        # Entry point
```

## Configuration

Update `src/utils/config.ts` with deployed contract addresses.
