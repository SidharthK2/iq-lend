# IQ Lend

Lending protocol for IQ token built on Morpho Blue with leveraged long/short support via flash loans.

## Architecture

**IQLend** — Morpho Blue fork with owner-managed supply/borrow caps.

**IQOracle** — Fraxswap TWAP oracle with decimal scaling for Morpho's 1e36 price format. Configurable observation window and spot/TWAP deviation check.

**IQRouter** — Opens and closes leveraged positions using IQLend flash loans. Swaps route through Fraxswap (IQ/FRAX) and Curve (FRAX/USDC).

## Markets

| Market | Collateral | Loan | Use case |
|--------|------------|------|----------|
| 1 | IQ | USDC | Long IQ |
| 2 | USDC | IQ | Short IQ |

Both markets use a 70% LLTV and the Morpho Blue adaptive curve IRM.

## How it works

**Long IQ** — User seeds USDC. Router flash borrows additional USDC, swaps all to IQ (via FRAX), supplies IQ as collateral, borrows USDC to repay flash loan. User profits if IQ goes up.

**Short IQ** — User seeds USDC. Router flash borrows IQ, sells it for USDC (via FRAX), supplies total USDC as collateral, borrows IQ to repay flash loan. User profits if IQ goes down.

Closing unwinds the position in reverse — repays debt, withdraws collateral, swaps back, and returns residual USDC to the user.

## Deployed contracts (Ethereum mainnet)

| Contract | Address |
|----------|---------|
| IQLend | `0x7731a73252371de56Fb37F7F428aBD9f0e54c737` |
| IQRouter | `0x4E54507D17d95e33F54081098B2648aB1a91c629` |
| IQOracle (Market 1) | `0xf967BB7DA29a187A16b9276A9edB31733CbA443A` |
| IQOracle (Market 2) | `0x13aF5D132f5e93EcEe7080D06d523EEb585c5b63` |

## Dev

```bash
pnpm i
forge build
forge test
```

## Scripts

```bash
# Seed liquidity
forge script script/SeedMarket1.s.sol --broadcast --rpc-url $RPC_URL
forge script script/SeedMarket2.s.sol --broadcast --rpc-url $RPC_URL

# Open/close positions
forge script script/OpenLong.s.sol --broadcast --rpc-url $RPC_URL
forge script script/CloseLong.s.sol --broadcast --rpc-url $RPC_URL
forge script script/OpenShort.s.sol --broadcast --rpc-url $RPC_URL
forge script script/CloseShort.s.sol --broadcast --rpc-url $RPC_URL
```

All scripts read `PRIVATE_KEY` from the environment.
