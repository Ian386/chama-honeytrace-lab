# Lab 2: Smart Contracts in Practice

- **Course:** Blockchain Systems
- **Duration:** 2 hours
- **Tools:** Remix (<https://remix.ethereum.org>) and your Hardhat project from Lab 1

---

## 1. Scenario

A honey cooperative in Kitui wants two things on a blockchain. First, its members run a chama: they save money together, move savings between members, and withdraw when they need cash. Second, buyers want proof of where their honey came from, so every batch must be tracked from the hive to the shop, and only approved handlers may update it. In Task 1 you build the savings contract (`Chama`), and in Task 2 the traceability contract (`HoneyTrace`).

---

## 2. Concept bridge

You already know these ideas from other languages. This is what they are called in Solidity.

| You know | In Solidity | Example in this lab |
|---|---|---|
| class | `contract` | `contract Chama { ... }` |
| object fields | state variables (stored on the blockchain) | `uint256 public totalSavings;` |
| dictionary / hash map | `mapping` | `mapping(address => uint256) public balances;` |
| constructor | `constructor` (runs once, at deployment) | `treasurer = msg.sender;` |
| `if` + raise / throw | `require(...)` or `revert CustomError(...)` | `revert InsufficientBalance(amount, available);` |
| print / log | `emit Event(...)` | `emit Deposited(msg.sender, msg.value);` |
| current user | `msg.sender` | the account that called the function |
| decorator / middleware | `modifier` | `onlyAdmin`, `onlyHandler` |
| money sent with a call | `payable` function + `msg.value` | `function deposit() external payable` |

When a call fails a `require` or `revert`, the whole call is cancelled. No state changes are kept.

---

## 3. Remix basics

Read this before you start. These are the points that most often cause problems.

- **Create the file:** in the File Explorer, create `Chama.sol` (later `HoneyTrace.sol`).
- **Compile:** open the Solidity Compiler tab, choose version 0.8.28 or later, and click Compile. A green tick means it compiled.
- **Deploy:** open the Deploy & Run Transactions tab. Keep the environment set to a **Remix VM**. Click **Deploy**. The contract appears under **Deployed Contracts**; click the arrow to expand it.
- **Accounts:** the Remix VM gives you several accounts with 100 ETH each. Use the **Account** dropdown to act as a different person. Click the copy icon next to the dropdown to copy the selected address.
- **Button colours:**
  - **Orange:** a transaction that changes state.
  - **Red:** a `payable` transaction that can receive ETH.
  - **Blue:** a free read. It changes nothing and costs no gas.
- **Functions with several inputs:** click the arrow next to the function name to get one box per input. This is easier than typing everything on one line.
- **Redeploy after every code change:** a deployed contract cannot be changed. After you edit and recompile, click Deploy again and use the new instance, which appears at the bottom of Deployed Contracts. Delete old instances with the bin icon to avoid confusion.
- **Terminal:** the panel at the bottom shows each call. Click an entry to expand it. The `logs` field shows the events it emitted.
- **Failed calls:** the terminal shows a red entry that says the transaction was reverted, followed by the error name and its parameters, for example `InsufficientBalance` with `requested` and `available`. Nothing changes: balances stay the same.

### Amounts: ETH and wei

Solidity has no decimal numbers. All amounts are whole numbers of **wei**, the smallest unit of ETH.

**1 ETH = 1,000,000,000,000,000,000 wei** (1 followed by 18 zeros).

| ETH | Type this in wei |
|---|---|
| 0.5 | `500000000000000000` |
| 1 | `1000000000000000000` |
| 2 | `2000000000000000000` |

- **`deposit`:** you send ETH with the call using the **Value** field above the Deploy button. Change the unit dropdown next to it from **Wei** to **Ether**, then type `2` for 2 ETH.
- **`transferTo` and `withdraw`:** these take the amount as a normal input, and that input is always in **wei**. Copy the numbers from the table above.
- **Reads:** values such as `balances` and `totalSavings` are also shown in wei.

---

## 4. Task 1: Chama (group savings)

Account 1 deploys the contract and becomes the treasurer. Accounts 2 and 3 are members.

### Step 1: State, constructor and deposit

Create `Chama.sol` and type:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/// @title Chama: a group savings wallet
/// @notice Members deposit ETH, move savings to each other, and withdraw.
contract Chama {
    // ---- State ----
    address public treasurer;                    // who deployed the chama
    mapping(address => uint256) public balances; // member => savings in wei
    uint256 public totalSavings;                 // sum of all balances

    // ---- Events (the contract's public receipts) ----
    event Deposited(address indexed member, uint256 amount);

    constructor() {
        treasurer = msg.sender;
    }

    /// Send ETH with this call (use the VALUE field in Remix).
    function deposit() external payable {
        require(msg.value > 0, "Deposit must be more than zero");
        balances[msg.sender] += msg.value;
        totalSavings += msg.value;
        emit Deposited(msg.sender, msg.value);
    }
}
```

**What this introduces:**

- **State variables and `mapping`:** stored on the blockchain permanently. `balances` keeps each member's savings by address, and `public` gives each variable a free read button in Remix.
- **`payable` and `msg.value`:** let a function receive ETH.
- **`require` and `emit`:** `require` stops bad input, and `emit` records a receipt that anyone can read later.

**In Remix:**

1. Compile, then deploy as **Account 1**. Click `treasurer`. It shows Account 1's address.
2. Switch to **Account 2**. Set Value to `2` **Ether** and click `deposit`.
3. Paste Account 2's address into `balances` and click it. It shows `2000000000000000000`. `totalSavings` shows the same.
4. Expand the deposit entry in the terminal. `logs` contains a `Deposited` event with Account 2's address and the amount.
5. Set Value to `0` and click `deposit`. The call fails with `Deposit must be more than zero`.

### Step 2: Moving savings between members

Add the `Transferred` event directly under the `Deposited` event. Then add the custom error below the events:

```solidity
    event Transferred(address indexed from, address indexed to, uint256 amount);

    // ---- Custom error (cheaper and more informative than a string) ----
    error InsufficientBalance(uint256 requested, uint256 available);
```

Add this function after `deposit()`, before the final `}`:

```solidity
    /// Move savings to another member. No ETH leaves the contract.
    function transferTo(address to, uint256 amount) external {
        require(to != address(0), "Invalid recipient");
        uint256 available = balances[msg.sender];
        if (amount > available) revert InsufficientBalance(amount, available);

        balances[msg.sender] = available - amount;
        balances[to] += amount;
        emit Transferred(msg.sender, to, amount);
    }
```

**What this introduces:**

- **Custom error:** reports *why* a call failed, together with the numbers involved. It is cheaper than a text message.
- **`transferTo`:** only changes numbers in the `balances` mapping. No ETH moves in or out of the contract.

**In Remix:**

1. Compile and redeploy as Account 1.
2. As Account 2, deposit `2` Ether. As Account 3, deposit `1` Ether.
3. Switch to Account 2. Call `transferTo` with Account 3's address and `500000000000000000` (0.5 ETH).
4. Check `balances`:
   - Account 2 shows `1500000000000000000`.
   - Account 3 shows `1500000000000000000`.
   - `totalSavings` is unchanged at `3000000000000000000`.
5. As Account 2, try to transfer `5000000000000000000` (5 ETH). The call fails with `InsufficientBalance`, with `requested` = 5 ETH and `available` = 1.5 ETH, both in wei.

### Step 3: Withdrawing ETH

Add the `Withdrawn` event under the `Transferred` event:

```solidity
    event Withdrawn(address indexed member, uint256 amount);
```

Add these two functions after `transferTo()`, before the final `}`:

```solidity
    /// Take ETH out of the chama back to your wallet.
    function withdraw(uint256 amount) external {
        uint256 available = balances[msg.sender];
        if (amount > available) revert InsufficientBalance(amount, available);

        // Update state BEFORE sending ETH (checks-effects-interactions).
        balances[msg.sender] = available - amount;
        totalSavings -= amount;

        (bool sent, ) = payable(msg.sender).call{value: amount}("");
        require(sent, "ETH transfer failed");
        emit Withdrawn(msg.sender, amount);
    }

    /// ETH physically held by the contract. Should always equal totalSavings.
    function contractBalance() external view returns (uint256) {
        return address(this).balance;
    }
```

**What this introduces:**

- **Sending ETH out:** `withdraw` sends ETH from the contract back to the caller.
- **Checks-effects-interactions:** the balance is reduced *before* the ETH is sent, so a caller cannot withdraw the same savings twice.
- **`view`:** a `view` function only reads, so it is free to call.

**In Remix:**

1. Compile and redeploy as Account 1.
2. As Account 2, deposit `2` Ether. As Account 3, deposit `1` Ether.
3. As Account 2, transfer `500000000000000000` to Account 3.
4. As Account 3, call `withdraw` with `1000000000000000000` (1 ETH). Account 3's balance in the Account dropdown goes up by about 1 ETH. It is slightly less because of the gas fee.
5. As Account 3, call `withdraw` with `100000000000000000000` (100 ETH). It fails with `InsufficientBalance`.
6. Click `totalSavings` and `contractBalance`. Both show `2000000000000000000`. The books match the ETH the contract actually holds.

---

## 5. Task 2: HoneyTrace (traceability)

Account 1 deploys the contract and becomes the admin. The admin is also the first approved handler (the beekeeper group).

A batch moves through five fixed stages, in order, one step at a time:

`Harvested (0) -> Processed (1) -> Packaged (2) -> Shipped (3) -> Delivered (4)`

### Step 1: Types, state and constructor

Create `HoneyTrace.sol` and type:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/// @title HoneyTrace: farm-to-shelf traceability for honey batches
/// @notice Approved handlers create batches and move them through fixed stages.
contract HoneyTrace {
    // ---- Types ----
    enum Stage { Harvested, Processed, Packaged, Shipped, Delivered } // 0..4

    struct Batch {
        uint256 id;
        string origin;          // e.g. "Kitui, beekeeper group A"
        address currentHolder;  // last handler to touch the batch
        Stage stage;
        uint256 updatedAt;      // block timestamp of last update
        bool exists;
    }

    // ---- State ----
    address public admin;
    mapping(address => bool) public isHandler;
    mapping(uint256 => Batch) public batches;
    uint256 public nextBatchId = 1;

    constructor() {
        admin = msg.sender;
        isHandler[msg.sender] = true;
    }
}
```

**What this introduces:**

- **`enum`:** a fixed list of named values. It is stored as a number from 0 to 4.
- **`struct`:** groups related fields into one record, like an object with no methods.
- **`mapping(address => bool)`:** works as an approved list.

**In Remix:**

1. Compile, then deploy as **Account 1**.
2. Click `admin`. It shows Account 1.
3. Call `isHandler` with Account 1's address: `true`. With Account 2's address: `false`.
4. Call `batches` with `1`. Every field is empty (zero, empty string, `false`), because no batch exists yet.

### Step 2: Access control

Add the event, errors and modifiers between the state variables and the constructor:

```solidity
    // ---- Events: together they form the batch's audit trail ----
    event HandlerAdded(address indexed handler);

    // ---- Custom errors ----
    error NotAdmin();
    error NotHandler(address caller);
    error BatchNotFound(uint256 id);
    error AlreadyDelivered(uint256 id);

    // ---- Modifiers: reusable access checks ----
    modifier onlyAdmin() {
        if (msg.sender != admin) revert NotAdmin();
        _;
    }

    modifier onlyHandler() {
        if (!isHandler[msg.sender]) revert NotHandler(msg.sender);
        _;
    }
```

Add this function after the constructor, before the final `}`:

```solidity
    function addHandler(address handler) external onlyAdmin {
        isHandler[handler] = true;
        emit HandlerAdded(handler);
    }
```

**What this introduces:**

- **Modifiers:** a modifier runs its check first. The `_;` line is where the function body runs.
- **Reusable checks:** writing `onlyAdmin` on a function applies the check without repeating the code.
- **Used in step 3:** `onlyHandler`, `BatchNotFound` and `AlreadyDelivered` are not used until step 3.

**In Remix:**

1. Compile and redeploy as Account 1.
2. Switch to **Account 2** and call `addHandler` with Account 2's address. It fails with `NotAdmin`.
3. Switch to **Account 1** and call `addHandler` with Account 2's address. It succeeds, and the terminal log shows `HandlerAdded`.
4. Call `isHandler` with Account 2's address. It now shows `true`.

### Step 3: Batches and stages

Add two events under the `HandlerAdded` event:

```solidity
    event BatchCreated(uint256 indexed id, string origin, address indexed by);
    event StageUpdated(uint256 indexed id, Stage stage, address indexed by, uint256 timestamp);
```

Add these two functions after `addHandler()`, before the final `}`:

```solidity
    function createBatch(string calldata origin) external onlyHandler returns (uint256 id) {
        id = nextBatchId++;
        batches[id] = Batch(id, origin, msg.sender, Stage.Harvested, block.timestamp, true);
        emit BatchCreated(id, origin, msg.sender);
        emit StageUpdated(id, Stage.Harvested, msg.sender, block.timestamp);
    }

    /// Moves a batch one stage forward. Stages cannot be skipped or reversed.
    function advanceStage(uint256 id) external onlyHandler {
        Batch storage b = batches[id];
        if (!b.exists) revert BatchNotFound(id);
        if (b.stage == Stage.Delivered) revert AlreadyDelivered(id);

        b.stage = Stage(uint8(b.stage) + 1);
        b.currentHolder = msg.sender;
        b.updatedAt = block.timestamp;
        emit StageUpdated(id, b.stage, msg.sender, block.timestamp);
    }
```

**What this introduces:**

- **`Batch storage b`:** a reference to the stored batch, so changes to `b` are saved.
- **Fixed stage order:** `advanceStage` can only move one stage forward.
- **Audit trail:** each change emits `StageUpdated`. Together, these events are the batch's history.

**In Remix:**

1. Compile and redeploy as Account 1.
2. Call `createBatch` with `"Kitui, group A"`. Keep the double quotes: the text contains a comma, and without quotes Remix reads it as two inputs.
3. Call `batches` with `1`. The result is a list of fields, in the same order as the struct. `stage` shows `0` (Harvested), because enums are stored as numbers. `exists` is `true`.
4. Switch to **Account 2**, which is not approved yet in this new deployment. Call `advanceStage` with `1`. It fails with `NotHandler` and Account 2's address.
5. Switch to **Account 1** and call `addHandler` with Account 2's address.
6. Switch to **Account 2** and call `advanceStage` with `1`. `batches(1)` now shows stage `1` (Processed), and `currentHolder` is Account 2.
7. Call `advanceStage(1)` three more times, as Account 1 or Account 2. The stage reaches `4` (Delivered).
8. Call `advanceStage(1)` once more. It fails with `AlreadyDelivered` and id `1`.
9. Call `advanceStage(99)`. It fails with `BatchNotFound` and id `99`.
10. Expand the successful `advanceStage` entries in the terminal. Each one has a `StageUpdated` log. Read in order, they show who handled the batch at each stage and when.

---

## 6. Verify with Hardhat

Remix is for trying things by hand. Tests check the same behaviour automatically, every time.

1. Open your Hardhat project from Lab 1.
2. Copy your finished `Chama.sol` and `HoneyTrace.sol` from Remix into the project's `contracts/` folder.
3. Copy the two test files from your lecturer, `Chama.t.sol` and `HoneyTrace.t.sol`, into the same `contracts/` folder.
4. Run:

```bash
npx hardhat test solidity
```

You should see 13 lab tests passing: 6 under `ChamaTest` and 7 under `HoneyTraceTest`. The 3 `CounterTest` tests from Lab 1 also run, so the total is `16 passing`.

To run one test file only:

```bash
npx hardhat test solidity contracts/Chama.t.sol
```

If a test fails, read its name and message. It tells you which behaviour is wrong. The tests check names and messages exactly. For example, the zero deposit test expects the exact text `Deposit must be more than zero`, and the custom error tests expect the exact error names and parameters. Compare your code with the handout, fix it, and run the tests again.

---

## 7. Extensions (take-home)

Do these in your Hardhat project. For each one, add at least one test that shows the new rule working and one that shows it blocking bad input.

1. **Minimum deposit (Chama):**
   - Add a `minimumDeposit` state variable, set in the constructor.
   - Deposits below it must fail with a custom error.
2. **Per-member withdrawal limit (Chama):**
   - Let the treasurer set a maximum amount per `withdraw` call.
   - Withdrawals above the limit must fail.
   - Only the treasurer may change the limit.
3. **`recall(id)` (HoneyTrace):**
   - Add a function that only the admin can call. It marks a batch as recalled.
   - A recalled batch cannot be advanced.
   - Emit an event so the recall appears in the audit trail.
4. **Location tracking (HoneyTrace):**
   - Add a `location` field to `Batch`.
   - Change `advanceStage` to take the new location as input, store it, and include it in the `StageUpdated` event.
