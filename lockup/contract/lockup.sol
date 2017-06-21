pragma solidity ^0.4.11;

contract owned {
    function owned() { owner = msg.sender; }
    address owner;
    modifier onlyOwner {
        require(msg.sender == owner);
        _;
    }
}

contract LockupContract is owned {
    // members
    uint                            totalBalance;
    uint                            globalDueDate;
    uint                            minDeposit;
    uint                            maxDeposit;

    mapping ( address => uint )     balanceOf;
    mapping ( address => bool )     haveContractOf;
    mapping ( address => bool )     mutexOf;

    address[]                       usersList;

    address                         highestDepositUser;
    uint                            highestDepositBalance;

    // modifiers
    modifier onlyAfter(uint _time) {        require(now >= _time);  _; }
    modifier onlyBefore(uint _time) {       require(now < _time);   _; }
    modifier onlyHaveContract() {           require(haveContractOf[msg.sender]);   _; }
    modifier limitRange() {                 require(msg.value >= (minDeposit * 1 finney) && msg.value <= (maxDeposit * 1 finney)); _; }

    // constructor
    function LockupContract(uint dayAfter, uint min, uint max)
    {
        totalBalance = 0 ;

        minDeposit = min;
        maxDeposit = max;

        highestDepositUser = msg.sender;
        highestDepositBalance = 0;

        globalDueDate = now + dayAfter * 1 days;
    }

    // fallback for donation
    function ()
        payable
    {
        // Thanks for your donation
    }

    // getter functions
    function getBalance()
        constant
        returns (uint balance)
    {
        uint currentBalance = balanceOf[msg.sender];
        return (currentBalance);
    }

    function getRemainTime()
        constant
        returns (bool isRemain, uint remainSecond)
    {
        uint due = globalDueDate;
        uint cur = now;

        if (cur < due)
            return (true, due - cur);
        else
            return (false, 0);
    }

    function getHaveContract()
        constant
        returns (bool doesHave)
    {
        bool have = haveContractOf[msg.sender];
        return have;
    }

    function getTotalBalance()
        constant
        returns (uint balance)
    {
        return (totalBalance);
    }

    function getGlobalDueDate()
        constant
        returns (uint date)
    {
        return globalDueDate;
    }

    function getDepositLimit()
        constant
        returns (uint min, uint max)
    {
        return (minDeposit, maxDeposit);
    }

    function getHighestDeposit()
        constant
        returns (address user, uint balance)
    {
        return (highestDepositUser, highestDepositBalance);
    }

    // main features
    function lockupCoin(bool agreeFee, bool agreeNoduty)
        payable
        limitRange
        onlyBefore(globalDueDate)
        returns (bool success)
    {
        if (!(agreeFee && agreeNoduty)) return false;

        if (mutexOf[msg.sender] == true) return false;
        mutexOf[msg.sender] = true;

        uint balance = balanceOf[msg.sender];
        uint ethereum = msg.value;

        ethereum = ethereum / 1000 * 995;
        balanceOf[msg.sender] = balance + ethereum;
        totalBalance = totalBalance + ethereum;

        if (highestDepositBalance < balance + ethereum)
        {
            highestDepositBalance = balance + ethereum;
            highestDepositUser = msg.sender;
        }

        if (haveContractOf[msg.sender] == false)
        {
            haveContractOf[msg.sender] = true;
        }

        mutexOf[msg.sender] = false;

        return true;
    }

    function withdrawal()
        onlyAfter(globalDueDate)
        returns (bool success)
    {
        if (mutexOf[msg.sender] == true)
        {
            // might be attack
            balanceOf[msg.sender] = 0;
            return false;
        }

        mutexOf[msg.sender] = true;

        if (haveContractOf[msg.sender] == false)
        {
            mutexOf[msg.sender] = false;
            return false;
        }

        haveContractOf[msg.sender] = false;

        uint balance = balanceOf[msg.sender];
        balanceOf[msg.sender] = 0;

        if (balance == 0)
        {
            mutexOf[msg.sender] = false;
            return false;
        }

        if(!msg.sender.send(balance))
        {
            totalBalance = totalBalance - balance;
            mutexOf[msg.sender] = false;

            return false;
        }

        totalBalance = totalBalance - balance;
        mutexOf[msg.sender] = false;

        return true;
    }

    // destroy function
    function destroyContract()
        onlyOwner
    {
        for (uint i = 0 ; i < usersList.length ; i++)
        {
            address userAddr = usersList[i];
            uint balance = balanceOf[userAddr];
            balanceOf[userAddr] = 0 ;
            totalBalance = totalBalance - balance;

            if (balance > 0)
            {
                if (!userAddr.send(balance))
                {
                    // failed
                }
            }
        }

        uint fee = this.balance / 10 * 7;
        owner.transfer(fee);
        selfdestruct(highestDepositUser);
    }
}
