// import { describe, expect, it } from "vitest";

// const accounts = simnet.getAccounts();
// const deployer = accounts.get("deployer")!;
// const address1 = accounts.get("wallet_1")!;
// const address2 = accounts.get("wallet_2")!;

// describe("FarmChain Carbon Credit System", () => {
//   it("ensures simnet is well initialized", () => {
//     expect(simnet.blockHeight).toBeDefined();
//   });

//   it("can register a farm", () => {
//     const { result } = simnet.callPublicFn(
//       "FarmChain",
//       "register-farm",
//       [stringUtf8("Green Valley Farm"), stringUtf8("California")],
//       deployer
//     );
//     expect(result).toBeOk();
//   });

//   it("can record carbon sequestration activity", () => {
//     // First register a farm
//     simnet.callPublicFn(
//       "FarmChain", 
//       "register-farm", 
//       ["Test Farm", "Oregon"], 
//       address1
//     );

//     // Record carbon activity
//     const { result } = simnet.callPublicFn(
//       "FarmChain",
//       "record-carbon-activity",
//       [1, "tree-planting", 100, 10, 20],
//       address1
//     );
//     expect(result).toBeOk();
//   });

//   it("can register carbon verifier", () => {
//     const { result } = simnet.callPublicFn(
//       "FarmChain",
//       "register-verifier",
//       [address2, "EcoVerify Ltd", "ISO-14064"],
//       deployer
//     );
//     expect(result).toBeOk();
//   });

//   it("can verify carbon activity", () => {
//     // Setup: register farm, activity, and verifier
//     simnet.callPublicFn("FarmChain", "register-farm", ["Test Farm", "Texas"], address1);
//     simnet.callPublicFn("FarmChain", "record-carbon-activity", [1, "cover-crops", 50, 5, 10], address1);
//     simnet.callPublicFn("FarmChain", "register-verifier", [address2, "Carbon Audits Inc", "VCS"], deployer);

//     // Verify activity
//     const { result } = simnet.callPublicFn(
//       "FarmChain",
//       "verify-carbon-activity",
//       [1],
//       address2
//     );
//     expect(result).toBeOk();
//   });

//   it("can mint carbon credits from verified activity", () => {
//     // Setup complete flow
//     simnet.callPublicFn("FarmChain", "register-farm", ["Climate Farm", "Montana"], address1);
//     simnet.callPublicFn("FarmChain", "record-carbon-activity", [1, "no-till", 200, 8, 15], address1);
//     simnet.callPublicFn("FarmChain", "register-verifier", [address2, "Green Check", "CDM"], deployer);
//     simnet.callPublicFn("FarmChain", "verify-carbon-activity", [1], address2);

//     // Mint credits
//     const { result } = simnet.callPublicFn(
//       "FarmChain",
//       "mint-carbon-credits",
//       [1, 2024],
//       address1
//     );
//     expect(result).toBeOk();
//   });

//   it("can transfer carbon credits", () => {
//     // Setup complete flow with minted credits
//     simnet.callPublicFn("FarmChain", "register-farm", ["Trade Farm", "Iowa"], address1);
//     simnet.callPublicFn("FarmChain", "record-carbon-activity", [1, "biochar", 75, 12, 25], address1);
//     simnet.callPublicFn("FarmChain", "register-verifier", [address2, "Veritas Carbon", "GS"], deployer);
//     simnet.callPublicFn("FarmChain", "verify-carbon-activity", [1], address2);
//     simnet.callPublicFn("FarmChain", "mint-carbon-credits", [1, 2024], address1);

//     // Transfer credits
//     const { result } = simnet.callPublicFn(
//       "FarmChain",
//       "transfer-carbon-credits",
//       [1, address2, 500, 25, "sale"],
//       address1
//     );
//     expect(result).toBeOk();
//   });

//   it("can retire carbon credits", () => {
//     // Setup with minted credits
//     simnet.callPublicFn("FarmChain", "register-farm", ["Retire Farm", "Vermont"], address1);
//     simnet.callPublicFn("FarmChain", "record-carbon-activity", [1, "agroforestry", 60, 15, 30], address1);
//     simnet.callPublicFn("FarmChain", "register-verifier", [address2, "Climate Solutions", "ACR"], deployer);
//     simnet.callPublicFn("FarmChain", "verify-carbon-activity", [1], address2);
//     simnet.callPublicFn("FarmChain", "mint-carbon-credits", [1, 2024], address1);

//     // Retire credits
//     const { result } = simnet.callPublicFn(
//       "FarmChain",
//       "retire-carbon-credits",
//       [1, 100],
//       address1
//     );
//     expect(result).toBeOk();
//   });

//   it("can get carbon activity data", () => {
//     // Setup activity
//     simnet.callPublicFn("FarmChain", "register-farm", ["Data Farm", "Kansas"], address1);
//     simnet.callPublicFn("FarmChain", "record-carbon-activity", [1, "regenerative", 120, 6, 20], address1);

//     // Get activity data
//     const { result } = simnet.callReadOnlyFn(
//       "FarmChain",
//       "get-carbon-activity",
//       [1],
//       address1
//     );
//     expect(result).toBeSome();
//   });

//   it("can get farm carbon balance", () => {
//     const { result } = simnet.callReadOnlyFn(
//       "FarmChain",
//       "get-farm-carbon-balance",
//       [1],
//       address1
//     );
//     expect(result).toBeOk();
//   });

//   it("can get carbon credit market price", () => {
//     const { result } = simnet.callReadOnlyFn(
//       "FarmChain",
//       "get-carbon-credit-market-price",
//       [2024],
//       address1
//     );
//     expect(result).toBeOk();
//   });

//   it("fails to verify activity without proper verifier registration", () => {
//     simnet.callPublicFn("FarmChain", "register-farm", ["Fail Farm", "Nevada"], address1);
//     simnet.callPublicFn("FarmChain", "record-carbon-activity", [1, "composting", 40, 4, 10], address1);

//     // Try to verify without being registered verifier
//     const { result } = simnet.callPublicFn(
//       "FarmChain",
//       "verify-carbon-activity",
//       [1],
//       address2
//     );
//     expect(result).toBeErr();
//   });

//   it("fails to mint credits from unverified activity", () => {
//     simnet.callPublicFn("FarmChain", "register-farm", ["Unverified Farm", "Alaska"], address1);
//     simnet.callPublicFn("FarmChain", "record-carbon-activity", [1, "wetland-restoration", 80, 20, 50], address1);

//     // Try to mint without verification
//     const { result } = simnet.callPublicFn(
//       "FarmChain",
//       "mint-carbon-credits",
//       [1, 2024],
//       address1
//     );
//     expect(result).toBeErr();
//   });

//   it("fails to transfer more credits than available", () => {
//     // Setup with limited credits
//     simnet.callPublicFn("FarmChain", "register-farm", ["Limited Farm", "Hawaii"], address1);
//     simnet.callPublicFn("FarmChain", "record-carbon-activity", [1, "permaculture", 10, 2, 5], address1);
//     simnet.callPublicFn("FarmChain", "register-verifier", [address2, "Island Verify", "REDD+"], deployer);
//     simnet.callPublicFn("FarmChain", "verify-carbon-activity", [1], address2);
//     simnet.callPublicFn("FarmChain", "mint-carbon-credits", [1, 2024], address1);

//     // Try to transfer more than available (100 total credits, trying 500)
//     const { result } = simnet.callPublicFn(
//       "FarmChain",
//       "transfer-carbon-credits",
//       [1, address2, 500, 30, "sale"],
//       address1
//     );
//     expect(result).toBeErr();
//   });
// });
