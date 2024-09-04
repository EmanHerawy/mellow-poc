## Mellow LRT POC 

This is a proof of concept for vulnerability in Mellow LRT.

## Vulnerability
- Potential Division-by-Zero Vulnerability in `_processLpAmount(...)` Function
- Deposit and Withdrawal Operations Reverting Due to Asset Debt in vault.sol

## Set up
- add MAINNET_RPC value in  .env file  
- install the dependencies in melow-lrt


If needed : to add mellow to submodules
```shell
 git submodule add https://github.com/mellow-finance/mellow-lrt.git lib/mellow-lrt

 git checkout  1c885ad9a2964ca88ad3e59c3a7411fc0059aa3
 git submodule update --init --recursive


```

## How to Reproduce
POC is added in the `test` folder and can be run using the following command:

 ```bash 
 forge test --fork-url mainnet --fork-block-number 19845261 
 ``` 
- Potential Division-by-Zero Vulnerability in `_processLpAmount(...)` Function
    - `forge test --fork-url mainnet --fork-block-number 19845261 --match-path ./test/ZeroDivisionttack.t.sol`
- Deposit and Withdrawal Operations Reverting Due to Asset Debt in vault.sol
    - `forge test --fork-url mainnet --fork-block-number 19845261 --match-path ./test/DOSTest.t.sol `
