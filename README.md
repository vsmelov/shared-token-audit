# StandardContract Audit

## Introduction

### General Provisions
StandardContract is an base contract class to create shared ownership token,
when all ETH received by the contract is shared among multiple owners according to the current shares.

Splitting new ETH among hundreds of share-holders would require too much gas, 
so all dividend computations are lazy (computed when explicitly called or as a result of tokens transfer).

### Scope of the Audit

The scope of the audit includes smart contract at 
- https://github.com/vsmelov/shared-token-audit/blob/main/StandardToken-original.sol

Also the contract uses source code from these links (but they were not reviewed) 
- https://github.com/aragon/zeppelin-solidity/blob/master/contracts/token/ERC20Lib.sol
- https://github.com/aragon/zeppelin-solidity/blob/master/contracts/SafeMathLib.sol


## Security Assessment Principles

### Classification of Issues

* COMPILATION: Error on compilation stage.

* CRITICAL: Bugs leading to Ether or token theft, fund access locking or any other loss of Ether/tokens to be transferred to any party (for example, dividends). 

* MAJOR: Bugs that can trigger a contract failure. Further recovery is possible only by manual modification of the contract state or replacement. 

* WARNINGS: Bugs that can break the intended contract logic or expose it to DoS attacks. 

* COMMENTS: Other issues and recommendations reported to/ acknowledged by the team.


### Security Assessment Methodology

One greatest auditor Vladimir Smelov verified the code.

Stages of the audit were as follows:

* Compilation problems investigation.
* "Blind" manual check of the code and its model.  
* Report preparation.


## Detected Issues

### COMPILATION

1. It was necessary to set github import name.

2. It was necessary to move class attributes declarations on the top of the class. 

3. Not `EmissionInfo`, but `EInfo`.

3. Not `uint256 initialBalance = balances[_for];`, but `uint256 initialBalance = token.balances[_for];`

4. Not `totalSupply: totalSupply,`, but `totalSupply: totalSupply(),`.

5. It was necessary to add `import 'https://github.com/aragon/zeppelin-solidity/blob/master/contracts/SafeMathLib.sol';`, 
and use it for uint256 and rename uint256 methods everywhere.

So the modified source code is here - https://github.com/vsmelov/shared-token-audit/blob/main/StandardToken-modified.sol

### CRITICAL

1. Functions transfer/payDividendsTo/calculateDividendsFor re-entrancy problem

    https://solidity.readthedocs.io/en/v0.4.26/security-considerations.html#re-entrancy
    use the Checks-Effects-Interactions pattern.
    
    In function `payDividendsTo` we first do *interaction* and then *effects* what is potentially risky. 

    The problem is (at least) that balance is changed inside super.transfer, 
    but transfer of dividends happens before it. So receiving contract can call payDividendsTo again with an old balance. 

### MAJOR

No major problems found.

### WARNINGS

1. Fallback function requires too much gas (>2300) so it can't be called from other contracts.

2. calculateDividendsFor potentially can consume a lot of gas.

    https://solidity.readthedocs.io/en/v0.4.26/security-considerations.html#gas-limit-and-loops

    So it's better to create limited version of the payDividend function and place limit on maximum number of iterations in for-loop
    so dividends could be payed by dozens.  

3. Division which is used on dividend calculation is not "honest", it round the result to the nearest integer.
    
    It's not a big deal, because rounding to 1 Wei is absolutely enough (less then $0.0000000000001).
    But anyway should be kept in mind. 

### COMMENTS

1. amount and value inconsistency

It's recommended to use the same name everywhere. 

2. Get rid of deprecated syntax.

3. It's better to add more comments on the logic inside `calculateDividendsFor`,
because it's not obvious what is happening inside and that's why it's harder to verify and that's why it's dangerous. 

4. Some unit-tests would be nice.

5. There is still one place where unsafe math is used. The function `getLastEmissionNum`, yeah in current implementation the array is always not empty, but it becomes extremely important requirement if we will remove initial supply from constructor. Maybe it's better to add safeMinus or assert array to be not empty.

6. The check `if (m_totalDividends == totalBalanceWasWhenLastPay)` is better to do with indexes from `m_lastAccountEmission` and `getLastEmissionNum`.

    This is more consistent with the essence of the check.

## CONCLUSION

Provided smart contracts were audited and several troublesome issues were identified:
 - 1 critical issue
 - 3 warnings
 - and also several recommendations
