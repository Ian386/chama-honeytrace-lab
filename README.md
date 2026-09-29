# Chama and HoneyTrace: Smart Contracts Lab

Lab 2 for a beginner Blockchain Systems practical. Two Solidity contracts share one scenario, a honey cooperative in Kitui:

- **Chama** (`contracts/Chama.sol`): group savings. Members deposit ETH, transfer savings to each other, and withdraw.
- **HoneyTrace** (`contracts/HoneyTrace.sol`): traceability. Approved handlers move honey batches through fixed stages, and events form the audit trail.

Students write the contracts in Remix, then verify them with Hardhat tests.

## Contents

| Path | What it is |
|---|---|
| `contracts/` | The two lab contracts and their Solidity tests (`*.t.sol`) |
| `staged/` | Each contract in three steps, as students build it. Every step compiles on its own. |
| `scripts/lab-demo.ts` | Classroom demo that runs both contracts and prints balances, errors and event history |
| `STUDENT_HANDOUT.md` | Student handout (draft) |
| `notes/` | Rehearsal records: gas table, demo output, node log |

## Requirements

- Node.js 22.13 or later
- npm and Git

Built with Hardhat 3.18 and Solidity 0.8.34.

## Setup

```bash
npm install
```

## Run the tests

```bash
npx hardhat test solidity
```

This runs 13 lab tests plus the template's Counter tests. To include a gas table:

```bash
npx hardhat test solidity --gas-stats
```

## Run the demo

On an in-process chain:

```bash
npx hardhat run scripts/lab-demo.ts
```

On a local node, using two terminals:

```bash
# terminal 1
npx hardhat node

# terminal 2
npx hardhat run scripts/lab-demo.ts --network localhost
```

Everything runs on local networks only. No testnet, private keys or `.env` file are needed.
