pragma solidity ^0.4.15;

import 'https://github.com/aragon/zeppelin-solidity/blob/master/contracts/token/StandardToken.sol';
import 'https://github.com/aragon/zeppelin-solidity/blob/master/contracts/SafeMathLib.sol';

contract Token is StandardToken {
    using SafeMathLib for uint256;
    event PayDividend(address indexed to, uint256 amount);
    event Deposit(address indexed sender, uint value);

    /// @dev parameters of an extra token emission
    struct EInfo {
        // new totalSupply after emission happened
        uint totalSupply;

        // total balance of Ether stored at the contract when emission happened
        uint totalBalanceWas;
    }

    EInfo[] private m_emissions;
    mapping(address => uint256) m_lastAccountEmission;
    mapping(address => uint256) m_lastDividents;
    uint256 m_totalDividends;

    constructor() public
    {
        m_emissions.push(EInfo({
            totalSupply: totalSupply(),
            totalBalanceWas: 0
        }));
    }

    function() external payable {
        if (msg.value > 0) {
            emit Deposit(msg.sender, msg.value);
            m_totalDividends = m_totalDividends.plus(msg.value);
        }
    }

    /// @notice Request dividends for current account.
    function requestDividends() public {
        payDividendsTo(msg.sender);
    }

    /// @notice hook on standard ERC20#transfer to pay dividends
    function transfer(address _to, uint256 _value) public returns (bool) {
        payDividendsTo(msg.sender);
        payDividendsTo(_to);
        return super.transfer(_to, _value);
    }

    /// @notice hook on standard ERC20#transferFrom to pay dividends
    function transferFrom(address _from, address _to, uint256 _value) public returns (bool) {
        payDividendsTo(_from);
        payDividendsTo(_to);
        return super.transferFrom(_from, _to, _value);
    }

    /// @dev adds dividends to the account _to
    function payDividendsTo(address _to) internal {
        var (hasNewDividends, dividends) = calculateDividendsFor(_to);
        if (!hasNewDividends)
            return;

        if (0 != dividends) {
            _to.transfer(dividends);
            emit PayDividend(_to, dividends);
        }

        m_lastAccountEmission[_to] = getLastEmissionNum();
        m_lastDividents[_to] = m_totalDividends;
    }

    function calculateDividendsFor(address _for) constant internal returns (bool hasNewDividends, uint dividends) {
        uint256 lastEmissionNum = getLastEmissionNum();
        uint256 lastAccountEmissionNum = m_lastAccountEmission[_for];
        assert(lastAccountEmissionNum <= lastEmissionNum);

        uint totalBalanceWasWhenLastPay = m_lastDividents[_for];

        assert(m_totalDividends >= totalBalanceWasWhenLastPay);

        // If no new ether was collected since last dividends claim
        if (m_totalDividends == totalBalanceWasWhenLastPay)
            return (false, 0);

        uint256 initialBalance = token.balances[_for];    // beware of recursion!

        // if no tokens owned by account
        if (0 == initialBalance)
            return (true, 0);

        for (uint256 emissionToProcess = lastAccountEmissionNum; emissionToProcess <= lastEmissionNum; emissionToProcess++) {
            EInfo storage emission = m_emissions[emissionToProcess];

            if (0 == emission.totalSupply)
                continue;

            uint totalEtherDuringEmission;
            // last emission we stopped on
            if (emissionToProcess == lastEmissionNum) {
                totalEtherDuringEmission = 0;
                totalEtherDuringEmission = m_totalDividends.minus(totalBalanceWasWhenLastPay);
            }
            else {
                totalEtherDuringEmission = m_emissions[emissionToProcess.plus(1)].totalBalanceWas.minus(totalBalanceWasWhenLastPay);
                totalBalanceWasWhenLastPay = m_emissions[emissionToProcess.plus(1)].totalBalanceWas;
            }

            uint256 dividend = totalEtherDuringEmission.times(initialBalance) / emission.totalSupply;

            dividends = dividends.plus(dividend);
        }

        return (true, dividends);
    }

    function getLastEmissionNum() private constant returns (uint256) {
        return m_emissions.length - 1;
    }

}
