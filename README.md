# CAIRO LOTO backend protocol (proof-of-concept)

To-Do List:

PART I - TICKETS HANDLER CONTRACT

1. Deploy contract and make end-to-end tests.

2. Refacto tests using more generic setups -> split 'SetupData' into separate Structs for each contract  
   and make fewer setup functions that are reusable for all tests.

3. Add/Complete tests using Events where relevant -> will imply to update setups again.

4. Add storage value for "tickets_limit_per_account" + getter and setter instead of hardcoded value of 10 (not urgent)

---

PART II - LOTTERY ENGINE CONTRACT

1. Get familiar again with Pragma's VRF using my implementation from beginning of this year.

2. Rewrite Lottery Engine contract using current latest cairo version.

3. Implement a shit-ton of tests again, because safety is key!

---

MISC:

1. Update all the codebase using latest cairo prelude/edition = "2023_11" in Scarb.toml (one of major change is the introduction of "pub", but there's more...)
   /!\ THIS MIGHT CAUSE ISSUES BECAUSE OPENZEPPELIN DEPENDENCY IS CURRENTLY USING AN OLD CAIRO PRELUDE/EDITION /!\

2. Refacto/Optimize codebase for gas efficiency + learn as much as possible about all kinds of testing to reinforce protection.
