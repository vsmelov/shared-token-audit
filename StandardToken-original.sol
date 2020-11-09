pragma solidity ^0.4.15;

import 'zeppelin-solidity/contracts/token/StandardToken.sol';

contract Token is StandardToken {
    event PayDividend(address indexed to, uint256 amount);
    event Deposit(address indexed sender, uint value);

    /// @dev parameters of an extra token emission
    struct EInfo {
        // new totalSupply after emission happened
        uint totalSupply;

        // total balance of Ether stored at the contract when emission happened
        uint totalBalanceWas;
    }

    function Token() public
    {
        m_emissions.push(EmissionInfo({
            totalSupply: totalSupply,
            totalBalanceWas: 0
        }));
    }

    function() external payable {
        if (msg.value > 0) {
            Deposit(msg.sender, msg.value);
            m_totalDividends = m_totalDividends.add(msg.value);
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
            PayDividend(_to, dividends);
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

        uint256 initialBalance = balances[_for];    // beware of recursion!

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
                totalEtherDuringEmission = m_totalDividends.sub(totalBalanceWasWhenLastPay);
            }
            else {
                totalEtherDuringEmission = m_emissions[emissionToProcess.add(1)].totalBalanceWas.sub(totalBalanceWasWhenLastPay);
                totalBalanceWasWhenLastPay = m_emissions[emissionToProcess.add(1)].totalBalanceWas;
            }

            uint256 dividend = totalEtherDuringEmission.mul(initialBalance).div(emission.totalSupply);

            dividends = dividends.add(dividend);
        }

        return (true, dividends);
    }

    function getLastEmissionNum() private constant returns (uint256) {
        return m_emissions.length - 1;
    }

    EInfo[] m_emissions;
    mapping(address => uint256) m_lastAccountEmission;
    mapping(address => uint256) m_lastDividents;
    uint256 m_totalDividends;
}
