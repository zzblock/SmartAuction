pragma solidity ^0.4.8;

contract Auction {
    // static
    address public owner;
    uint public bidIncrement;
    uint public startBlock;
    uint public endBlock;
    string public ipfsHash;

    // state variable
    bool public canceled;
    uint public highestBindingBid;
    address public highestBidder;
    mapping(address => uint256) public fundsByBidder;
    bool ownerHasWithdrawn;

    //events
    event LogBid(address bidder, uint bid, address highestBidder, uint highestBid, uint highestBindingBid);
    event LogWithdrawal(address withdrawer, address withdrawalAccount, uint amount);
    event LogCanceled();

    //constructor
    function Auction(address _owner, uint _bidIncrement, uint _startBlock, uint _endBlock, string _ipfsHash) {
        if (_startBlock >= _endBlock) throw;
        if (_startBlock < block.number) throw;
        if (_owner == 0) throw;

        owner = _owner;
        bidIncrement = _bidIncrement;
        startBlock = _startBlock;
        endBlock = _endBlock;
        ipfsHash = _ipfsHash;
    }

    function getHighestBid()
        constant
        returns (uint)
    {
        return fundsByBidder[highestBidder];
    }

    function placeBid()
        payable
        onlyAfterStart
        onlyBeforeEnd
        onlyNotCanceled
        onlyNotOwner
        returns (bool success)
    {
        // reject payments of 0 ETH
        if (msg.value == 0) throw;

        // calculate the user's total bid
        uint newBid = fundsByBidder[msg.sender] + msg.value;

        // if new bid is lower then highestBindingBid
        if (newBid <= highestBindingBid) throw;

        // grab the previous highest bid
        uint highestBid = fundsByBidder[highestBidder];

        fundsByBidder[msg.sender] = newBid;

        if (newBid <= highestBid) {
            // increase the highestBindingBid and leave highestBidder alone.

            highestBindingBid = min(newBid + bidIncrement, highestBid);
        } else {
            // set them new highestBidder and recalculate highestBindingBid.

            if (msg.sender != highestBidder) {
                highestBidder = msg.sender;
                highestBindingBid = min(newBid, highestBid + bidIncrement);
            }
            highestBid = newBid;
        }

        LogBid(msg.sender, newBid, highestBidder, highestBid, highestBindingBid);
        return true;
    }

    function min(uint a, uint b)
        private
        constant
        returns (uint)
    {
        if (a < b) return a;
        return b;
    }

    function cancelAuction()
        onlyOwner
        onlyBeforeEnd
        onlyNotCanceled
        returns (bool success)
    {
        canceled = true;
        LogCanceled();
        return true;
    }

    function withdraw()
        onlyEndedOrCanceled
        returns (bool success)
    {
        address withdrawalAccount;
        uint withdrawalAmount;

        if (canceled) {
            // if the auction was canceled, everyone should simply be allowed to withdraw their funds
            withdrawalAccount = msg.sender;
            withdrawalAmount = fundsByBidder[withdrawalAccount];

        } else {
            // the auction finished without being canceled

            if (msg.sender == owner) {
                // the auction's owner should be allowed to withdraw the highestBindingBid
                withdrawalAccount = highestBidder;
                withdrawalAmount = highestBindingBid;
                ownerHasWithdrawn = true;

            } else if (msg.sender == highestBidder) {
                // the highest bidder should only be allowed to withdraw the difference between their
                // highest bid and the highestBindingBid
                withdrawalAccount = highestBidder;
                if (ownerHasWithdrawn) {
                    withdrawalAmount = fundsByBidder[highestBidder];
                } else {
                    withdrawalAmount = fundsByBidder[highestBidder] - highestBindingBid;
                }

            } else {
                // return funds to other participants
                withdrawalAccount = msg.sender;
                withdrawalAmount = fundsByBidder[withdrawalAccount];
            }
        }

        if (withdrawalAmount == 0) throw;

        fundsByBidder[withdrawalAccount] -= withdrawalAmount;

        // send the funds
        if (!msg.sender.send(withdrawalAmount)) throw;

        LogWithdrawal(msg.sender, withdrawalAccount, withdrawalAmount);

        return true;
    }

    modifier onlyOwner {
        if (msg.sender != owner) throw;
        _;
    }

    modifier onlyNotOwner {
        if (msg.sender == owner) throw;
        _;
    }

    modifier onlyBeforeEnd {
        if (block.number > endBlock) throw;
        _;
    }

    modifier onlyAfterStart {
        if (block.number < startBlock) throw;
        _;
    }

    modifier onlyEndedOrCanceled {
        if (block.number < endBlock && !canceled) throw;
        _;
    }

    modifier onlyNotCanceled {
        if (canceled) throw;
        _;
    }


}


